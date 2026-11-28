import { writable, get } from 'svelte/store';

export const me = writable(null);        // profil connecté
export const settings = writable(null);
export const staff = writable([]);       // équipe (hors clients)
export const shift = writable(null);     // { since } si pointé
export const badges = writable({});      // compteurs du menu
export const sheet = writable(null);     // { component, props } panneau latéral / bas
export const modal = writable(null);     // { component, props }
export const toastMsg = writable(null);
export const liveTick = writable(0);     // incrémenté à chaque changement en direct

let th;
export function toast(text, error = false) {
  toastMsg.set({ text, error });
  clearTimeout(th);
  th = setTimeout(() => toastMsg.set(null), 3400);
}
export const openSheet = (component, props = {}) => sheet.set({ component, props });
export const closeSheet = () => sheet.set(null);
export const openModal = (component, props = {}) => modal.set({ component, props });
export const closeModal = () => modal.set(null);

export const staffName = id => get(staff).find(s => s.id === id)?.full_name || '—';
export const isMgr = () => ['admin', 'manager'].includes(get(me)?.role);

// Parc de machines (tableau de bord temps réel) — partagé par toutes les vues.
export const board = writable(null);
export async function loadBoard() {
  const { sb } = await import('./sb.js');
  const { data, error } = await sb.rpc('dtf_machine_board');
  if (!error) board.set(data || []);
  return data || [];
}
// Machine choisie par le poste d'impression (mémorisée sur cet appareil).
const MK = 'mydtf.machine';
let saved = null; try { saved = localStorage.getItem(MK); } catch (_) {}
export const myMachine = writable(saved);
myMachine.subscribe(v => { try { v ? localStorage.setItem(MK, v) : localStorage.removeItem(MK); } catch (_) {} });
// État déclaré de la machine (choisi par l'équipe). « idle » = à l'arrêt, pas forcément prête à imprimer.
export const MSTATUS = { idle: ['متوقفة', 'idle', 'blue'], running: ['تطبع', 'run', 'green'], maintenance: ['صيانة', 'maint', 'amber'], down: ['عطل', 'down', 'red'] };
// Aptitude réelle à imprimer, déduite de l'état ET du rouleau : t = libellé, c = couleur, block = impression impossible, why = raison / action.
export function readiness(x) {
  if (!x) return { t: '—', c: 'gray' };
  const left = +x.roll_remaining, hasRoll = !!x.roll_code;
  if (x.active === false) return { t: 'غير مفعّلة', c: 'gray', block: true, why: 'الآلة موقوفة من الإعدادات' };
  if (x.status === 'down') return { t: 'معطّلة', c: 'red', block: true, why: x.status_note || 'عطل — أصلح الآلة ثم غيّر حالتها' };
  if (x.status === 'maintenance') return { t: 'في الصيانة', c: 'amber', block: true, why: x.status_note || 'صيانة جارية' };
  if (x.status === 'running') return hasRoll ? { t: 'تطبع', c: 'green' } : { t: 'تطبع — دون رولو مسجّل', c: 'amber', why: 'سجّل الرولو المركّب حتى يُحسب الاستهلاك' };
  if (!hasRoll) return { t: 'تحتاج رولو', c: 'amber', block: true, why: 'لا يوجد رولو مركّب — ركّب رولو لتبدأ الطباعة' };
  if (left <= 0) return { t: 'الرولو انتهى', c: 'red', block: true, why: 'الرولو فارغ — بدّله برولو جديد' };
  if (left <= +x.alert_m) return { t: 'جاهزة — الرولو ينفد', c: 'amber', why: `بقي ${left.toFixed(1)} م فقط — جهّز رولو جديداً` };
  return { t: 'جاهزة للطباعة', c: 'green' };
}
export const tv = writable(false);
