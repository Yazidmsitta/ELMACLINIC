import { z } from 'zod';
import { authenticate,requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { expenseFields } from '../../../../../lib/expenses';
import { handle,HttpError,json } from '../../../../../lib/http';
export const runtime='nodejs';
type Context={params:Promise<{id:string}>};
export async function PATCH(request:Request,context:Context){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const id=z.uuid().parse((await context.params).id);
  const body=expenseFields.extend({version:z.number().int().positive()}).parse(await request.json());
  const result=await db.rpc('save_expense',{description_text:body.description,category_text:body.category,amount:body.amount_centimes,expense_date:body.spent_on,record_id:id,expected_version:body.version});
  databaseError(result.error);if(!result.data)throw new HttpError(404,'Dépense introuvable.');return json({id:result.data});
});}
export async function DELETE(request:Request,context:Context){return handle(async()=>{
  const {db,user}=await authenticate(request);requireAdmin(user.role);
  const id=z.uuid().parse((await context.params).id);
  const body=z.object({version:z.number().int().positive(),reason:z.string().trim().min(3).max(500)}).strict().parse(await request.json());
  const result=await db.rpc('void_expense',{record_id:id,expected_version:body.version,reason:body.reason});
  databaseError(result.error);if(!result.data)throw new HttpError(404,'Dépense introuvable.');return json({id:result.data});
});}
