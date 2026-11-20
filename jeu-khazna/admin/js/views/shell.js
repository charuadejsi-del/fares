// الهيكل الثابت: الشريط الجانبي، الشريط العلوي، شريط الهاتف، الجرس، لوحة الأوامر.
import { icon } from '../core/icons.js';
import { esc, avatar, dzd, ago } from '../core/format.js';
import { $, $$, dialog } from '../core/ui.js';
import { store } from '../core/store.js';
import { go } from '../core/router.js';

export const NAV = [
  { id: 'dashboard', label: 'مركز القيادة', short: 'الرئيسية', icon: 'dashboard', key: '1' },
  { id: 'players', label: 'العملاء', short: 'العملاء', icon: 'users', key: '2' },
  { id: 'payments', label: 'المدفوعات', short: 'الدفع', icon: 'card', key: '3', badge: true },
  { id: 'activity', label: 'سجلّ الحركات', short: 'السجلّ', icon: 'activity', key: '4' },
  { id: 'rooms', label: 'الغرف الحيّة', short: 'الغرف', icon: 'rooms', key: '5', desktopOnly: true },
  { id: 'settings', label: 'الإعدادات', short: 'الإعدادات', icon: 'settings', key: '6' },
];

export function renderShell(root, { onLogout }) {
  const { me } = store.get();
  root.innerHTML = `
  <div class="shell">
    <aside class="sidebar">
      <div class="brand"><span class="brand-mark">${icon('vault')}</span><div><b>الخزنة</b><small>COMMAND CENTER</small></div></div>
      <div class="nav-label">الإدارة</div>
      <nav id="side-nav"></nav>
      <div class="sidebar-foot">
        <button class="nav-item" data-palette style="width:100%">${icon('command')}<span>بحث سريع</span><kbd>Ctrl K</kbd></button>
        <div class="status-card"><span class="dot on"></span> <b style="color:var(--accent)">متّصل</b>
          <div class="faint" style="margin-top:4px">تحديث تلقائي كل 15 ثانية</div></div>
      </div>
    </aside>
    <div class="main">
      <header class="topbar">
        <div class="title"><h1 id="page-title"></h1><small id="page-sub"></small></div>
        <span class="spacer"></span>
        <span class="hide-sm mono faint" id="clock" style="font-size:13px"></span>
        <button class="btn btn-ghost icon-btn hide-sm" data-palette aria-label="بحث">${icon('search')}</button>
        <div style="position:relative"><button class="btn icon-btn" id="bell" aria-label="الإشعارات">${icon('bell')}<span class="badge" id="bell-badge" hidden></span></button><div id="bell-pop"></div></div>
        <button class="btn btn-ghost" id="me" style="padding:0 6px 0 10px;height:44px">${avatar(me.nickname, 32)}<span class="hide-sm" style="text-align:start;line-height:1.2"><b style="font-size:13.5px;display:block">${esc(me.nickname)}</b><span class="faint" style="font-size:11.5px">مدير</span></span></button>
      </header>
      <main class="page" id="page"></main>
    </div>
  </div>
  <nav class="tabbar" id="tab-nav"></nav>`;

  const tick = () => { const c = $('#clock'); if (c) c.textContent = new Date().toLocaleTimeString('fr-FR'); };
  tick();
  setInterval(tick, 1000);

  $('#me').onclick = async () => {
    if (await dialog({ title: 'تسجيل الخروج؟', body: `أنت مسجّل باسم <b>${esc(me.email)}</b>`, confirm: 'خروج', tone: 'danger' })) onLogout();
  };
  $('#bell').onclick = (e) => { e.stopPropagation(); toggleBell(); };
  document.addEventListener('click', (e) => { if (!e.target.closest('#bell-pop')) $('#bell-pop').innerHTML = ''; });
  $$('[data-palette]').forEach((b) => (b.onclick = openPalette));
  addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); }
    if (e.altKey && /^[1-6]$/.test(e.key)) go(NAV[+e.key - 1].id);
  });
  store.subscribe(paintBadges);
}

export function setActive(route, meta = {}) {
  const pending = store.get().pending.length;
  const item = (n, cls, label) => `<a class="${cls} ${route === n.id ? 'active' : ''}" href="#/${n.id}">${icon(n.icon)}<span>${label}</span>${n.badge && pending ? `<span class="badge">${pending}</span>` : ''}</a>`;
  $('#side-nav').innerHTML = NAV.map((n) => item(n, 'nav-item', n.label)).join('');
  $('#tab-nav').innerHTML = NAV.filter((n) => !n.desktopOnly).map((n) => item(n, 'tab', n.short)).join('');
  if (meta.title) { $('#page-title').textContent = meta.title; document.title = `${pending ? `(${pending}) ` : ''}${meta.title} · الخزنة`; }
  if (meta.sub) $('#page-sub').textContent = `HQ // ${meta.sub}`;
}

