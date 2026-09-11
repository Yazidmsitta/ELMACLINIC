import { z } from 'zod';
import { authenticate } from '../../../../../../lib/auth';
import { databaseError } from '../../../../../../lib/catalog';
import { handle, HttpError, json } from '../../../../../../lib/http';
export const runtime='nodejs';
export async function GET(request:Request,context:{params:Promise<{id:string}>}) {
  return handle(async()=>{
    const {db}=await authenticate(request);
    const result=await db.rpc('appointment_payment_balance',{appointment:z.uuid().parse((await context.params).id)});
    databaseError(result.error);
    if(!result.data)throw new HttpError(404,'Rendez-vous introuvable.');
    return json({data:result.data});
  });
}
