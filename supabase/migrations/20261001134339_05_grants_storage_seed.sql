
-- ============ lock down default privileges ============
revoke all on all tables    in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke execute on all functions in schema public  from public, anon;
revoke execute on all functions in schema private from public, anon, authenticated;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke execute on functions from public, anon;

-- the anonymous booking form only needs the service catalog + 4 RPCs
grant select on public.services to anon;
drop policy services_select on public.services;
create policy services_select_anon on public.services for select to anon using (is_active);
create policy services_select_auth on public.services for select to authenticated
  using (is_active or private.is_platform_admin());

grant execute on function public.get_booking_form(text), public.preview_referral(text),
  public.submit_booking(text,text,text,text,text,text,public.dispatch_priority,text,date,text,int,public.opportunity_visibility,text,text,text,numeric,numeric),
  public.attach_media(uuid,text,text,text,text,bigint) to anon, authenticated;
grant execute on function public.accept_opportunity(uuid,uuid), public.decline_offer(uuid),
  public.claim_referral(text,uuid), public.set_project_status(uuid,public.project_status) to authenticated;

-- policy helpers must be callable by signed-in users (RLS runs them as the caller)
grant execute on function private.is_platform_admin(), private.is_any_member(uuid), private.is_internal_member(uuid),
  private.is_ws_admin(uuid), private.project_workspace(uuid), private.is_project_participant(uuid),
  private.can_see_project(uuid,uuid), private.shares_workspace_or_project(uuid),
  private.can_see_opportunity(uuid,uuid,uuid,public.opportunity_visibility,text,public.opportunity_status,uuid),
  private.valid_upload_path(text) to authenticated;
grant execute on function private.valid_upload_path(text) to anon;

-- ============ storage for damage photos / videos ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('opportunity-media', 'opportunity-media', false, 10485760,
        array['image/jpeg','image/png','image/webp','video/mp4','video/webm','video/quicktime'])
on conflict (id) do nothing;

create policy opp_media_upload on storage.objects for insert to anon, authenticated
  with check (bucket_id = 'opportunity-media' and private.valid_upload_path(name));
create policy opp_media_read on storage.objects for select to authenticated
  using (bucket_id = 'opportunity-media'
         and exists (select 1 from public.opportunity_media m where m.storage_path = storage.objects.name));

-- ============ seed: the six services on the booking form ============
insert into public.services (code, name, description, tag, response_label, is_bookable, sort_order) values
 ('fire-smoke-containment','Fire & Smoke Containment','Soot mitigation, smoke removal, and structural safety stabilization.','Priority triage','Immediate',true,1),
 ('water-damage-pipe-burst','Water Damage / Pipe Burst','Emergency extraction, leak isolation, and structural drying.','Water removal','24/7 response',true,2),
 ('structural-roof-tarping','Structural / Roof Tarping','Board-up, roof tarping, structural shoring, and storm damage.','Stabilization','Site safety',true,3),
 ('sewage-drain-backup','Sewage / Drain Backup','Contaminated water extraction, sanitation, and drain cleanup.','Biohazard response','Containment',true,4),
 ('environmental-remediation','Environmental Remediation','Mold containment, environmental cleanup, and air quality control.','Mold remediation','Air quality',true,5),
 ('wind-storm-damage','Wind / Storm Damage','Emergency storm recovery, debris removal, and property protection.','Storm recovery','Rapid response',true,6)
on conflict (code) do nothing;

