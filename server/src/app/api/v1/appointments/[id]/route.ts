import { z } from 'zod';
import { authenticate,requireAdmin } from '../../../../../lib/auth';
import { handle,HttpError,json } from '../../../../../lib/http';
import { appointmentStatus,appointmentError } from '../../../../../lib/appointments';
export const runtime='nodejs';
type Context={params:Promise<{id:string}>};
const version=z.number().int().positive();
const change=z.discriminatedUnion('action',[
  z.object({action:z.literal('STATUS'),version,status:appointmentStatus}).strict(),
  z.object({action:z.literal('RESCHEDULE'),version,practitioner_id:z.uuid(),starts_at:z.iso.datetime({offset:true}),notes:z.string().trim().max(2000).nullable()}).strict(),
]);
export async function GET(request:Request,context:Context) {
  return handle(async () => {
    const {db}=await authenticate(request);const id=z.uuid().parse((await context.params).id);
    const result=await db.rpc('appointment_details',{record_id:id}); appointmentError(result.error);
    if (!result.data) throw new HttpError(404,'Rendez-vous introuvable.'); return json({data:result.data});
  });
}
export async function PATCH(request:Request,context:Context) {
  return handle(async () => {
    const {db}=await authenticate(request);const id=z.uuid().parse((await context.params).id);
    const body=change.parse(await request.json());
    const result=await db.rpc('change_appointment',{record_id:id,expected_version:body.version,command:body.action,
      ...(body.action==='STATUS' ? {new_status:body.status} : {new_practitioner:body.practitioner_id,new_start:body.starts_at,new_notes:body.notes})});
    appointmentError(result.error);if(!result.data) throw new HttpError(404,'Rendez-vous introuvable.');return json({id:result.data});
  });
}
export async function DELETE(request:Request,context:Context) {
  return handle(async () => {
    const identity=await authenticate(request); requireAdmin(identity.user.role);
    const id=z.uuid().parse((await context.params).id);
    const body=z.object({version}).strict().parse(await request.json());
    const result=await identity.db.rpc('change_appointment',{record_id:id,expected_version:body.version,command:'ARCHIVE'});
    appointmentError(result.error);if(!result.data) throw new HttpError(404,'Rendez-vous introuvable.');return json({message:'Rendez-vous archivé.'});
  });
}
