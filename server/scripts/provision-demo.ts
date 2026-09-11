import { createClient } from '@supabase/supabase-js';
if (process.env.ALLOW_DEMO_PROVISIONING !== 'true') throw new Error('Set ALLOW_DEMO_PROVISIONING=true explicitly for a development project.');
const password = process.env.DEMO_PASSWORD;
if (!password || password.length < 12) throw new Error('Set a unique DEMO_PASSWORD of at least 12 characters.');
const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!url || !key) throw new Error('Missing Supabase server credentials.');
const db = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
for (const role of ['ADMIN', 'USER'] as const) {
  const email = `${role.toLowerCase()}@elmaclinic.test`;
  let id: string | undefined;
  for (let page = 1; !id; page++) {
    const result = await db.auth.admin.listUsers({ page, perPage: 100 });
    if (result.error) throw result.error;
    id = result.data.users.find(user => user.email === email)?.id;
    if (result.data.users.length < 100) break;
  }
  if (!id) {
    const result = await db.auth.admin.createUser({ email, password, email_confirm: true });
    if (result.error) throw result.error;
    id = result.data.user.id;
  }
  const result = await db.from('profiles').upsert({ id, full_name: `Demo ${role}`, role, active: true });
  if (result.error) throw result.error;
  console.log(`Provisioned ${email}; existing passwords are unchanged.`);
}
