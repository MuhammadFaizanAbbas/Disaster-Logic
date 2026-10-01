import {serve,ok,ws,id,page,search} from "./shared.ts";
serve({
 list:async(c,b)=>{const w=ws(c,b.workspace_id);const pg=page(b);let q=c.sb.from("opportunities").select("*,customers(id,full_name,email,phone),services(id,name,code),opportunity_media(id,storage_path,file_name,mime_type)",{count:"exact"}).in("status",["new","offered"]).order("created_at",{ascending:false});
 // RLS is the authority across memberships. Limit the active workspace board to its own or eligible public jobs.
 if(!c.isAdmin){const sv=ok(await c.sb.from("workspace_services").select("service_id").eq("workspace_id",w));const ls=ok(await c.sb.from("workspace_locations").select("postal_codes").eq("workspace_id",w));const codes=[...new Set(ls.flatMap((x:any)=>x.postal_codes))];
 const owned=ok(await c.sb.from("opportunities").select("id").eq("workspace_id",w).in("status",["new","offered"]));const ids=owned.map((x:any)=>x.id);
 if(sv.length&&codes.length){const matches=ok(await c.sb.from("opportunities").select("id").eq("visibility","public").in("status",["new","offered"]).in("service_id",sv.map((x:any)=>x.service_id)).in("postal_code",codes));ids.push(...matches.map((x:any)=>x.id));}if(!ids.length)return {items:[],count:0};q=q.in("id",ids);}
 if(b.priority)q=q.eq("priority",b.priority);if(b.service_id)q=q.eq("service_id",id(b.service_id));const result=await q.range(pg.offset,pg.offset+pg.limit-1);ok(result);return {items:result.data,count:result.count};},
 get:async(c,b)=>ok(await c.sb.from("opportunities").select("*,customers(*),services(*),opportunity_media(*)").eq("id",id(b.id)).single()),
 accept:async(c,b)=>({project_id:ok(await c.sb.rpc("accept_opportunity",{p_opportunity:id(b.id),p_workspace:ws(c,b.workspace_id)}))}),
 decline:async(c,b)=>{ok(await c.sb.rpc("decline_offer",{p_offer:id(b.offer_id)}));return {declined:true};},
 referral_board:async(c)=>ok(await c.sb.rpc("referral_board")),
 accept_referral:async(c,b)=>({project_id:ok(await c.sb.rpc("accept_referral_listing",{p_invite:id(b.id),p_workspace:ws(c,b.workspace_id)}))}),
 form:async(c,b)=>{const w=ws(c,b.workspace_id);const row=ok(await c.sb.from("workspaces").select("public_key").eq("id",w).single());return {public_key:row.public_key,...ok(await c.sb.rpc("get_booking_form",{p_public_key:row.public_key}))};},
 stats:async(c,b)=>ok(await c.sb.rpc("dashboard_stats",{p_workspace:ws(c,b.workspace_id)})),
});