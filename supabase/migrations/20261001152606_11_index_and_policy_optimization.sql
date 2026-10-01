create index if not exists opportunities_accepted_by_idx on public.opportunities(accepted_by);
create index if not exists project_activity_actor_idx on public.project_activity(actor_id);
create index if not exists project_members_added_by_idx on public.project_members(added_by);
create index if not exists project_steps_step_idx on public.project_steps(step);
create index if not exists project_steps_updated_by_idx on public.project_steps(updated_by);
create index if not exists projects_current_step_idx on public.projects(current_step);
-- Separate write policies to avoid evaluating duplicate SELECT predicates.
do $$ declare p record; begin
 for p in select tablename,policyname,qual,with_check from pg_policies where schemaname='public' and policyname like '%_write' and cmd='ALL' loop
 execute format('drop policy %I on public.%I',p.policyname,p.tablename);
 execute format('create policy %I on public.%I for insert to authenticated with check (%s)',p.tablename||'_insert',p.tablename,p.with_check);
 execute format('create policy %I on public.%I for update to authenticated using (%s) with check (%s)',p.tablename||'_update',p.tablename,p.qual,p.with_check);
 execute format('create policy %I on public.%I for delete to authenticated using (%s)',p.tablename||'_delete',p.tablename,p.qual);
 end loop;
end $$;
-- Payment changes are accounting actions reserved for workspace or platform admins.
drop policy payments_insert on public.payments;
drop policy payments_update on public.payments;
drop policy payments_delete on public.payments;
create policy payments_insert on public.payments for insert to authenticated with check(private.is_platform_admin() or private.is_ws_admin(private.project_workspace(project_id)));
create policy payments_update on public.payments for update to authenticated using(private.is_platform_admin() or private.is_ws_admin(private.project_workspace(project_id))) with check(private.is_platform_admin() or private.is_ws_admin(private.project_workspace(project_id)));
create policy payments_delete on public.payments for delete to authenticated using(private.is_platform_admin() or private.is_ws_admin(private.project_workspace(project_id)));
