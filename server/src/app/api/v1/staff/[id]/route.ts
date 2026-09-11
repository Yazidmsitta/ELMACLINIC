import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { handle, json } from '../../../../../lib/http';
export const runtime='nodejs';
export async function PATCH(request:Request,context:{params:Promise<{id:string}>}){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const id=z.uuid().parse((await context.params).id);
  const body=z.object({full_name:z.string().trim().min(1).max(200),role:z.enum(['ADMIN','USER']),active:z.boolean(),version:z.number().int().positive().max(2147483647)}).strict().parse(await request.json());
  const result=await db.rpc('update_staff',{record_id:id,name_text:body.full_name,role_text:body.role,enabled:body.active,expected_version:body.version});
  databaseError(result.error);return result.data?json({id:result.data}):json({message:'Utilisateur introuvable.'},404);
});}
