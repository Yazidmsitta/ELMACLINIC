import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { handle, json } from '../../../../../lib/http';
import { productFields, productArgs } from '../../../../../lib/inventory';
export const runtime = 'nodejs';
export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }) {
  return handle(async () => {
    const { db, user } = await authenticate(request); requireAdmin(user.role);
    const id = z.uuid().parse((await context.params).id);
    const body = productFields.extend({ version: z.number().int().positive().max(2147483647) }).parse(await request.json());
    const result = await db.rpc('save_product', { ...productArgs(body), record_id: id, expected_version: body.version });
    databaseError(result.error);
    return result.data ? json({ id: result.data }) : json({ message: 'Produit introuvable.' }, 404);
  });
}
