-- ===== columns the Customers / Projects screens need =====
alter table public.opportunities add column if not exists cause text check (length(cause) <= 200);
alter table public.customers add column if not exists property_type text check (property_type in ('residential','commercial'));
alter table public.projects add column if not exists payment_status public.payment_status not null default 'pending';

-- ===== contact rule: only an individual referral needs email/phone =====
do $$ declare c text; begin
  for c in select conname from pg_constraint
           where conrelid = 'public.referral_invites'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%invitee_phone IS NOT NULL%' loop
    execute format('alter table public.referral_invites drop constraint %I', c);
  end loop;
end $$;
alter table public.referral_invites add constraint referral_contact_required
  check (target <> 'individual' or invitee_email is not null or invitee_phone is not null);

-- one accepted referral per project
create unique index if not exists one_active_referral_per_project
  on public.referral_invites (project_id) where status in ('accepted','in_progress');

-- ===== shared "referral accepted" logic =====
create or replace function private.complete_referral(p_invite uuid, p_user uuid, p_ws uuid)
returns uuid language plpgsql security definer set search_path = '' as $$
declare i public.referral_invites;
begin
  select * into i from public.referral_invites where id = p_invite for update;
  if exists (select 1 from public.referral_invites
             where project_id = i.project_id and id <> i.id and status in ('accepted','in_progress')) then
    raise exception 'This project already has an accepted referral';
  end if;
  insert into public.workspace_members (workspace_id, user_id, member_type, role, status, referred_by)
  values (i.workspace_id, p_user, 'referral', 'member', 'active', i.invited_by)
  on conflict (workspace_id, user_id) do nothing;
  insert into public.project_members (project_id, user_id, role, added_by)
  values (i.project_id, p_user, 'referral', i.invited_by)
  on conflict (project_id, user_id) do nothing;
  update public.referral_invites
     set status = 'accepted', claimed_by = p_user, claimed_at = now(),
         invitee_workspace_id = coalesce(p_ws, invitee_workspace_id)
   where id = i.id;
  update public.referral_invites set status = 'revoked'
   where project_id = i.project_id and id <> i.id and status in ('draft','link_sent','viewed');
  insert into public.referral_payouts (invite_id, project_id, payee_id, amount, status)
  values (i.id, i.project_id, p_user, i.payout_amount, 'held')
  on conflict (invite_id) do nothing;
  insert into public.notifications (user_id, workspace_id, project_id, title)
  values (i.invited_by, i.workspace_id, i.project_id, i.invitee_name || ' accepted your referral');
  return i.project_id;
end $$;

-- ===== claim by private link (individual / workspace) =====
create or replace function public.claim_referral(p_token text, p_workspace uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); i public.referral_invites; v_inv_ws uuid;
begin
  if v_uid is null then raise exception 'Sign in to accept this referral' using errcode = '28000'; end if;
  select * into i from public.referral_invites where token = p_token for update;
  if not found or i.status not in ('link_sent','viewed') or i.expires_at < now() then
    raise exception 'This referral link is invalid or has expired' using errcode = 'P0002';
  end if;
  if i.target = 'opportunities' then raise exception 'This referral is listed on the Opportunities board'; end if;
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
  return private.complete_referral(i.id, v_uid, v_inv_ws);
end $$;

-- ===== accept from the board / incoming list (no link needed) =====
create or replace function public.accept_referral_listing(p_invite uuid, p_workspace uuid default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); i public.referral_invites; p public.projects; o public.opportunities; v_ws uuid;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select * into i from public.referral_invites where id = p_invite for update;
  if not found or i.status not in ('link_sent','viewed') or i.expires_at < now() then
    raise exception 'This referral is no longer available' using errcode = 'P0002';
  end if;
  if i.invited_by = v_uid then raise exception 'You cannot accept your own referral'; end if;
  select * into p from public.projects where id = i.project_id;
  select * into o from public.opportunities where id = p.opportunity_id;
  if i.target = 'workspace' then
    v_ws := i.invitee_workspace_id;
    if v_ws is null or not private.is_ws_admin(v_ws) then
      raise exception 'Only an admin of the receiving workspace can accept this' using errcode = '42501';
    end if;
  elsif i.target = 'opportunities' then
    v_ws := p_workspace;
    if v_ws is null or v_ws = i.workspace_id or not private.is_internal_member(v_ws) or not exists (
         select 1 from public.workspaces w
         join public.workspace_services s on s.workspace_id = w.id and s.service_id = p.service_id
         join public.workspace_locations l on l.workspace_id = w.id and o.postal_code = any (l.postal_codes)
         where w.id = v_ws and w.is_active) then
      raise exception 'Your workspace does not cover this service and area' using errcode = '42501';
    end if;
  else
    raise exception 'This referral must be accepted from its private link';
  end if;
  return private.complete_referral(i.id, v_uid, v_ws);
