
-- The existing single-service intake remains intact; accepted jobs are projects.
create table public.workflow_steps(code text primary key,name text not null,position integer not null unique check(position>0));
insert into public.workflow_steps values ('evaluate','Evaluate',1),('claim','Claim',2),('scope','Scope',3),('drying_plan','Drying Plan',4),('contracts','Contracts',5),('work','Work',6),('payments','Payments',7);
alter table public.projects add column current_step text not null default 'evaluate' references public.workflow_steps(code);
create table public.project_steps(project_id uuid not null references public.projects(id) on delete cascade,step text not null references public.workflow_steps(code),data jsonb not null default '{}' check(jsonb_typeof(data)='object'),completed_at timestamptz,updated_by uuid references public.profiles(id),updated_at timestamptz not null default now(),primary key(project_id,step));
create table public.project_activity(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,actor_id uuid references public.profiles(id) on delete set null,action text not null,details jsonb not null default '{}',created_at timestamptz not null default now());
create index project_activity_project_date_idx on public.project_activity(project_id,created_at desc);
create or replace function private.log_project_status() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='INSERT' then
 insert into public.project_steps(project_id,step) select new.id,code from public.workflow_steps;
 insert into public.project_activity(project_id,actor_id,action,details) values(new.id,auth.uid(),'created',jsonb_build_object('status',new.status));
 elsif new.status is distinct from old.status then
 insert into public.project_activity(project_id,actor_id,action,details) values(new.id,auth.uid(),'status_changed',jsonb_build_object('from',old.status,'to',new.status));
 end if; return new;
end $$;
create trigger project_activity_status after insert or update of status on public.projects for each row execute function private.log_project_status();
insert into public.project_steps(project_id,step) select p.id,s.code from public.projects p cross join public.workflow_steps s on conflict do nothing;

create or replace function private.can_work_project(pid uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.projects p where p.id=pid and (private.is_internal_member(p.workspace_id) or private.is_platform_admin() or private.is_project_participant(pid))) $$;
create or replace function private.can_manage_project(pid uuid) returns boolean language sql stable security definer set search_path='' as $$
select exists(select 1 from public.projects p where p.id=pid and (private.is_internal_member(p.workspace_id) or private.is_platform_admin())) $$;
create or replace function public.save_project_step(p_project uuid,p_step text,p_data jsonb default '{}',p_complete boolean default false) returns public.project_steps language plpgsql security definer set search_path='' as $$
declare s public.project_steps; p public.projects;
begin
 select * into p from public.projects where id=p_project for update;
 if not found then raise exception 'Project not found' using errcode='P0002'; end if;
 if not private.can_work_project(p_project) then raise exception 'Not allowed' using errcode='42501'; end if;
 if p.status in ('completed','cancelled') then raise exception 'Project is closed'; end if;
 if p_step in ('payments','contracts','claim') and not private.can_manage_project(p_project) then raise exception 'Workspace access required for financial or contract records' using errcode='42501'; end if;
 if jsonb_typeof(p_data)<>'object' or octet_length(p_data::text)>65536 then raise exception 'Step data must be an object up to 64 KB'; end if;
 update public.project_steps set data=p_data,completed_at=case when p_complete then now() else null end,updated_by=auth.uid(),updated_at=now() where project_id=p_project and step=p_step returning * into s;
 if not found then raise exception 'Unknown workflow step'; end if;
 update public.projects set current_step=coalesce((select st.code from public.workflow_steps st join public.project_steps ps on ps.step=st.code where ps.project_id=p_project and ps.completed_at is null order by st.position limit 1),p_step) where id=p_project;
 insert into public.project_activity(project_id,actor_id,action,details) values(p_project,auth.uid(),'step_saved',jsonb_build_object('step',p_step,'complete',p_complete));
 return s;
end $$;

