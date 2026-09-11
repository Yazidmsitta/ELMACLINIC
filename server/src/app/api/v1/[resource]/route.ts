import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../lib/auth';
import { handle, HttpError, json } from '../../../../lib/http';
import { parseCatalog, catalogTables, catalogColumns, isCatalog, databaseError } from '../../../../lib/catalog';
export const runtime = 'nodejs';
type Context = { params: Promise<{ resource: string }> };
const resources: Record<string, { table: string; columns: string; admin?: boolean }> = {
  ...Object.fromEntries(Object.entries(catalogTables).map(([key, table]) => [key, { table, columns: catalogColumns[key as keyof typeof catalogTables] }])),
  appointments: { table: 'appointments', columns: 'id,client_id,practitioner_id,starts_at,ends_at,source,status' },
  notifications: { table: 'notifications', columns: 'id,type,appointment_id,payload,read_at,created_at' },
  payments: { table: 'payments', columns: '*', admin: true },
  expenses: { table: 'expenses', columns: '*', admin: true },
  inventory: { table: 'products', columns: '*', admin: true },
  users: { table: 'profiles', columns: 'id,full_name,role,active', admin: true },
  settings: { table: 'settings', columns: '*', admin: true },
  'activity-logs': { table: 'activity_logs', columns: '*', admin: true },
  schedules: { table: 'practitioner_schedules', columns: '*' },
};
export async function GET(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request);
    const key = (await context.params).resource;
    const resource = Object.hasOwn(resources,key) ? resources[key] : undefined;
    if (!resource) throw new HttpError(404, 'Introuvable.');
    if (resource.admin) requireAdmin(identity.user.role);
    const page = z.coerce.number().int().min(1).max(100000).parse(new URL(request.url).searchParams.get('page') ?? 1);
    let query = identity.db.from(resource.table).select(resource.columns, { count: 'exact' }).order('created_at', { ascending: false }).order('id').range((page - 1) * 50, page * 50 - 1);
    if (['clients', 'services', 'practitioners', 'appointments', 'service_categories'].includes(resource.table)) query = query.is('deleted_at', null);
    const params = new URL(request.url).searchParams;
    const search = z.string().trim().max(100).parse(params.get('search') ?? '');
    if (search && ['clients','services','practitioners','service_categories'].includes(resource.table)) {
      const literal = search.replace(/[\\%_]/g, character => '\\' + character);
      query = query.ilike(['clients','practitioners'].includes(resource.table) ? 'full_name' : 'name', `%${literal}%`);
    }
    if (params.has('category_id') && resource.table === 'services') {
      const id = z.uuid().parse(params.get('category_id'));
      const children = await identity.db.from('service_categories').select('id').eq('parent_id',id).is('deleted_at',null);
      databaseError(children.error);
      query = query.in('category_id',[id,...(children.data ?? []).map(child => child.id)]);
    }
    if (identity.user.role !== 'ADMIN' && ['services','practitioners','service_categories'].includes(resource.table)) query = query.eq('active', true);
    const result = await query;
    databaseError(result.error);
    const data = result.data as unknown as Record<string, unknown>[];
    if (resource.table === 'services') {
      const paths = data.flatMap(row => typeof row.image_path === 'string' ? [row.image_path] : []);
      if (paths.length) {
        const signed = await identity.db.storage.from('service-images').createSignedUrls(paths, 300);
        if (signed.error) throw new Error('Image signing failed');
        const urls = new Map(signed.data.map(image => [image.path, image.signedUrl]));
        for (const row of data) row.image_url = typeof row.image_path === 'string' ? urls.get(row.image_path) ?? null : null;
      }
      for (const row of data) delete row.image_path;
    }
    return json({ data, page, per_page: 50, total: result.count, has_more: page * 50 < (result.count ?? 0) });
  });
}
export async function POST(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request);
    const { resource } = await context.params;
    if (!Object.hasOwn(resources,resource)) throw new HttpError(404, 'Introuvable.');
    if (!['clients', 'appointments', 'payments'].includes(resource)) requireAdmin(identity.user.role);
    if (!isCatalog(resource)) throw new HttpError(501, 'Disponible dans une prochaine phase.');
    const body = parseCatalog(resource, await request.json());
    const result = await identity.db.from(catalogTables[resource]).insert(resource === 'clients' ? { ...body, created_by: identity.user.id } : body).select(catalogColumns[resource]).single();
    databaseError(result.error);
    return json({ data: result.data }, 201);
  });
}

