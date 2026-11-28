'use strict';
// Sources de lecture PrintExp (lecture seule). Aucune n'envoie de commande à PrintExp ni à la machine.
//  - LogSource : lit en continu un journal / historique texte de PrintExp selon des règles (expressions régulières)
//                décrites dans printexp.json — les règles exactes seront fixées d'après de vrais fichiers de l'atelier.
//  - UiaSource : lit les textes de la fenêtre PrintExp via Windows UI Automation (repli), sans coordonnées d'écran.
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const UNIT = { m: 1, cm: 0.01, mm: 0.001 };
const toNum = v => { if (v == null) return null; const n = +String(v).replace(',', '.').replace(/[^\d.\-]/g, ''); return isFinite(n) && String(v).trim() !== '' ? n : null; };
function parseTs(v) { if (!v) return null; const t = Date.parse(String(v).replace(/\//g, '-').replace(' ', 'T')); return isNaN(t) ? null : t; }

/** Modèle d'état d'une imprimante tenu à partir des événements du journal. */
function emptyModel(printer) { return { key: printer.key, name: printer.name, connection: 'unknown', activity: 'unknown', job: null, ended: [] }; }

/** Applique une ligne de journal au modèle. Pur : utilisé tel quel par les tests. */
function applyLine(model, line, rules, unit = 'm', now = Date.now()) {
  const k = UNIT[unit] || 1;
  for (const r of rules) {
    const m = r._re ? r._re.exec(line) : new RegExp(r.match, r.flags || 'i').exec(line);
    if (!m) continue;
    const g = m.groups || {};
    const ts = parseTs(g.ts) || now;
    const meters = toNum(g.m) != null ? toNum(g.m) * k : null;
    const planned = toNum(g.planned) != null ? toNum(g.planned) * k : null;
    const job = model.job || (model.job = {});
    if (g.id) job.id = g.id; if (g.name) job.name = g.name.trim();
    if (planned != null) job.plannedM = planned;
    if (meters != null) job.printedM = meters;
    if (toNum(g.progress) != null) job.progress = toNum(g.progress);
    switch (r.event) {
      case 'connected': model.connection = 'connected'; if (model.activity === 'unknown') model.activity = 'idle'; model.job = model.job && model.job.startedAt ? model.job : null; break;
      case 'disconnected': model.connection = 'disconnected'; break;
      case 'start': model.job = { id: g.id || null, name: g.name ? g.name.trim() : null, startedAt: ts, plannedM: planned, printedM: meters ?? 0, progress: toNum(g.progress) };
        model.activity = 'printing'; model.connection = 'connected'; break;
      case 'progress': model.activity = 'printing'; model.connection = 'connected'; break;
      case 'pause': model.activity = 'paused'; break;
      case 'resume': model.activity = 'printing'; break;
      case 'error': model.activity = 'error'; break;
      case 'end': {
        const j = model.job || {};
        model.ended.push({ printer: model.key, id: j.id || g.id || null, name: j.name || (g.name && g.name.trim()) || null, startedAt: j.startedAt || null,
          endedAt: ts, reportedM: meters ?? j.printedM ?? null, plannedM: planned ?? j.plannedM ?? null, outcome: r.outcome || 'unknown' });
        model.job = null; model.activity = 'idle'; break;
      }
    }
    return r.event;
  }
  return null;
}

class LogSource {
  constructor(cfg, store) { this.cfg = cfg; this.store = store; this.model = emptyModel(cfg.printer); this.lastErr = null;
    this.rules = (cfg.log.rules || []).map(r => ({ ...r, _re: new RegExp(r.match, r.flags || 'i') }));
    this.fileRe = new RegExp(cfg.log.file || '\\.(log|txt|csv)$', 'i'); }
  async read() {
    const now = Date.now();
    const c = this.cfg.log; let ok = false;
    try {
      const files = fs.readdirSync(c.folder).filter(f => this.fileRe.test(f)).map(f => ({ f, st: fs.statSync(path.join(c.folder, f)) }))
        .sort((a, b) => a.st.mtimeMs - b.st.mtimeMs);
      const offs = this.store.offsets || (this.store.offsets = {});
      for (const { f, st } of files.slice(-3)) {             // le fichier du jour (+ rotation récente)
        const p = path.join(c.folder, f); let from = offs[f] ?? 0;
        if (st.size < from) from = 0;                       // fichier recréé
        if (st.size > from) {
          const fd = fs.openSync(p, 'r'); const buf = Buffer.alloc(Math.min(st.size - from, 4 << 20));
          fs.readSync(fd, buf, 0, buf.length, from); fs.closeSync(fd);
          const text = buf.toString(c.encoding || 'utf8'); const lastNl = text.lastIndexOf('\n');
          if (lastNl >= 0) { for (const line of text.slice(0, lastNl).split(/\r?\n/)) applyLine(this.model, line, this.rules, c.units, now); offs[f] = from + Buffer.byteLength(text.slice(0, lastNl + 1), c.encoding || 'utf8'); }
        }
      }
      ok = files.length > 0; this.lastErr = ok ? null : 'لا يوجد ملف سجل في المجلد';
    } catch (e) { this.lastErr = e.message; }
    const ended = this.model.ended.splice(0);
    return { at: now, ok, source: 'log', printers: [{ key: this.model.key, name: this.model.name, connection: this.model.connection, activity: this.model.activity, job: this.model.job }], ended };
  }
}

/** Interprète la liste d'éléments UIA (nom / valeur) selon les règles de printexp.json. Pur, testable. */
function interpretUia(elements, cfg, printer, now = Date.now()) {
  const u = cfg.uia; const texts = elements.map(e => [e.name, e.value].filter(Boolean).join(' ')).filter(Boolean);
  const pick = re => { if (!re) return null; const r = new RegExp(re, 'i'); for (const t of texts) { const m = r.exec(t); if (m) return (m.groups && m.groups.v) || m[1] || m[0]; } return null; };
  const status = pick(u.status) || '';
  let activity = 'unknown';
  for (const [act, re] of Object.entries(u.activity || {})) if (new RegExp(re, 'i').test(status) || (!u.status && texts.some(t => new RegExp(re, 'i').test(t)))) { activity = act; break; }
  const connection = u.disconnected && texts.some(t => new RegExp(u.disconnected, 'i').test(t)) ? 'disconnected'
    : u.connected && texts.some(t => new RegExp(u.connected, 'i').test(t)) ? 'connected' : 'unknown';
  const k = UNIT[u.units] || 1;
  const pm = toNum(pick(u.printedM)), pl = toNum(pick(u.plannedM));
  const job = (activity === 'printing' || activity === 'paused') ? { id: pick(u.jobId), name: pick(u.jobName), printedM: pm != null ? pm * k : null, plannedM: pl != null ? pl * k : null, progress: toNum(pick(u.progress)) } : null;
  return { at: now, ok: true, source: 'uia', printers: [{ key: printer.key, name: printer.name, connection, activity, job }], ended: [] };
}

class UiaSource {
  constructor(cfg, script) { this.cfg = cfg; this.script = script; this.lastErr = null; }
  read() {
    return new Promise(res => {
      execFile('powershell.exe', ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', this.script, '-Process', this.cfg.uia.process || 'PrintExp', '-Json'],
        { windowsHide: true, timeout: 15000, maxBuffer: 8 << 20 }, (err, out) => {
          const now = Date.now();
          let els = null; try { els = JSON.parse(out || 'null'); } catch (_) {}
          if (err || !Array.isArray(els) || !els.length) { this.lastErr = err ? err.message : 'نافذة PrintExp غير موجودة'; return res({ at: now, ok: false, source: 'uia', printers: [{ key: this.cfg.printer.key, name: this.cfg.printer.name }], ended: [] }); }
          this.lastErr = null; res(interpretUia(els, this.cfg, this.cfg.printer, now));
        });
    });
  }
}

module.exports = { applyLine, emptyModel, interpretUia, LogSource, UiaSource, parseTs };
