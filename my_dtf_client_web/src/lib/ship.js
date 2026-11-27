// Wilayas et communes de la société de livraison (Expedia / EcoTrack), synchronisées par l'atelier.
// Même forme que algeria.json : { wilayas: [{ c, fr, ar, home, desk, hasDesk }], communes: [{ w, fr, ar, desk, code }] }.
// Le nom français `fr` d'une commune est exactement celui de la société (sinon le colis est refusé).
import { sb } from './sb.js';
import { loadDz, norm } from './algeria.js';
import { da } from './fmt.js';

let cache = null;
async function all(table, cols) {
  const out = [];
  for (let from = 0; ; from += 1000) {
    const { data, error } = await sb.from(table).select(cols).range(from, from + 999);
    if (error) throw error;
    out.push(...data);
    if (data.length < 1000) return out;
  }
}

export async function loadShip() {
  if (cache) return cache;
  const dz = await loadDz();
  let rates = [], coms = [], wil = [];
  try { [rates, coms, wil] = await Promise.all([all('dtf_ship_rates', 'wilaya_code,home,desk'), all('dtf_ship_communes', 'wilaya_code,name,has_desk,code_postal'), all('dtf_wilayas', 'code,fr,ar')]); }
  catch (_) { /* hors ligne : liste générale */ }
  if (!rates.length || !coms.length) return (cache = { ...dz, live: false });
  const arOf = new Map(dz.communes.map(c => [c.w + '|' + norm(c.fr), c.ar]));
  const communes = coms.map(c => ({ w: c.wilaya_code, fr: c.name, ar: arOf.get(c.wilaya_code + '|' + norm(c.name)) || c.name, desk: !!c.has_desk, code: c.code_postal,
    tag: c.has_desk ? 'فيها مكتب' : 'منزل فقط' }));
  const deskW = new Set(communes.filter(c => c.desk).map(c => c.w));
  const wilayas = rates.map(r => {
    const w = wil.find(x => x.code === r.wilaya_code) || dz.wilayas.find(x => x.c === r.wilaya_code) || {};
    const hasDesk = deskW.has(r.wilaya_code) && +r.desk > 0;
    return { c: r.wilaya_code, fr: w.fr || String(r.wilaya_code), ar: w.ar || w.fr || '', home: +r.home || null, desk: hasDesk ? +r.desk : null, hasDesk,
      tag: hasDesk ? 'فيها مكتب' : 'منزل فقط', sub: [hasDesk && `المكتب ${da(r.desk)}`, +r.home && `المنزل ${da(r.home)}`].filter(Boolean).join(' · ') };
  }).sort((a, b) => a.c - b.c);
  return (cache = { wilayas, communes, live: true });
}

// Retrouve la wilaya / commune enregistrée dans le profil (nom français ou arabe).
export function findPlace(sh, wName, cName) {
  const wilaya = sh.wilayas.find(w => w.fr === wName || w.ar === wName || norm(w.fr) === norm(wName)) || null;
  const commune = wilaya ? sh.communes.find(c => c.w === wilaya.c && (c.fr === cName || c.ar === cName || norm(c.fr) === norm(cName))) || null : null;
  return { wilaya, commune };
}
