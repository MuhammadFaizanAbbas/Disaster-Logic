import { createClient } from "npm:@supabase/supabase-js@2.99.3";
export const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization,x-client-info,apikey,content-type,x-supabase-client-platform,x-supabase-client-platform-version,x-supabase-client-runtime,x-supabase-client-runtime-version","Access-Control-Allow-Methods":"POST,OPTIONS"};
export class HttpError extends Error { constructor(public status:number,message:string){super(message);} }
export const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,"Content-Type":"application/json","Cache-Control":"no-store"}});
export const ok=(r:any)=>{if(r.error)throw r.error;return r.data;};
export const id=(v:unknown)=>{if(typeof v!=="string"||! /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v))throw new HttpError(400,"Valid ID required");return v;};
export const clean=(v:any,max=2000)=>typeof v==="string"?v.trim().slice(0,max):null;
export const page=(b:any)=>({limit:Math.max(1,Math.min(100,Math.trunc(Number(b.limit)||25))),offset:Math.max(0,Math.trunc(Number(b.offset)||0))});
export const search=(v:any)=>clean(v,100)?.replace(/[,%()]/g," ");
function envKey(kind:string,fallback:string){const raw=Deno.env.get(kind);return raw?JSON.parse(raw).default:Deno.env.get(fallback);}
export function adminClient(){return createClient(Deno.env.get("SUPABASE_URL")!,envKey("SUPABASE_SECRET_KEYS","SUPABASE_SERVICE_ROLE_KEY")!,{auth:{persistSession:false,autoRefreshToken:false}});}
export async function ctx(req:Request){
 const auth=req.headers.get("Authorization")||"";if(!/^Bearer \S+/i.test(auth))throw new HttpError(401,"Sign in required");
 const sb=createClient(Deno.env.get("SUPABASE_URL")!,envKey("SUPABASE_PUBLISHABLE_KEYS","SUPABASE_ANON_KEY")!,{global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await sb.auth.getUser(auth.replace(/^Bearer\s+/i,""));if(error||!data.user)throw new HttpError(401,"Session expired; sign in again");
 const memberships=ok(await sb.from("workspace_members").select("workspace_id,member_type,role,status,workspaces(name,slug,public_key,timezone)").eq("user_id",data.user.id).eq("status","active"));
 const profile=ok(await sb.from("profiles").select("id,email,full_name,phone,avatar_url,is_platform_admin").eq("id",data.user.id).single());
 return {sb,user:data.user,memberships,profile,isAdmin:profile.is_platform_admin};
}
export function ws(c:any,requested:any){
 if(requested){id(requested);if(c.isAdmin||c.memberships.some((m:any)=>m.workspace_id===requested&&m.member_type==="internal"))return requested;throw new HttpError(403,"No internal access to workspace");}
 const mine=c.memberships.filter((m:any)=>m.member_type==="internal");if(mine.length===1)return mine[0].workspace_id;
 throw new HttpError(400,"Select a workspace");
}
export function wsAdmin(c:any,w:string){if(!c.isAdmin&&!c.memberships.some((m:any)=>m.workspace_id===w&&m.member_type==="internal"&&m.role==="admin"))throw new HttpError(403,"Workspace admin required");}
export function panels(c:any,w?:string){const m=c.memberships.find((m:any)=>m.workspace_id===w&&m.member_type==="internal");const base=["projects","profile","notifications"];if(c.isAdmin||m)base.push("dashboard","opportunities","quick-referral","customers","new-service");if(c.isAdmin||m?.role==="admin")base.push("user-list","user-management","user-tiers","core-services","location","workspace");return base;}
export function serve(routes:Record<string,(c:any,b:any)=>Promise<any>>){Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 try{if(req.method!=="POST")throw new HttpError(405,"Use POST");const c=await ctx(req);let b;try{b=await req.json();}catch{throw new HttpError(400,"JSON body required");}if(!b||typeof b!=="object"||Array.isArray(b))throw new HttpError(400,"JSON object required");const fn=routes[b.action];if(!fn)throw new HttpError(400,"Unknown action");return json({data:await fn(c,b)});}
 catch(e:any){const status=e instanceof HttpError?e.status:e.code==="42501"?403:e.code==="28000"?401:e.code==="P0002"?404:e.code==="23505"?409:400;return json({error:e.message||"Request failed"},status);}
});}
export const projectSelect="*,customers(id,full_name,email,phone,property_type),services(id,name,code),opportunities(id,address,city,state,postal_code,priority,damage_notes,preferred_date,preferred_window),project_members(user_id,role,profiles!project_members_user_id_fkey(id,full_name))";
export async function project(c:any,p:any){return ok(await c.sb.from("projects").select(projectSelect).eq("id",id(p)).single());}
