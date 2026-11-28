'use strict';
// Tests du collecteur avec des lectures SIMULÉES (format de journal inventé pour les tests uniquement :
// le vrai format PrintExp sera relevé sur le PC de l'atelier). Lancement : node --test test/
const test = require('node:test');
const assert = require('node:assert/strict');
const { Tracker } = require('../collector/tracker');
const { applyLine, emptyModel, interpretUia } = require('../collector/sources');

const P = { key: 'AUDLEY-1', name: 'Audley' };
const T0 = Date.parse('2026-11-28T09:00:00Z');
const snap = (s, at, extra = {}) => ({ at: T0 + at * 1000, ok: true, source: 'test', printers: [{ key: P.key, name: P.name, ...s }], ended: [], ...extra });
const job = (m, o = {}) => ({ name: 'logo.png', startedAt: T0, printedM: m, ...o });

test('imprimante connectée au repos : aucun passage, état « idle »', () => {
  const t = new Tracker();
  const { live, newRuns } = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 0));
  assert.equal(newRuns.length, 0);
  assert.equal(live[0].connection, 'connected'); assert.equal(live[0].activity, 'idle');
});

test('imprimante déconnectée pendant un passage : le passage reste ouvert puis reprend', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1.2) }, 0));
  const r = t.ingest(snap({ connection: 'disconnected', activity: 'unknown', job: null }, 5));
  assert.equal(r.live[0].connection, 'disconnected'); assert.equal(r.newRuns.length, 0);
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(2.0) }, 10));
  const end = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 15, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 15e3, reportedM: 2.4, outcome: 'completed' }] }));
  assert.equal(end.newRuns.length, 1); assert.equal(end.newRuns[0].reported_m, 2.4); assert.equal(end.newRuns[0].outcome, 'completed');
});

test('passage terminé : fin explicite de la source ⇒ métrage final et issue', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(0.5, { plannedM: 3 }) }, 0));
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(2.9, { plannedM: 3 }) }, 60));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 65, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 65e3, reportedM: 3.02, outcome: 'completed' }] }));
  assert.equal(r.newRuns.length, 1);
  assert.deepEqual([r.newRuns[0].planned_m, r.newRuns[0].reported_m, r.newRuns[0].outcome, r.newRuns[0].needs_review], [3, 3.02, 'completed', false]);
});

test('passage annulé avec mètres partiels', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1.1, { plannedM: 4 }) }, 0));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 30, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 30e3, reportedM: 1.35, outcome: 'cancelled' }] }));
  assert.equal(r.newRuns[0].outcome, 'cancelled'); assert.equal(r.newRuns[0].reported_m, 1.35);
});

test('arrêt sans fin explicite : issue « unknown », à vérifier, jamais inventée', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1.7) }, 0));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 20));
  assert.equal(r.newRuns[0].outcome, 'unknown'); assert.equal(r.newRuns[0].needs_review, true); assert.equal(r.newRuns[0].reported_m, 1.7);
});

test('pause puis reprise : un seul passage', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1) }, 0));
  t.ingest(snap({ connection: 'connected', activity: 'paused', job: job(1.4) }, 10));
  t.ingest(snap({ connection: 'connected', activity: 'paused', job: job(1.4) }, 20));
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(2.2) }, 30));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 40, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 40e3, reportedM: 2.5, outcome: 'completed' }] }));
  assert.equal(r.newRuns.length, 1); assert.equal(t.pending().length, 1); assert.equal(r.newRuns[0].raw.paused_reads, 2);
});

test('réimpression volontaire du même fichier : deux passages distincts', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1.9) }, 0));
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 10, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 10e3, reportedM: 2, outcome: 'completed' }] }));
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(0.4, { startedAt: T0 + 300e3 }) }, 310));
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 400, { ended: [{ printer: P.key, name: 'logo.png', endedAt: T0 + 400e3, reportedM: 2, outcome: 'completed' }] }));
  const keys = t.pending().map(r => r.run_key);
  assert.equal(keys.length, 2); assert.notEqual(keys[0], keys[1]);
});

test('réimpression sans heure de départ : le compteur qui repart à zéro ouvre un nouveau passage', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: { name: 'a.png', printedM: 1.8 } }, 0));
  const r = t.ingest(snap({ connection: 'connected', activity: 'printing', job: { name: 'a.png', printedM: 0.1 } }, 5));
  assert.equal(r.newRuns.length, 1); assert.equal(r.newRuns[0].reported_m, 1.8);
});

test('identifiant de passage fourni par la source : relecture de l\'historique sans doublon', () => {
  const t = new Tracker();
  const e = { printer: P.key, id: 'J-77', name: 'x.png', startedAt: T0, endedAt: T0 + 50e3, reportedM: 1.2, outcome: 'completed' };
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 50, { ended: [e] }));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 55, { ended: [e] }));   // même ligne relue
  assert.equal(r.newRuns.length, 0); assert.equal(t.pending().length, 1);
});

