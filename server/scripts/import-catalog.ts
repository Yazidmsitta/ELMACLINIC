import { createClient } from '@supabase/supabase-js';
import sharp from 'sharp';

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error('Missing Supabase credentials.');

const db = createClient(url, key, { auth: { persistSession: false } });
const defaultDuration = 60;
const imageSources: Record<string, string> = {
  'Laser - Femme': 'https://images.unsplash.com/photo-1516975080664-ed2fc6a32937?w=1200&q=80',
  'Laser - Hommes': 'https://images.unsplash.com/photo-1621605815971-fbc98d665033?w=1200&q=80',
  'Soins dos et corps': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=1200&q=80',
  'Head Spa': 'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?w=1200&q=80',
  'Soins capillaires': 'https://images.unsplash.com/photo-1562322140-8baeececf3df?w=1200&q=80',
  'Nail Bar': 'https://images.unsplash.com/photo-1604654894610-df63bc536371?w=1200&q=80',
  HydraFacial: 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=1200&q=80',
  'Soins visage avances': 'https://images.unsplash.com/photo-1616394584738-fc6e612e71b9?w=1200&q=80',
  'Injectables et rejuvenation': 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=1200&q=80',
};

type Service = { name: string; category: string; price: number; duration?: number; description?: string };
type Pack = { name: string; price: number; service: string; sessions: number; category: string };

