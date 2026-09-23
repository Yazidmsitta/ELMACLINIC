import { ZodError } from 'zod';
export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}
export function json(data: unknown, status = 200) {
  return Response.json(data, { status, headers: { 'Cache-Control': 'no-store' } });
}
export async function handle(action: () => Promise<Response>) {
  try { return await action(); }
  catch (error) {
    if (error instanceof HttpError) return json({ message: error.message }, error.status);
    if (error instanceof ZodError || error instanceof SyntaxError) {
      const message = error instanceof ZodError && error.issues[0]?.message ? error.issues[0].message : 'Données invalides.';
      return json({ message }, 422);
    }
    return json({ message: 'Service temporairement indisponible.' }, 503);
  }
}
