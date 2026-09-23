import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../../lib/auth';
import { appointmentError } from '../../../../../../lib/appointments';
import { handle, HttpError, json } from '../../../../../../lib/http';

export const runtime = 'nodejs';

export async function POST(
  request: Request,
  context: { params: Promise<{ id: string }> },
) {
  return handle(async () => {
    const { db, user } = await authenticate(request);
    requireAdmin(user.role);
    const id = z.uuid().parse((await context.params).id);
    const body = z.object({ version: z.number().int().positive() }).strict()
      .parse(await request.json());
    const result = await db.rpc('archive_imported_website_booking', {
      event_record: id,
      expected_version: body.version,
    });
    appointmentError(result.error);
    if (!result.data) throw new HttpError(404, 'Réservation introuvable.');
    return json({ archived: true });
  });
}