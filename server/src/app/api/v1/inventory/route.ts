import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle, json } from '../../../../lib/http';
import { productFields, productArgs } from '../../../../lib/inventory';
export const runtime = 'nodejs';
export async function GET(request: Request) {
  return handle(async () => {
    const { db, user } = await authenticate(request); requireAdmin(user.role);
    const page = z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page') ?? 1);
    const result = await db.rpc('inventory_list', { page_number: page });
    databaseError(result.error); return json(result.data);
  });
}
export async function POST(request: Request) {
  return handle(async () => {
    const { db, user } = await authenticate(request); requireAdmin(user.role);
    const body = productFields.parse(await request.json());
    const result = await db.rpc('save_product', productArgs(body));
    databaseError(result.error); return json({ id: result.data }, 201);
  });
}
