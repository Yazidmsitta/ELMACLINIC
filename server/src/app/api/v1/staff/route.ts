import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle, json } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const page=z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page')??1);
  const result=await db.from('profiles').select('id,full_name,role,active,version',{count:'exact'}).order('full_name').order('id').range((page-1)*50,page*50-1);
  databaseError(result.error);return json({data:result.data,total:result.count,has_more:page*50<(result.count??0),page,per_page:50});
});}