create or replace function public.create_project_upload_token(p_project uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare oid uuid; t text;
begin
 if not private.can_work_project(p_project) then raise exception 'Not allowed' using errcode='42501'; end if;
 select opportunity_id into oid from public.projects where id=p_project;
 insert into private.upload_tokens(opportunity_id) values(oid) on conflict(opportunity_id) do update set token=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-',''),expires_at=now()+interval '1 hour' returning token into t;
 return jsonb_build_object('opportunity_id',oid,'upload_token',t);
end $$;

create or replace function public.update_member_settings(p_workspace uuid,p_user uuid,p_role public.workspace_role default null,p_status public.member_status default null,p_scheduling boolean default null) returns void language plpgsql security definer set search_path='' as $$
declare m public.workspace_members;
begin
 if not (private.is_ws_admin(p_workspace) or private.is_platform_admin()) then raise exception 'Workspace admin required' using errcode='42501'; end if;
 perform 1 from public.workspaces where id=p_workspace for update;
 select * into m from public.workspace_members where workspace_id=p_workspace and user_id=p_user;
 if not found then raise exception 'Member not found' using errcode='P0002'; end if;
 if m.role='admin' and m.member_type='internal' and m.status='active' and (coalesce(p_role,m.role)<>'admin' or coalesce(p_status,m.status)<>'active')
 and not exists(select 1 from public.workspace_members where workspace_id=p_workspace and user_id<>p_user and member_type='internal' and role='admin' and status='active') then raise exception 'Keep at least one active workspace admin'; end if;
 update public.workspace_members set role=coalesce(p_role,role),status=coalesce(p_status,status),available_for_scheduling=coalesce(p_scheduling,available_for_scheduling) where workspace_id=p_workspace and user_id=p_user;
end $$;
revoke update,delete on public.workspace_members from authenticated;

create or replace function public.save_workspace_services(p_workspace uuid,p_services uuid[]) returns void language plpgsql security definer set search_path='' as $$
begin
 if not (private.is_ws_admin(p_workspace) or private.is_platform_admin()) then raise exception 'Workspace admin required' using errcode='42501'; end if;
 perform 1 from public.workspaces where id=p_workspace for update;
 delete from public.workspace_services where workspace_id=p_workspace and not(service_id=any(p_services));
 insert into public.workspace_services(workspace_id,service_id) select p_workspace,id from public.services where id=any(p_services) and is_active on conflict do nothing;
end $$;

create table public.claims(project_id uuid primary key references public.projects(id) on delete cascade,cause text,cause_detail text,water_category smallint check(water_category between 1 and 3),property_type text check(property_type in ('residential','commercial')),coverage_recommendation text,billing_type public.billing_type,cancelled boolean not null default false);

create table public.payments(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,kind text not null check(kind in ('down_payment','final')),amount numeric(12,2) not null check(amount>=0),status text not null default 'pending' check(status in ('pending','paid','failed','refunded')),stripe_payment_id text unique,paid_at timestamptz,created_at timestamptz not null default now());

create table public.project_floors(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,name text not null,position integer not null default 0,sketch jsonb not null default '{}');

create table public.project_rooms(id uuid primary key default gen_random_uuid(),floor_id uuid not null references public.project_floors(id) on delete cascade,name text not null);

create table public.moisture_readings(id uuid primary key default gen_random_uuid(),floor_id uuid not null references public.project_floors(id) on delete cascade,room_id uuid references public.project_rooms(id) on delete cascade,name text not null,wetness text not null check(wetness in ('dry','wet','soaked')),material text,dry_standard numeric check(dry_standard>=0),ep_goal numeric check(ep_goal>=0),x numeric,y numeric,recorded_at timestamptz not null default now());

create table public.room_photos(id uuid primary key default gen_random_uuid(),room_id uuid not null references public.project_rooms(id) on delete cascade,storage_path text not null,is_additional boolean not null default false,position integer not null default 0);

create table public.room_materials(id uuid primary key default gen_random_uuid(),room_id uuid not null references public.project_rooms(id) on delete cascade,surface text not null check(surface in ('floor','wall','ceiling')),material text not null,affected boolean not null default false);

create table public.room_measurements(room_id uuid primary key references public.project_rooms(id) on delete cascade,length_in numeric check(length_in>=0),width_in numeric check(width_in>=0),height_in numeric check(height_in>=0),total_sqft numeric check(total_sqft>=0),affected_sqft numeric check(affected_sqft>=0),affected boolean not null default false,check(affected_sqft is null or total_sqft is null or affected_sqft<=total_sqft));

create table public.drying_plans(project_id uuid primary key references public.projects(id) on delete cascade,plan jsonb not null default '{}',updated_at timestamptz not null default now());

create table public.service_packages(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces(id) on delete cascade,service_id uuid references public.services(id),name text not null,description text,image_url text,price numeric(12,2) not null check(price>=0));

create table public.project_scope_items(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,package_id uuid references public.service_packages(id),description text not null,quantity numeric not null check(quantity>0),unit_price numeric(12,2) not null check(unit_price>=0));

create table public.project_expenses(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,description text not null,amount numeric(12,2) not null check(amount>=0),incurred_by uuid references public.profiles(id),incurred_at timestamptz not null default now());

create table public.contract_templates(id uuid primary key default gen_random_uuid(),workspace_id uuid not null references public.workspaces(id) on delete cascade,name text not null,body text not null);

create table public.project_contracts(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,template_id uuid not null references public.contract_templates(id),signed_by text,signed_in_person boolean not null default false,signature_url text,signed_at timestamptz);

create table public.project_files(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,kind text not null check(kind in ('proof_of_loss','efile','damage','contract','other')),storage_path text not null,uploaded_by uuid references public.profiles(id),created_at timestamptz not null default now());

create table public.project_emails(id uuid primary key default gen_random_uuid(),project_id uuid not null references public.projects(id) on delete cascade,direction text not null check(direction in ('inbox','sent')),subject text,body text,sent_at timestamptz);

create or replace function private.floor_project(fid uuid) returns uuid language sql stable security definer set search_path='' as $$select project_id from public.project_floors where id=fid$$;
create or replace function private.room_project(rid uuid) returns uuid language sql stable security definer set search_path='' as $$select f.project_id from public.project_rooms r join public.project_floors f on f.id=r.floor_id where r.id=rid$$;

alter table public.workflow_steps enable row level security;
grant select on public.workflow_steps to authenticated;
create policy workflow_read on public.workflow_steps for select to authenticated using(true);

alter table public.project_steps enable row level security;
grant select on public.project_steps to authenticated;
create policy project_steps_read on public.project_steps for select to authenticated using(private.can_work_project(project_id));

alter table public.project_activity enable row level security;
grant select on public.project_activity to authenticated;
create policy project_activity_read on public.project_activity for select to authenticated using(private.can_work_project(project_id));

alter table public.claims enable row level security;
grant select on public.claims to authenticated;
create policy claims_read on public.claims for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.claims to authenticated;
create policy claims_write on public.claims for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));

