import { z } from 'zod';
import { authenticate,requireAdmin } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { expenseFields } from '../../../../lib/expenses';
import { handle,json } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const params=new URL(request.url).searchParams;
  const page=z.coerce.number().int().min(1).max(100000).parse(params.get('page')??1);
  const state=z.enum(['active','voided']).parse(params.get('state')??'active');
  let query=db.from('expenses').select('id,description,category,amount_centimes,spent_on,version,voided_at,void_reason',{count:'exact'});
  query=state==='active'?query.is('voided_at',null):query.not('voided_at','is',null);
  const result=await query.order('spent_on',{ascending:false}).order('id').range((page-1)*50,page*50-1);
  databaseError(result.error);return json({data:result.data,page,per_page:50,total:result.count,has_more:page*50<(result.count??0)});
});}
export async function POST(request:Request){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const body=expenseFields.extend({request_id:z.uuid()}).parse(await request.json());
  const result=await db.rpc('save_expense',{description_text:body.description,category_text:body.category,amount:body.amount_centimes,expense_date:body.spent_on,request_key:body.request_id});
  databaseError(result.error);return json({id:result.data},201);
});}
