'use strict';
// Suivi des passages d'impression à partir de lectures successives d'une source (PrintExp).
// Logique pure, sans E/S : testable avec des lectures simulées (test/fixtures).
//
// Lecture (snapshot) fournie par une source :
//   { at: ms, ok: bool, source: 'log'|'uia'|…, printers: [{ key, name, connection, activity, job }], ended: [...] }
//   connection : 'connected' | 'disconnected' | 'unknown'
//   activity   : 'printing' | 'paused' | 'idle' | 'error' | 'unknown'
//   job        : { id?, name?, startedAt?, plannedM?, printedM?, progress? } | null
//   ended      : fins de travail rapportées explicitement par la source (historique / journal)
//                [{ printer, id?, name?, startedAt?, endedAt, reportedM?, plannedM?, outcome }]
//
// Principe : on ne compte un passage qu'une fois (clé stable), on n'invente pas l'issue
// (« unknown » si la source ne la donne pas), et on signale ce qui est ambigu (needs_review).

const OUTCOMES = new Set(['completed', 'cancelled', 'failed', 'unknown']);
const RESET_DROP_M = 0.3;        // mètres en baisse au-delà desquels on considère un nouveau passage
const AMBIGUOUS_WINDOW = 120e3;  // deux fins quasi identiques à < 2 min d'écart ⇒ à vérifier
const KEEP_KEYS = 500;

function h(s) { let x = 2166136261; for (const c of String(s || '')) { x ^= c.codePointAt(0); x = Math.imul(x, 16777619) >>> 0; } return x.toString(36); }
const num = v => (v == null || v === '' || !isFinite(+v) ? null : +v);
const iso = t => (t == null ? null : new Date(t).toISOString());

class Tracker {
  constructor(state = {}, opts = {}) {
    this.staleMs = opts.staleMs || 30e3;
    this.collector = opts.collector || 'pc';
    this.s = { runs: {}, emitted: [], pending: [], lastOk: 0, ...state };   // runs : passage en cours par imprimante
  }
  state() { return this.s; }

  key(src, printer, job, firstSeen) {
    if (job && job.id != null && job.id !== '') return `${src}:${printer}:id:${job.id}`;
    return `${src}:${printer}:t:${job && job.startedAt ? new Date(job.startedAt).getTime() : firstSeen}:${h(job && job.name)}`;
  }

  /** Traite une lecture ; renvoie { live, newRuns }. */
  ingest(snap) {
    const now = snap.at || Date.now();
    const src = snap.source || 'unknown';
    const newRuns = [];
    const close = (pk, run, end) => {
      delete this.s.runs[pk];
      const r = this.finish(src, pk, run, end, now);
      if (r) newRuns.push(r);
    };
    if (snap.ok) this.s.lastOk = now;

    // 1) Fins explicites rapportées par la source : elles font foi (issue + métrage final).
    for (const e of snap.ended || []) {
      const pk = String(e.printer);
      const cur = this.s.runs[pk];
      const same = cur && ((e.id != null && cur.job.id != null && String(e.id) === String(cur.job.id)) ||
        (e.id == null && (!e.name || e.name === cur.job.name)));
      if (same) close(pk, cur, e);
      else {
        const run = { key: this.key(src, pk, { id: e.id, name: e.name, startedAt: e.startedAt }, e.endedAt ? new Date(e.endedAt).getTime() : now),
          job: { id: e.id, name: e.name, startedAt: e.startedAt, plannedM: e.plannedM }, firstSeen: null, maxM: null };
        const r = this.finish(src, pk, run, e, now);
        if (r) newRuns.push(r);
      }
    }

    // 2) État courant de chaque imprimante.
    const live = [];
    for (const p of snap.printers || []) {
      const pk = String(p.key);
      const job = p.job || null;
      let cur = this.s.runs[pk];
      const active = p.activity === 'printing' || p.activity === 'paused';
      if (snap.ok && active && job) {
        const m = num(job.printedM);
        const differs = cur && (
          (job.id != null && cur.job.id != null && String(job.id) !== String(cur.job.id)) ||
          (job.startedAt && cur.job.startedAt && new Date(job.startedAt).getTime() !== new Date(cur.job.startedAt).getTime()) ||
          (job.name && cur.job.name && job.name !== cur.job.name) ||
          (m != null && cur.maxM != null && m < cur.maxM - RESET_DROP_M));   // le compteur repart : réimpression
        if (differs) { close(pk, cur, null); cur = null; }
        if (!cur) {
          cur = this.s.runs[pk] = { key: this.key(src, pk, job, now), job: { ...job }, firstSeen: now, maxM: null, paused: 0 };
        }
        cur.job = { ...cur.job, ...stripNull(job) };
        if (m != null) cur.maxM = Math.max(cur.maxM ?? 0, m);
        if (num(job.progress) != null) cur.progress = num(job.progress);
        if (p.activity === 'paused') cur.paused = (cur.paused || 0) + 1;
        cur.lastSeen = now;
      } else if (snap.ok && cur && (p.activity === 'idle' || p.activity === 'error')) {
        // La machine ne bouge plus : fin, pause non signalée ou erreur. Sans fin explicite, l'issue reste à confirmer.
        close(pk, cur, p.activity === 'error' ? { outcome: 'failed', endedAt: now } : null);
        cur = null;
      }
      // Déconnexion ou lecture impossible pendant un passage : on garde le passage ouvert (il peut reprendre).
      live.push({
        printer_key: pk, printer_name: p.name || null, source: src,
        connection: snap.ok ? (p.connection || 'unknown') : 'unknown',
        activity: snap.ok ? (p.activity || 'unknown') : 'unknown',
        job_name: (snap.ok && job && job.name) || null,
        progress: snap.ok && job ? num(job.progress) : null,
        printed_m: snap.ok && job ? num(job.printedM) : null,
        planned_m: snap.ok && job ? num(job.plannedM) : null,
        read_at: iso(now),
      });
    }
    this.s.pending.push(...newRuns);
    return { live, newRuns };
  }

