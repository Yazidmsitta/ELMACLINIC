import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle,json } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const params=new URL(request.url).searchParams;
  const page=z.coerce.number().int().min(1).max(100000).parse(params.get('page')??1);
  let query=db.from('activity_logs').select('id,actor_id,action,entity_type,entity_id,created_at,actor:profiles!activity_logs_actor_id_fkey(full_name)',{count:'exact'});
  if(params.has('actor_id'))query=query.eq('actor_id',z.uuid().parse(params.get('actor_id')));
  if(params.has('entity_type'))query=query.eq('entity_type',z.string().regex(/^[a-z_]{1,60}$/).parse(params.get('entity_type')));
  const result=await query.order('created_at',{ascending:false}).order('id').range((page-1)*50,page*50-1);
  databaseError(result.error);return json({data:result.data?.map(({actor,...entry})=>({...entry,actor_name:actorName(actor)})),total:result.count,page,per_page:50,has_more:page*50<(result.count??0)});
});}

function actorName(actor: unknown): string | null {
 const profile = Array.isArray(actor) ? actor[0] : actor;
 return profile && typeof profile === "object" && "full_name" in profile && typeof profile.full_name === "string" ? profile.full_name : null;
}
