import { z } from 'zod';
import { authenticate } from '../../../../../../lib/auth';
import { appointmentError } from '../../../../../../lib/appointments';
import { handle, HttpError, json } from '../../../../../../lib/http';

const selection = z.object({
  version: z.number().int().positive(), client_id: z.uuid(), practitioner_id: z.uuid(),
  service_ids: z.array(z.uuid()).min(1).max(10).refine(ids => new Set(ids).size === ids.length),
  expected_total_centimes: z.number().int().min(0).max(1000000000),
  expected_duration_minutes: z.number().int().min(1).max(1440),
  notes: z.string().trim().max(2000).nullable().optional(),
}).strict();
export const runtime = 'nodejs';
export async function POST(request: Request, context: { params: Promise<{ id: string }> }) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const id = z.uuid().parse((await context.params).id);
    const body = selection.parse(await request.json());
    const result = await db.rpc('import_website_booking', {
      event_record: id, expected_version: body.version, client: body.client_id,
      practitioner: body.practitioner_id, service_ids: body.service_ids,
      expected_total: body.expected_total_centimes, expected_duration: body.expected_duration_minutes,
    });
    appointmentError(result.error);
    if (!result.data) throw new HttpError(404, 'Réservation introuvable.');
    if (body.notes !== undefined) {
      const appointment = await db.from('appointments')
        .select('version,practitioner_id,starts_at')
        .eq('id', result.data)
        .maybeSingle();
      if (appointment.error || !appointment.data) throw new Error('Appointment lookup unavailable');
      const updated = await db.rpc('change_appointment', {
        record_id: result.data,
        expected_version: appointment.data.version,
        command: 'RESCHEDULE',
        new_practitioner: appointment.data.practitioner_id,
        new_start: appointment.data.starts_at,
        new_notes: body.notes,
        new_status: null,
      });
      appointmentError(updated.error);
    }
    return json({ id: result.data }, 201);
  });
}
