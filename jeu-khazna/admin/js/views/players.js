import { api, errorText } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, minutes, num, ago, date, dateTime, avatar, signed, downloadCsv } from '../core/format.js';
import { $, $$, toast, dialog, sheet, emptyState } from '../core/ui.js';
import { LOW_BALANCE_SECONDS, REASONS } from '../core/config.js';
import { go } from '../core/router.js';

const state = { list: [], q: '', filter: 'all', sort: 'new' };
const FILTERS = [['all', 'الكل'], ['online', 'متصل'], ['new', 'جدد'], ['low', 'رصيد ضعيف'], ['banned', 'محظور']];
const SORTS = { new: 'الأحدث تسجيلاً', seen: 'آخر دخول', balance: 'الأعلى رصيداً', stage: 'الأعلى مرحلة' };

function filtered() {
  const q = state.q.trim().toLowerCase();
  const week = Date.now() - 7 * 864e5;
  const by = {
    new: (a, b) => new Date(b.created_at) - new Date(a.created_at),
    seen: (a, b) => new Date(b.last_seen) - new Date(a.last_seen),
    balance: (a, b) => b.balance_seconds - a.balance_seconds,
    stage: (a, b) => b.best_stage - a.best_stage,
  };
  return state.list
    .filter((p) => !q || p.nickname.toLowerCase().includes(q) || (p.email || '').toLowerCase().includes(q))
    .filter((p) => ({
      all: true, online: p.online, banned: p.banned, low: p.balance_seconds < LOW_BALANCE_SECONDS, new: new Date(p.created_at) > week,
    })[state.filter])
    .sort(by[state.sort]);
}

const statusTag = (p) =>
  p.banned ? '<span class="tag danger">محظور</span>'
    : p.online ? '<span class="tag ok"><span class="dot on"></span>متصل</span>'
      : `<span class="tag">${ago(p.last_seen)}</span>`;

export async function renderPlayers(page, param) {
  state.list = await api.players();
  window.__players = state.list;
  const count = (k) => state.list.filter((p) => ({ all: true, online: p.online, banned: p.banned, low: p.balance_seconds < LOW_BALANCE_SECONDS, new: new Date(p.created_at) > Date.now() - 7 * 864e5 })[k]).length;
  const totalMin = minutes(state.list.reduce((a, p) => a + p.balance_seconds, 0));
  page.innerHTML = `
  <div class="page-head">
    <div><h2>العملاء</h2><p>${num(state.list.length)} حساباً · ${num(totalMin)} دقيقة في الأرصدة</p></div>
    <div class="end"><button class="btn btn-sm" data-export>${icon('download')} تصدير CSV</button></div>
  </div>
  <div class="card">
    <div class="toolbar">
      <div class="grow input-wrap">${icon('search')}<input class="input" id="q" placeholder="ابحث بالاسم أو البريد…" value="${esc(state.q)}"></div>
      <select class="input" id="sort" style="width:auto">${Object.entries(SORTS).map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}</select>
    </div>
    <div class="toolbar" style="padding-top:12px">
      <div class="segmented" id="filters">${FILTERS.map(([k, l]) => `<button data-f="${k}" class="${state.filter === k ? 'active' : ''}">${l}<span class="count">${count(k)}</span></button>`).join('')}</div>
    </div>
    <div class="table-wrap players-table"><table class="table"><thead><tr>
      <th>العميل</th><th>الحالة</th><th>الرصيد</th><th>أعلى مرحلة</th><th>التسجيل</th></tr></thead><tbody id="rows"></tbody></table></div>
    <div class="player-cards" id="cards"></div>
  </div>`;
  $('#sort', page).value = state.sort;
  $('#q', page).oninput = (e) => { state.q = e.target.value; draw(page); };
  $('#sort', page).onchange = (e) => { state.sort = e.target.value; draw(page); };
  $$('#filters button', page).forEach((b) => (b.onclick = () => {
    state.filter = b.dataset.f;
    $$('#filters button', page).forEach((x) => x.classList.toggle('active', x === b));
    draw(page);
  }));
  $('[data-export]', page).onclick = () =>
    downloadCsv(`khazna-clients-${new Date().toISOString().slice(0, 10)}.csv`, [
      ['الاسم', 'البريد', 'الرصيد (دقيقة)', 'أعلى مرحلة', 'محظور', 'التسجيل', 'آخر دخول'],
      ...filtered().map((p) => [p.nickname, p.email, minutes(p.balance_seconds), p.best_stage, p.banned ? 'نعم' : 'لا', date(p.created_at), dateTime(p.last_seen)]),
    ]);
  draw(page);
  if (param) openPlayer(param, page);
  return { title: 'العملاء', sub: 'CLIENTS' };
}

