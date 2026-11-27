import { writable } from 'svelte/store';
export const me = writable(null);
export const settings = writable(null);
export const orders = writable([]);
export const messages = writable([]);
export const notifs = writable([]);
export const liveTick = writable(0);
export const toastMsg = writable(null);
let th;
export function toast(text, error = false) { toastMsg.set({ text, error }); clearTimeout(th); th = setTimeout(() => toastMsg.set(null), 3400); }
