import { createClient } from '@supabase/supabase-js';
export const sb = createClient(
  'https://pxifieuohgthtqkwasug.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB4aWZpZXVvaGd0aHRxa3dhc3VnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxMzI3NDUsImV4cCI6MjEwODcwODc0NX0.pXYktWDzEcjzcwEFspJnul1zzdSkmiWlMra2ukQkG8k',
  { realtime: { params: { eventsPerSecond: 5 } } },
);
export const BUCKET = 'dtf-images';
export async function q(p) { const { data, error } = await p; if (error) throw error; return data; }
export async function rpc(fn, args = {}) { const { data, error } = await sb.rpc(fn, args); if (error) throw error; return data; }
export function errMsg(e) {
  const m = (e && (e.message || e.error_description || e.error)) || String(e);
  if (/Invalid login/i.test(m)) return 'البريد الإلكتروني أو كلمة السر غير صحيحة';
  if (/already registered|already been registered/i.test(m)) return 'هذا البريد مسجّل من قبل، ادخل بكلمة السر';
  if (/Password should be/i.test(m)) return 'كلمة السر قصيرة جداً (6 أحرف على الأقل)';
  if (/Email not confirmed/i.test(m)) return 'أكّد بريدك الإلكتروني أولاً من الرسالة التي وصلتك';
  if (/Failed to fetch|NetworkError/i.test(m)) return 'لا يوجد اتصال بالإنترنت';
  return m;
}
