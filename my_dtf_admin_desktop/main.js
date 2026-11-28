// My DTF — programme Windows de la ورشة : une seule application pour toute l'équipe
// (administrateur, gérant, designers, imprimeurs). Elle charge le site de l'équipe : toujours identique
// au site et à jour sans réinstallation. En plus : téléchargements directs, PDF imprimables,
// notifications Windows, icône près de l'horloge, démarrage avec Windows, mise à jour automatique.
const { app, BrowserWindow, Menu, Tray, shell, nativeImage, session, Notification, dialog, globalShortcut } = require('electron');
const path = require('path');
const fs = require('fs');

const PKG = require('./package.json');
// Adresse du site de l'installation : package.json → "mydtf"."appUrl".
const URL = (PKG.mydtf || {}).appUrl || 'https://mydtf-admin.pages.dev/';
const ORIGIN = new globalThis.URL(URL).origin;
const NAME = PKG.productName || 'My DTF';
const ICON = path.join(__dirname, 'build', 'icon.png');
const STATE = () => path.join(app.getPath('userData'), 'window.json');
const DL_DIR = () => path.join(app.getPath('downloads'), 'MyDTF');
let win, tray, quitting = false, updateReady = false;

if (!app.requestSingleInstanceLock()) app.quit();
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } });
app.setAppUserModelId('com.mydtf.desktop');

function loadState() { try { return JSON.parse(fs.readFileSync(STATE(), 'utf8')); } catch (_) { return { width: 1360, height: 860 }; } }
function saveState() { try { if (win && !win.isMinimized()) fs.writeFileSync(STATE(), JSON.stringify({ ...win.getBounds(), max: win.isMaximized(), zoom: win.webContents.getZoomFactor() })); } catch (_) {} }
const inApp = url => url.startsWith(ORIGIN);
function notify(title, body, onClick) {
  if (!Notification.isSupported()) return;
  const n = new Notification({ title, body, icon: ICON, silent: false });
  if (onClick) n.on('click', onClick);
  n.show();
}

// Fenêtre d'aperçu pour les PDF (étiquettes de livraison, factures) : impression directe avec Ctrl+P.
function openPreview(url) {
  const w = new BrowserWindow({ width: 900, height: 1000, title: NAME, icon: ICON, autoHideMenuBar: true, backgroundColor: '#090B11',
    webPreferences: { contextIsolation: true, sandbox: true, plugins: true } });
  w.loadURL(url);
  w.webContents.on('before-input-event', (_e, i) => { if (i.type === 'keyDown' && i.control && i.key.toLowerCase() === 'p') w.webContents.print(); });
}

function create() {
  const st = loadState();
  win = new BrowserWindow({
    x: st.x, y: st.y, width: st.width || 1360, height: st.height || 860, minWidth: 980, minHeight: 640, show: false,
    backgroundColor: '#090B11', title: NAME, icon: ICON, autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true, spellcheck: false, plugins: true },
  });
  if (st.max) win.maximize();
  Menu.setApplicationMenu(null);
  win.loadURL(URL);
  win.once('ready-to-show', () => { win.show(); if (st.zoom) win.webContents.setZoomFactor(st.zoom); });
  win.on('page-title-updated', e => { e.preventDefault(); win.setTitle(NAME); });

  // Pas d'internet : page d'attente qui réessaie toute seule.
  win.webContents.on('did-fail-load', (_e, code, _d, _url, isMain) => {
    if (isMain && code !== -3) win.loadFile(path.join(__dirname, 'offline.html'), { query: { u: URL } });
  });
  // Fenêtres ouvertes par le site : PDF / fichiers générés (blob:) → aperçu imprimable ; liens externes → navigateur.
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('blob:') || url.startsWith('data:')) { openPreview(url); return { action: 'deny' }; }
    if (!inApp(url)) shell.openExternal(url);
    else win.loadURL(url);
    return { action: 'deny' };
  });
  win.webContents.on('will-navigate', (e, url) => { if (!inApp(url) && !url.startsWith('file:')) { e.preventDefault(); shell.openExternal(url); } });

  // Raccourcis : F5 actualiser, F11 plein écran (mode écran de l'atelier), Ctrl +/−/0 zoom, Ctrl+P imprimer.
  win.webContents.on('before-input-event', (e, i) => {
    if (i.type !== 'keyDown') return;
    const k = i.key.toLowerCase();
    if (k === 'f5') { win.webContents.reload(); e.preventDefault(); }
    else if (k === 'f11') { win.setFullScreen(!win.isFullScreen()); e.preventDefault(); }
    else if (i.control && (k === '=' || k === '+')) { win.webContents.setZoomFactor(Math.min(2, win.webContents.getZoomFactor() + 0.1)); e.preventDefault(); }
    else if (i.control && k === '-') { win.webContents.setZoomFactor(Math.max(0.6, win.webContents.getZoomFactor() - 0.1)); e.preventDefault(); }
    else if (i.control && k === '0') { win.webContents.setZoomFactor(1); e.preventDefault(); }
    else if (i.control && k === 'p') { win.webContents.print(); e.preventDefault(); }
  });
  win.on('close', e => { saveState(); if (!quitting) { e.preventDefault(); win.hide(); } });
}

