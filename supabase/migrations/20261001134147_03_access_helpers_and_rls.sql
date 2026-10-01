
-- ============ ACCESS HELPERS (security definer so policies don't recurse) ============
create or replace function private.is_platform_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select p.is_platform_admin from public.profiles p where p.id = (select auth.uid())), false)
$$;

create or replace function private.is_any_member(ws uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.workspace_members m
                 where m.workspace_id = ws and m.user_id = (select auth.uid()) and m.status = 'active')
$$;

create or replace function private.is_internal_member(ws uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.workspace_members m
                 where m.workspace_id = ws and m.user_id = (select auth.uid())
                   and m.member_type = 'internal' and m.status = 'active')
$$;

create or replace function private.is_ws_admin(ws uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.workspace_members m
                 where m.workspace_id = ws and m.user_id = (select auth.uid())
                   and m.member_type = 'internal' and m.role = 'admin' and m.status = 'active')
$$;

create or replace function private.project_workspace(pid uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select workspace_id from public.projects where id = pid
$$;

create or replace function private.is_project_participant(pid uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.project_members pm where pm.project_id = pid and pm.user_id = (select auth.uid()))
$$;

create or replace function private.can_see_project(pid uuid, ws uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_admin() or private.is_internal_member(ws) or private.is_project_participant(pid)
$$;

create or replace function private.shares_workspace_or_project(other uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
           select 1 from public.workspace_members me
           join public.workspace_members o on o.workspace_id = me.workspace_id
           where me.user_id = (select auth.uid()) and me.member_type = 'internal' and me.status = 'active'
             and o.user_id = other)
      or exists (
           select 1 from public.project_members a
           join public.project_members b on b.project_id = a.project_id
           where a.user_id = (select auth.uid()) and b.user_id = other)
$$;

-- who can see an opportunity: platform admin, owning/accepting workspace staff, project participants,
-- or (for PUBLIC ones still open) staff of any active workspace that offers the service and covers the ZIP
create or replace function private.can_see_opportunity(
  p_id uuid, p_ws uuid, p_svc uuid, p_vis public.opportunity_visibility,
  p_zip text, p_status public.opportunity_status, p_acc_ws uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_platform_admin()
      or private.is_internal_member(p_ws)
      or (p_acc_ws is not null and private.is_internal_member(p_acc_ws))
      or exists (select 1 from public.opportunity_offers f where f.opportunity_id = p_id and f.user_id = (select auth.uid()))
      or exists (select 1 from public.projects pr join public.project_members pm on pm.project_id = pr.id
                 where pr.opportunity_id = p_id and pm.user_id = (select auth.uid()))
      or (p_vis = 'public' and p_status in ('new','offered') and exists (
            select 1 from public.workspace_members m
            join public.workspaces w on w.id = m.workspace_id and w.is_active
            join public.workspace_services s on s.workspace_id = m.workspace_id and s.service_id = p_svc
            join public.workspace_locations l on l.workspace_id = m.workspace_id and p_zip = any (l.postal_codes)
            where m.user_id = (select auth.uid()) and m.member_type = 'internal' and m.status = 'active'))
$$;

-- stop normal users from promoting themselves
create or replace function private.protect_profile_fields()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select auth.uid()) is not null and not private.is_platform_admin() then
    new.is_platform_admin := old.is_platform_admin;
    new.stripe_account_id := old.stripe_account_id;
    new.id := old.id;
  end if;
  return new;
end $$;
create trigger protect_profile_fields before update on public.profiles
  for each row execute function private.protect_profile_fields();

-- ============ ENABLE RLS ============
alter table public.profiles            enable row level security;
alter table public.workspaces          enable row level security;
alter table public.services            enable row level security;
alter table public.workspace_members   enable row level security;
alter table public.workspace_services  enable row level security;
alter table public.workspace_locations enable row level security;
alter table public.member_services     enable row level security;
alter table public.member_availability enable row level security;
alter table public.customers           enable row level security;
alter table public.opportunities       enable row level security;
alter table public.opportunity_media   enable row level security;
alter table public.opportunity_offers  enable row level security;
alter table public.projects            enable row level security;
alter table public.project_members     enable row level security;
alter table public.referral_invites    enable row level security;
alter table public.referral_payouts    enable row level security;
alter table public.notifications       enable row level security;
alter table private.upload_tokens      enable row level security;

-- ============ POLICIES ============
-- profiles
create policy profiles_select on public.profiles for select to authenticated
  using (id = (select auth.uid()) or private.is_platform_admin() or private.shares_workspace_or_project(id));
create policy profiles_update on public.profiles for update to authenticated
  using (id = (select auth.uid()) or private.is_platform_admin())
  with check (id = (select auth.uid()) or private.is_platform_admin());

-- services catalog
create policy services_select on public.services for select to anon, authenticated
  using (is_active or private.is_platform_admin());
create policy services_insert on public.services for insert to authenticated with check (private.is_platform_admin());
create policy services_update on public.services for update to authenticated
  using (private.is_platform_admin()) with check (private.is_platform_admin());
create policy services_delete on public.services for delete to authenticated using (private.is_platform_admin());

-- workspaces
create policy workspaces_select on public.workspaces for select to authenticated
  using (private.is_any_member(id) or private.is_platform_admin());
create policy workspaces_insert on public.workspaces for insert to authenticated with check (private.is_platform_admin());
create policy workspaces_update on public.workspaces for update to authenticated
  using (private.is_ws_admin(id) or private.is_platform_admin())
  with check (private.is_ws_admin(id) or private.is_platform_admin());
create policy workspaces_delete on public.workspaces for delete to authenticated using (private.is_platform_admin());

-- workspace_members
create policy wm_select on public.workspace_members for select to authenticated
  using (user_id = (select auth.uid()) or private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy wm_insert on public.workspace_members for insert to authenticated
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy wm_update on public.workspace_members for update to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin())
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy wm_delete on public.workspace_members for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- workspace_services / workspace_locations
create policy wsvc_select on public.workspace_services for select to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy wsvc_insert on public.workspace_services for insert to authenticated
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy wsvc_delete on public.workspace_services for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

create policy wloc_select on public.workspace_locations for select to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy wloc_insert on public.workspace_locations for insert to authenticated
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy wloc_update on public.workspace_locations for update to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin())
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy wloc_delete on public.workspace_locations for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- member_services (tiers) : admin-managed
create policy msvc_select on public.member_services for select to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy msvc_insert on public.member_services for insert to authenticated
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy msvc_update on public.member_services for update to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin())
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin());
create policy msvc_delete on public.member_services for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- member_availability : admin, or the member for their own row
create policy mav_select on public.member_availability for select to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy mav_insert on public.member_availability for insert to authenticated
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin()
              or (user_id = (select auth.uid()) and private.is_internal_member(workspace_id)));
