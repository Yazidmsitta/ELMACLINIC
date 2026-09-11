import { expect, test } from 'vitest';
import sharp from 'sharp';
import { sanitizeServiceImage } from '../src/lib/service-image';
test('image processor rejects fake images and oversized bodies', async () => {
  await expect(sanitizeServiceImage(new Request('http://localhost',{method:'PUT',headers:{'content-type':'image/jpeg'},body:'not an image'}))).rejects.toMatchObject({status:422});
  await expect(sanitizeServiceImage(new Request('http://localhost',{method:'PUT',headers:{'content-type':'image/jpeg','content-length':'2097153'},body:'x'}))).rejects.toMatchObject({status:413});
  await expect(sanitizeServiceImage(new Request('http://localhost',{method:'PUT',headers:{'content-type':'image/svg+xml'},body:'<svg/>'}))).rejects.toMatchObject({status:422});
});
test('valid input becomes bounded JPEG without original metadata', async () => {
  const input = await sharp({create:{width:1800,height:100,channels:3,background:'white'}}).png().withMetadata().toBuffer();
  const result = await sanitizeServiceImage(new Request('http://localhost',{method:'PUT',headers:{'content-type':'image/png'},body:new Uint8Array(input)}));
  const metadata = await sharp(result).metadata();
  expect(metadata.format).toBe('jpeg'); expect(metadata.width).toBe(1600); expect(metadata.exif).toBeUndefined();
});