function draw(page) {
  const list = filtered();
  const max = Math.max(6000, ...state.list.map((p) => p.balance_seconds));
  const meter = (p) => `<div class="meter" style="margin-top:6px"><i class="${p.balance_seconds < LOW_BALANCE_SECONDS ? 'low' : ''}" style="width:${Math.max(3, Math.min(100, (p.balance_seconds / max) * 100))}%"></i></div>`;
  const role = (p) => (p.role === 'admin' ? ' <span class="tag warn">مدير</span>' : '');
  $('#rows', page).innerHTML = list.length ? list.map((p) => `
    <tr class="row-link" data-id="${p.id}">
      <td><div class="person">${avatar(p.nickname)}<div class="meta"><b>${esc(p.nickname)}${role(p)}</b><small class="ltr">${esc(p.email)}</small></div></div></td>
      <td>${statusTag(p)}</td>
      <td style="min-width:150px"><b class="num">${num(minutes(p.balance_seconds))}</b> <span class="faint">دقيقة</span>${meter(p)}</td>
      <td><span class="tag info mono">${p.best_stage || '—'}</span></td>
      <td class="muted">${date(p.created_at)}</td>
    </tr>`).join('') : `<tr><td colspan="5">${emptyState('users', 'لا نتائج', 'غيّر البحث أو التصفية')}</td></tr>`;
  $('#cards', page).innerHTML = list.length ? list.map((p) => `
    <div class="pcard" data-id="${p.id}">
      <div class="row">${avatar(p.nickname, 42)}<div class="person" style="flex:1;min-width:0"><div class="meta"><b>${esc(p.nickname)}${role(p)}</b><small class="ltr">${esc(p.email)}</small></div></div>
        <div class="bal"><b class="num">${num(minutes(p.balance_seconds))}</b><div class="faint" style="font-size:11.5px">دقيقة</div></div></div>
      ${meter(p)}
      <div class="row">${statusTag(p)}<span class="tag info">المرحلة ${p.best_stage || '—'}</span><span class="faint" style="margin-inline-start:auto;font-size:12px">${date(p.created_at)}</span></div>
    </div>`).join('') : emptyState('users', 'لا نتائج', 'غيّر البحث أو التصفية');
  $$('[data-id]', page).forEach((el) => (el.onclick = () => go('players', el.dataset.id)));
}

