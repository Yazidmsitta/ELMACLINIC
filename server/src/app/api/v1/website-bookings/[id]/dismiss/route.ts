import { z } from 'zod';
import { authenticate } from '../../../../../../lib/auth';
import { databaseError } from '../../../../../../lib/catalog';
import { handle, HttpError, json } from '../../../../../../lib/http';
export const runtime = 'nodejs';
export async function POST(request:Request, context:{params:Promise<{id:string}>}) {
  return handle(async()=>{
    const {db}=await authenticate(request);
    const id=z.uuid().parse((await context.params).id);
    const body=z.object({version:z.number().int().positive(),reason:z.string().trim().min(3).max(500)}).strict().parse(await request.json());
    const result=await db.rpc('dismiss_website_booking',{event_record:id,expected_version:body.version,reason:body.reason});
    databaseError(result.error);
    if(!result.data)throw new HttpError(404,'Réservation introuvable.');
    return json({id:result.data});
  });
}