end $$;

-- ===== create_referral: individual | workspace | opportunities =====
create or replace function public.create_referral(
  p_project uuid, p_target public.referral_target, p_name text, p_email text default null, p_phone text default null,
  p_workspace uuid default null, p_payout numeric default 0, p_instructions text default null, p_send boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_ws uuid; v_status public.project_status; v_row public.referral_invites;
  v_name text; v_email text := nullif(lower(trim(p_email)), ''); v_phone text := nullif(trim(p_phone), '');
  v_svc text; v_target_ws uuid := p_workspace;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select workspace_id, status into v_ws, v_status from public.projects where id = p_project;
  if v_ws is null then raise exception 'Project not found' using errcode = 'P0002'; end if;
  if not private.is_internal_member(v_ws) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if v_status in ('completed','cancelled') then raise exception 'This project is already closed'; end if;
  if exists (select 1 from public.referral_invites where project_id = p_project and status in ('accepted','in_progress')) then
    raise exception 'This project already has an accepted referral';
  end if;
  if coalesce(p_payout, 0) < 0 then raise exception 'Payout cannot be negative'; end if;
  if v_email is not null and v_email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Invalid email'; end if;

  if p_target = 'individual' then
    if nullif(trim(p_name), '') is null then raise exception 'Contractor name is required'; end if;
    if v_email is null and v_phone is null then raise exception 'Email or phone is required so the link can be sent'; end if;
    v_name := trim(p_name); v_target_ws := null;
  elsif p_target = 'workspace' then
    if v_target_ws is null or v_target_ws = v_ws
       or not exists (select 1 from public.workspaces where id = v_target_ws and is_active) then
      raise exception 'Choose a different, active workspace to receive this project';
    end if;
    v_name := coalesce(nullif(trim(p_name), ''), (select name from public.workspaces where id = v_target_ws));
  else
    v_name := coalesce(nullif(trim(p_name), ''), 'Open listing'); v_target_ws := null;
  end if;

  insert into public.referral_invites (project_id, workspace_id, invited_by, target, invitee_name, invitee_email,
                                       invitee_phone, invitee_workspace_id, payout_amount, special_instructions, status)
  values (p_project, v_ws, v_uid, p_target, v_name, v_email, v_phone, v_target_ws, coalesce(p_payout, 0),
          nullif(trim(p_instructions), ''),
          case when p_send then 'link_sent'::public.referral_status else 'draft'::public.referral_status end)
  returning * into v_row;

  if p_send and p_target = 'workspace' then
    select s.name into v_svc from public.projects p join public.services s on s.id = p.service_id where p.id = p_project;
    insert into public.notifications (user_id, workspace_id, project_id, title, body)
    select m.user_id, v_target_ws, null, 'Referral offered: ' || coalesce(v_svc, 'project'),
           'A workspace wants to refer you a project. Open Opportunities to accept.'
    from public.workspace_members m
    where m.workspace_id = v_target_ws and m.member_type = 'internal' and m.role = 'admin' and m.status = 'active';
  end if;
  return jsonb_build_object('id', v_row.id, 'token', v_row.token, 'status', v_row.status,
                            'target', v_row.target, 'expires_at', v_row.expires_at);
end $$;

-- ===== board: workspace referrals sent to my workspace + public listings I can take =====
create or replace function public.referral_board()
returns jsonb language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.created_at desc), '[]'::jsonb) from (
    select i.id, i.target, i.created_at, i.expires_at, i.payout_amount, i.special_instructions,
           w.name as from_workspace, s.name as service, o.postal_code, o.city, o.state, o.priority,
           o.preferred_date, o.preferred_window,
           case when i.target = 'workspace' then jsonb_build_array(i.invitee_workspace_id)
                else (select coalesce(jsonb_agg(m.workspace_id), '[]'::jsonb)
                      from public.workspace_members m
                      join public.workspaces mw on mw.id = m.workspace_id and mw.is_active
                      join public.workspace_services ws on ws.workspace_id = m.workspace_id and ws.service_id = p.service_id
                      join public.workspace_locations l on l.workspace_id = m.workspace_id and o.postal_code = any (l.postal_codes)
                      where m.user_id = (select auth.uid()) and m.member_type = 'internal' and m.status = 'active'
                        and m.workspace_id <> i.workspace_id) end as eligible_workspaces
    from public.referral_invites i
    join public.projects p on p.id = i.project_id
    join public.opportunities o on o.id = p.opportunity_id
    join public.services s on s.id = p.service_id
    join public.workspaces w on w.id = i.workspace_id
    where i.status in ('link_sent','viewed') and i.expires_at > now()
      and p.status not in ('completed','cancelled')
      and i.invited_by <> (select auth.uid())
      and ((i.target = 'workspace' and private.is_ws_admin(i.invitee_workspace_id))
        or (i.target = 'opportunities' and exists (
              select 1 from public.workspace_members m
              join public.workspaces mw on mw.id = m.workspace_id and mw.is_active
              join public.workspace_services ws on ws.workspace_id = m.workspace_id and ws.service_id = p.service_id
              join public.workspace_locations l on l.workspace_id = m.workspace_id and o.postal_code = any (l.postal_codes)
              where m.user_id = (select auth.uid()) and m.member_type = 'internal' and m.status = 'active'
                and m.workspace_id <> i.workspace_id)))
    order by i.created_at desc limit 100) r
