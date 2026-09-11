import { z } from 'zod';
import { authenticate } from '../../../../lib/auth';
import { databaseError } from '../../../../lib/catalog';
import { handle, json } from '../../../../lib/http';

export const runtime = 'nodejs';
export async function GET(request: Request) {
  return handle(async () => {
    const { db } = await authenticate(request);
    const params = new URL(request.url).searchParams;
    const page = z.coerce.number().int().min(1).max(100000).parse(params.get('page') ?? 1);
    const state = z.enum(['REVIEW', 'IMPORTED', 'DISMISSED']).parse(params.get('state') ?? 'REVIEW');
    const result = await db.from('website_booking_events')
      .select('id,booking_id,payload,occurred_at,state,version,appointment_id,created_at,dismissal_reason', { count: 'exact' })
      .eq('state', state).order('created_at', { ascending: false }).order('id')
      .range((page - 1) * 50, page * 50 - 1);
    databaseError(result.error);
    return json({ data: result.data, page, per_page: 50, total: result.count, has_more: page * 50 < (result.count ?? 0) });
  });
}
