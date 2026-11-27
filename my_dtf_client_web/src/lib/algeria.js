// 58 wilayas et 1541 communes, recherche arabe / français insensible aux accents.
let data = null;
export async function loadDz() { if (!data) data = (await import('./algeria.json')).default; return data; }
export const norm = s => (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
  .replace(/[أإآٱ]/g, 'ا').replace(/ة/g, 'ه').replace(/ى/g, 'ي').replace(/[ًٌٍَُِّْـ]/g, '').replace(/[-'’\s]+/g, ' ').trim();
export const match = (x, qy) => { const n = norm(qy); return !n || norm(x.ar).includes(n) || norm(x.fr).includes(n) || String(x.c || '') === n; };
