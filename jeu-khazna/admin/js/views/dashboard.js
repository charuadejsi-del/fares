import { api } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, minutes, dzd, ago, avatar, dayLabel, signed } from '../core/format.js';
import { $, countUp, emptyState } from '../core/ui.js';
import { lineChart, ringChart, stackedBars } from '../core/charts.js';
import { REASONS } from '../core/config.js';
import { go } from '../core/router.js';

const kpi = (id, label, ic, tone, color, foot, spark = false) => `
  <div class="card kpi" style="--kpi-glow:${color}">
    <div class="top"><span class="label">${label}</span><span class="chip-icon ${tone}">${icon(ic)}</span></div>
    <div class="value num" style="color:${color}"><span id="${id}">0</span></div>
    <div class="foot">${foot}</div>
    ${spark ? `<canvas class="spark" id="${id}-spark"></canvas>` : ''}
  </div>`;

export async function renderDashboard(page) {
  const [s, feed] = await Promise.all([api.stats(), api.ledger({ limit: 10 })]);
  const days = s.new_per_day.map((d) => dayLabel(d.day));
  const inactive = Math.max(0, s.players_total - s.active_7d);
  const todayNew = s.new_per_day.at(-1)?.n || 0;
  const week = (arr) => arr.slice(-7).reduce((a, d) => a + d.n, 0);
  const prevWeek = (arr) => arr.slice(0, 7).reduce((a, d) => a + d.n, 0);
  const trend = (a, b) => (b === 0 ? (a > 0 ? '+100%' : '0%') : `${a >= b ? '+' : ''}${Math.round(((a - b) / b) * 100)}%`);

  page.innerHTML = `
  <div class="page-head">
    <div><h2>نظرة عامة</h2><p>آخر تحديث ${new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' })}</p></div>
    <div class="end"><a class="btn btn-sm" href="#/rooms">${icon('rooms')} الغرف الحيّة</a><button class="btn btn-sm btn-ghost" data-reload>${icon('refresh')} تحديث</button></div>
  </div>
  <div class="stack">
    <div class="kpis">
      ${kpi('k-players', 'إجمالي العملاء', 'users', '', 'var(--accent)', `<span class="tag ok">+${todayNew} اليوم</span>`, true)}
      ${kpi('k-online', 'متصل الآن', 'pulse', 'info', 'var(--info)', `<span class="dot on"></span> مباشر · ${s.active_24h} نشط اليوم`)}
      ${kpi('k-revenue', 'أرباح اليوم', 'coin', 'warn', 'var(--warn)', `الشهر: <b class="num" style="color:var(--text-2)">${dzd(s.revenue_month)}</b>`, true)}
      ${kpi('k-pending', 'طلبات معلّقة', 'card', s.pending_payments ? 'danger' : 'violet', s.pending_payments ? 'var(--danger)' : 'var(--violet)',
        s.pending_payments ? `<a class="tag danger" href="#/payments">راجعها الآن ←</a>` : 'لا شيء ينتظرك')}
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head"><span class="chip-icon">${icon('trend')}</span><div><h3>نموّ العملاء</h3><p>تسجيلات آخر 14 يوماً</p></div>
          <div class="end"><span class="tag ${week(s.new_per_day) >= prevWeek(s.new_per_day) ? 'ok' : 'danger'}">${trend(week(s.new_per_day), prevWeek(s.new_per_day))} أسبوعياً</span></div></div>
        <div class="card-body"><div class="chart-box"><canvas id="c-growth"></canvas></div></div>
      </div>
      <div class="card">
        <div class="card-head"><span class="chip-icon info">${icon('pulse')}</span><div><h3>نشاط العملاء</h3><p>حسب آخر دخول</p></div></div>
        <div class="card-body">
          <div class="chart-box" style="height:190px"><canvas id="c-ring"></canvas></div>
          <div class="ring-legend">
            <div><b class="num" style="color:var(--accent)">${s.active_24h}</b><span>24 ساعة</span></div>
            <div><b class="num" style="color:var(--info)">${Math.max(0, s.active_7d - s.active_24h)}</b><span>هذا الأسبوع</span></div>
            <div><b class="num faint">${inactive}</b><span>غير نشط</span></div>
          </div>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="card">
        <div class="card-head"><span class="chip-icon warn">${icon('coin')}</span><div><h3>الأرباح اليومية</h3><p>بالدينار — آخر 14 يوماً</p></div>
          <div class="end"><span class="tag warn">${dzd(week(s.revenue_per_day))} / 7 أيام</span></div></div>
        <div class="card-body"><div class="chart-box"><canvas id="c-revenue"></canvas></div></div>
      </div>
      <div class="card">
        <div class="card-head"><span class="chip-icon violet">${icon('activity')}</span><div><h3>آخر الحركات</h3><p>الوقت المضاف والمخصوم</p></div>
          <div class="end"><a class="btn btn-sm btn-ghost" href="#/activity">الكل</a></div></div>
        <div class="card-body">
          ${feed.length ? feed.map((e) => {
            const [label, tone] = REASONS[e.reason] || [e.reason, ''];
            return `<div class="feed-item" data-user="${e.user_id}" style="cursor:pointer">${avatar(e.profiles?.nickname, 32)}
              <div class="who"><b>${esc(e.profiles?.nickname)}</b> <span class="tag ${tone}">${label}</span></div>
              <span class="delta ${e.delta_seconds >= 0 ? 'pos' : 'neg'}">${signed(minutes(e.delta_seconds))}د</span>
              <span class="when">${ago(e.created_at)}</span></div>`;
          }).join('') : emptyState('activity', 'لا حركات بعد')}
        </div>
      </div>
    </div>

    <div class="card">
      <div class="card-head"><span class="chip-icon danger">${icon('flag')}</span><div><h3>المراحل الأصعب</h3><p>حيث يخسر العملاء أكثر — لضبط الوقت أو الصعوبة</p></div>
        <div class="end"><a class="btn btn-sm btn-ghost" href="#/settings">ضبط الأوقات</a></div></div>
      <div class="card-body">${s.stuck_stages.length
        ? `<div class="chart-box" style="height:${Math.max(180, s.stuck_stages.length * 36)}px"><canvas id="c-stuck"></canvas></div>`
        : emptyState('flag', 'لا بيانات بعد', 'تظهر بعد تفعيل العداد في الخادم')}</div>
    </div>
  </div>`;

  page.querySelector('[data-reload]').onclick = () => renderDashboard(page);
  page.querySelectorAll('[data-user]').forEach((el) => (el.onclick = () => go('players', el.dataset.user)));

  countUp($('#k-players', page), s.players_total);
  countUp($('#k-online', page), s.online_now);
  countUp($('#k-revenue', page), s.revenue_today, dzd);
  countUp($('#k-pending', page), s.pending_payments);
  lineChart($('#k-players-spark', page), days, s.new_per_day.map((d) => d.n), '#00ffa3', { spark: true });
  lineChart($('#k-revenue-spark', page), days, s.revenue_per_day.map((d) => d.n), '#ffb547', { spark: true });
  lineChart($('#c-growth', page), days, s.new_per_day.map((d) => d.n), '#00ffa3', { unit: ' عميل' });
  lineChart($('#c-revenue', page), days, s.revenue_per_day.map((d) => d.n), '#ffb547', { bar: true, unit: ' دج' });
  ringChart($('#c-ring', page), ['نشط اليوم', 'نشط هذا الأسبوع', 'غير نشط'],
    [s.active_24h, Math.max(0, s.active_7d - s.active_24h), inactive], ['#00ffa3', '#22c7ff', '#1b2a2b']);
  if (s.stuck_stages.length)
    stackedBars($('#c-stuck', page), s.stuck_stages.map((x) => `المرحلة ${x.stage}`), [
      { label: 'خسارة / انسحاب', data: s.stuck_stages.map((x) => x.fails), backgroundColor: '#ff4d6ab0' },
      { label: 'فوز', data: s.stuck_stages.map((x) => x.wins), backgroundColor: '#00ffa380' },
    ]);
  return { title: 'مركز القيادة', sub: 'OVERVIEW' };
}
