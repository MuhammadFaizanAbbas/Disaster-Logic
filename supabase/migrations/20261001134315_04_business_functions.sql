
-- ============ new auth user -> profile ============
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, email, full_name, phone)
  values (new.id, new.email,
          coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
          new.phone)
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- ============ routing by tier ============
create or replace function private.route_opportunity(p_opp uuid, p_min_tier smallint default 1)
returns int language plpgsql security definer set search_path = '' as $$
declare
  o      public.opportunities;
  svc    public.services;
  v_mins int;
  t      int;
  n      int := 0;
begin
  select * into o from public.opportunities where id = p_opp and status in ('new','offered');
  if not found then return 0; end if;
  select * into svc from public.services where id = o.service_id;
  select tier_timeout_minutes into v_mins from public.workspaces where id = o.workspace_id;

  for t in p_min_tier..3 loop
    insert into public.opportunity_offers (opportunity_id, workspace_id, user_id, tier, expires_at)
    select o.id, ms.workspace_id, ms.user_id, ms.tier, now() + make_interval(mins => v_mins)
    from public.member_services ms
    join public.workspace_members m on m.workspace_id = ms.workspace_id and m.user_id = ms.user_id
    where ms.workspace_id = o.workspace_id and ms.service_id = o.service_id and ms.tier = t
      and m.member_type = 'internal' and m.status = 'active' and m.available_for_scheduling
      and (not svc.requires_verification or ms.verification_status = 'verified')
    on conflict (opportunity_id, user_id) do nothing;
    get diagnostics n = row_count;
    if n > 0 then
      insert into public.notifications (user_id, workspace_id, opportunity_id, title, body)
      select f.user_id, f.workspace_id, o.id, 'New opportunity: ' || svc.name, 'Service ZIP ' || o.postal_code
      from public.opportunity_offers f
      where f.opportunity_id = o.id and f.tier = t and f.status = 'pending';
      update public.opportunities set status = 'offered' where id = o.id;
      return n;
    end if;
  end loop;
  return 0;
end $$;

create or replace function private.on_opportunity_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform private.route_opportunity(new.id, 1::smallint);
  return new;
end $$;
create trigger opportunity_route after insert on public.opportunities
  for each row execute function private.on_opportunity_insert();

-- call from pg_cron every minute (see notes)
create or replace function private.escalate_expired_offers()
returns int language plpgsql security definer set search_path = '' as $$
declare r record; c int := 0;
begin
  update public.opportunity_offers set status = 'expired' where status = 'pending' and expires_at < now();
  for r in
    select o.id, max(f.tier) as maxt
    from public.opportunities o join public.opportunity_offers f on f.opportunity_id = o.id
    where o.status = 'offered'
    group by o.id
    having not bool_or(f.status = 'pending')
  loop
    if r.maxt < 3 then c := c + private.route_opportunity(r.id, (r.maxt + 1)::smallint); end if;
  end loop;
  return c;
end $$;

-- ============ public booking form ============
create or replace function public.get_booking_form(p_public_key text)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'workspace', jsonb_build_object('name', w.name, 'logo_url', w.logo_url, 'timezone', w.timezone),
    'services', coalesce((
      select jsonb_agg(jsonb_build_object('code', s.code, 'name', s.name, 'description', s.description,
                                          'tag', s.tag, 'response_label', s.response_label) order by s.sort_order, s.name)
      from public.workspace_services ws join public.services s on s.id = ws.service_id
      where ws.workspace_id = w.id and s.is_active and s.is_bookable), '[]'::jsonb))
  from public.workspaces w where w.public_key = p_public_key and w.is_active
$$;

