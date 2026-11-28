// Relais du collecteur PrintExp (programme Windows My DTF uniquement : window.mydtfCollector).
// Reçoit les relevés, les enregistre avec la session de l'équipe, puis accuse réception :
// le programme ne retire un passage de son journal local qu'après cet accusé (pas de perte si le réseau tombe,
// et pas de doublon grâce à la clé unique côté serveur).
import { sb } from './sb.js';
let stop = null, busy = false, queued = null;
export function startCollectorRelay(onChange) {
  const c = typeof window !== 'undefined' && window.mydtfCollector;
  if (!c || stop) return;
  const send = async d => {
    if (busy) { queued = d; return; }
    busy = true;
    try {
      const { data, error } = await sb.rpc('dtf_printexp_report', { p_collector: d.collector || 'pc', p_live: d.live || [], p_runs: d.runs || [] });
      if (!error) { if (data?.length) c.ack(data); onChange?.(d); }
    } catch (_) { /* réseau coupé : le programme renverra les passages au prochain relevé */ }
    busy = false;
    if (queued) { const n = queued; queued = null; send(n); }
  };
  stop = c.onReport(send);
}
