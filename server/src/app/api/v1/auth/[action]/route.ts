import { z } from 'zod';
import { createHmac } from 'node:crypto';
import { authenticate } from '../../../../../lib/auth';
import { database, privilegedDatabase } from '../../../../../lib/supabase';
import { handle, HttpError, json } from '../../../../../lib/http';
export const runtime = 'nodejs';
type Context = { params: Promise<{ action: string }> };
export async function GET(request: Request, context: Context) {
  return handle(async () => {
    if ((await context.params).action !== 'me') throw new HttpError(404, 'Introuvable.');
    return json({ user: (await authenticate(request)).user });
  });
}
export async function POST(request: Request, context: Context) {
  return handle(async () => {
    const { action } = await context.params;
    if (action === 'logout') {
      const { token } = await authenticate(request);
      const { error } = await privilegedDatabase().auth.admin.signOut(token, 'local');
      if (error) throw new HttpError(503, 'Déconnexion indisponible.');
      return json({ message: 'Déconnecté.' });
    }
    if (!['login', 'refresh'].includes(action)) throw new HttpError(404, 'Introuvable.');
    const secret = process.env.RATE_LIMIT_SECRET;
    if (!secret || secret.length < 32) throw new Error('Missing rate limit secret');
    const ip = process.env.TRUST_VERCEL_PROXY === 'true' && process.env.VERCEL ? request.headers.get('x-vercel-forwarded-for') ?? 'shared' : 'shared';
    const key = createHmac('sha256', secret).update(`${action}:${ip}`).digest('hex');
    const limit = await privilegedDatabase().rpc('consume_auth_limit', { bucket_key: key, maximum: action === 'login' ? 20 : 120 });
    if (limit.error) throw new Error('Rate limiter unavailable');
    if (!limit.data) throw new HttpError(429, 'Trop de tentatives.');
    const body = await request.json();
    const db = database();
    const result = action === 'login'
      ? await db.auth.signInWithPassword(z.object({ email: z.email().max(254), password: z.string().min(1).max(256) }).parse(body))
      : await db.auth.refreshSession(z.object({ refresh_token: z.string().min(1).max(4096) }).parse(body));
    if (result.error || !result.data.session) throw new HttpError(result.error?.status && result.error.status >= 500 ? 503 : 401, 'Identifiants ou session invalides.');
    const session = result.data.session;
    let identity;
    try {
      identity = await authenticate(new Request(request.url, { headers: { authorization: `Bearer ${session.access_token}` } }));
    } catch (error) {
      // A valid Auth account without an active staff profile must not retain a new session.
      if (error instanceof HttpError && error.status === 403) {
        await privilegedDatabase().auth.admin.signOut(session.access_token, 'local');
      }
      throw error;
    }
    return json({ session: { access_token: session.access_token, refresh_token: session.refresh_token, expires_at: session.expires_at }, user: identity.user });
  });
}