const services: Service[] = [
  ...[
    ['Levre superieure', 200], ['Menton', 300], ['Visage', 600], ['Aisselles', 400],
    ['Maillot integral', 700], ['Bord du maillot', 400], ['Demi-jambes', 400],
    ['Jambes completes', 700], ['Bras', 600], ['Demi-bras', 400], ['Fesses', 500],
    ['Corps complet', 3500],
  ].map(([name, price]) => ({ name, price, category: 'Laser - Femme' } as Service)),
  ...[
    ['Tracage de barbe', 400], ['Barbe complete', 700], ['Cou', 400], ['Tour d’oreille', 300],
    ['Entre sourcils', 200], ['Torse', 600], ['Ventre', 600], ['Dos', 600],
    ['Demi-jambe homme', 600], ['Demi-bras homme', 600],
  ].map(([name, price]) => ({ name, price, category: 'Laser - Hommes' } as Service)),
  { name: 'Soins dos propreté', category: 'Soins dos et corps', price: 800 },
  { name: 'Peeling dos', category: 'Soins dos et corps', price: 1500 },
  { name: 'Massage jambe lourde + Pressothérapie', category: 'Soins dos et corps', price: 400, duration: 45 },
  { name: 'Head Spa + massage cou, épaules', category: 'Soins dos et corps', price: 400, duration: 45 },
  { name: 'Massage corps complet relaxant', category: 'Soins dos et corps', price: 400, duration: 45 },
  { name: 'Massage corps complet Deep Serenity', category: 'Soins dos et corps', price: 600, duration: 75 },
  { name: 'Massage corps complet + Pressothérapie', category: 'Soins dos et corps', price: 600, duration: 75 },
  { name: 'ELMACLINIC Signature', category: 'Soins dos et corps', price: 800, duration: 120, description: 'Massage corps complet + Head Spa.' },
  { name: 'Pressothérapie', category: 'Soins dos et corps', price: 250, duration: 30, description: 'Tarif initial calculé depuis le pack 6 séances à 1500 DH.' },
  { name: 'Massage corps complet + drainage lymphatique', category: 'Soins dos et corps', price: 800, duration: 90, description: 'Drainage ventre, cuisse et visage.' },
  { name: 'Head Spa', category: 'Head Spa', price: 400, duration: 45, description: 'Soin complet du cuir chevelu + massage relaxant.' },
  { name: 'Head Spa 75 min', category: 'Head Spa', price: 600, duration: 75, description: 'Head Spa + massage nuque, épaules et bras.' },
  { name: 'Head Spa Premium', category: 'Head Spa', price: 800, duration: 120, description: 'Head Spa complet + massage du corps entier.' },
  { name: 'Scalp Glow', category: 'Soins capillaires', price: 400, description: 'Diagnostic et Head Spa propreté.' },
  { name: 'Anti-Dandruff Scalp Detox', category: 'Soins capillaires', price: 500 },
  { name: 'Soin intensif hydratant et nourrissant', category: 'Soins capillaires', price: 400, description: 'Tarif de départ, ajustable jusqu’à 800 DH.' },
  { name: 'Soin Anti-Chute & Fortifiant', category: 'Soins capillaires', price: 1333, description: 'Prix unitaire indicatif depuis le pack 6 séances à 8000 DH.' },
  { name: 'Soin Color Protect', category: 'Soins capillaires', price: 500 },
  { name: 'Protein lissage', category: 'Soins capillaires', price: 900, description: 'Tarif de départ, ajustable de 900 à 2500 DH.' },
  { name: 'Manicure russe', category: 'Nail Bar', price: 180 },
  { name: 'Manicure russe + pose permanent', category: 'Nail Bar', price: 250 },
  { name: 'Manicure russe + popit gel', category: 'Nail Bar', price: 350 },
  { name: 'Manicure russe + chablon gel', category: 'Nail Bar', price: 450 },
  { name: 'Depose', category: 'Nail Bar', price: 50 },
  { name: 'Pedicure russe à sec', category: 'Nail Bar', price: 250 },
  { name: 'Pedicure spa simple', category: 'Nail Bar', price: 300 },
  { name: 'Pedicure spa premium', category: 'Nail Bar', price: 400 },
  { name: 'Pedicure russe + pose permanent', category: 'Nail Bar', price: 350 },
  { name: 'Pedicure spa + pose permanente', category: 'Nail Bar', price: 500 },
  { name: 'Pedicure medical', category: 'Nail Bar', price: 800 },
  ...[['Glass Skin', 600], ['Anti-Age', 700], ['Anti-Taches', 800], ['Anti-Acne', 1000]].map(([name, price]) => ({ name, price, category: 'HydraFacial' } as Service)),
  { name: 'Radiofrequence fractionnee', category: 'Soins visage avances', price: 1167, description: 'Prix unitaire indicatif depuis le pack 3 séances à 3500 DH.' },
  { name: 'Microneedling', category: 'Soins visage avances', price: 500, description: 'Prix unitaire indicatif depuis le pack 6 séances à 3000 DH.' },
  { name: 'Mesotherapie PRP visage', category: 'Soins visage avances', price: 800 },
  { name: 'LED Therapy', category: 'Soins visage avances', price: 150, duration: 30 },
  { name: 'Peeling visage', category: 'Soins visage avances', price: 1500 },
  { name: 'Hydralips', category: 'Soins visage avances', price: 400 },
  { name: 'Radiofrequence anti-age', category: 'Soins visage avances', price: 333, description: 'Prix unitaire indicatif depuis le pack 6 séances à 2000 DH.' },
  { name: 'Profhilo', category: 'Injectables et rejuvenation', price: 3200 },
  { name: 'NCTF 135', category: 'Injectables et rejuvenation', price: 1400 },
  { name: 'Hyaron', category: 'Injectables et rejuvenation', price: 1000 },
  { name: 'KIARA', category: 'Injectables et rejuvenation', price: 1600 },
  { name: 'Filler 0,5 ml', category: 'Injectables et rejuvenation', price: 900 },
  { name: 'Filler 1 ml', category: 'Injectables et rejuvenation', price: 1800 },
];

