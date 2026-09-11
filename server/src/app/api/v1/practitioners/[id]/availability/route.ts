import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../../lib/auth';
import { handle, HttpError, json } from '../../../../../../lib/http';
import { databaseError } from '../../../../../../lib/catalog';
export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
const time = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/);
const schema = z.object({
  shifts: z.array(z.object({ weekday: z.number().int().min(1).max(7), starts_at: time, ends_at: time }).strict().refine(s => s.ends_at > s.starts_at)).max(28),
  absences: z.array(z.object({ starts_at: z.iso.datetime({ offset: true }), ends_at: z.iso.datetime({ offset: true }) }).strict().refine(s => Date.parse(s.ends_at) > Date.parse(s.starts_at))).max(100),
}).strict();
export async function GET(request: Request, context: Context) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const id = z.uuid().parse((await context.params).id);
    const practitioner = await db.from('practitioners').select('id').eq('id', id).is('deleted_at', null).maybeSingle();
    databaseError(practitioner.error);
    if (!practitioner.data) throw new HttpError(404, 'Praticienne introuvable.');
    const [shifts, absences] = await Promise.all([
      db.from('practitioner_schedules').select('weekday,starts_at,ends_at').eq('practitioner_id', id).order('weekday').order('starts_at'),
      db.from('practitioner_time_off').select('starts_at,ends_at').eq('practitioner_id', id).order('starts_at'),
    ]);
    databaseError(shifts.error); databaseError(absences.error);
    return json({ data: { shifts: shifts.data, absences: absences.data, timezone: 'Africa/Casablanca' } });
  });
}
export async function PUT(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request);
    requireAdmin(identity.user.role);
    const id = z.uuid().parse((await context.params).id);
    const body = schema.parse(await request.json());
    const result = await identity.db.rpc('replace_practitioner_availability', { practitioner: id, ...body });
    databaseError(result.error);
    if (!result.data) throw new HttpError(404, 'Praticienne introuvable.');
    return json({ message: 'Disponibilités enregistrées.' });
  });
}
