import { createClient } from '@supabase/supabase-js';

export const sb = createClient(
  'https://pxifieuohgthtqkwasug.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k',
  { realtime: { params: { eventsPerSecond: 5 } } },
);

// Session perdue (jeton expiré / révoqué) : la requête part en « anon » → « permission denied ».
const lostSession = e => e && (e.code === '42501' || e.code === 'PGRST301' || /permission denied|JWT/i.test(e.message || ''));
let healing = null;
/** Tente de récupérer la session une seule fois (partagé entre les appels simultanés). */
export async function heal() {
  if (!healing) healing = (async () => {
    const { data } = await sb.auth.getSession();
    if (data.session && data.session.expires_at * 1000 > Date.now() + 30000) return true;
    const r = await sb.auth.refreshSession();
    return !r.error && !!r.data.session;
  })().finally(() => setTimeout(() => (healing = null), 3000));
  return healing;
}
export const SESSION_LOST = 'انتهت جلستك — أعد الدخول بحسابك';

export async function rpc(fn, args = {}) {
  let { data, error } = await sb.rpc(fn, args);
  if (error && lostSession(error) && await heal()) ({ data, error } = await sb.rpc(fn, args));
  if (error && lostSession(error)) { window.dispatchEvent(new Event('mydtfsessionlost')); throw new Error(SESSION_LOST); }
  if (error) throw error;
  return data;
}

export async function q(promise) {
  const { data, error } = await promise;
  if (error && lostSession(error)) { heal().then(ok => window.dispatchEvent(new Event(ok ? 'mydtfhealed' : 'mydtfsessionlost'))); throw new Error(SESSION_LOST); }
  if (error) throw error;
  return data;
}

/** URLs signées en un seul appel (miniatures si disponibles). */
export async function signedUrls(paths, download = false) {
  const list = paths.filter(Boolean);
  if (!list.length) return {};
  const { data } = await sb.storage.from('dtf-images').createSignedUrls(list, 3600, download ? { download: true } : undefined);
  return Object.fromEntries((data || []).map(d => [d.path, d.signedUrl]));
}

export const invokeDhd = body => invokeAdmin(body, 'dtf-dhd');
export async function invokeAdmin(body, fn = 'dtf-admin') {
  const { data, error } = await sb.functions.invoke(fn, { body });
  if (error) {
    let msg = error.message;
    try { msg = (await error.context.json()).error || msg; } catch (_) {}
    throw new Error(msg);
  }
  if (data?.error) throw new Error(data.error);
  return data;
}

export function errMsg(e) {
  const m = (e && (e.message || e.error_description || e.error)) || String(e);
  if (/Invalid login/i.test(m)) return 'البريد الإلكتروني أو كلمة السر غير صحيحة';
  if (/Failed to fetch|NetworkError/i.test(m)) return 'لا يوجد اتصال بالإنترنت';
  return m;
}
