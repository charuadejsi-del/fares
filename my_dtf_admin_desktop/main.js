// My DTF Admin — application Windows : le centre de contrôle dans sa propre fenêtre,
// toujours à jour (il charge le site d'administration), notifications Windows, démarrage automatique.
const { app, BrowserWindow, Menu, Tray, shell, nativeImage, session } = require('electron');
const path = require('path');
const fs = require('fs');

const URL = 'https://mydtf-admin.pages.dev/';
const ICON = path.join(__dirname, 'build', 'icon.png');
const STATE = () => path.join(app.getPath('userData'), 'window.json');
let win, tray, quitting = false;

if (!app.requestSingleInstanceLock()) app.quit();
app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.show(); win.focus(); } });
app.setAppUserModelId('com.mydtf.admin.desktop');

function loadState() { try { return JSON.parse(fs.readFileSync(STATE(), 'utf8')); } catch (_) { return { width: 1360, height: 860 }; } }
function saveState() { try { if (!win.isMinimized()) fs.writeFileSync(STATE(), JSON.stringify({ ...win.getBounds(), max: win.isMaximized() })); } catch (_) {} }

function create() {
  const st = loadState();
  win = new BrowserWindow({
    ...st, minWidth: 980, minHeight: 640, show: false, backgroundColor: '#0B0C0F', title: 'My DTF Admin', icon: ICON, autoHideMenuBar: true,
    webPreferences: { contextIsolation: true, sandbox: true, spellcheck: false },
  });
  if (st.max) win.maximize();
  Menu.setApplicationMenu(null);
  win.loadURL(URL);
  win.once('ready-to-show', () => win.show());
  // Pas d'internet : page d'attente qui réessaie toute seule.
  win.webContents.on('did-fail-load', (_e, code, _d, url, isMain) => { if (isMain && code !== -3) win.loadFile(path.join(__dirname, 'offline.html')); });
  // Les liens externes s'ouvrent dans le navigateur.
  win.webContents.setWindowOpenHandler(({ url }) => { if (!url.startsWith(URL)) shell.openExternal(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => { if (!url.startsWith(URL) && !url.startsWith('file:')) { e.preventDefault(); shell.openExternal(url); } });
  win.on('close', e => { saveState(); if (!quitting) { e.preventDefault(); win.hide(); } });
}

function buildTray() {
  tray = new Tray(nativeImage.createFromPath(ICON).resize({ width: 16, height: 16 }));
  const auto = () => app.getLoginItemSettings().openAtLogin;
  const menu = () => Menu.buildFromTemplate([
    { label: 'فتح My DTF Admin', click: () => { win.show(); win.focus(); } },
    { label: 'تحديث الصفحة', click: () => win.loadURL(URL) },
    { type: 'separator' },
    { label: 'التشغيل مع ويندوز', type: 'checkbox', checked: auto(), click: i => { app.setLoginItemSettings({ openAtLogin: i.checked }); tray.setContextMenu(menu()); } },
    { type: 'separator' },
    { label: 'إغلاق نهائي', click: () => { quitting = true; app.quit(); } },
  ]);
  tray.setToolTip('My DTF Admin');
  tray.setContextMenu(menu());
  tray.on('click', () => { win.isVisible() ? win.focus() : win.show(); });
}

app.whenReady().then(() => {
  // Notifications autorisées pour le site d'administration uniquement.
  session.defaultSession.setPermissionRequestHandler((wc, perm, cb) => cb(perm === 'notifications' && wc.getURL().startsWith(URL)));
  if (!app.getLoginItemSettings().wasOpenedAtLogin && !fs.existsSync(path.join(app.getPath('userData'), 'first'))) {
    app.setLoginItemSettings({ openAtLogin: true });
    try { fs.writeFileSync(path.join(app.getPath('userData'), 'first'), '1'); } catch (_) {}
  }
  create();
  buildTray();
});
app.on('before-quit', () => { quitting = true; });
app.on('window-all-closed', () => {});
