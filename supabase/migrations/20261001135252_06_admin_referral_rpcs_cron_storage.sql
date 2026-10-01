-- ============ create_workspace (platform admin only) ============
create or replace function public.create_workspace(
  p_name text, p_slug text, p_admin_email text default null,
  p_service_ids uuid[] default '{}'::uuid[], p_timezone text default 'America/Chicago')
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_ws public.workspaces; v_admin uuid;
begin
  if not private.is_platform_admin() then
    raise exception 'Only a platform admin can create workspaces' using errcode = '42501';
  end if;
  insert into public.workspaces (name, slug, timezone, created_by)
  values (trim(p_name), lower(trim(p_slug)), coalesce(p_timezone, 'America/Chicago'), v_uid)
  returning * into v_ws;

  if coalesce(array_length(p_service_ids, 1), 0) > 0 then
    insert into public.workspace_services (workspace_id, service_id)
    select v_ws.id, s.id from public.services s where s.id = any (p_service_ids)
    on conflict do nothing;
  end if;

  if nullif(trim(p_admin_email), '') is not null then
    select id into v_admin from public.profiles where lower(email) = lower(trim(p_admin_email));
    if v_admin is null then
      raise exception 'No account found for %. Ask them to sign up first.', p_admin_email using errcode = 'P0002';
    end if;
    insert into public.workspace_members (workspace_id, user_id, member_type, role, status)
    values (v_ws.id, v_admin, 'internal', 'admin', 'active');
  end if;
  return jsonb_build_object('id', v_ws.id, 'slug', v_ws.slug, 'public_key', v_ws.public_key);
end $$;

