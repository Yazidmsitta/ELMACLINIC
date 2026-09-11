import { z } from 'zod';
import { authenticate } from '../../../../../../lib/auth';
import { databaseError } from '../../../../../../lib/catalog';
import { handle,json } from '../../../../../../lib/http';
export const runtime='nodejs';
export async function POST(request:Request,context:{params:Promise<{id:string}>}){
  return handle(async()=>{
    const {db}=await authenticate(request);
    const id=z.uuid().parse((await context.params).id);
    const result=await db.rpc('mark_notification_read',{record_id:id});
    databaseError(result.error);
    return result.data?json({id:result.data}):json({message:'Notification introuvable.'},404);
  });
}
