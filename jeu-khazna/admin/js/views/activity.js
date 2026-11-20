import { api } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, minutes, num, dateTime, avatar, signed, downloadCsv } from '../core/format.js';
import { $, $$, emptyState } from '../core/ui.js';
import { REASONS } from '../core/config.js';
import { go } from '../core/router.js';

let reason = '';

export async function renderActivity(page) {
  const rows = await api.ledger({ reason: reason || undefined, limit: 300 });
  const plus = rows.filter((r) => r.delta_seconds > 0).reduce((a, r) => a + r.delta_seconds, 0);
  const minus = rows.filter((r) => r.delta_seconds < 0).reduce((a, r) => a - r.delta_seconds, 0);
  page.innerHTML = `
  <div class="page-head">
    <div><h2>سجلّ الحركات</h2><p>كل دقيقة أُضيفت أو خُصمت — مرجع للتدقيق</p></div>
    <div class="end"><button class="btn btn-sm" data-export>${icon('download')} تصدير CSV</button></div>
  </div>
  <div class="stack">
    <div class="kpis" style="grid-template-columns:repeat(3,minmax(0,1fr))">
      <div class="card kpi"><div class="top"><span class="label">الحركات</span><span class="chip-icon violet">${icon('activity')}</span></div><div class="value num">${num(rows.length)}</div></div>
      <div class="card kpi"><div class="top"><span class="label">أُضيف</span><span class="chip-icon">${icon('plus')}</span></div><div class="value num pos">${num(minutes(plus))}<span class="unit">د</span></div></div>
      <div class="card kpi"><div class="top"><span class="label">خُصم</span><span class="chip-icon danger">${icon('clock')}</span></div><div class="value num neg">${num(minutes(minus))}<span class="unit">د</span></div></div>
    </div>
    <div class="card">
      <div class="toolbar"><select class="input" id="reason" style="width:auto;min-width:200px">
        <option value="">كل الأنواع</option>${Object.entries(REASONS).map(([k, [l]]) => `<option value="${k}">${l}</option>`).join('')}</select>
        <span class="faint" style="font-size:12.5px">آخر 300 حركة</span></div>
      <div class="table-wrap"><table class="table"><thead><tr><th>العميل</th><th>النوع</th><th>التغيير</th><th>ملاحظة</th><th>الوقت</th></tr></thead>
      <tbody>${rows.length ? rows.map((r) => {
        const [label, tone] = REASONS[r.reason] || [r.reason, ''];
        return `<tr class="row-link" data-user="${r.user_id}">
          <td><div class="person">${avatar(r.profiles?.nickname, 30)}<div class="meta"><b>${esc(r.profiles?.nickname)}</b></div></div></td>
          <td><span class="tag ${tone}">${label}</span></td>
          <td class="mono ${r.delta_seconds >= 0 ? 'pos' : 'neg'}" style="font-weight:700">${signed(minutes(r.delta_seconds))}د</td>
          <td class="muted" style="max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${r.reason === 'admin' || r.reason === 'purchase' ? esc(r.ref || '') : ''}</td>
          <td class="faint" style="white-space:nowrap">${dateTime(r.created_at)}</td></tr>`;
      }).join('') : `<tr><td colspan="5">${emptyState('activity', 'لا حركات')}</td></tr>`}</tbody></table></div>
    </div>
  </div>`;
  $('#reason', page).value = reason;
  $('#reason', page).onchange = (e) => { reason = e.target.value; renderActivity(page); };
  $$('[data-user]', page).forEach((el) => (el.onclick = () => go('players', el.dataset.user)));
  $('[data-export]', page).onclick = () =>
    downloadCsv(`khazna-activity-${new Date().toISOString().slice(0, 10)}.csv`, [
      ['العميل', 'النوع', 'الدقائق', 'ملاحظة', 'الوقت'],
      ...rows.map((r) => [r.profiles?.nickname, (REASONS[r.reason] || [r.reason])[0], minutes(r.delta_seconds), r.ref || '', dateTime(r.created_at)]),
    ]);
  return { title: 'السجلّ', sub: 'AUDIT LOG' };
}