-- ============ add_workspace_member (workspace admin / platform admin) ============
create or replace function public.add_workspace_member(
  p_workspace uuid, p_email text, p_role public.workspace_role default 'member', p_job_title text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid;
begin
  if not (private.is_ws_admin(p_workspace) or private.is_platform_admin()) then
    raise exception 'Only a workspace admin can add members' using errcode = '42501';
  end if;
  select id into v_user from public.profiles where lower(email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account found for %. Ask them to sign up first, then add them again.', p_email using errcode = 'P0002';
  end if;
  insert into public.workspace_members (workspace_id, user_id, member_type, role, status, job_title)
  values (p_workspace, v_user, 'internal', p_role, 'active', nullif(trim(p_job_title), ''))
  on conflict (workspace_id, user_id) do update
    set member_type = 'internal', role = excluded.role, status = 'active',
        job_title = coalesce(excluded.job_title, public.workspace_members.job_title);
  return v_user;
end $$;

-- ============ set_member_services: [{"service_id": "...", "tier": 1}, ...] ============
create or replace function public.set_member_services(p_workspace uuid, p_user uuid, p_items jsonb)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not (private.is_ws_admin(p_workspace) or private.is_platform_admin()) then
    raise exception 'Only a workspace admin can change member services' using errcode = '42501';
  end if;
  if not exists (select 1 from public.workspace_members where workspace_id = p_workspace and user_id = p_user and member_type = 'internal') then
    raise exception 'User is not an internal member of this workspace' using errcode = 'P0002';
  end if;
  delete from public.member_services
   where workspace_id = p_workspace and user_id = p_user
     and service_id not in (select (e->>'service_id')::uuid from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e);
  insert into public.member_services (workspace_id, user_id, service_id, tier)
  select p_workspace, p_user, (e->>'service_id')::uuid, greatest(1, least(3, coalesce((e->>'tier')::int, 1)))::smallint
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e
  join public.workspace_services ws on ws.workspace_id = p_workspace and ws.service_id = (e->>'service_id')::uuid
  on conflict (workspace_id, user_id, service_id) do update set tier = excluded.tier;
end $$;

-- ============ create_referral (workspace admin OR internal user) ============
create or replace function public.create_referral(
  p_project uuid, p_target public.referral_target, p_name text, p_email text default null, p_phone text default null,
  p_workspace uuid default null, p_payout numeric default 0, p_instructions text default null, p_send boolean default true)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_ws uuid; v_status public.project_status; v_row public.referral_invites;
begin
  if v_uid is null then raise exception 'Not authenticated' using errcode = '28000'; end if;
  select workspace_id, status into v_ws, v_status from public.projects where id = p_project;
  if v_ws is null then raise exception 'Project not found' using errcode = 'P0002'; end if;
  if not private.is_internal_member(v_ws) then raise exception 'Not allowed' using errcode = '42501'; end if;
  if v_status in ('completed', 'cancelled') then raise exception 'This project is already closed'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'Contractor name is required'; end if;
  if nullif(trim(p_email), '') is null and nullif(trim(p_phone), '') is null then
    raise exception 'Email or phone is required so the link can be sent';
  end if;
  if coalesce(p_payout, 0) < 0 then raise exception 'Payout cannot be negative'; end if;

  insert into public.referral_invites (project_id, workspace_id, invited_by, target, invitee_name, invitee_email,
                                       invitee_phone, invitee_workspace_id, payout_amount, special_instructions, status)
  values (p_project, v_ws, v_uid, p_target, trim(p_name), nullif(lower(trim(p_email)), ''), nullif(trim(p_phone), ''),
          p_workspace, coalesce(p_payout, 0), nullif(trim(p_instructions), ''),
          case when p_send then 'link_sent'::public.referral_status else 'draft'::public.referral_status end)
  returning * into v_row;
  return jsonb_build_object('id', v_row.id, 'token', v_row.token, 'status', v_row.status, 'expires_at', v_row.expires_at);
end $$;

-- ============ assign_project (reassign to another internal member) ============
create or replace function public.assign_project(p_project uuid, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); p public.projects;
begin
  select * into p from public.projects where id = p_project for update;
  if not found then raise exception 'Project not found' using errcode = 'P0002'; end if;
  if not private.is_internal_member(p.workspace_id) then raise exception 'Not allowed' using errcode = '42501'; end if;
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
end $$;

-- ============ mark_notifications_read ============
create or replace function public.mark_notifications_read(p_ids uuid[] default null)
returns integer language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  update public.notifications set read_at = now()
   where user_id = (select auth.uid()) and read_at is null and (p_ids is null or id = any (p_ids));
  get diagnostics n = row_count;
  return n;
end $$;

-- ============ dashboard_stats (SECURITY INVOKER so RLS decides what you can count) ============
create or replace function public.dashboard_stats(p_workspace uuid default null)
returns jsonb language sql stable security invoker set search_path = '' as $$
  select jsonb_build_object(
    'open_opportunities', (select count(*) from public.opportunities where status in ('new','offered')),
    'active_projects',    (select count(*) from public.projects where status not in ('completed','cancelled') and (p_workspace is null or workspace_id = p_workspace)),
    'completed_projects', (select count(*) from public.projects where status = 'completed' and (p_workspace is null or workspace_id = p_workspace)),
    'pipeline_value',     (select coalesce(sum(scope_estimate),0) from public.projects where status not in ('completed','cancelled') and (p_workspace is null or workspace_id = p_workspace)),
    'completed_value',    (select coalesce(sum(scope_estimate),0) from public.projects where status = 'completed' and (p_workspace is null or workspace_id = p_workspace)))
$$;

-- ============ grants: signed-in users only ============
revoke all on function public.create_workspace(text,text,text,uuid[],text) from public, anon;
revoke all on function public.add_workspace_member(uuid,text,public.workspace_role,text) from public, anon;
revoke all on function public.set_member_services(uuid,uuid,jsonb) from public, anon;
revoke all on function public.create_referral(uuid,public.referral_target,text,text,text,uuid,numeric,text,boolean) from public, anon;
revoke all on function public.assign_project(uuid,uuid) from public, anon;
revoke all on function public.mark_notifications_read(uuid[]) from public, anon;
revoke all on function public.dashboard_stats(uuid) from public, anon;
grant execute on function public.create_workspace(text,text,text,uuid[],text) to authenticated;
grant execute on function public.add_workspace_member(uuid,text,public.workspace_role,text) to authenticated;
grant execute on function public.set_member_services(uuid,uuid,jsonb) to authenticated;
grant execute on function public.create_referral(uuid,public.referral_target,text,text,text,uuid,numeric,text,boolean) to authenticated;
grant execute on function public.assign_project(uuid,uuid) to authenticated;
grant execute on function public.mark_notifications_read(uuid[]) to authenticated;
grant execute on function public.dashboard_stats(uuid) to authenticated;

-- ============ storage: media readable only by people who can see the opportunity ============
drop policy if exists opp_media_read on storage.objects;
create policy opp_media_read on storage.objects for select to authenticated
using (bucket_id = 'opportunity-media'
       and exists (select 1 from public.opportunity_media m where m.storage_path = objects.name));

-- ============ schedule tier escalation (every minute) ============
create extension if not exists pg_cron;
select cron.schedule('escalate-expired-offers', '* * * * *', $$select private.escalate_expired_offers()$$);