test('données périmées : lecture impossible ⇒ état inconnu, aucun passage fermé à tort', () => {
  const t = new Tracker({}, { staleMs: 30e3 });
  t.ingest(snap({ connection: 'connected', activity: 'printing', job: job(1) }, 0));
  const r = t.ingest({ at: T0 + 40e3, ok: false, source: 'test', printers: [{ key: P.key }], ended: [] });
  assert.equal(r.live[0].connection, 'unknown'); assert.equal(r.live[0].activity, 'unknown');
  assert.equal(r.newRuns.length, 0); assert.equal(t.isStale(T0 + 40e3), true);
});

test('redémarrage du programme pendant un passage : même passage repris depuis l\'état sauvegardé', () => {
  const a = new Tracker();
  a.ingest(snap({ connection: 'connected', activity: 'printing', job: { name: 'b.png', printedM: 0.8 } }, 0));
  const saved = JSON.parse(JSON.stringify(a.state()));
  const b = new Tracker(saved);
  b.ingest(snap({ connection: 'connected', activity: 'printing', job: { name: 'b.png', printedM: 1.6 } }, 30));
  const r = b.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 40, { ended: [{ printer: P.key, name: 'b.png', endedAt: T0 + 40e3, reportedM: 1.9, outcome: 'completed' }] }));
  assert.equal(r.newRuns.length, 1); assert.equal(r.newRuns[0].started_at, new Date(T0).toISOString());
});

test('réseau coupé : passages gardés jusqu\'à l\'accusé du serveur, puis retirés une seule fois', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 0, { ended: [{ printer: P.key, id: 1, endedAt: T0, reportedM: 1, outcome: 'completed' }] }));
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 5, { ended: [{ printer: P.key, id: 2, endedAt: T0 + 5e3, reportedM: 2, outcome: 'completed' }] }));
  assert.equal(t.pending().length, 2);
  t.ack([t.pending()[0].run_key]); assert.equal(t.pending().length, 1);
  t.ack([t.pending()[0].run_key, 'inconnu']); assert.equal(t.pending().length, 0);
});

test('deux fins indiscernables sans identifiant : la seconde est signalée à vérifier', () => {
  const t = new Tracker();
  t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 0, { ended: [{ printer: P.key, name: 'c.png', startedAt: T0, endedAt: T0 + 60e3, reportedM: 1.5, outcome: 'completed' }] }));
  const r = t.ingest(snap({ connection: 'connected', activity: 'idle', job: null }, 70, { ended: [{ printer: P.key, name: 'c.png', startedAt: T0 + 1e3, endedAt: T0 + 70e3, reportedM: 1.5, outcome: 'completed' }] }));
  assert.equal(r.newRuns.length, 1); assert.equal(r.newRuns[0].needs_review, true);
});

test('lecture de journal par règles (format de test) : départ, progression, pause, fin annulée', () => {
  const rules = [
    { match: '^(?<ts>\\S+ \\S+) START job=(?<id>\\S+) file=(?<name>.+?) len=(?<planned>[\\d.]+)$', event: 'start' },
    { match: '^(?<ts>\\S+ \\S+) PRINTED (?<m>[\\d.]+)', event: 'progress' },
    { match: 'PAUSE', event: 'pause' }, { match: 'RESUME', event: 'resume' },
    { match: '^(?<ts>\\S+ \\S+) CANCEL printed=(?<m>[\\d.]+)', event: 'end', outcome: 'cancelled' },
    { match: 'USB LOST', event: 'disconnected' },
  ];
  const md = emptyModel(P);
  ['2026-11-28 10:00:00 START job=55 file=team.png len=4.00', '2026-11-28 10:01:00 PRINTED 0.80', '2026-11-28 10:02:00 PAUSE', '2026-11-28 10:03:00 RESUME',
   '2026-11-28 10:04:00 PRINTED 1.60', '2026-11-28 10:05:00 CANCEL printed=1.75'].forEach(l => applyLine(md, l, rules));
  assert.equal(md.ended.length, 1);
  assert.deepEqual([md.ended[0].id, md.ended[0].name, md.ended[0].reportedM, md.ended[0].plannedM, md.ended[0].outcome], ['55', 'team.png', 1.75, 4, 'cancelled']);
  assert.equal(md.activity, 'idle');
  applyLine(md, '2026-11-28 10:06:00 USB LOST', rules); assert.equal(md.connection, 'disconnected');
});

test('lecture UI Automation (textes de test) : état et mètres sans coordonnées d\'écran', () => {
  const cfg = { uia: { units: 'm', status: 'Status:\\s*(?<v>\\w+)', activity: { printing: 'Printing', paused: 'Pause', idle: 'Ready|Idle', error: 'Error' },
    connected: 'Online', disconnected: 'Offline', printedM: 'Printed:\\s*(?<v>[\\d.,]+)', jobName: 'File:\\s*(?<v>.+)' } };
  const s = interpretUia([{ name: 'Status: Printing' }, { name: 'Online' }, { name: 'Printed: 2,35 m' }, { name: 'File: logo.png' }], cfg, P, T0);
  assert.equal(s.printers[0].activity, 'printing'); assert.equal(s.printers[0].connection, 'connected');
  assert.equal(s.printers[0].job.printedM, 2.35); assert.equal(s.printers[0].job.name, 'logo.png');
});
