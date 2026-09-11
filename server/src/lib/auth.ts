import 'server-only';
import { database } from './supabase';
import { HttpError } from './http';
export async function authenticate(request: Request) {
  const token = request.headers.get('authorization')?.match(/^Bearer (\S+)$/i)?.[1];
  if (!token) throw new HttpError(401, 'Authentification requise.');
  const db = database(token);
  const { data, error } = await db.auth.getUser(token);
  if (error || !data.user) throw new HttpError(error && error.status && error.status >= 500 ? 503 : 401, 'Session invalide.');
  const profile = await db.from('profiles').select('id,full_name,role,active').eq('id', data.user.id).single();
  if (profile.error && profile.error.code !== 'PGRST116') throw new HttpError(503, 'Profil indisponible.');
  if (!profile.data?.active || !['ADMIN', 'USER'].includes(profile.data.role)) throw new HttpError(403, 'Accès refusé.');
  return { db, token, user: { id: data.user.id, name: profile.data.full_name, email: data.user.email, role: profile.data.role as 'ADMIN' | 'USER' } };
}
export function requireAdmin(role: string) {
  if (role !== 'ADMIN') throw new HttpError(403, 'Accès administrateur requis.');
}
