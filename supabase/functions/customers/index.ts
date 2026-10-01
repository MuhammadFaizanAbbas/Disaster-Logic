import {serve,ok,ws,id,page,search} from "./shared.ts";
serve({
 list:async(c,b)=>{const w=ws(c,b.workspace_id),pg=page(b);let q=c.sb.from("customers").select("*,projects(id,status,scope_estimate,payment_status,created_at,services(name))",{count:"exact"}).eq("workspace_id",w).order("created_at",{ascending:false});const s=search(b.search);if(s)q=q.or(`full_name.ilike.%${s}%,email.ilike.%${s}%,phone.ilike.%${s}%`);const r=await q.range(pg.offset,pg.offset+pg.limit-1);ok(r);return {items:r.data,count:r.count};},
 get:async(c,b)=>ok(await c.sb.from("customers").select("*,projects(id,status,scope_estimate,payment_status,services(name)),opportunities(id,status,postal_code,created_at)").eq("id",id(b.id)).eq("workspace_id",ws(c,b.workspace_id)).single()),
 save:async(c,b)=>ok(await c.sb.rpc("save_customer",{p_workspace:ws(c,b.workspace_id),p_name:b.full_name,p_email:b.email??null,p_phone:b.phone??null,p_id:b.id?id(b.id):null,p_property_type:b.property_type||null})),
});