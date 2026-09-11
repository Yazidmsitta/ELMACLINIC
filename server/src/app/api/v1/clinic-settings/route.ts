import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle, json } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const result=await db.from('settings').select('value,version').eq('key','clinic_profile').maybeSingle();
  databaseError(result.error);return json({data:result.data?.value??null,version:result.data?.version??0});
});}
export async function PUT(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const body=z.object({name:z.string().trim().min(1).max(200),phone:z.string().trim().max(40),address:z.string().trim().max(1000),version:z.number().int().min(0).max(2147483646)}).strict().parse(await request.json());
  const result=await db.rpc('save_clinic_settings',{clinic_name:body.name,phone_text:body.phone,address_text:body.address,expected_version:body.version});
  databaseError(result.error);return json({saved:true,version:result.data});
});}
