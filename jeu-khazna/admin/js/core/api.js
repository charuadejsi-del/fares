// طبقة البيانات: كل طلبات Supabase في مكان واحد.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

export const sb = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, storageKey: 'khazna-admin' },
});

const ok = ({ data, error }) => {
  if (error) throw error;
  return data;
};

export const auth = {
  session: async () => (await sb.auth.getSession()).data.session,
  signIn: (email, password) => sb.auth.signInWithPassword({ email, password }).then(ok),
  signOut: () => sb.auth.signOut(),
  isAdmin: () => sb.rpc('is_admin').then(ok),
  me: (id) => sb.from('profiles').select('nickname').eq('id', id).single().then(ok),
};

export const api = {
  stats: () => sb.rpc('admin_stats').then(ok),
  players: () => sb.rpc('admin_list_players').then(ok),
  rooms: () => sb.rpc('admin_rooms').then(ok),
  stageStats: () => sb.rpc('admin_stage_stats').then(ok),
  matchStats: () => sb.rpc('admin_match_stats').then(ok),
  season: () => sb.rpc('admin_season').then(ok),
  reports: (status) => sb.rpc('admin_reports', { p_status: status || '' }).then(ok),
  resolveReport: (id, status, ban) => sb.rpc('admin_resolve_report', { p_id: id, p_status: status, p_ban: !!ban }).then(ok),
  adjustTime: (user, deltaSeconds, note) =>
    sb.rpc('admin_adjust_time', { p_user: user, p_delta_seconds: deltaSeconds, p_note: note || null }).then(ok),
  setBanned: (user, banned) => sb.rpc('admin_set_banned', { p_user: user, p_banned: banned }).then(ok),
  reviewPayment: (id, approve, note) =>
    sb.rpc('admin_review_payment', { p_id: id, p_approve: approve, p_note: note || null }).then(ok),

  ledger: ({ user, reason, limit = 200 } = {}) => {
    let q = sb
      .from('time_ledger')
      .select('id, user_id, delta_seconds, reason, ref, created_at, profiles!time_ledger_user_id_fkey(nickname)')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (user) q = q.eq('user_id', user);
    if (reason) q = q.eq('reason', reason);
    return q.then(ok);
  },
  payments: (status) => {
    let q = sb
      .from('payment_requests')
      .select('id, user_id, minutes, amount_dzd, transaction_ref, receipt_path, status, admin_note, created_at, reviewed_at, profiles!payment_requests_user_id_fkey(nickname)')
      .order('created_at', { ascending: false })
      .limit(300);
    if (status) q = q.eq('status', status);
    return q.then(ok);
  },
  receiptUrl: (path) => sb.storage.from('receipts').createSignedUrl(path, 600).then(ok).then((d) => d.signedUrl),

  settings: () => sb.from('settings').select('*').then(ok),
  saveSettings: (rows) => sb.from('settings').upsert(rows).then(ok),
  stageConfig: () => sb.from('stage_config').select('*').order('stage').then(ok),
  saveStages: (rows) => sb.from('stage_config').upsert(rows).then(ok),
  packages: () => sb.from('packages').select('*').order('sort').then(ok),
  addPackage: (row) => sb.from('packages').insert(row).then(ok),
  updatePackage: (id, row) => sb.from('packages').update(row).eq('id', id).then(ok),
};

export function errorText(e) {
  const m = String(e?.message || e || '');
  if (m.includes('admin only')) return 'هذا الحساب ليس مديراً';
  if (m.includes('Invalid login')) return 'البريد أو كلمة السر غير صحيحة';
  if (m.includes('already reviewed')) return 'هذا الطلب عولج من قبل';
  if (m.includes('Failed to fetch') || m.includes('NetworkError')) return 'لا يوجد اتصال بالإنترنت';
  if (m.includes('JWT')) return 'انتهت الجلسة، سجّل الدخول من جديد';
  return m || 'حدث خطأ غير متوقّع';
}
