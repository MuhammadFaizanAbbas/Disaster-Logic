import {serve,ok,ws,id,page,adminClient,project} from "./shared.ts";
async function provision(c:any,r:any){const invite=ok(await c.sb.from("referral_invites").select("invitee_email,invitee_phone,invitee_name,target").eq("id",r.id).single());if(invite.target!=="individual")return {...r,account_status:"not_required"};
 const admin=adminClient();const existing=invite.invitee_email?ok(await admin.from("profiles").select("id").eq("email",invite.invitee_email).maybeSingle()):null;
 if(existing)return {...r,account_status:"existing"};
 const {error}=await admin.auth.admin.createUser({...invite.invitee_email?{email:invite.invitee_email,email_confirm:false}:{phone:invite.invitee_phone,phone_confirm:false},user_metadata:{full_name:invite.invitee_name}});
 // An account may have been created concurrently. Return the saved referral even if provisioning needs a retry.
 return {...r,account_status:error?"pending":"created",account_warning:error?"Referral saved; account provisioning needs retry or recipient sign-in.":null};}
serve({
 list:async(c,b)=>{const pg=page(b),r=await c.sb.from("referral_invites").select("*,projects(id,customers(full_name),services(name))",{count:"exact"}).eq("workspace_id",ws(c,b.workspace_id)).order("created_at",{ascending:false}).range(pg.offset,pg.offset+pg.limit-1);ok(r);return {items:r.data,count:r.count};},
 contacts:async(c,b)=>ok(await c.sb.rpc("list_referral_contacts",{p_workspace:ws(c,b.workspace_id)})),
 workspaces:async(c)=>ok(await c.sb.rpc("workspace_directory")),
 create:async(c,b)=>{const p=await project(c,b.project_id);ws(c,p.workspace_id);const r=ok(await c.sb.rpc("create_referral",{p_project:p.id,p_target:b.target,p_name:b.name??null,p_email:b.email??null,p_phone:b.phone??null,p_workspace:b.target_workspace_id??null,p_payout:b.payout_amount??0,p_instructions:b.instructions??null,p_send:true}));return provision(c,r);},
 refer_opportunity:async(c,b)=>{const r=ok(await c.sb.rpc("refer_opportunity",{p_opportunity:id(b.opportunity_id),p_workspace:ws(c,b.workspace_id),p_target:b.target,p_name:b.name??null,p_email:b.email??null,p_phone:b.phone??null,p_target_workspace:b.target_workspace_id??null,p_payout:b.payout_amount??0,p_instructions:b.instructions??null}));return provision(c,r);},
 claim:async(c,b)=>({project_id:ok(await c.sb.rpc("claim_referral",{p_token:b.token,p_workspace:b.workspace_id??null}))}),
 revoke:async(c,b)=>{ok(await c.sb.rpc("revoke_referral",{p_invite:id(b.id)}));return {revoked:true};},
});