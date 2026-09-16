import { z } from 'zod';
import { authenticate } from '../../../../../../../../lib/auth';
import { handle, json } from '../../../../../../../../lib/http';
import { databaseError } from '../../../../../../../../lib/catalog';
export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string; packId: string }> };
const schema = z.object({
  delta: z.number().int().min(-100).max(100).refine((value) => value !== 0),
  reason: z.string().trim().max(500).nullable().optional(),
}).strict();
export async function POST(request: Request, context: Context) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const params = await context.params;
    const clientId = z.uuid().parse(params.id);
    const packId = z.uuid().parse(params.packId);
    const body = schema.parse(await request.json());
    const result = await db.rpc('adjust_client_pack_sessions', {
      client: clientId,
      pack: packId,
      session_delta: body.delta,
      adjustment_reason: body.reason ?? null,
    });
    databaseError(result.error);
    return json({ data: result.data });
  });
}
