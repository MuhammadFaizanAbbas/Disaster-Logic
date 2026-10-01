import {serve,ok,ws,id,page,project,projectSelect} from "./shared.ts";
serve({
 list:async(c,b)=>{const pg=page(b);let q=c.sb.from("projects").select(projectSelect,{count:"exact"}).order("created_at",{ascending:false});
 if(b.workspace_id){
 if(!c.isAdmin&&!c.memberships.some((m:any)=>m.workspace_id===b.workspace_id))throw new Error("Unknown workspace");
 const incoming=ok(await c.sb.from("referral_invites").select("project_id").eq("claimed_by",c.user.id).eq("invitee_workspace_id",id(b.workspace_id)).in("status",["accepted","in_progress","finished"]));
 const ids=incoming.map((x:any)=>x.project_id);q=ids.length?q.or(`workspace_id.eq.${b.workspace_id},id.in.(${ids.join(",")})`):q.eq("workspace_id",id(b.workspace_id));
 }
 if(b.mine!==false&&!c.isAdmin){const memberships=ok(await c.sb.from("project_members").select("project_id").eq("user_id",c.user.id));if(!memberships.length)return {items:[],count:0};q=q.in("id",memberships.map((m:any)=>m.project_id));}
 if(b.status)q=q.eq("status",b.status);const r=await q.range(pg.offset,pg.offset+pg.limit-1);ok(r);return {items:r.data,count:r.count};},
 get:async(c,b)=>{const p=await project(c,b.id);return {...p,referrals:ok(await c.sb.from("referral_invites").select("id,target,invitee_name,status,payout_amount,expires_at,claimed_by").eq("project_id",p.id)),payouts:ok(await c.sb.from("referral_payouts").select("*").eq("project_id",p.id))};},
 set_status:async(c,b)=>{ok(await c.sb.rpc("set_project_status",{p_project:id(b.id),p_status:b.status}));return project(c,b.id);},
 assign:async(c,b)=>{ok(await c.sb.rpc("assign_project",{p_project:id(b.id),p_user:id(b.user_id)}));return project(c,b.id);},
 update:async(c,b)=>ok(await c.sb.rpc("update_project_details",{p_project:id(b.id),p_scope:b.scope_estimate??null,p_billing:b.billing_type??null,p_payment:b.payment_status??null})),
 save_step:async(c,b)=>ok(await c.sb.rpc("save_project_step",{p_project:id(b.id),p_step:b.step,p_data:b.data??{},p_complete:!!b.complete})),
 steps:async(c,b)=>ok(await c.sb.from("project_steps").select("*,workflow_steps(*)").eq("project_id",id(b.id))),
 upload_token:async(c,b)=>ok(await c.sb.rpc("create_project_upload_token",{p_project:id(b.id)})),
});