
drop policy project_steps_read on public.project_steps;
create policy project_steps_read on public.project_steps for select to authenticated using(private.can_work_project(project_id) and (step not in ('claim','contracts','payments') or private.can_manage_project(project_id)));
create or replace function private.is_internal_member(ws uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.workspace_members m join public.workspaces w on w.id=m.workspace_id and w.is_active where m.workspace_id=ws and m.user_id=(select auth.uid()) and m.member_type='internal' and m.status='active') $$;
create or replace function private.is_ws_admin(ws uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.workspace_members m join public.workspaces w on w.id=m.workspace_id and w.is_active where m.workspace_id=ws and m.user_id=(select auth.uid()) and m.member_type='internal' and m.role='admin' and m.status='active') $$;
-- These joins are also used from storage and REST policies.
create or replace function private.is_project_participant(pid uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.project_members pm join public.projects p on p.id=pm.project_id join public.workspaces w on w.id=p.workspace_id and w.is_active join public.workspace_members m on m.workspace_id=p.workspace_id and m.user_id=pm.user_id where pm.project_id=pid and pm.user_id=(select auth.uid()) and m.status='active') $$;
create or replace function private.sync_auth_identity() returns trigger language plpgsql security definer set search_path='' as $$
begin update public.profiles set email=new.email,phone=coalesce(nullif(new.phone,''),phone) where id=new.id;return new;end $$;
create trigger sync_auth_identity after update of email,phone on auth.users for each row execute function private.sync_auth_identity();
CREATE OR REPLACE FUNCTION public.add_workspace_member(p_workspace uuid, p_email text, p_role workspace_role DEFAULT 'member'::workspace_role, p_job_title text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_user uuid;
begin
  if not (private.is_ws_admin(p_workspace) or private.is_platform_admin()) then
    raise exception 'Only a workspace admin can add members' using errcode = '42501';
  end if;
  perform 1 from public.workspaces where id=p_workspace for update;
  select id into v_user from public.profiles where lower(email) = lower(trim(p_email));
  if v_user is null then
    raise exception 'No account found for %. Ask them to sign up first, then add them again.', p_email using errcode = 'P0002';
  end if;
  if p_role<>'admin' and exists(select 1 from public.workspace_members where workspace_id=p_workspace and user_id=v_user and role='admin' and member_type='internal' and status='active')
   and not exists(select 1 from public.workspace_members where workspace_id=p_workspace and user_id<>v_user and role='admin' and member_type='internal' and status='active') then raise exception 'Keep at least one active workspace admin';end if;
  insert into public.workspace_members (workspace_id, user_id, member_type, role, status, job_title)
  values (p_workspace, v_user, 'internal', p_role, 'active', nullif(trim(p_job_title), ''))
  on conflict (workspace_id, user_id) do update
    set member_type = 'internal', role = excluded.role, status = 'active',
        job_title = coalesce(excluded.job_title, public.workspace_members.job_title);
  return v_user;
end $function$
;
CREATE OR REPLACE FUNCTION private.route_opportunity(p_opp uuid, p_min_tier smallint DEFAULT 1)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  o      public.opportunities;
  svc    public.services; w public.workspaces; local_dt timestamp;
  v_mins int;
  t      int;
  n      int := 0;
begin
  select * into o from public.opportunities where id = p_opp and status in ('new','offered');
  if not found then return 0; end if;
  select * into svc from public.services where id = o.service_id;
  select * into w from public.workspaces where id=o.workspace_id and is_active;
  if not found then return 0;end if;
  v_mins:=w.tier_timeout_minutes;
  local_dt:=case when o.priority='scheduled' then o.preferred_date+split_part(o.preferred_window,'-',1)::time else now() at time zone w.timezone end;

  for t in p_min_tier..3 loop
    insert into public.opportunity_offers (opportunity_id, workspace_id, user_id, tier, expires_at)
    select o.id, ms.workspace_id, ms.user_id, ms.tier, now() + make_interval(mins => v_mins)
    from public.member_services ms
    join public.workspace_members m on m.workspace_id = ms.workspace_id and m.user_id = ms.user_id
    where ms.workspace_id = o.workspace_id and ms.service_id = o.service_id and ms.tier = t
      and m.member_type = 'internal' and m.status = 'active' and m.available_for_scheduling
      and (not exists(select 1 from public.member_availability a where a.workspace_id=ms.workspace_id and a.user_id=ms.user_id)
        or exists(select 1 from public.member_availability a where a.workspace_id=ms.workspace_id and a.user_id=ms.user_id and a.day_of_week=extract(dow from local_dt)::integer and (case when local_dt::time>='09:00' and local_dt::time<'17:00' then a.available_9_5 else a.available_after_hours end)))
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
end $function$
;
CREATE OR REPLACE FUNCTION private.can_see_opportunity(p_id uuid, p_ws uuid, p_svc uuid, p_vis opportunity_visibility, p_zip text, p_status opportunity_status, p_acc_ws uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select private.is_platform_admin()
      or private.is_internal_member(p_ws)
      or (p_acc_ws is not null and private.is_internal_member(p_acc_ws))
      or exists (select 1 from public.opportunity_offers f where f.opportunity_id = p_id and f.user_id = (select auth.uid()) and private.is_internal_member(f.workspace_id))
      or exists(select 1 from public.projects pr where pr.opportunity_id=p_id and private.is_project_participant(pr.id))
      or (p_vis = 'public' and p_status in ('new','offered') and exists (
            select 1 from public.workspace_members m
            join public.workspaces w on w.id = m.workspace_id and w.is_active
            join public.workspace_services s on s.workspace_id = m.workspace_id and s.service_id = p_svc
            join public.workspace_locations l on l.workspace_id = m.workspace_id and p_zip = any (l.postal_codes)
            where m.user_id = (select auth.uid()) and m.member_type = 'internal' and m.status = 'active'))
$function$
;

create or replace function public.attach_media(p_opportunity uuid,p_token text,p_path text,p_file_name text,p_mime text,p_size bigint) returns uuid language plpgsql security definer set search_path='' as $$
declare vid uuid; obj storage.objects;
begin
 if not exists(select 1 from private.upload_tokens where opportunity_id=p_opportunity and token=p_token and expires_at>now()) or left(p_path,length(p_opportunity::text||'/'||p_token||'/'))<>p_opportunity::text||'/'||p_token||'/' then raise exception 'Invalid or expired upload capability' using errcode='42501';end if;
 perform 1 from public.opportunities where id=p_opportunity for update;
 select * into obj from storage.objects where bucket_id='opportunity-media' and name=p_path;
 if not found then raise exception 'Upload object does not exist';end if;
 if p_size not between 1 and 10485760 or p_mime not in ('image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime') then raise exception 'Unsupported media';end if;
 if obj.metadata->>'mimetype' is distinct from p_mime or (obj.metadata->>'size')::bigint is distinct from p_size then raise exception 'Media metadata does not match uploaded object';end if;
 insert into public.opportunity_media(opportunity_id,storage_path,file_name,mime_type,size_bytes) values(p_opportunity,p_path,left(p_file_name,255),p_mime,p_size) on conflict(storage_path) do update set storage_path=excluded.storage_path returning id into vid;
 return vid;
end $$;

revoke all on function private.sync_auth_identity() from public,anon,authenticated;
-- Every callable private function remains hidden from the Data API.