const packs: Pack[] = [
  ...[
    ['Levre superieure', 1200], ['Menton', 2000], ['Visage', 3800], ['Aisselles', 2800], ['Maillot integral', 4800],
    ['Bord du maillot', 2800], ['Demi-jambes', 2800], ['Jambes completes', 4800], ['Bras', 3800], ['Demi-bras', 2800],
    ['Fesses', 3200], ['Corps complet', 16000],
  ].map(([service, price]) => ({ name: `Pack 8 séances - ${service}`, service, price, sessions: 8, category: 'Laser - Femme' } as Pack)),
  ...[
    ['Tracage de barbe', 2800], ['Barbe complete', 4800], ['Cou', 2800], ['Tour d’oreille', 2000], ['Entre sourcils', 1200],
    ['Torse', 3800], ['Ventre', 3800], ['Dos', 3800], ['Demi-jambe homme', 3800], ['Demi-bras homme', 3800],
  ].map(([service, price]) => ({ name: `Pack 8 séances - ${service}`, service, price, sessions: 8, category: 'Laser - Hommes' } as Pack)),
  { name: 'Pack Pressothérapie - 6 séances', service: 'Pressothérapie', price: 1500, sessions: 6, category: 'Soins dos et corps' },
  { name: 'Pack Soin Anti-Chute & Fortifiant - 6 séances', service: 'Soin Anti-Chute & Fortifiant', price: 8000, sessions: 6, category: 'Soins capillaires' },
  { name: 'Pack Profhilo - 2 séances', service: 'Profhilo', price: 6000, sessions: 2, category: 'Injectables et rejuvenation' },
  { name: 'Pack NCTF 135 - 3 séances', service: 'NCTF 135', price: 3600, sessions: 3, category: 'Injectables et rejuvenation' },
  { name: 'Pack Hyaron - 3 séances', service: 'Hyaron', price: 2500, sessions: 3, category: 'Injectables et rejuvenation' },
  { name: 'Pack KIARA - 2 séances', service: 'KIARA', price: 3000, sessions: 2, category: 'Injectables et rejuvenation' },
  { name: 'Pack Radiofrequence fractionnee - 3 séances', service: 'Radiofrequence fractionnee', price: 3500, sessions: 3, category: 'Soins visage avances' },
  { name: 'Pack Microneedling - 6 séances', service: 'Microneedling', price: 3000, sessions: 6, category: 'Soins visage avances' },
  { name: 'Pack Radiofrequence anti-age - 6 séances', service: 'Radiofrequence anti-age', price: 2000, sessions: 6, category: 'Soins visage avances' },
];

async function imageBuffer(category: string): Promise<Buffer> {
  const response = await fetch(imageSources[category]);
  if (!response.ok) throw new Error(`Image download failed for ${category}: ${response.status}`);
  return sharp(Buffer.from(await response.arrayBuffer())).resize(1600, 1600, { fit: 'inside', withoutEnlargement: true }).jpeg({ quality: 80 }).toBuffer();
}

const archivedAt = new Date().toISOString();
await db.from('packs').update({ active: false, updated_at: archivedAt }).eq('active', true).throwOnError();
await db.from('services').update({ active: false, deleted_at: archivedAt, updated_at: archivedAt }).is('deleted_at', null).throwOnError();
await db.from('service_categories').update({ active: false, deleted_at: archivedAt, updated_at: archivedAt }).not('parent_id', 'is', null).is('deleted_at', null).throwOnError();
await db.from('service_categories').update({ active: false, deleted_at: archivedAt, updated_at: archivedAt }).is('parent_id', null).is('deleted_at', null).throwOnError();

const categoryIds = new Map<string, string>();
for (const name of Object.keys(imageSources)) {
  const row = await db.from('service_categories').insert({ name, active: true }).select('id').single().throwOnError();
  categoryIds.set(name, row.data.id);
}
const serviceIds = new Map<string, string>();
const imageCache = new Map<string, Buffer>();
for (const service of services) {
  const row = await db.from('services').insert({
    category_id: categoryIds.get(service.category), name: service.name, description: service.description ?? null,
    duration_minutes: service.duration ?? defaultDuration, price_centimes: service.price * 100, active: true,
  }).select('id').single().throwOnError();
  serviceIds.set(service.name, row.data.id);
  if (!imageCache.has(service.category)) imageCache.set(service.category, await imageBuffer(service.category));
  const path = `${row.data.id}/catalog.jpg`;
  const upload = await db.storage.from('service-images').upload(path, imageCache.get(service.category)!, { contentType: 'image/jpeg', upsert: true });
  if (upload.error) throw upload.error;
  await db.from('services').update({ image_path: path }).eq('id', row.data.id).throwOnError();
}
for (const pack of packs) {
  let serviceId = serviceIds.get(pack.service);
  if (!serviceId) {
    const row = await db.from('services').insert({ category_id: categoryIds.get(pack.category), name: pack.service, description: 'Pack importé; tarif et durée modifiables.', duration_minutes: defaultDuration, price_centimes: 0, active: true }).select('id').single().throwOnError();
    const createdServiceId = row.data.id;
    serviceId = createdServiceId;
    serviceIds.set(pack.service, createdServiceId);
  }
  const row = await db.from('packs').insert({ name: pack.name, description: null, price_centimes: pack.price * 100, active: true, version: 1 }).select('id').single().throwOnError();
  await db.from('pack_items').insert({ pack_id: row.data.id, service_id: serviceId, sessions: pack.sessions }).throwOnError();
}
console.log(`Imported ${services.length} services and ${packs.length} packs; previous active catalog archived.`);