-- one entry point for BOTH forms. Anonymous / non-member callers => public_form (always public).
-- Internal members of the workspace => internal_form and may choose public/private.
create or replace function public.submit_booking(
  p_public_key text, p_full_name text, p_phone text, p_email text,
  p_postal_code text, p_service_code text,
  p_priority public.dispatch_priority default 'emergency',
  p_damage_notes text default null,
  p_preferred_date date default null, p_preferred_window text default null,
  p_notify_before_hours int default 2,
  p_visibility public.opportunity_visibility default 'public',
  p_address text default null, p_city text default null, p_state text default null,
  p_latitude numeric default null, p_longitude numeric default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  v_ws   public.workspaces;
  v_svc  uuid;
  v_cust uuid;
  v_opp  uuid;
  v_src  public.opportunity_source := 'public_form';
  v_vis  public.opportunity_visibility := 'public';
  v_tok  text;
  v_email text := nullif(lower(trim(p_email)), '');
  v_phone text := nullif(trim(p_phone), '');
begin
  select * into v_ws from public.workspaces where public_key = p_public_key and is_active;
  if not found then raise exception 'Unknown booking form' using errcode = 'P0002'; end if;

  if p_full_name is null or length(trim(p_full_name)) not between 1 and 120 then raise exception 'Full name is required'; end if;
  if v_email is null and v_phone is null then raise exception 'Email or phone is required'; end if;
  if v_email is not null and v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Invalid email'; end if;
  if p_postal_code is null or length(trim(p_postal_code)) not between 3 and 10 then raise exception 'A valid ZIP / postal code is required'; end if;
  if p_damage_notes is not null and length(p_damage_notes) > 4000 then raise exception 'Notes are too long'; end if;
  if p_priority = 'scheduled' and (p_preferred_date is null or p_preferred_window is null) then
    raise exception 'Scheduled requests need a date and arrival window';
  end if;
  if p_preferred_date is not null and p_preferred_date < current_date - 1 then raise exception 'Preferred date is in the past'; end if;

  select s.id into v_svc
  from public.services s join public.workspace_services ws on ws.service_id = s.id and ws.workspace_id = v_ws.id
  where s.code = p_service_code and s.is_active;
  if v_svc is null then raise exception 'Service not offered by this workspace'; end if;

  if v_uid is not null and private.is_internal_member(v_ws.id) then
    v_src := 'internal_form';
    v_vis := p_visibility;
  end if;

  -- crude abuse guard for the anonymous form
  if v_src = 'public_form' and (
       select count(*) from public.opportunities o join public.customers c on c.id = o.customer_id
       where o.workspace_id = v_ws.id and o.created_at > now() - interval '1 hour'
         and ((v_email is not null and lower(c.email) = v_email) or (v_phone is not null and c.phone = v_phone))) >= 5 then
    raise exception 'Too many requests, please try again later';
  end if;

  if v_email is not null then
    insert into public.customers (workspace_id, full_name, phone, email)
    values (v_ws.id, trim(p_full_name), v_phone, v_email)
    on conflict (workspace_id, lower(email)) where email is not null
    do update set updated_at = now()          -- never let an anonymous caller overwrite existing customer data
    returning id into v_cust;
  else
    select id into v_cust from public.customers where workspace_id = v_ws.id and phone = v_phone limit 1;
    if v_cust is null then
      insert into public.customers (workspace_id, full_name, phone) values (v_ws.id, trim(p_full_name), v_phone) returning id into v_cust;
    end if;
  end if;

  insert into public.opportunities (
    workspace_id, customer_id, service_id, source, visibility, priority, postal_code, address, city, state,
    latitude, longitude, damage_notes, preferred_date, preferred_window, notify_before_hours, created_by)
  values (
    v_ws.id, v_cust, v_svc, v_src, v_vis, p_priority, trim(p_postal_code), p_address, p_city, p_state,
    p_latitude, p_longitude, p_damage_notes, p_preferred_date, p_preferred_window,
    greatest(0, least(48, coalesce(p_notify_before_hours, 2)))::smallint,
    case when v_src = 'internal_form' then v_uid end)
  returning id into v_opp;

  insert into private.upload_tokens (opportunity_id) values (v_opp) returning token into v_tok;
  return jsonb_build_object('opportunity_id', v_opp, 'upload_token', v_tok);
end $$;

-- register an uploaded file (path must be  <opportunity_id>/<upload_token>/<file>)
create or replace function public.attach_media(
  p_opportunity uuid, p_token text, p_path text, p_file_name text, p_mime text, p_size bigint)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if not exists (select 1 from private.upload_tokens t
                 where t.opportunity_id = p_opportunity and t.token = p_token and t.expires_at > now()) then
    raise exception 'Upload link expired' using errcode = '42501';
  end if;
  if p_path not like p_opportunity::text || '/' || p_token || '/%' then
    raise exception 'Invalid file path' using errcode = '42501';
  end if;
  insert into public.opportunity_media (opportunity_id, storage_path, file_name, mime_type, size_bytes)
  values (p_opportunity, p_path, p_file_name, p_mime, p_size) returning id into v_id;
  return v_id;
end $$;

create or replace function private.valid_upload_path(p_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.upload_tokens t
                 where t.opportunity_id::text = (storage.foldername(p_name))[1]
                   and t.token = (storage.foldername(p_name))[2]
                   and t.expires_at > now())
$$;

-- ============ accept / decline ============
create or replace function public.accept_opportunity(p_opportunity uuid, p_workspace uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid  uuid := (select auth.uid());
  o      public.opportunities;
  w      public.workspaces;
  v_ws   uuid;
  v_proj uuid;
  v_start timestamptz;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select * into o from public.opportunities where id = p_opportunity for update;
  if not found then raise exception 'Opportunity not found' using errcode = 'P0002'; end if;
  if o.status not in ('new','offered') then raise exception 'This opportunity is no longer available'; end if;

  v_ws := coalesce(p_workspace, o.workspace_id);
  if not private.is_internal_member(v_ws) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if v_ws <> o.workspace_id then
    if o.visibility <> 'public' or not exists (
         select 1 from public.workspace_services s
         join public.workspace_locations l on l.workspace_id = s.workspace_id and o.postal_code = any (l.postal_codes)
         where s.workspace_id = v_ws and s.service_id = o.service_id) then
      raise exception 'This workspace cannot take this opportunity' using errcode = '42501';
    end if;
  end if;

  select * into w from public.workspaces where id = v_ws and is_active;
  if not found then raise exception 'Workspace inactive'; end if;
  if o.preferred_date is not null and o.preferred_window is not null then
    v_start := (o.preferred_date + split_part(o.preferred_window, '-', 1)::time) at time zone w.timezone;
  end if;

  insert into public.projects (opportunity_id, workspace_id, customer_id, service_id, assigned_to, scheduled_start)
  values (o.id, v_ws, o.customer_id, o.service_id, v_uid, v_start)
  returning id into v_proj;
  insert into public.project_members (project_id, user_id, role, added_by) values (v_proj, v_uid, 'assignee', v_uid);

  update public.opportunities
     set status = 'accepted', accepted_by = v_uid, accepted_workspace_id = v_ws, accepted_at = now()
   where id = o.id;
  update public.opportunity_offers set status = 'accepted', responded_at = now()
   where opportunity_id = o.id and user_id = v_uid and status = 'pending';
  update public.opportunity_offers set status = 'withdrawn', responded_at = now()
   where opportunity_id = o.id and status = 'pending';

  if o.created_by is not null and o.created_by <> v_uid then
    insert into public.notifications (user_id, workspace_id, project_id, opportunity_id, title)
    values (o.created_by, v_ws, v_proj, o.id, 'Your opportunity was accepted');
  end if;
  return v_proj;
end $$;

create or replace function public.decline_offer(p_offer uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare f public.opportunity_offers;
begin
  update public.opportunity_offers set status = 'declined', responded_at = now()
   where id = p_offer and user_id = (select auth.uid()) and status = 'pending'
  returning * into f;
  if not found then return; end if;
  if not exists (select 1 from public.opportunity_offers where opportunity_id = f.opportunity_id and status = 'pending')
     and f.tier < 3 then
    perform private.route_opportunity(f.opportunity_id, (f.tier + 1)::smallint);
  end if;
end $$;

-- ============ referrals ============
-- stop clients from tampering with invite state; only security-definer functions may move it forward
create or replace function private.guard_invite_update()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('authenticated','anon') then
    if new.token is distinct from old.token or new.project_id is distinct from old.project_id
       or new.workspace_id is distinct from old.workspace_id or new.claimed_by is distinct from old.claimed_by
       or new.claimed_at is distinct from old.claimed_at or new.invited_by is distinct from old.invited_by then
      raise exception 'Protected column' using errcode = '42501';
    end if;
    if new.status is distinct from old.status and new.status not in ('link_sent','revoked') then
      raise exception 'Status can only be changed to link_sent or revoked' using errcode = '42501';
    end if;
    if old.status in ('accepted','in_progress','finished') and new.status = 'link_sent' then
      raise exception 'Invite already used' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
create trigger guard_invite_update before update on public.referral_invites
  for each row execute function private.guard_invite_update();

-- what the invitee sees BEFORE signing in (no customer contact details)
create or replace function public.preview_referral(p_token text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare i public.referral_invites; r jsonb;
begin
  select * into i from public.referral_invites where token = p_token;
  if not found or i.status in ('revoked','expired','draft') or i.expires_at < now() then return null; end if;
  if i.status = 'link_sent' then
    update public.referral_invites set status = 'viewed', viewed_at = now() where id = i.id;
  end if;
  select jsonb_build_object(
    'status', case when i.status = 'link_sent' then 'viewed' else i.status end,
    'invitee_name', i.invitee_name, 'target', i.target,
    'workspace', w.name, 'workspace_logo', w.logo_url,
    'service', s.name, 'postal_code', o.postal_code, 'city', o.city, 'priority', o.priority,
    'preferred_date', o.preferred_date, 'preferred_window', o.preferred_window,
    'payout_amount', i.payout_amount, 'special_instructions', i.special_instructions,
    'expires_at', i.expires_at)
  into r
  from public.projects p
  join public.opportunities o on o.id = p.opportunity_id
  join public.services s on s.id = p.service_id
  join public.workspaces w on w.id = i.workspace_id
  where p.id = i.project_id;
  return r;
end $$;

-- signed-in invitee claims the link: becomes a 'referral' member of the workspace + participant of ONLY this project
create or replace function public.claim_referral(p_token text, p_workspace uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  i     public.referral_invites;
  v_inv_ws uuid;
begin
  if v_uid is null then raise exception 'Sign in to accept this referral' using errcode = '28000'; end if;
  select * into i from public.referral_invites where token = p_token for update;
  if not found or i.status not in ('link_sent','viewed') or i.expires_at < now() then
    raise exception 'This referral link is invalid or has expired' using errcode = 'P0002';
  end if;
  if i.invited_by = v_uid then raise exception 'You cannot accept your own referral'; end if;
  if i.invitee_email is not null and lower(coalesce((select auth.jwt()->>'email'), '')) <> lower(i.invitee_email) then
    raise exception 'This link was issued to a different email address' using errcode = '42501';
  end if;

  if i.target = 'workspace' then
    v_inv_ws := coalesce(i.invitee_workspace_id, p_workspace);
    if v_inv_ws is null or not private.is_ws_admin(v_inv_ws) then
      raise exception 'Only an admin of the receiving workspace can accept this referral' using errcode = '42501';
    end if;
  end if;

  insert into public.workspace_members (workspace_id, user_id, member_type, role, status, referred_by)
  values (i.workspace_id, v_uid, 'referral', 'member', 'active', i.invited_by)
  on conflict (workspace_id, user_id) do nothing;

  insert into public.project_members (project_id, user_id, role, added_by)
  values (i.project_id, v_uid, 'referral', i.invited_by)
  on conflict (project_id, user_id) do nothing;

  update public.referral_invites
     set status = 'accepted', claimed_by = v_uid, claimed_at = now(),
         invitee_workspace_id = coalesce(v_inv_ws, invitee_workspace_id)
   where id = i.id;

  insert into public.referral_payouts (invite_id, project_id, payee_id, amount, status)
  values (i.id, i.project_id, v_uid, i.payout_amount, 'held')
  on conflict (invite_id) do nothing;

  insert into public.notifications (user_id, workspace_id, project_id, title)
  values (i.invited_by, i.workspace_id, i.project_id, i.invitee_name || ' accepted your referral');
  return i.project_id;
end $$;

-- status changes by assignee / crew / referral / internal staff
create or replace function public.set_project_status(p_project uuid, p_status public.project_status)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  p public.projects;
  v_role public.participant_role;
begin
  select * into p from public.projects where id = p_project for update;
  if not found then raise exception 'Project not found' using errcode = 'P0002'; end if;
  select role into v_role from public.project_members where project_id = p_project and user_id = v_uid;
  if not (private.is_platform_admin() or private.is_internal_member(p.workspace_id) or v_role is not null) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  if v_role = 'referral' and not private.is_internal_member(p.workspace_id) and p_status in ('cancelled','accepted') then
    raise exception 'Referral users cannot set this status' using errcode = '42501';
  end if;
  update public.projects
     set status = p_status,
         completed_at = case when p_status = 'completed' then now() else completed_at end
   where id = p_project;
end $$;

-- keep referral invites + payouts in step with the project
create or replace function private.sync_referrals_on_project_status()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.status is not distinct from old.status then return new; end if;
  if new.status in ('en_route','in_progress','inspection') then
    update public.referral_invites set status = 'in_progress' where project_id = new.id and status = 'accepted';
  elsif new.status = 'completed' then
    update public.referral_invites set status = 'finished' where project_id = new.id and status in ('accepted','in_progress');
    update public.referral_payouts set status = 'pending' where project_id = new.id and status = 'held';
  elsif new.status = 'cancelled' then
    update public.referral_invites set status = 'revoked' where project_id = new.id and status in ('draft','link_sent','viewed','accepted','in_progress');
    update public.referral_payouts set status = 'cancelled' where project_id = new.id and status in ('held','pending');
  end if;
  return new;
end $$;
create trigger project_status_sync after update of status on public.projects
  for each row execute function private.sync_referrals_on_project_status();

