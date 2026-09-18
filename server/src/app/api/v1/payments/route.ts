import { z } from 'zod';
import { authenticate } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle, HttpError, json } from '../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request) {
  return handle(async()=>{
    const {db}=await authenticate(request);
    const page=z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page')??1);
    const result=await db.rpc('payment_ledger',{page_number:page});databaseError(result.error);return json(result.data);
  });
}
export async function POST(request:Request) {
  return handle(async()=>{
    const {db}=await authenticate(request);
    const body=z.object({appointment_id:z.uuid(),amount_centimes:z.number().int().positive().max(2147483647),
      method:z.enum(['CASH','CARD','TRANSFER']),request_id:z.uuid()}).strict().parse(await request.json());
    const result=await db.rpc('record_payment',{appointment:body.appointment_id,amount:body.amount_centimes,payment_method:body.method,request_key:body.request_id});
    databaseError(result.error);
    if(!result.data)throw new HttpError(404,'Rendez-vous introuvable.');
    return json({id:result.data},201);
  });
}