  /** Lecture devenue trop ancienne (PrintExp fermé, fichier figé…) */
  isStale(now = Date.now()) { return now - (this.s.lastOk || 0) > this.staleMs; }

  finish(src, pk, run, end, now) {
    end = end || {};
    const reported = num(end.reportedM) ?? run.maxM;
    let outcome = OUTCOMES.has(end.outcome) ? end.outcome : 'unknown';
    if (outcome === 'unknown' && run.progress != null && run.progress >= 100 && !end.outcome) outcome = 'completed';
    const endedAt = end.endedAt ? new Date(end.endedAt).getTime() : now;
    const notes = [];
    if (outcome === 'unknown') notes.push('الآلة توقفت دون أن يذكر PrintExp سبب التوقف');
    if (reported == null) notes.push('لا يوجد طول مطبوع في القراءة');

    // Déjà compté ? (relecture de l'historique, redémarrage)
    if (this.s.emitted.some(x => x.key === run.key)) return null;
    // Ambiguïté : même imprimante, même nom, fin très proche, sans identifiant de la source.
    const twin = this.s.emitted.find(x => x.printer === pk && x.name === (run.job.name || null) && !run.job.id &&
      Math.abs(x.endedAt - endedAt) < AMBIGUOUS_WINDOW && Math.abs((x.m ?? -1) - (reported ?? -1)) < 0.05);
    if (twin) notes.push('قد يكون نفس الطبعة المسجّلة سابقاً — تحقّق');

    this.s.emitted.push({ key: run.key, printer: pk, name: run.job.name || null, endedAt, m: reported });
    if (this.s.emitted.length > KEEP_KEYS) this.s.emitted.splice(0, this.s.emitted.length - KEEP_KEYS);
    return {
      run_key: run.key, printer_key: pk, source: src,
      source_run_id: run.job.id != null ? String(run.job.id) : null,
      job_name: run.job.name || end.name || null,
      planned_m: num(end.plannedM) ?? num(run.job.plannedM),
      reported_m: reported,
      outcome,
      started_at: iso(run.job.startedAt || end.startedAt || run.firstSeen),
      ended_at: iso(endedAt),
      needs_review: !!twin || outcome === 'unknown',
      review_note: notes.join(' · ') || null,
      raw: { paused_reads: run.paused || 0, progress: run.progress ?? null, collector: this.collector },
    };
  }

  /** Accusé de réception du serveur : ces passages sont enregistrés (ou l'étaient déjà). */
  ack(keys) { const k = new Set(keys); this.s.pending = this.s.pending.filter(r => !k.has(r.run_key)); }
  pending() { return this.s.pending.slice(); }
}
function stripNull(o) { const r = {}; for (const k in o) if (o[k] != null && o[k] !== '') r[k] = o[k]; return r; }

module.exports = { Tracker };
