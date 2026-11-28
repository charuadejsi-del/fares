'use strict';
// Collecteur local PrintExp : lit la source toutes les 5 s, suit les passages, garde un journal local
// des passages confirmés tant que le serveur ne les a pas accusés, et les transmet à la page My DTF
// (session de l'utilisateur connecté) qui les enregistre via dtf_printexp_report.
const fs = require('fs');
const path = require('path');
const os = require('os');
const { Tracker } = require('./tracker');
const { LogSource, UiaSource } = require('./sources');

const DEFAULT_CFG = {
  _aide: 'source: off | log | uia. Les règles exactes se fixent à partir du rapport de diagnostic (menu de l\'icône > PrintExp > Diagnostic).',
  source: 'off',
  printer: { key: 'AUDLEY-1', name: 'Audley' },
  intervalSec: 5,
  staleSec: 30,
  log: { folder: '', file: '\\.(log|txt|csv)$', encoding: 'utf8', units: 'm', rules: [] },
  uia: { process: 'PrintExp', units: 'm', status: null, activity: {}, connected: null, disconnected: null, printedM: null, plannedM: null, progress: null, jobName: null, jobId: null },
};

class Collector {
  constructor(app, send) {
    this.dir = app.getPath('userData');
    this.cfgFile = path.join(this.dir, 'printexp.json');
    this.stateFile = path.join(this.dir, 'printexp-state.json');
    this.send = send; this.timer = null; this.lastErr = null; this.lastLive = []; this.lastPush = 0;
    this.script = path.join(__dirname, 'printexp-probe.ps1').replace('app.asar', 'app.asar.unpacked');
    this.load();
  }
  load() {
    if (!fs.existsSync(this.cfgFile)) fs.writeFileSync(this.cfgFile, JSON.stringify(DEFAULT_CFG, null, 2));
    try { this.cfg = { ...DEFAULT_CFG, ...JSON.parse(fs.readFileSync(this.cfgFile, 'utf8')) }; this.cfgErr = null; }
    catch (e) { this.cfg = { ...DEFAULT_CFG, source: 'off' }; this.cfgErr = 'printexp.json غير صالح: ' + e.message; }
    let st = {}; try { st = JSON.parse(fs.readFileSync(this.stateFile, 'utf8')); } catch (_) {}
    this.tracker = new Tracker(st.tracker || {}, { staleMs: this.cfg.staleSec * 1000, collector: os.hostname() });
    this.store = st.source || {};
    this.src = this.cfg.source === 'log' && this.cfg.log.folder ? new LogSource(this.cfg, this.store)
      : this.cfg.source === 'uia' ? new UiaSource(this.cfg, this.script) : null;
  }
  save() { try { fs.writeFileSync(this.stateFile + '.tmp', JSON.stringify({ tracker: this.tracker.state(), source: this.store })); fs.renameSync(this.stateFile + '.tmp', this.stateFile); } catch (_) {} }
  start() { this.stop(); if (!this.src) return; const tick = async () => { await this.poll(); this.timer = setTimeout(tick, this.cfg.intervalSec * 1000); }; tick(); }
  stop() { clearTimeout(this.timer); this.timer = null; }
  restart() { this.stop(); this.load(); this.start(); }

  async poll() {
    try {
      const snap = await this.src.read();
      this.lastErr = this.src.lastErr;
      const { live } = this.tracker.ingest(snap);
      this.save();                                   // passage confirmé écrit sur disque AVANT l'envoi
      const changed = JSON.stringify(live.map(l => ({ ...l, read_at: 0 }))) !== JSON.stringify(this.lastLive.map(l => ({ ...l, read_at: 0 })));
      this.lastLive = live;
      if (changed || Date.now() - this.lastPush > 15e3 || this.tracker.pending().length) this.push();
    } catch (e) { this.lastErr = e.message; }
  }
  push() { this.lastPush = Date.now(); this.send({ collector: os.hostname(), live: this.lastLive, runs: this.tracker.pending() }); }
  ack(keys) { this.tracker.ack(keys || []); this.save(); }
  status() {
    return { source: this.cfg.source, printer: this.cfg.printer, configured: !!this.src, cfgErr: this.cfgErr, lastErr: this.lastErr,
      stale: this.src ? this.tracker.isStale() : null, pending: this.tracker.pending().length, cfgFile: this.cfgFile };
  }
}

module.exports = { Collector, DEFAULT_CFG };