function paintBadges() {
  const n = store.get().pending.length;
  const b = $('#bell-badge');
  if (!b) return;
  b.hidden = !n;
  b.textContent = n;
  $$('.nav-item .badge, .tab .badge').forEach((x) => x.remove());
  if (n) $$('a[href="#/payments"]').forEach((a) => a.insertAdjacentHTML('beforeend', `<span class="badge">${n}</span>`));
}

function toggleBell() {
  const host = $('#bell-pop');
  if (host.innerHTML) { host.innerHTML = ''; return; }
  const list = store.get().pending;
  host.innerHTML = `<div class="popover">
    <div style="display:flex;align-items:center;padding:6px 8px 10px"><b>الإشعارات</b><span class="tag warn" style="margin-inline-start:auto">${list.length} معلّق</span></div>
    ${list.length ? list.map((r) => `<div class="pop-item" data-go>${avatar(r.profiles?.nickname, 34)}<div style="flex:1;min-width:0"><b style="font-size:14px">${esc(r.profiles?.nickname)}</b>
      <div class="faint" style="font-size:12.5px">طلب ${r.minutes} دقيقة · ${dzd(r.amount_dzd)}</div></div><span class="faint" style="font-size:12px">${ago(r.created_at)}</span></div>`).join('')
      : `<div class="empty" style="padding:26px">${icon('bell')}<span>لا إشعارات جديدة</span></div>`}
  </div>`;
  $$('[data-go]', host).forEach((el) => (el.onclick = () => { host.innerHTML = ''; go('payments'); }));
}

function openPalette() {
  if ($('.palette')) return;
  const host = document.createElement('div');
  host.innerHTML = `<div class="scrim"></div><div class="palette"><input placeholder="اذهب إلى صفحة أو ابحث عن عميل…" autofocus><div class="results"></div></div>`;
  $('#overlay').appendChild(host);
  const input = $('input', host), results = $('.results', host);
  let sel = 0, items = [];
  const close = () => host.remove();
  const paint = () => {
    const q = input.value.trim().toLowerCase();
    const pages = NAV.filter((n) => !q || n.label.includes(q)).map((n) => ({ label: n.label, ic: n.icon, run: () => go(n.id), hint: `Alt ${n.key}` }));
    const people = q.length < 1 ? [] : (window.__players || []).filter((p) => p.nickname.toLowerCase().includes(q) || (p.email || '').toLowerCase().includes(q))
      .slice(0, 6).map((p) => ({ label: p.nickname, sub: p.email, avatar: p.nickname, run: () => go('players', p.id) }));
    items = [...pages, ...people];
    sel = Math.min(sel, Math.max(0, items.length - 1));
    results.innerHTML = items.length ? items.map((it, i) => `<div class="pop-item ${i === sel ? 'sel' : ''}" data-i="${i}">
      ${it.avatar ? avatar(it.avatar, 30) : `<span class="chip-icon" style="width:30px;height:30px">${icon(it.ic)}</span>`}
      <div style="flex:1;min-width:0"><b style="font-size:14px">${esc(it.label)}</b>${it.sub ? `<div class="faint ltr" style="font-size:12px">${esc(it.sub)}</div>` : ''}</div>
      ${it.hint ? `<kbd>${it.hint}</kbd>` : ''}</div>`).join('') : '<div class="empty" style="padding:20px">لا نتائج</div>';
    $$('[data-i]', results).forEach((el) => (el.onclick = () => { close(); items[+el.dataset.i].run(); }));
  };
  input.oninput = () => { sel = 0; paint(); };
  input.onkeydown = (e) => {
    if (e.key === 'Escape') close();
    if (e.key === 'ArrowDown') { sel = Math.min(items.length - 1, sel + 1); paint(); e.preventDefault(); }
    if (e.key === 'ArrowUp') { sel = Math.max(0, sel - 1); paint(); e.preventDefault(); }
    if (e.key === 'Enter' && items[sel]) { close(); items[sel].run(); }
  };
  $('.scrim', host).onclick = close;
  paint();
  input.focus();
}
