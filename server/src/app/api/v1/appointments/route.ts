import { z } from 'zod';
import { authenticate } from '../../../../lib/auth';
import { handle, json } from '../../../../lib/http';
import { appointmentStatus, bookingCreate, appointmentError } from '../../../../lib/appointments';
export const runtime='nodejs';
export async function GET(request:Request) {
  return handle(async () => {
    const {db}=await authenticate(request);
    const params=new URL(request.url).searchParams;
    const result=await db.rpc('appointments_day',{
      day:z.iso.date().parse(params.get('date')),
      status_filter:params.has('status') ? appointmentStatus.parse(params.get('status')) : null,
      source_filter:params.has('source') ? z.enum(['MANUAL','WEBSITE']).parse(params.get('source')) : null,
      practitioner_filter:params.has('practitioner_id') ? z.uuid().parse(params.get('practitioner_id')) : null,
      page_number:z.coerce.number().int().min(1).max(100000).parse(params.get('page')??1),
    });
    appointmentError(result.error); return json(result.data);
  });
}
export async function POST(request:Request) {
  return handle(async () => {
    const {db}=await authenticate(request);
    const body=bookingCreate.parse(await request.json());
    const result=await db.rpc(body.pack_ids.length ? 'create_manual_appointment_cart' : 'create_manual_appointment',{
      client:body.client_id,practitioner:body.practitioner_id,service_ids:body.service_ids,slot_start:body.starts_at,
      ...(body.pack_ids.length ? {pack_ids:body.pack_ids} : {}),
      booking_notes:body.notes??null,request_key:body.request_id,
      expected_total:body.expected_total_centimes,expected_duration:body.expected_duration_minutes,
    });
    appointmentError(result.error); return json({id:result.data},201);
  });
}