create policy mav_update on public.member_availability for update to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin() or user_id = (select auth.uid()))
  with check (private.is_ws_admin(workspace_id) or private.is_platform_admin() or user_id = (select auth.uid()));
create policy mav_delete on public.member_availability for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin() or user_id = (select auth.uid()));

-- customers
create policy cust_select on public.customers for select to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin()
         or exists (select 1 from public.projects p join public.project_members pm on pm.project_id = p.id
                    where p.customer_id = customers.id and pm.user_id = (select auth.uid())));
create policy cust_insert on public.customers for insert to authenticated
  with check (private.is_internal_member(workspace_id));
create policy cust_update on public.customers for update to authenticated
  using (private.is_internal_member(workspace_id)) with check (private.is_internal_member(workspace_id));
create policy cust_delete on public.customers for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- opportunities (public form inserts go through submit_booking())
create policy opp_select on public.opportunities for select to authenticated
  using (private.can_see_opportunity(id, workspace_id, service_id, visibility, postal_code, status, accepted_workspace_id));
create policy opp_insert on public.opportunities for insert to authenticated
  with check (private.is_internal_member(workspace_id) and created_by = (select auth.uid()) and source <> 'public_form');
create policy opp_update on public.opportunities for update to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin())
  with check (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy opp_delete on public.opportunities for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

create policy omedia_select on public.opportunity_media for select to authenticated
  using (exists (select 1 from public.opportunities o where o.id = opportunity_id));
create policy omedia_insert on public.opportunity_media for insert to authenticated
  with check (exists (select 1 from public.opportunities o where o.id = opportunity_id and private.is_internal_member(o.workspace_id)));
create policy omedia_delete on public.opportunity_media for delete to authenticated
  using (exists (select 1 from public.opportunities o where o.id = opportunity_id and private.is_internal_member(o.workspace_id)));

-- offers are read-only from the client; responses go through functions
create policy offers_select on public.opportunity_offers for select to authenticated
  using (user_id = (select auth.uid()) or private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- projects (created only by accept_opportunity())
create policy proj_select on public.projects for select to authenticated
  using (private.can_see_project(id, workspace_id));
create policy proj_update on public.projects for update to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin())
  with check (private.is_internal_member(workspace_id) or private.is_platform_admin());

create policy pmem_select on public.project_members for select to authenticated
  using (user_id = (select auth.uid()) or private.is_internal_member(private.project_workspace(project_id)) or private.is_platform_admin());
create policy pmem_insert on public.project_members for insert to authenticated
  with check (private.is_internal_member(private.project_workspace(project_id)));
create policy pmem_delete on public.project_members for delete to authenticated
  using (private.is_internal_member(private.project_workspace(project_id)) or private.is_platform_admin());

-- referral invites
create policy inv_select on public.referral_invites for select to authenticated
  using (private.is_internal_member(workspace_id) or claimed_by = (select auth.uid()) or private.is_platform_admin());
create policy inv_insert on public.referral_invites for insert to authenticated
  with check (invited_by = (select auth.uid())
              and private.is_internal_member(workspace_id)
              and private.project_workspace(project_id) = workspace_id);
create policy inv_update on public.referral_invites for update to authenticated
  using (private.is_internal_member(workspace_id) or private.is_platform_admin())
  with check (private.is_internal_member(workspace_id) or private.is_platform_admin());
create policy inv_delete on public.referral_invites for delete to authenticated
  using (private.is_ws_admin(workspace_id) or private.is_platform_admin());

-- payouts
create policy payout_select on public.referral_payouts for select to authenticated
  using (payee_id = (select auth.uid()) or private.is_ws_admin(private.project_workspace(project_id)) or private.is_platform_admin());
create policy payout_update on public.referral_payouts for update to authenticated
  using (private.is_ws_admin(private.project_workspace(project_id)) or private.is_platform_admin())
  with check (private.is_ws_admin(private.project_workspace(project_id)) or private.is_platform_admin());

-- notifications
create policy notif_select on public.notifications for select to authenticated using (user_id = (select auth.uid()));
create policy notif_update on public.notifications for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy notif_delete on public.notifications for delete to authenticated using (user_id = (select auth.uid()));

