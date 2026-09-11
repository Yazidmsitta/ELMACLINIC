import { authenticate } from '../../../../lib/auth';
import { handle, json } from '../../../../lib/http';
export const runtime = 'nodejs';
export async function GET(request: Request) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const result = await db.rpc('dashboard_summary');
    if (result.error) throw new Error('Dashboard unavailable');
    return json({ data: result.data });
  });
}