$$;

-- ===== previously used referral contacts (dropdown) =====
create or replace function public.list_referral_contacts(p_workspace uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not (private.is_internal_member(p_workspace) or private.is_platform_admin()) then
    raise exception 'Not allowed' using errcode = '42501';
  end if;
  return (select coalesce(jsonb_agg(to_jsonb(c) order by c.invitee_name), '[]'::jsonb) from (
    select distinct on (coalesce(lower(invitee_email), invitee_phone))
           invitee_name, invitee_email, invitee_phone, (claimed_by is not null) as has_account, payout_amount as last_payout
    from public.referral_invites
    where workspace_id = p_workspace and target = 'individual'
    order by coalesce(lower(invitee_email), invitee_phone), created_at desc) c);
end $$;

-- ===== workspaces I can refer to =====
create or replace function public.workspace_directory()
returns jsonb language sql stable security definer set search_path = '' as $$
  select case when exists (select 1 from public.workspace_members where user_id = (select auth.uid()) and member_type = 'internal' and status = 'active')
              or private.is_platform_admin()
         then (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', name, 'slug', slug) order by name), '[]'::jsonb)
               from public.workspaces where is_active)
         else '[]'::jsonb end
$$;

-- ===== grants =====
revoke all on function public.claim_referral(text, uuid) from public, anon;
revoke all on function public.accept_referral_listing(uuid, uuid) from public, anon;
revoke all on function public.referral_board() from public, anon;
revoke all on function public.list_referral_contacts(uuid) from public, anon;
revoke all on function public.workspace_directory() from public, anon;
revoke all on function public.create_referral(uuid, public.referral_target, text, text, text, uuid, numeric, text, boolean) from public, anon;
revoke all on function private.complete_referral(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.claim_referral(text, uuid) to authenticated;
grant execute on function public.accept_referral_listing(uuid, uuid) to authenticated;
grant execute on function public.referral_board() to authenticated;
grant execute on function public.list_referral_contacts(uuid) to authenticated;
grant execute on function public.workspace_directory() to authenticated;
grant execute on function public.create_referral(uuid, public.referral_target, text, text, text, uuid, numeric, text, boolean) to authenticated;
