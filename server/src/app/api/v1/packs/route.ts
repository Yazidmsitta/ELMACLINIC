import { z } from 'zod';
import { authenticate,requireAdmin } from '../../../../lib/auth';
import { privilegedDatabase } from '../../../../lib/supabase';
import { databaseError } from '../../../../lib/catalog';
import { handle,json,HttpError } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
 const {db}=await authenticate(request);const page=z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page')??1);
 const r=await db.from('packs').select('id,name,description,price_centimes,total_sessions,active,version,image_path,items:pack_items(service_id,sessions)',{count:'exact'}).order('name').order('id').range((page-1)*50,page*50-1);databaseError(r.error);
 const data=await Promise.all((r.data??[]).map(async({image_path,...p})=>{let image_url:string|null=null;if(image_path){const signed=await privilegedDatabase().storage.from('pack-images').createSignedUrl(image_path,300);if(!signed.error)image_url=signed.data.signedUrl;}return {...p,image_url};}));
 return json({data,has_more:page*50<(r.count??0)});
});}
export async function POST(request:Request){return handle(async()=>{
 const {db,user}=await authenticate(request);requireAdmin(user.role);
 const b=z.object({id:z.uuid().nullable(),name:z.string().trim().min(1).max(200),description:z.string().max(2000).nullable(),price_centimes:z.number().int().min(0).max(100000000),total_sessions:z.number().int().min(1).max(100),active:z.boolean(),version:z.number().int().min(0),items:z.array(z.object({service_id:z.uuid(),sessions:z.number().int().min(1).max(100)}).strict()).max(30).default([])}).strict().parse(await request.json());
 const r=await db.rpc('save_pack',{record_id:b.id,pack_name:b.name,description_text:b.description,price:b.price_centimes,total_sessions_count:b.total_sessions,enabled:b.active,expected_version:b.version,items:b.items});databaseError(r.error);if(!r.data)throw new HttpError(404,'Pack introuvable.');return json({id:r.data},b.id?200:201);
});}