async function openPlayer(id, page) {
  const p = state.list.find((x) => x.id === id);
  if (!p) return toast('العميل غير موجود', 'err');
  const { body, close } = sheet({ title: 'ملف العميل', subtitle: p.email, onClose: () => location.hash.includes(id) && history.replaceState(null, '', '#/players') });
  let ledger = [];
  try { ledger = await api.ledger({ user: id, limit: 50 }); } catch (e) { toast(errorText(e), 'err'); }
  const spent = ledger.filter((l) => l.delta_seconds < 0).reduce((a, l) => a - l.delta_seconds, 0);
  const bought = ledger.filter((l) => l.reason === 'purchase').reduce((a, l) => a + l.delta_seconds, 0);
  body.innerHTML = `
    <div class="profile-hero">${avatar(p.nickname, 60)}<div style="min-width:0">
      <h3 style="font-size:20px">${esc(p.nickname)}</h3>
      <div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px">${statusTag(p)}${p.role === 'admin' ? '<span class="tag warn">مدير</span>' : ''}<span class="tag">منذ ${date(p.created_at)}</span></div>
    </div></div>
    <div class="stat-trio">
      <div><b class="num" style="color:var(--accent)">${num(minutes(p.balance_seconds))}</b><span>دقيقة رصيد</span></div>
      <div><b class="num" style="color:var(--warn)">${num(minutes(bought))}</b><span>دقيقة مشتراة</span></div>
      <div><b class="num" style="color:var(--info)">${num(minutes(spent))}</b><span>دقيقة مستهلكة</span></div>
    </div>
    <div class="card card-pad" style="display:grid;gap:12px">
      <div style="display:flex;align-items:center;gap:10px"><span class="chip-icon">${icon('clock')}</span><b>تعديل الرصيد</b></div>
      <div class="quick-grid">
        ${[10, 30, 60, 120].map((n) => `<button data-d="${n}">+${n}</button>`).join('')}
        ${[-10, -30, -60].map((n) => `<button class="minus" data-d="${n}">−${-n}</button>`).join('')}
        <button data-d="custom" style="font-family:var(--font);font-size:13px;color:var(--text-2)">مخصّص</button>
      </div>
    </div>
    ${p.role === 'admin' ? '' : `<button class="btn ${p.banned ? 'btn-primary' : 'btn-danger'} btn-block" data-ban>${icon('ban')} ${p.banned ? 'رفع الحظر' : 'حظر هذا العميل'}</button>`}
    <div>
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:6px"><span class="chip-icon violet">${icon('activity')}</span><b>سجلّ الوقت</b><span class="faint" style="margin-inline-start:auto;font-size:12px">${ledger.length} حركة</span></div>
      ${ledger.length ? ledger.map((l) => {
        const [label, tone] = REASONS[l.reason] || [l.reason, ''];
        return `<div class="ledger-row"><span class="tag ${tone}">${label}</span>${l.ref && l.reason === 'admin' ? `<span class="faint" style="font-size:12.5px">${esc(l.ref)}</span>` : ''}
          <span class="delta ${l.delta_seconds >= 0 ? 'pos' : 'neg'}">${signed(minutes(l.delta_seconds))}د</span><time>${dateTime(l.created_at)}</time></div>`;
      }).join('') : emptyState('activity', 'لا حركات')}
    </div>`;

  const refresh = async () => { close(); state.list = await api.players(); draw(page); go('players', id); };
  $$('[data-d]', body).forEach((b) => (b.onclick = async () => {
    let n = b.dataset.d;
    if (n === 'custom') {
      n = await dialog({ title: 'تعديل مخصّص', input: { label: 'عدد الدقائق (سالب للخصم)', type: 'number', placeholder: 'مثلاً 45 أو -20' }, confirm: 'متابعة' });
      if (n === null) return;
    }
    n = parseInt(n, 10);
    if (!n) return toast('رقم غير صحيح', 'err');
    const note = await dialog({
      title: `${n > 0 ? 'إضافة' : 'خصم'} ${Math.abs(n)} دقيقة`, body: `للعميل <b>${esc(p.nickname)}</b>`,
      input: { label: 'السبب (يُحفظ في السجل)', placeholder: 'مثلاً: تعويض انقطاع' }, confirm: n > 0 ? 'إضافة' : 'خصم', tone: n > 0 ? 'primary' : 'danger',
    });
    if (note === null) return;
    try {
      const bal = await api.adjustTime(id, n * 60, note);
      toast(`الرصيد الآن ${num(minutes(bal))} دقيقة`);
      refresh();
    } catch (e) { toast(errorText(e), 'err'); }
  }));
  const ban = $('[data-ban]', body);
  if (ban) ban.onclick = async () => {
    const yes = await dialog({
      title: p.banned ? 'رفع الحظر؟' : 'حظر العميل؟',
      body: p.banned ? `سيستطيع <b>${esc(p.nickname)}</b> الدخول للعبة مجدداً.` : `لن يستطيع <b>${esc(p.nickname)}</b> الدخول للعبة حتى ترفع الحظر.`,
      confirm: p.banned ? 'رفع الحظر' : 'حظر', tone: p.banned ? 'primary' : 'danger',
    });
    if (!yes) return;
    try { await api.setBanned(id, !p.banned); toast(p.banned ? 'رُفع الحظر' : 'تم الحظر'); refresh(); } catch (e) { toast(errorText(e), 'err'); }
  };
}
