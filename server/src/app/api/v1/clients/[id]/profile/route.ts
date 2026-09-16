import { z } from 'zod';
import { authenticate } from '../../../../../../lib/auth';
import { handle, HttpError, json } from '../../../../../../lib/http';
import { databaseError } from '../../../../../../lib/catalog';
export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
export async function GET(request: Request, context: Context) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const id = z.uuid().parse((await context.params).id);
    const result = await db.rpc('client_profile', { record_id: id });
    databaseError(result.error);
    if (!result.data) throw new HttpError(404, 'Client introuvable.');
    return json({ data: result.data });
  });
}