alter table public.payments enable row level security;
grant select on public.payments to authenticated;
create policy payments_read on public.payments for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.payments to authenticated;
create policy payments_write on public.payments for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));
create index payments_project_id_idx on public.payments(project_id);

alter table public.project_floors enable row level security;
grant select on public.project_floors to authenticated;
create policy project_floors_read on public.project_floors for select to authenticated using(private.can_work_project(project_id));
grant insert,update,delete on public.project_floors to authenticated;
create policy project_floors_write on public.project_floors for all to authenticated using(private.can_work_project(project_id)) with check(private.can_work_project(project_id));
create index project_floors_project_id_idx on public.project_floors(project_id);

alter table public.project_rooms enable row level security;
grant select on public.project_rooms to authenticated;
create policy project_rooms_read on public.project_rooms for select to authenticated using(private.can_work_project(private.floor_project(floor_id)));
grant insert,update,delete on public.project_rooms to authenticated;
create policy project_rooms_write on public.project_rooms for all to authenticated using(private.can_work_project(private.floor_project(floor_id))) with check(private.can_work_project(private.floor_project(floor_id)));
create index project_rooms_floor_id_idx on public.project_rooms(floor_id);

alter table public.moisture_readings enable row level security;
grant select on public.moisture_readings to authenticated;
create policy moisture_readings_read on public.moisture_readings for select to authenticated using(private.can_work_project(private.floor_project(floor_id)));
grant insert,update,delete on public.moisture_readings to authenticated;
create policy moisture_readings_write on public.moisture_readings for all to authenticated using(private.can_work_project(private.floor_project(floor_id))) with check(private.can_work_project(private.floor_project(floor_id)));
create index moisture_readings_floor_id_idx on public.moisture_readings(floor_id);
create index moisture_readings_room_id_idx on public.moisture_readings(room_id);

