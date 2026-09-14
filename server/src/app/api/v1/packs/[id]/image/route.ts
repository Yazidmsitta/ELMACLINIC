import { randomUUID } from 'node:crypto';
import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../../lib/auth';
import { privilegedDatabase } from '../../../../../../lib/supabase';
import { databaseError } from '../../../../../../lib/catalog';
import { handle, HttpError, json } from '../../../../../../lib/http';
import { sanitizeServiceImage } from '../../../../../../lib/service-image';
export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
export async function PUT(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request); requireAdmin(identity.user.role);
    const id = z.uuid().parse((await context.params).id);
    const existing = await identity.db.from('packs').select('id,image_path').eq('id',id).maybeSingle();
    databaseError(existing.error);
    if (!existing.data) throw new HttpError(404,'Pack introuvable.');
    const bytes = await sanitizeServiceImage(request);
    const path = `${id}/${randomUUID()}.jpg`;
    const storage = privilegedDatabase().storage.from('pack-images');
    const uploaded = await storage.upload(path,bytes,{contentType:'image/jpeg',upsert:false});
    if (uploaded.error) throw new Error('Image upload failed');
    const linked = await identity.db.rpc('set_pack_image',{pack:id,object_path:path});
    if (linked.error || !linked.data) {
      await storage.remove([path]); databaseError(linked.error);
      throw new HttpError(404,'Pack introuvable.');
    }
    if (existing.data.image_path) await storage.remove([existing.data.image_path]);
    return json({message:'Photo enregistrée.'});
  });
}
