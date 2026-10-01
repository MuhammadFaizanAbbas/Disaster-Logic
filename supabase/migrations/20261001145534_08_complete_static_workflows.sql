alter table public.customers drop constraint customers_email_check;
alter table public.customers add constraint customers_email_check check(email is null or email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$');
alter table public.referral_invites drop constraint referral_invites_invitee_email_check;
alter table public.referral_invites add constraint referral_invites_invitee_email_check check(invitee_email is null or invitee_email ~* '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$');
-- Workflow columns may only be mutated by guarded RPCs, never arbitrary REST writes.
revoke insert,update,delete on public.opportunities,public.projects,public.project_members,public.referral_invites,public.opportunity_media from authenticated;
revoke update on public.profiles from authenticated;
grant update(full_name,phone,avatar_url) on public.profiles to authenticated;
revoke update on public.notifications from authenticated;
grant update(read_at) on public.notifications to authenticated;
revoke insert,update,delete on public.customers from authenticated;
create index if not exists notifications_user_history_idx on public.notifications(user_id,created_at desc);
create index if not exists project_members_project_role_idx on public.project_members(project_id,role);
create index if not exists referral_invites_board_idx on public.referral_invites(target,expires_at) where status in ('link_sent','viewed');


create or replace function private.is_project_participant(pid uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.project_members pm join public.projects p on p.id=pm.project_id
 join public.workspace_members m on m.workspace_id=p.workspace_id and m.user_id=pm.user_id
 where pm.project_id=pid and pm.user_id=(select auth.uid()) and m.status='active') $$;
create or replace function private.can_see_project(pid uuid,ws uuid) returns boolean language sql stable security definer set search_path='' as $$
select private.is_platform_admin() or private.is_internal_member(ws) or private.is_project_participant(pid) $$;
drop policy cust_select on public.customers;
create policy cust_select on public.customers for select to authenticated using(
 private.is_internal_member(workspace_id) or private.is_platform_admin()
 or exists(select 1 from public.opportunities o where o.customer_id=customers.id));


CREATE OR REPLACE FUNCTION private.can_see_opportunity(p_id uuid, p_ws uuid, p_svc uuid, p_vis opportunity_visibility, p_zip text, p_status opportunity_status, p_acc_ws uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.is_platform_admin()
      or private.is_internal_member(p_ws)
      or (p_acc_ws is not null and private.is_internal_member(p_acc_ws))
      or exists (select 1 from public.opportunity_offers f where f.opportunity_id = p_id and f.user_id = (select auth.uid()))
      or exists (select 1 from public.projects pr where pr.opportunity_id=p_id and private.is_project_participant(pr.id))
      or (p_vis = 'public' and p_status in ('new','offered') and exists (
            select 1 from public.workspace_members m
            join public.workspaces w on w.id = m.workspace_id and w.is_active
            join public.workspace_services s on s.workspace_id = m.workspace_id and s.service_id = p_svc
            join public.workspace_locations l on l.workspace_id = m.workspace_id and p_zip = any (l.postal_codes)
            where m.user_id = (select auth.uid()) and m.member_type = 'internal' and m.status = 'active'))
$function$
;

CREATE OR REPLACE FUNCTION public.accept_opportunity(p_opportunity uuid, p_workspace uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if not (private.is_internal_member(v_ws) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
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
end $function$
;

CREATE OR REPLACE FUNCTION public.assign_project(p_project uuid, p_user uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := (select auth.uid()); p public.projects;
begin
  select * into p from public.projects where id = p_project for update;
  if not found then raise exception 'Project not found' using errcode = 'P0002'; end if;
  if not (private.is_internal_member(p.workspace_id) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if not exists (select 1 from public.workspace_members where workspace_id = p.workspace_id and user_id = p_user
                 and member_type = 'internal' and status = 'active') then
    raise exception 'That user is not an active internal member of this workspace';
  end if;
  update public.project_members set role = 'crew' where project_id = p_project and role = 'assignee';
  insert into public.project_members (project_id, user_id, role, added_by) values (p_project, p_user, 'assignee', v_uid)
  on conflict (project_id, user_id) do update set role = 'assignee';
  update public.projects set assigned_to = p_user where id = p_project;
  if p_user <> v_uid then
    insert into public.notifications (user_id, workspace_id, project_id, title)
    values (p_user, p.workspace_id, p_project, 'A project was assigned to you');
  end if;
end $function$
;

CREATE OR REPLACE FUNCTION public.create_referral(p_project uuid, p_target referral_target, p_name text, p_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_workspace uuid DEFAULT NULL::uuid, p_payout numeric DEFAULT 0, p_instructions text DEFAULT NULL::text, p_send boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_uid uuid := (select auth.uid());
  v_ws uuid; v_status public.project_status; v_row public.referral_invites;
  v_name text; v_email text := nullif(lower(trim(p_email)), ''); v_phone text := nullif(trim(p_phone), '');
  v_svc text; v_target_ws uuid := p_workspace;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select workspace_id, status into v_ws, v_status from public.projects where id = p_project for update;
  if v_ws is null then raise exception 'Project not found' using errcode = 'P0002'; end if;
  if not (private.is_internal_member(v_ws) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode = '42501'; end if;
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
end $function$
;

CREATE OR REPLACE FUNCTION public.submit_booking(p_public_key text, p_full_name text, p_phone text, p_email text, p_postal_code text, p_service_code text, p_priority dispatch_priority DEFAULT 'emergency'::dispatch_priority, p_damage_notes text DEFAULT NULL::text, p_preferred_date date DEFAULT NULL::date, p_preferred_window text DEFAULT NULL::text, p_notify_before_hours integer DEFAULT 2, p_visibility opportunity_visibility DEFAULT 'public'::opportunity_visibility, p_address text DEFAULT NULL::text, p_city text DEFAULT NULL::text, p_state text DEFAULT NULL::text, p_latitude numeric DEFAULT NULL::numeric, p_longitude numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  if p_preferred_window is not null and p_preferred_window not in ('08:00-12:00','12:00-16:00','16:00-20:00') then raise exception 'Invalid arrival window'; end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then raise exception 'Invalid latitude'; end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then raise exception 'Invalid longitude'; end if;
  if p_preferred_date is not null and p_preferred_date < current_date - 1 then raise exception 'Preferred date is in the past'; end if;

  select s.id into v_svc
  from public.services s join public.workspace_services ws on ws.service_id = s.id and ws.workspace_id = v_ws.id
  where s.code = p_service_code and s.is_active and s.is_bookable;
  if v_svc is null then raise exception 'Service not offered by this workspace'; end if;

  if v_uid is not null and (private.is_internal_member(v_ws.id) or private.is_platform_admin()) then
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
end $function$
;

CREATE OR REPLACE FUNCTION public.claim_referral(p_token text, p_workspace uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := (select auth.uid()); i public.referral_invites; v_inv_ws uuid;
begin
  if v_uid is null then raise exception 'Sign in to accept this referral' using errcode = '28000'; end if;
  select * into i from public.referral_invites where token = p_token;
  if not found or i.status not in ('link_sent','viewed') or i.expires_at < now() then
    raise exception 'This referral link is invalid or has expired' using errcode = 'P0002';
  end if;
  if i.target = 'opportunities' then raise exception 'This referral is listed on the Opportunities board'; end if;
  if i.invited_by = v_uid then raise exception 'You cannot accept your own referral'; end if;
  if i.target='individual' and not exists(select 1 from auth.users u where u.id=v_uid and ((i.invitee_email is not null and lower(u.email)=lower(i.invitee_email) and u.email_confirmed_at is not null) or (i.invitee_email is null and i.invitee_phone=u.phone and u.phone_confirmed_at is not null))) then
    raise exception 'This link was issued to a different email address' using errcode = '42501';
  end if;
  if i.target='workspace' and i.invitee_email is not null and not exists(select 1 from auth.users u where u.id=v_uid and lower(u.email)=lower(i.invitee_email) and u.email_confirmed_at is not null) then raise exception 'This link was issued to a different email' using errcode='42501'; end if;
  if i.target = 'workspace' then
    v_inv_ws := coalesce(i.invitee_workspace_id, p_workspace);
    if v_inv_ws is null or not private.is_ws_admin(v_inv_ws) then
      raise exception 'Only an admin of the receiving workspace can accept this referral' using errcode = '42501';
    end if;
  end if;
  return private.complete_referral(i.id, v_uid, v_inv_ws);
end $function$
;

CREATE OR REPLACE FUNCTION private.complete_referral(p_invite uuid, p_user uuid, p_ws uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare i public.referral_invites;
begin
  select * into i from public.referral_invites where id=p_invite;
  if not found then raise exception 'Referral not found' using errcode='P0002'; end if;
  perform 1 from public.projects where id=i.project_id and status not in ('completed','cancelled') for update;
  if not found then raise exception 'Project is closed' using errcode='P0002'; end if;
  if i.status not in ('link_sent','viewed') or i.expires_at<=now() then raise exception 'Referral is unavailable'; end if;
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
  -- Other listings become ineligible immediately; revocation is done without holding their row locks.

  insert into public.referral_payouts (invite_id, project_id, payee_id, amount, status)
  values (i.id, i.project_id, p_user, i.payout_amount, 'pending')
  on conflict (invite_id) do nothing;
  insert into public.notifications (user_id, workspace_id, project_id, title)
  values (i.invited_by, i.workspace_id, i.project_id, i.invitee_name || ' accepted your referral');
  return i.project_id;
end $function$
;

CREATE OR REPLACE FUNCTION public.accept_referral_listing(p_invite uuid, p_workspace uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_uid uuid := (select auth.uid()); i public.referral_invites; p public.projects; o public.opportunities; v_ws uuid;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select * into i from public.referral_invites where id = p_invite;
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
end $function$
;

create or replace function public.set_project_status(p_project uuid,p_status public.project_status) returns void language plpgsql security definer set search_path='' as $$
declare p public.projects; v_role public.participant_role; allowed boolean;
begin
 if auth.uid() is null then raise exception 'Not authenticated' using errcode='28000'; end if;
 select * into p from public.projects where id=p_project for update;
 if not found then raise exception 'Project not found' using errcode='P0002'; end if;
 select role into v_role from public.project_members where project_id=p_project and user_id=auth.uid();
 if not (private.is_platform_admin() or private.is_internal_member(p.workspace_id) or private.is_project_participant(p_project)) then raise exception 'Not allowed' using errcode='42501'; end if;
 if p.status=p_status then return; end if;
 allowed := case p.status when 'accepted' then p_status in ('en_route','in_progress','cancelled') when 'en_route' then p_status in ('in_progress','cancelled') when 'in_progress' then p_status in ('inspection','cancelled') when 'inspection' then p_status in ('in_progress','completed','cancelled') else false end;
 if not coalesce(allowed,false) then raise exception 'Invalid project status transition'; end if;
 if v_role='referral' and not private.is_internal_member(p.workspace_id) and not private.is_platform_admin() and p_status in ('completed','cancelled') then raise exception 'Workspace must approve completion or cancellation' using errcode='42501'; end if;
 update public.projects set status=p_status,completed_at=case when p_status='completed' then now() else null end where id=p_project;
end $$;

create or replace function public.update_project_details(p_project uuid,p_scope numeric default null,p_billing public.billing_type default null,p_payment public.payment_status default null) returns public.projects language plpgsql security definer set search_path='' as $$
declare p public.projects;
begin
 select * into p from public.projects where id=p_project for update;
 if not found then raise exception 'Project not found' using errcode='P0002'; end if;
 if not (private.is_internal_member(p.workspace_id) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode='42501'; end if;
 if p_payment is not null and not (private.is_ws_admin(p.workspace_id) or private.is_platform_admin()) then raise exception 'Only an admin can change payment state' using errcode='42501'; end if;
 update public.projects set scope_estimate=coalesce(p_scope,scope_estimate),billing_type=coalesce(p_billing,billing_type),payment_status=coalesce(p_payment,payment_status) where id=p_project returning * into p;
 return p;
end $$;

create or replace function public.save_customer(p_workspace uuid,p_name text,p_email text default null,p_phone text default null,p_id uuid default null,p_property_type text default null) returns public.customers language plpgsql security definer set search_path='' as $$
declare c public.customers;
begin
 if not (private.is_internal_member(p_workspace) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode='42501'; end if;
 if nullif(trim(p_name),'') is null or length(p_name)>120 then raise exception 'Name is required (maximum 120 characters)'; end if;
 if p_id is null then
 insert into public.customers(workspace_id,full_name,email,phone,property_type) values(p_workspace,trim(p_name),nullif(lower(trim(p_email)),''),nullif(trim(p_phone),''),p_property_type) returning * into c;
 else
 update public.customers set full_name=trim(p_name),email=nullif(lower(trim(p_email)),''),phone=nullif(trim(p_phone),''),property_type=p_property_type where id=p_id and workspace_id=p_workspace returning * into c;
 if not found then raise exception 'Customer not found' using errcode='P0002'; end if;
 end if;
 return c;
end $$;

create or replace function public.revoke_referral(p_invite uuid) returns void language plpgsql security definer set search_path='' as $$
declare i public.referral_invites;
begin
 select * into i from public.referral_invites where id=p_invite;
 if not found then raise exception 'Referral not found' using errcode='P0002'; end if;
 if not (private.is_internal_member(i.workspace_id) or private.is_platform_admin()) then raise exception 'Not allowed' using errcode='42501'; end if;
 perform 1 from public.projects where id=i.project_id for update;
 if i.status in ('accepted','in_progress','finished') then raise exception 'An accepted referral cannot be revoked; manage the project instead'; end if;
 update public.referral_invites set status='revoked' where id=i.id and status in ('draft','link_sent','viewed');
end $$;

create or replace function public.refer_opportunity(p_opportunity uuid,p_workspace uuid,p_target public.referral_target,p_name text default null,p_email text default null,p_phone text default null,p_target_workspace uuid default null,p_payout numeric default 0,p_instructions text default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare pid uuid; r jsonb;
begin
 pid:=public.accept_opportunity(p_opportunity,p_workspace);
 r:=public.create_referral(pid,p_target,p_name,p_email,p_phone,p_target_workspace,p_payout,p_instructions,true);
 return r||jsonb_build_object('project_id',pid);
end $$;

create or replace function public.dashboard_stats(p_workspace uuid default null) returns jsonb language sql stable security invoker set search_path='' as $$
select jsonb_build_object(
 'open_opportunities',(select count(*) from public.opportunities where status in ('new','offered') and (p_workspace is null or workspace_id=p_workspace)),
 'active_projects',(select count(*) from public.projects where status not in ('completed','cancelled') and (p_workspace is null or workspace_id=p_workspace)),
 'completed_projects',(select count(*) from public.projects where status='completed' and (p_workspace is null or workspace_id=p_workspace)),
 'pipeline_value',(select coalesce(sum(scope_estimate),0) from public.projects where status not in ('completed','cancelled') and (p_workspace is null or workspace_id=p_workspace)),
 'completed_value',(select coalesce(sum(scope_estimate),0) from public.projects where status='completed' and (p_workspace is null or workspace_id=p_workspace))) $$;


CREATE OR REPLACE FUNCTION public.referral_board()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
      and p.status not in ('completed','cancelled') and not exists(select 1 from public.referral_invites a where a.project_id=i.project_id and a.status in ('accepted','in_progress','finished'))
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
$function$
;

-- New RPCs are authenticated APIs with explicit ownership checks.
do $$ declare f record; begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('save_customer','revoke_referral','update_project_details','refer_opportunity') loop
 execute format('revoke all on function %s from public,anon',f.sig);
 execute format('grant execute on function %s to authenticated',f.sig);
 end loop;
end $$;