alter table public.room_photos enable row level security;
grant select on public.room_photos to authenticated;
create policy room_photos_read on public.room_photos for select to authenticated using(private.can_work_project(private.room_project(room_id)));
grant insert,update,delete on public.room_photos to authenticated;
create policy room_photos_write on public.room_photos for all to authenticated using(private.can_work_project(private.room_project(room_id))) with check(private.can_work_project(private.room_project(room_id)));
create index room_photos_room_id_idx on public.room_photos(room_id);

alter table public.room_materials enable row level security;
grant select on public.room_materials to authenticated;
create policy room_materials_read on public.room_materials for select to authenticated using(private.can_work_project(private.room_project(room_id)));
grant insert,update,delete on public.room_materials to authenticated;
create policy room_materials_write on public.room_materials for all to authenticated using(private.can_work_project(private.room_project(room_id))) with check(private.can_work_project(private.room_project(room_id)));
create index room_materials_room_id_idx on public.room_materials(room_id);

alter table public.room_measurements enable row level security;
grant select on public.room_measurements to authenticated;
create policy room_measurements_read on public.room_measurements for select to authenticated using(private.can_work_project(private.room_project(room_id)));
grant insert,update,delete on public.room_measurements to authenticated;
create policy room_measurements_write on public.room_measurements for all to authenticated using(private.can_work_project(private.room_project(room_id))) with check(private.can_work_project(private.room_project(room_id)));

alter table public.drying_plans enable row level security;
grant select on public.drying_plans to authenticated;
create policy drying_plans_read on public.drying_plans for select to authenticated using(private.can_work_project(project_id));
grant insert,update,delete on public.drying_plans to authenticated;
create policy drying_plans_write on public.drying_plans for all to authenticated using(private.can_work_project(project_id)) with check(private.can_work_project(project_id));

alter table public.service_packages enable row level security;
grant select on public.service_packages to authenticated;
create policy service_packages_read on public.service_packages for select to authenticated using(private.is_internal_member(workspace_id) or private.is_platform_admin());
grant insert,update,delete on public.service_packages to authenticated;
create policy service_packages_write on public.service_packages for all to authenticated using(private.is_ws_admin(workspace_id) or private.is_platform_admin()) with check(private.is_ws_admin(workspace_id) or private.is_platform_admin());
create index service_packages_workspace_id_idx on public.service_packages(workspace_id);
create index service_packages_service_id_idx on public.service_packages(service_id);

alter table public.project_scope_items enable row level security;
grant select on public.project_scope_items to authenticated;
create policy project_scope_items_read on public.project_scope_items for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.project_scope_items to authenticated;
create policy project_scope_items_write on public.project_scope_items for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));
create index project_scope_items_project_id_idx on public.project_scope_items(project_id);
create index project_scope_items_package_id_idx on public.project_scope_items(package_id);

alter table public.project_expenses enable row level security;
grant select on public.project_expenses to authenticated;
create policy project_expenses_read on public.project_expenses for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.project_expenses to authenticated;
create policy project_expenses_write on public.project_expenses for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));
create index project_expenses_project_id_idx on public.project_expenses(project_id);
create index project_expenses_incurred_by_idx on public.project_expenses(incurred_by);

alter table public.contract_templates enable row level security;
grant select on public.contract_templates to authenticated;
create policy contract_templates_read on public.contract_templates for select to authenticated using(private.is_internal_member(workspace_id) or private.is_platform_admin());
grant insert,update,delete on public.contract_templates to authenticated;
create policy contract_templates_write on public.contract_templates for all to authenticated using(private.is_ws_admin(workspace_id) or private.is_platform_admin()) with check(private.is_ws_admin(workspace_id) or private.is_platform_admin());
create index contract_templates_workspace_id_idx on public.contract_templates(workspace_id);

