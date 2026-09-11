import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { databaseError } from '../../../../../lib/catalog';
import { handle, json } from '../../../../../lib/http';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  return handle(async () => {
    const { db, user } = await authenticate(request);
    requireAdmin(user.role);
    const result = await db.rpc('expense_summary');
    databaseError(result.error);
    return json(result.data);
  });
}
