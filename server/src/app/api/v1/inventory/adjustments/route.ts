import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { handle, json } from '../../../../../lib/http';

export const runtime = 'nodejs';
const input = z.object({
  product_id: z.uuid(),
  quantity: z.string().regex(/^-?\d{1,9}(?:\.\d{1,3})?$/).refine(value => !/^-?0+(?:\.0+)?$/.test(value)),
  reason: z.string().trim().min(3).max(500),
  request_id: z.uuid(),
}).strict();

export async function POST(request: Request) {
  return handle(async () => {
    const { db, user } = await authenticate(request);
    requireAdmin(user.role);
    const body = input.parse(await request.json());
    const result = await db.rpc('adjust_inventory', {
      product: body.product_id, quantity_delta: body.quantity,
      reason_text: body.reason, request_key: body.request_id,
    });
    databaseError(result.error);
    if (!result.data) return json({ message: 'Produit introuvable.' }, 404);
    return json({ id: result.data }, 201);
  });
}
