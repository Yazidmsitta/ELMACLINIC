import { createHmac } from 'node:crypto';
import { z } from 'zod';
import { privilegedDatabase } from '../../../../../lib/supabase';
import { handle, HttpError, json } from '../../../../../lib/http';
import { SignedWebsiteAdapter, WebsiteDeliveryError } from '../../../../../lib/integrations/signed-website-adapter';

export const runtime = 'nodejs';
const receipt = z.object({
  id: z.uuid(), state: z.enum(['REVIEW', 'IMPORTED', 'DISMISSED']),
  appointment_id: z.uuid().nullable(), replayed: z.boolean(),
});

export async function POST(request: Request) {
  return handle(async () => {
    if (process.env.WEBSITE_WEBHOOK_ENABLED !== 'true') throw new HttpError(503, 'Réception des réservations désactivée.');
    const secret = process.env.WEBSITE_WEBHOOK_SECRET_HEX;
    const limiterSecret = process.env.RATE_LIMIT_SECRET;
    if (!secret || !limiterSecret || limiterSecret.length < 32) throw new Error('Missing webhook configuration');
    let event;
    try { event = await new SignedWebsiteAdapter(secret).authenticateAndDecode(request); }
    catch (error) {
      if (error instanceof WebsiteDeliveryError) throw new HttpError(error.status, error.message);
      throw error;
    }
    // Only authenticated deliveries reach the database. Use a shared durable
    // provider bucket; arbitrary request headers cannot evade this allowance.
    const db = privilegedDatabase();
    const limit = await db.rpc('consume_auth_limit', {
      bucket_key: createHmac('sha256', limiterSecret).update('website-bookings:elmaclinic.ma:v1').digest('hex'), maximum: 60,
    });
    if (limit.error) throw new Error('Webhook limiter unavailable');
    if (!limit.data) {
      const response = json({ message: 'Trop de livraisons. Réessayez dans une minute.' }, 429);
      response.headers.set('Retry-After', '60');
      return response;
    }
    const result = await db.rpc('receive_website_booking', { event_payload: event });
    if (result.error?.code === '23505') throw new HttpError(409, 'Identifiant d’événement déjà utilisé.');
    if (result.error) throw new Error('Webhook storage unavailable');
    const parsed = receipt.safeParse(result.data);
    if (!parsed.success) throw new Error('Invalid receipt response');
    return json(parsed.data, parsed.data.replayed ? 200 : 202);
  });
}
