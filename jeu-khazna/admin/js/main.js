// نقطة الدخول: التحقّق من المدير ← الهيكل ← الموجّه ← التحديث الدوري.
import { auth, api, errorText } from './core/api.js';
import { store } from './core/store.js';
import { current, onRoute, go } from './core/router.js';
import { $, toast, beep, emptyState } from './core/ui.js';
import { disposeCharts } from './core/charts.js';
import { startFx } from './core/fx.js';
import { POLL_MS } from './core/config.js';
import { renderLogin } from './views/login.js';
import { renderShell, setActive, NAV } from './views/shell.js';
import { renderDashboard } from './views/dashboard.js';
import { renderPlayers } from './views/players.js';
import { renderPayments } from './views/payments.js';
import { renderActivity } from './views/activity.js';
import { renderSettings, settingsDirty } from './views/settings.js';
import { renderRooms } from './views/rooms.js';

const VIEWS = {
  dashboard: renderDashboard, players: renderPlayers, payments: renderPayments,
  activity: renderActivity, settings: renderSettings, rooms: renderRooms,
};
const app = $('#app');
let pollTimer = 0;
let lastRoute = null;
let routed = false;

async function refreshPending(notify = false) {
  try {
    const list = await api.payments('pending');
    const before = store.get().pending.length;
    store.set({ pending: list });
    if (notify && list.length > before) {
      beep();
      toast(`طلب دفع جديد — ${list.length} في الانتظار`, 'warn');
      if ('Notification' in window && Notification.permission === 'granted')
        new Notification('الخزنة: طلب دفع جديد', { body: `${list.length} طلب في الانتظار`, icon: '/icon.svg' });
      if (current().name === 'payments' || current().name === 'dashboard') route(current());
    }
  } catch {}
}

async function route({ name, param }) {
  if (!VIEWS[name]) return go('dashboard');
  if (lastRoute === 'settings' && name !== 'settings' && settingsDirty() && !confirm('لديك تغييرات غير محفوظة. المغادرة؟')) {
    history.replaceState(null, '', '#/settings');
    return;
  }
  lastRoute = name;
  disposeCharts();
  const page = $('#page');
  const meta = NAV.find((n) => n.id === name);
  setActive(name, { title: meta.label });
  page.style.animation = 'none';
  void page.offsetHeight;
  page.style.animation = '';
  page.innerHTML = `<div class="kpis">${'<div class="skeleton" style="height:118px"></div>'.repeat(4)}</div><div class="skeleton" style="height:320px;margin-top:16px"></div>`;
  try {
    const res = await VIEWS[name](page, param, { refreshPending });
    setActive(name, res || {});
  } catch (e) {
    page.innerHTML = `<div class="card">${emptyState('alert', 'تعذّر تحميل الصفحة', errorText(e))}</div>`;
    if (String(e?.message).includes('JWT')) logout();
  }
}

async function logout() {
  clearInterval(pollTimer);
  await auth.signOut();
  location.hash = '';
  start();
}

async function enter() {
  const session = await auth.session();
  if (!session) return renderLogin(app, { onSuccess: enter });
  let admin = false;
  try { admin = await auth.isAdmin(); } catch {}
  if (!admin) {
    await auth.signOut();
    return renderLogin(app, { message: 'هذا الحساب ليس مديراً', onSuccess: enter });
  }
  const me = await auth.me(session.user.id).catch(() => ({ nickname: 'المدير' }));
  store.set({ me: { id: session.user.id, nickname: me.nickname, email: session.user.email } });
  renderShell(app, { onLogout: logout });
  await refreshPending();
  api.players().then((p) => (window.__players = p)).catch(() => {});
  if (!routed) { onRoute(route); routed = true; }
  route(current());
  clearInterval(pollTimer);
  pollTimer = setInterval(() => refreshPending(true), POLL_MS);
  if ('Notification' in window && Notification.permission === 'default') setTimeout(() => Notification.requestPermission(), 4000);
}

function start() {
  enter().catch((e) => renderLogin(app, { message: errorText(e), onSuccess: enter }));
}

startFx();
start();
