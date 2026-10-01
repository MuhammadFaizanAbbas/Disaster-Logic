-- Re-read the invitation after obtaining the shared project lock.
-- A competing claimant may have committed while this transaction waited.
CREATE OR REPLACE FUNCTION private.complete_referral(p_invite uuid, p_user uuid, p_ws uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO '' AS $function$
declare i public.referral_invites;
begin
  select * into i from public.referral_invites where id=p_invite;
  if not found then raise exception 'Referral not found' using errcode='P0002'; end if;
  perform 1 from public.projects where id=i.project_id and status not in ('completed','cancelled') for update;
  if not found then raise exception 'Project is closed' using errcode='P0002'; end if;
  select * into i from public.referral_invites where id=p_invite for update;
  if not found or i.status not in ('link_sent','viewed') or i.expires_at<=now() then
    raise exception 'Referral is unavailable';
  end if;
  if exists (select 1 from public.referral_invites where project_id=i.project_id and id<>i.id and status in ('accepted','in_progress')) then
    raise exception 'This project already has an accepted referral';
  end if;
  insert into public.workspace_members(workspace_id,user_id,member_type,role,status,referred_by)
    values(i.workspace_id,p_user,'referral','member','active',i.invited_by)
    on conflict(workspace_id,user_id) do nothing;
  insert into public.project_members(project_id,user_id,role,added_by)
    values(i.project_id,p_user,'referral',i.invited_by)
    on conflict(project_id,user_id) do nothing;
  update public.referral_invites set status='accepted',claimed_by=p_user,claimed_at=now(),
    invitee_workspace_id=coalesce(p_ws,invitee_workspace_id) where id=i.id;
  insert into public.referral_payouts(invite_id,project_id,payee_id,amount,status)
    values(i.id,i.project_id,p_user,i.payout_amount,'pending')
    on conflict(invite_id) do nothing;
  insert into public.notifications(user_id,workspace_id,project_id,title)
    values(i.invited_by,i.workspace_id,i.project_id,i.invitee_name || ' accepted your referral');
  return i.project_id;
end $function$;