// Téléchargements (fichiers des designers, exports CSV, étiquettes) : directement dans Téléchargements\MyDTF.
function setupDownloads() {
  session.defaultSession.on('will-download', (_e, item) => {
    try { fs.mkdirSync(DL_DIR(), { recursive: true }); } catch (_) {}
    const base = item.getFilename() || 'fichier';
    let target = path.join(DL_DIR(), base), n = 1;
    while (fs.existsSync(target)) { const p = path.parse(base); target = path.join(DL_DIR(), `${p.name} (${n++})${p.ext}`); }
    item.setSavePath(target);
    item.once('done', (_ev, state) => {
      if (state === 'completed') notify('تمّ التنزيل', path.basename(target), () => shell.showItemInFolder(target));
      else if (state !== 'cancelled') notify('فشل التنزيل', base);
    });
  });
}

function buildTray() {
  tray = new Tray(nativeImage.createFromPath(ICON).resize({ width: 16, height: 16 }));
  const auto = () => app.getLoginItemSettings().openAtLogin;
  const menu = () => Menu.buildFromTemplate([
    { label: `فتح ${NAME}`, click: () => { win.show(); win.focus(); } },
    { label: 'تحديث الصفحة', click: () => win.loadURL(URL) },
    { label: 'مجلد التنزيلات', click: () => { fs.mkdirSync(DL_DIR(), { recursive: true }); shell.openPath(DL_DIR()); } },
    { type: 'separator' },
    { label: 'التشغيل مع ويندوز', type: 'checkbox', checked: auto(), click: i => { app.setLoginItemSettings({ openAtLogin: i.checked }); tray.setContextMenu(menu()); } },
    { label: updateReady ? 'تثبيت التحديث الآن' : 'البحث عن تحديث', click: () => (updateReady ? installUpdate() : checkUpdates(true)) },
    { type: 'separator' },
    { label: `الإصدار ${app.getVersion()}`, enabled: false },
    { label: 'إغلاق نهائي', click: () => { quitting = true; app.quit(); } },
  ]);
  tray.setToolTip(NAME);
  tray.setContextMenu(menu());
  tray.on('click', () => { win.isVisible() ? win.focus() : win.show(); });
  return menu;
}

// ---------- Mise à jour automatique du programme (publication GitHub « my-dtf-desktop-latest ») ----------
let updater = null, refreshTray = () => {};
function installUpdate() { quitting = true; updater?.quitAndInstall(false, true); }
function checkUpdates(manual = false) {
  if (!updater) { if (manual) dialog.showMessageBox(win, { message: 'التحديث التلقائي غير متاح في هذه النسخة.' }); return; }
  updater.checkForUpdates().then(r => {
    if (manual && (!r || !r.updateInfo || r.updateInfo.version === app.getVersion())) dialog.showMessageBox(win, { message: `لديك آخر إصدار (${app.getVersion()}).` });
  }).catch(e => { if (manual) dialog.showMessageBox(win, { type: 'warning', message: 'تعذّر البحث عن تحديث', detail: String(e?.message || e) }); });
}
function setupUpdates() {
  if (!app.isPackaged) return;
  try { updater = require('electron-updater').autoUpdater; } catch (_) { return; }
  updater.autoDownload = true;
  updater.autoInstallOnAppQuit = true;
  updater.on('update-downloaded', info => {
    updateReady = true; refreshTray();
    notify('تحديث جديد جاهز', `الإصدار ${info.version} — يُثبَّت عند إغلاق البرنامج، أو اضغط للتثبيت الآن`, () => installUpdate());
  });
  updater.on('error', () => {});
  checkUpdates();
  setInterval(() => checkUpdates(), 6 * 3600 * 1000);
}

app.whenReady().then(() => {
  // Notifications et téléchargements autorisés pour le site de l'équipe uniquement.
  session.defaultSession.setPermissionRequestHandler((wc, perm, cb) => cb(['notifications', 'clipboard-sanitized-write', 'fullscreen'].includes(perm) && inApp(wc.getURL())));
  // Premier lancement : démarrage avec Windows activé (désactivable depuis l'icône près de l'horloge).
  const first = path.join(app.getPath('userData'), 'first');
  if (!fs.existsSync(first)) { app.setLoginItemSettings({ openAtLogin: true }); try { fs.writeFileSync(first, '1'); } catch (_) {} }
  setupDownloads();
  create();
  const menu = buildTray();
  refreshTray = () => tray.setContextMenu(menu());
  setupUpdates();
});
app.on('before-quit', () => { quitting = true; saveState(); });
app.on('will-quit', () => globalShortcut.unregisterAll());
app.on('window-all-closed', () => {});
