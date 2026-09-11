import { z } from 'zod';
import { HttpError } from './http';

const name = z.string().trim().min(1).max(200);
const optionalText = z.string().trim().max(2000).nullable().optional();
export const clientSchema = z.object({ full_name: name, phone: z.string().trim().max(40).nullable().optional(), email: z.email().max(254).nullable().optional(), birth_date: z.iso.date().nullable().optional() }).strict();
export const catalogSchemas = {
  clients: clientSchema,
  services: z.object({ name, category_id: z.uuid().nullable().optional(), description: optionalText, duration_minutes: z.number().int().min(1).max(1440), price_centimes: z.number().int().min(0).max(100000000), active: z.boolean().optional() }).strict(),
  practitioners: z.object({ full_name: name, specialty: optionalText, job_title: z.string().trim().max(200).nullable().optional(), phone: z.string().trim().max(40).nullable().optional(), email: z.email().max(254).nullable().optional(), active: z.boolean().optional() }).strict(),
  categories: z.object({ name, parent_id: z.uuid().nullable().optional(), sort_order: z.number().int().min(0).max(10000).optional(), active: z.boolean().optional() }).strict(),
};
export type CatalogResource = keyof typeof catalogSchemas;
export function parseCatalog(resource: CatalogResource, input: unknown, partial = false): Record<string, unknown> {
  const schema = catalogSchemas[resource];
  const value = partial ? schema.partial().parse(input) : schema.parse(input);
  if (Object.keys(value).length === 0) throw new HttpError(422, 'Aucune modification fournie.');
  return value;
}
export function isCatalog(value: string): value is CatalogResource { return value in catalogSchemas && Object.hasOwn(catalogSchemas, value); }
export const catalogTables: Record<CatalogResource, string> = { clients: 'clients', services: 'services', practitioners: 'practitioners', categories: 'service_categories' };
export const catalogColumns: Record<CatalogResource, string> = {
  clients: 'id,full_name,phone,email,birth_date',
  services: 'id,category_id,name,description,duration_minutes,price_centimes,active,image_path',
  practitioners: 'id,full_name,specialty,job_title,phone,email,active',
  categories: 'id,name,parent_id,sort_order,active',
};
export function databaseError(error: { code?: string } | null): void {
  if (!error) return;
  if (error.code === '42501') throw new HttpError(403, 'Action non autorisée.');
  if (['23503', '23505', '23P01'].includes(error.code ?? '')) throw new HttpError(409, 'Cette modification est incompatible avec les données existantes.');
  if (['23514', '22007', '22023'].includes(error.code ?? '')) throw new HttpError(422, 'Données invalides.');
  throw new Error('Database operation failed');
}
