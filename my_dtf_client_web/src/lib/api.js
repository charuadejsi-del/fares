// Accès aux données du client connecté.
import { sb, q, rpc, BUCKET } from './sb.js';
import { me, settings, orders, messages, notifs, liveTick } from './store.js';
import { get } from 'svelte/store';

export const uid = () => get(me)?.id;
export const STAFF_ONLY = 'هذا الحساب خاص بفريق الورشة، ادخل من موقع الإدارة mydtf-admin.pages.dev';

export async function myProfile() {
  const { data: { user } } = await sb.auth.getUser();
  if (!user) return null;
  let p = await q(sb.from('dtf_profiles').select('*').eq('id', user.id).maybeSingle());
  if (!p && user.user_metadata?.dtf) {
    const d = user.user_metadata.dtf;
    await q(sb.from('dtf_profiles').insert({ id: user.id, role: 'client', full_name: d.full_name || '', phone: d.phone || '', wilaya: d.wilaya, commune: d.commune, address: d.address }));
    p = await q(sb.from('dtf_profiles').select('*').eq('id', user.id).maybeSingle());
  }
  return p;
}
export async function createProfile(f) {
  const { data: { user } } = await sb.auth.getUser();
  await q(sb.from('dtf_profiles').insert({ id: user.id, role: 'client', ...f }));
}
export async function loadAll() {
  const id = uid(); if (!id) return;
  const [s, o, m, n] = await Promise.all([
    q(sb.from('dtf_settings').select('*').limit(1).maybeSingle()),
    q(sb.from('dtf_orders').select('*').eq('client_id', id).order('created_at', { ascending: false })),
    q(sb.from('dtf_messages').select('*').eq('client_id', id).order('created_at').limit(500)),
    q(sb.from('dtf_notifications').select('*').eq('user_id', id).order('created_at', { ascending: false }).limit(100)),
  ]);
  settings.set(s); orders.set(o); messages.set(m); notifs.set(n);
  try { localStorage.setItem('mydtf.orders.' + id, JSON.stringify(o)); } catch (_) {}
}
export function cachedOrders() { try { return JSON.parse(localStorage.getItem('mydtf.orders.' + uid()) || '[]'); } catch (_) { return []; } }

let ch;
export function live() {
  ch?.unsubscribe();
  let t; const bump = () => { clearTimeout(t); t = setTimeout(async () => { try { await loadAll(); } catch (_) {} liveTick.update(x => x + 1); }, 400); };
  ch = sb.channel('client-' + uid() + '-' + Date.now());
  ['dtf_orders', 'dtf_notifications', 'dtf_messages', 'dtf_settings'].forEach(table => ch.on('postgres_changes', { event: '*', schema: 'public', table }, bump));
  ch.subscribe();
}
export function stopLive() { ch?.unsubscribe(); ch = null; }

export const signedUrl = async (path, download = false) => (await sb.storage.from(BUCKET).createSignedUrl(path, 3600, download ? { download: true } : undefined)).data?.signedUrl;
export async function signedUrls(paths) {
  const list = paths.filter(Boolean); if (!list.length) return {};
  const { data } = await sb.storage.from(BUCKET).createSignedUrls(list, 3600);
  return Object.fromEntries((data || []).map(d => [d.path, d.signedUrl]));
}

// Miniature 400 px (WebP) pour l'affichage rapide côté atelier.
export function makeThumb(file, max = 400) {
  return new Promise(res => {
    const img = new Image(); const url = URL.createObjectURL(file);
    img.onload = () => {
      const k = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
      const c = document.createElement('canvas'); c.width = Math.max(1, Math.round(img.naturalWidth * k)); c.height = Math.max(1, Math.round(img.naturalHeight * k));
      c.getContext('2d').drawImage(img, 0, 0, c.width, c.height); URL.revokeObjectURL(url);
      c.toBlob(b => res(b), 'image/webp', 0.78);
    };
    img.onerror = () => { URL.revokeObjectURL(url); res(null); };
    img.src = url;
  });
}

export async function createOrder({ lengthCm, mode, ship, note, images }, onProgress) {
  const o = await rpc('dtf_create_order', {
    p_estimated_length_cm: lengthCm, p_delivery_mode: mode, p_delivery_fee: 0,
    p_ship_name: ship.name ?? null, p_ship_phone: ship.phone ?? null, p_ship_wilaya: ship.wilaya ?? null, p_ship_commune: ship.commune ?? null, p_ship_address: ship.address ?? null, p_note: note || null,
  });
  const id = uid();
  for (let i = 0; i < images.length; i++) {
    const im = images[i];
    const safe = (im.file.name || 'image.png').replace(/[^A-Za-z0-9._-]/g, '_');
    const path = `${id}/${o.id}/${i + 1}_${safe}`;
    const up = await sb.storage.from(BUCKET).upload(path, im.file, { upsert: true, contentType: im.file.type || 'image/png' });
    if (up.error) throw up.error;
    let thumb = null;
    const tb = await makeThumb(im.file);
    if (tb) { const tp = `${id}/${o.id}/thumb_${i + 1}.webp`; const r = await sb.storage.from(BUCKET).upload(tp, tb, { upsert: true, contentType: 'image/webp' }); if (!r.error) thumb = tp; }
    await q(sb.from('dtf_order_images').insert({ order_id: o.id, storage_path: path, width_cm: im.w, height_cm: im.h, quantity: im.q, thumb_path: thumb }));
    onProgress?.(i + 1, images.length);
  }
  return o;
}
export async function sendMessage(body, orderId) { const id = uid(); await q(sb.from('dtf_messages').insert({ client_id: id, sender_id: id, from_staff: false, order_id: orderId || null, body })); }
export async function markChatRead() { try { await rpc('dtf_chat_mark_read'); } catch (_) {} }
export async function markNotifsRead() { await sb.from('dtf_notifications').update({ read: true }).eq('user_id', uid()).eq('read', false); }