alter table public.project_contracts enable row level security;
grant select on public.project_contracts to authenticated;
create policy project_contracts_read on public.project_contracts for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.project_contracts to authenticated;
create policy project_contracts_write on public.project_contracts for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));
create index project_contracts_project_id_idx on public.project_contracts(project_id);
create index project_contracts_template_id_idx on public.project_contracts(template_id);

alter table public.project_files enable row level security;
grant select on public.project_files to authenticated;
create policy project_files_read on public.project_files for select to authenticated using(private.can_work_project(project_id));
grant insert,update,delete on public.project_files to authenticated;
create policy project_files_write on public.project_files for all to authenticated using(private.can_work_project(project_id)) with check(private.can_work_project(project_id));
create index project_files_project_id_idx on public.project_files(project_id);
create index project_files_uploaded_by_idx on public.project_files(uploaded_by);

alter table public.project_emails enable row level security;
grant select on public.project_emails to authenticated;
create policy project_emails_read on public.project_emails for select to authenticated using(private.can_manage_project(project_id));
grant insert,update,delete on public.project_emails to authenticated;
create policy project_emails_write on public.project_emails for all to authenticated using(private.can_manage_project(project_id)) with check(private.can_manage_project(project_id));
create index project_emails_project_id_idx on public.project_emails(project_id);

-- No privileges through PUBLIC for internal definer helpers.
do $$ declare f record; begin
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('can_work_project','can_manage_project','floor_project','room_project','log_project_status') loop
 execute format('revoke all on function %s from public,anon',f.sig);
 if f.sig::text not like '%log_project_status%' then execute format('grant execute on function %s to authenticated',f.sig); end if;
 end loop;
 for f in select p.oid::regprocedure sig from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('save_project_step','create_project_upload_token','update_member_settings','save_workspace_services') loop
 execute format('revoke all on function %s from public,anon',f.sig);execute format('grant execute on function %s to authenticated',f.sig);
 end loop;
end $$;
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
  if not found then raise exception 'Project closed' using errcode='P0002'; end if;
  select * into i from public.referral_invites where id=p_invite;
  if i.status not in ('link_sent','viewed') or i.expires_at<=now() then raise exception 'Referral unavailable'; end if;
  if exists (select 1 from public.referral_invites
             where project_id = i.project_id and id <> i.id and status in ('accepted','in_progress','finished')) then
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
  update public.referral_invites set status='revoked' where project_id=i.project_id and id<>i.id and status in ('draft','link_sent','viewed');
  insert into public.referral_payouts (invite_id, project_id, payee_id, amount, status)
  values (i.id, i.project_id, p_user, i.payout_amount, 'pending')
  on conflict (invite_id) do nothing;
  insert into public.notifications (user_id, workspace_id, project_id, title)
  values (i.invited_by, i.workspace_id, i.project_id, i.invitee_name || ' accepted your referral');
  return i.project_id;
end $function$
;

-- Protect cross-parent references that ordinary RLS alone cannot validate.
create or replace function private.check_job_parent() returns trigger language plpgsql set search_path='' as $$
declare pid uuid; other uuid;
begin
 if tg_table_name='moisture_readings' and new.room_id is not null then
 select floor_id into other from public.project_rooms where id=new.room_id;
 if other is distinct from new.floor_id then raise exception 'Room is on another floor'; end if;
 elsif tg_table_name='project_scope_items' and new.package_id is not null then
 select workspace_id into other from public.service_packages where id=new.package_id;
 if other is distinct from (select workspace_id from public.projects where id=new.project_id) then raise exception 'Package is from another workspace'; end if;
 elsif tg_table_name='project_contracts' then
 select workspace_id into other from public.contract_templates where id=new.template_id;
 if other is distinct from (select workspace_id from public.projects where id=new.project_id) then raise exception 'Template is from another workspace'; end if;
 end if;return new;
end $$;
create trigger moisture_parent before insert or update on public.moisture_readings for each row execute function private.check_job_parent();
create trigger scope_parent before insert or update on public.project_scope_items for each row execute function private.check_job_parent();
create trigger contract_parent before insert or update on public.project_contracts for each row execute function private.check_job_parent();
