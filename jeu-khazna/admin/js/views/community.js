// المجتمع: الرادار (المطابقة)، الأصدقاء، الدعوات، التحديات، والبلاغات مع قرارات المدير.
import { api, errorText } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, ago, avatar, num } from '../core/format.js';
import { countUp, dialog, emptyState, toast } from '../core/ui.js';
import { lineChart } from '../core/charts.js';

const REASON_AR = {
  insult: 'شتم أو إساءة',
  inappropriate: 'كلام غير لائق',
  cheat: 'غشّ أو تخريب',
  spam: 'إزعاج',
  other: 'سبب آخر',
};
const STATUS = { open: ['مفتوح', 'danger'], resolved: ['عولج', 'ok'], dismissed: ['مرفوض', ''] };

const kpi = (id, label, ic, tone, color, foot) => `
  <div class="card kpi" style="--kpi-glow:${color}">
    <div class="top"><span class="label">${label}</span><span class="chip-icon ${tone}">${icon(ic)}</span></div>
    <div class="value num" style="color:${color}"><span id="${id}">0</span></div>
    <div class="foot">${foot}</div>
  </div>`;

let filter = 'open';

export async function renderCommunity(page) {
  const [s, reports] = await Promise.all([api.matchStats(), api.reports(filter)]);
  const hours = Array.from({ length: 24 }, (_, h) => s.by_hour.find((x) => x.h === h)?.n || 0);
  page.innerHTML = `
  <div class="page-head">
    <div><h2>المجتمع والبلاغات</h2><p><span class="dot on"></span> ${s.queue_now} يبحثون على الرادار الآن</p></div>
    <div class="end"><button class="btn btn-sm" data-reload>${icon('refresh')} تحديث</button></div>
  </div>
  <div class="stack">
    <div class="kpis">
      ${kpi('k-q', 'على الرادار الآن', 'pulse', 'info', 'var(--info)', 'يبحثون عن شريك')}
      ${kpi('k-m', 'مطابقات 24 ساعة', 'users', '', 'var(--accent)', `متوسّط الانتظار <b class="num">${s.avg_wait_today}</b> ث · الأسبوع ${num(s.matches_week)}`)}
      ${kpi('k-r', 'دعوات ناجحة', 'gift', 'warn', 'var(--warn)', `${num(s.referrals)} سجّلوا بكود · ${num(s.friendships)} صداقة`)}
      ${kpi('k-o', 'بلاغات مفتوحة', 'flag', s.open_reports ? 'danger' : 'violet', s.open_reports ? 'var(--danger)' : 'var(--violet)',
        `تحديات مُطالَب بها اليوم: <b class="num">${num(s.challenges_claimed_today)}</b>`)}
    </div>
    <div class="card">
      <div class="card-head"><span class="chip-icon info">${icon('clock')}</span><div><h3>ساعات الذروة على الرادار</h3><p>المطابقات حسب الساعة (توقيت الجزائر) · آخر 7 أيام</p></div></div>
      <div class="card-body"><div class="chart-box" style="height:220px"><canvas id="c-hours"></canvas></div></div>
    </div>
    <div class="card">
      <div class="card-head"><span class="chip-icon danger">${icon('flag')}</span><div><h3>البلاغات</h3><p>قرارك يُطبَّق فوراً · الحظر يمنع الدخول نهائياً</p></div>
        <div class="end seg">${['open', 'resolved', 'dismissed', ''].map((f) => `<button class="btn btn-sm ${f === filter ? '' : 'btn-ghost'}" data-f="${f}">${f ? STATUS[f][0] : 'الكل'}</button>`).join('')}</div></div>
      <div class="table-wrap"><table class="table"><thead><tr><th>المُبلَّغ عنه</th><th>السبب</th><th>المُبلِّغ</th><th>الحالة</th><th>الوقت</th><th></th></tr></thead>
      <tbody>${reports.length ? reports.map((r) => `
        <tr>
          <td><div style="display:flex;align-items:center;gap:8px">${avatar(r.reported_nick, 30)}<div><b>${esc(r.reported_nick)}</b>
            <div class="faint" style="font-size:12px">${r.against_count} بلاغ ضدّه${r.reported_banned ? ' · <span class="tag danger">موقوف</span>' : ''}</div></div></div></td>
          <td><b>${esc(REASON_AR[r.reason] || r.reason)}</b>${r.details ? `<div class="faint" style="font-size:12px;max-width:260px">${esc(r.details)}</div>` : ''}</td>
          <td>${esc(r.reporter_nick)}</td>
          <td><span class="tag ${STATUS[r.status]?.[1] || ''}">${STATUS[r.status]?.[0] || r.status}</span></td>
          <td class="faint">${ago(r.created_at)}</td>
          <td>${r.status === 'open' ? `<div style="display:flex;gap:6px;justify-content:flex-end">
            <button class="btn btn-sm" data-act="resolved" data-id="${r.id}" title="عولج">${icon('check')}</button>
            <button class="btn btn-sm btn-ghost" data-act="dismissed" data-id="${r.id}" title="رفض البلاغ">${icon('x')}</button>
            ${r.reported_banned ? '' : `<button class="btn btn-sm btn-danger" data-act="ban" data-id="${r.id}" data-nick="${esc(r.reported_nick)}">${icon('ban')} إيقاف</button>`}
          </div>` : ''}</td>
        </tr>`).join('') : `<tr><td colspan="6">${emptyState('flag', 'لا بلاغات هنا', 'مجتمعك هادئ 👌')}</td></tr>`}</tbody></table></div>
    </div>
  </div>`;

  countUp(page.querySelector('#k-q'), s.queue_now);
  countUp(page.querySelector('#k-m'), s.matches_today);
  countUp(page.querySelector('#k-r'), s.referrals_rewarded);
  countUp(page.querySelector('#k-o'), s.open_reports);
  lineChart(page.querySelector('#c-hours'), hours.map((_, h) => `${h}h`), hours, '#22c7ff', { bar: true });

  page.querySelector('[data-reload]').onclick = () => renderCommunity(page);
  page.querySelectorAll('[data-f]').forEach((b) => (b.onclick = () => { filter = b.dataset.f; renderCommunity(page); }));
  page.querySelectorAll('[data-act]').forEach((b) => (b.onclick = async () => {
    const id = Number(b.dataset.id);
    const ban = b.dataset.act === 'ban';
    if (ban) {
      const yes = await dialog({ title: `إيقاف ${b.dataset.nick}؟`, body: 'يُغلق حسابه ولا يستطيع اللعب. يمكنك رفع الإيقاف من صفحة العملاء.', confirm: 'إيقاف', tone: 'danger' });
      if (!yes) return;
    }
    try {
      await api.resolveReport(id, ban ? 'resolved' : b.dataset.act, ban);
      toast(ban ? 'أُوقف الحساب وعولج البلاغ' : 'تمّ');
      renderCommunity(page);
    } catch (e) {
      toast(errorText(e), 'err');
    }
  }));
  return { title: 'المجتمع والبلاغات', sub: 'COMMUNITY' };
}
