import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { handle, json } from '../../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const params=new URL(request.url).searchParams;
  const first=z.iso.date().parse(params.get('from')),last=z.iso.date().parse(params.get('to'));
  const result=await db.rpc('financial_report',{first_day:first,last_day:last});
  databaseError(result.error);return json(result.data);
});}
