import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../../lib/auth';
import { databaseError } from '../../../../../../lib/catalog';
import { handle, json } from '../../../../../../lib/http';
export const runtime = 'nodejs';
export async function GET(request: Request, context: { params: Promise<{ id: string }> }) {
  return handle(async () => {
    const { db, user } = await authenticate(request); requireAdmin(user.role);
    const id = z.uuid().parse((await context.params).id);
    const page = z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page') ?? 1);
    const result = await db.rpc('inventory_history', { product: id, page_number: page });
    databaseError(result.error);
    return result.data ? json(result.data) : json({ message: 'Produit introuvable.' }, 404);
  });
}
