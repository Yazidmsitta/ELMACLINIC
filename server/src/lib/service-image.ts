import sharp from 'sharp';
import { HttpError } from './http';

export async function sanitizeServiceImage(request: Request): Promise<Buffer> {
  const limit = 2 * 1024 * 1024;
  if (!['image/jpeg','image/png','image/webp'].includes(request.headers.get('content-type') ?? '')) throw new HttpError(422, 'Choisissez une image JPEG, PNG ou WebP.');
  if (Number(request.headers.get('content-length')) > limit) throw new HttpError(413, 'Image limitée à 2 Mo.');
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(422, 'Image manquante.');
  const chunks: Uint8Array[] = []; let length = 0;
  try {
    while (true) {
      const { value, done } = await reader.read(); if (done) break;
      length += value.byteLength;
      if (length > limit) { await reader.cancel(); throw new HttpError(413, 'Image limitée à 2 Mo.'); }
      chunks.push(value);
    }
  } finally { reader.releaseLock(); }
  try {
    const pipeline = sharp(Buffer.concat(chunks), { limitInputPixels: 20000000, failOn: 'warning' });
    const metadata = await pipeline.metadata();
    if (!['jpeg','png','webp'].includes(metadata.format ?? '') || (metadata.pages ?? 1) !== 1) throw new Error('Unsupported image');
    // Re-encode to remove EXIF/location and active/polyglot payloads.
    return await pipeline.rotate().resize(1600,1600,{fit:'inside',withoutEnlargement:true}).jpeg({quality:80}).toBuffer();
  } catch { throw new HttpError(422, 'Le fichier ne contient pas une image valide.'); }
}
