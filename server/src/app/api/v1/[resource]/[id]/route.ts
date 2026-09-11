import { z } from 'zod';
import { authenticate, requireAdmin } from '../../../../../lib/auth';
import { handle, HttpError, json } from '../../../../../lib/http';
import { parseCatalog, catalogTables, catalogColumns, isCatalog, databaseError } from '../../../../../lib/catalog';
export const runtime = 'nodejs';
type Context = { params: Promise<{ resource: string; id: string }> };
export async function PATCH(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request);
    const { resource, id } = await context.params;
    if (!['clients', 'appointments', 'notifications', 'payments', 'services', 'practitioners', 'users', 'expenses', 'inventory', 'settings', 'schedules', 'categories'].includes(resource)) throw new HttpError(404, 'Introuvable.');
    if (!['clients', 'appointments', 'notifications'].includes(resource)) requireAdmin(identity.user.role);
    z.uuid().parse(id);
    if (!isCatalog(resource)) throw new HttpError(501, 'Disponible dans une prochaine phase.');
    const body = parseCatalog(resource, await request.json(), true);
    const result = await identity.db.from(catalogTables[resource]).update(body).eq('id', id).is('deleted_at', null).select(catalogColumns[resource]).maybeSingle();
    databaseError(result.error);
    if (!result.data) throw new HttpError(404, 'Introuvable.');
    return json({ data: result.data });
  });
}

export async function DELETE(request: Request, context: Context) {
  return handle(async () => {
    const identity = await authenticate(request);
    requireAdmin(identity.user.role);
    const { resource, id } = await context.params;
    z.uuid().parse(id);
    if (!isCatalog(resource)) throw new HttpError(501, 'Disponible dans une prochaine phase.');
    const result = await (resource === 'clients' ? identity.db.rpc('archive_client', { client_id: id }) : identity.db.rpc('archive_catalog', { resource_name: catalogTables[resource], record_id: id }));
    databaseError(result.error);
    if (!result.data) throw new HttpError(404, 'Introuvable.');
    return json({ message: 'Élément archivé.' });
  });
}

