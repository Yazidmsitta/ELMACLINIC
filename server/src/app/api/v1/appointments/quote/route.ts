import { authenticate } from '../../../../../lib/auth';
import { handle,json } from '../../../../../lib/http';
import { bookingSelection,appointmentError } from '../../../../../lib/appointments';
export const runtime='nodejs';
export async function POST(request:Request) {
  return handle(async () => {
    const {db}=await authenticate(request); const body=bookingSelection.parse(await request.json());
    const result=await db.rpc(body.pack_ids.length ? 'quote_appointment_cart' : 'quote_appointment',{
      client:body.client_id,practitioner:body.practitioner_id,service_ids:body.service_ids,
      ...(body.pack_ids.length ? {pack_ids:body.pack_ids} : {}),slot_start:body.starts_at,
    });
    appointmentError(result.error); return json({data:result.data});
  });
}
