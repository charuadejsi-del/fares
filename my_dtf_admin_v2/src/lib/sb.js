import { createClient } from '@supabase/supabase-js';

export const sb = createClient(
  'https://pxifieuohgthtqkwasug.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k',
  { realtime: { params: { eventsPerSecond: 5 } } },
);

export async function rpc(fn, args = {}) {
  const { data, error } = await sb.rpc(fn, args);
  if (error) throw error;
  return data;
}

export async function q(promise) {
  const { data, error } = await promise;
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

export async function invokeAdmin(body) {
  const { data, error } = await sb.functions.invoke('dtf-admin', { body });
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
