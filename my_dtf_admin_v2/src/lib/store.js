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
