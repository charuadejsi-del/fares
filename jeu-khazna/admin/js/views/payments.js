import { api, errorText } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, dzd, num, ago, dateTime, avatar } from '../core/format.js';
import { $$, toast, dialog, zoomImage, emptyState } from '../core/ui.js';

let tab = 'pending';
const TABS = [['pending', 'في الانتظار'], ['approved', 'مقبولة'], ['rejected', 'مرفوضة']];
const STATUS = { pending: ['في الانتظار', 'warn'], approved: ['مقبول', 'ok'], rejected: ['مرفوض', 'danger'] };

export async function renderPayments(page, _param, ctx) {
  const all = await api.payments();
  const of = (s) => all.filter((r) => r.status === s);
  const sum = (s) => of(s).reduce((a, r) => a + r.amount_dzd, 0);
  const list = of(tab);
  page.innerHTML = `
  <div class="page-head"><div><h2>المدفوعات</h2><p>طلبات بريدي موب — راجع المبلغ في حسابك قبل القبول</p></div></div>
  <div class="stack">
    <div class="kpis">
      <div class="card kpi" style="--kpi-glow:var(--warn)"><div class="top"><span class="label">في الانتظار</span><span class="chip-icon warn">${icon('clock')}</span></div>
        <div class="value num" style="color:var(--warn)">${of('pending').length}</div><div class="foot">${dzd(sum('pending'))}</div></div>
      <div class="card kpi" style="--kpi-glow:var(--accent)"><div class="top"><span class="label">مقبولة</span><span class="chip-icon">${icon('check')}</span></div>
        <div class="value num" style="color:var(--accent)">${of('approved').length}</div><div class="foot">${dzd(sum('approved'))} إجمالاً</div></div>
      <div class="card kpi" style="--kpi-glow:var(--danger)"><div class="top"><span class="label">مرفوضة</span><span class="chip-icon danger">${icon('x')}</span></div>
        <div class="value num" style="color:var(--danger)">${of('rejected').length}</div><div class="foot">${dzd(sum('rejected'))}</div></div>
      <div class="card kpi" style="--kpi-glow:var(--info)"><div class="top"><span class="label">متوسّط الطلب</span><span class="chip-icon info">${icon('coin')}</span></div>
        <div class="value num" style="color:var(--info)">${num(of('approved').length ? Math.round(sum('approved') / of('approved').length) : 0)}<span class="unit">دج</span></div><div class="foot">للطلبات المقبولة</div></div>
    </div>
    <div class="segmented" id="tabs">${TABS.map(([k, l]) => `<button data-t="${k}" class="${tab === k ? 'active' : ''}">${l}<span class="count">${of(k).length}</span></button>`).join('')}</div>
    ${list.length ? `<div class="pay-grid">${list.map((r) => {
      const [label, tone] = STATUS[r.status];
      return `<article class="card pay-card ${r.status}">
        <div class="person">${avatar(r.profiles?.nickname, 40)}<div class="meta" style="flex:1"><b>${esc(r.profiles?.nickname)}</b><small>${dateTime(r.created_at)} · ${ago(r.created_at)}</small></div><span class="tag ${tone}">${label}</span></div>
        <div class="receipt" data-path="${esc(r.receipt_path || '')}">${r.receipt_path ? icon('image') : '<span>بلا صورة وصل</span>'}</div>
        <div style="display:flex;align-items:flex-end;justify-content:space-between;gap:10px">
          <div class="amount num">${num(r.amount_dzd)} <small>دج</small></div><span class="tag info">${icon('clock', 'width="13" height="13"')} ${r.minutes} دقيقة</span></div>
        <div class="ref-box"><span class="faint" style="font-size:12.5px">رقم العملية</span>
          <span style="display:flex;align-items:center;gap:6px"><b class="mono ltr">${esc(r.transaction_ref)}</b><button class="btn btn-ghost btn-sm" data-copy="${esc(r.transaction_ref)}" aria-label="نسخ">${icon('copy')}</button></span></div>
        ${r.status === 'pending'
          ? `<div style="display:flex;gap:8px"><button class="btn btn-primary" style="flex:1" data-ok="${r.id}">${icon('check')} قبول</button><button class="btn btn-danger" style="flex:1" data-no="${r.id}">${icon('x')} رفض</button></div>`
          : r.admin_note ? `<div class="faint" style="font-size:13px">ملاحظة: ${esc(r.admin_note)}</div>` : ''}
      </article>`;
    }).join('')}</div>` : `<div class="card">${emptyState('card', tab === 'pending' ? 'لا توجد طلبات تنتظرك' : 'لا شيء هنا')}</div>`}
  </div>`;

  $$('#tabs button', page).forEach((b) => (b.onclick = () => { tab = b.dataset.t; renderPayments(page, null, ctx); }));
  $$('[data-copy]', page).forEach((b) => (b.onclick = () => navigator.clipboard?.writeText(b.dataset.copy).then(() => toast('نُسخ رقم العملية'))));
  $$('.receipt[data-path]', page).forEach((el) => {
    if (!el.dataset.path) return;
    api.receiptUrl(el.dataset.path).then((url) => {
      el.style.backgroundImage = `url("${url}")`;
      el.innerHTML = '';
      el.onclick = () => zoomImage(url);
    }).catch(() => {});
  });
  const review = async (id, approve) => {
    const r = all.find((x) => x.id === id);
    let note = null;
    if (approve) {
      const yes = await dialog({
        title: 'تأكيد قبول الدفع',
        body: `هل وصل <b style="color:var(--warn)">${dzd(r.amount_dzd)}</b> فعلاً إلى حسابك برقم العملية <b class="mono ltr">${esc(r.transaction_ref)}</b>؟<br>ستُضاف <b>${r.minutes} دقيقة</b> للعميل <b>${esc(r.profiles?.nickname)}</b> ولا يمكن التراجع.`,
        confirm: 'نعم، وصل المبلغ',
      });
      if (!yes) return;
    } else {
      note = await dialog({ title: 'رفض الطلب', input: { label: 'سبب الرفض (يراه العميل)', placeholder: 'مثلاً: رقم العملية غير موجود' }, confirm: 'رفض', tone: 'danger' });
      if (note === null) return;
    }
    try {
      await api.reviewPayment(id, approve, note);
      toast(approve ? `قُبل — أُضيفت ${r.minutes} دقيقة` : 'رُفض الطلب');
      await ctx.refreshPending();
      renderPayments(page, null, ctx);
    } catch (e) { toast(errorText(e), 'err'); }
  };
  $$('[data-ok]', page).forEach((b) => (b.onclick = () => review(b.dataset.ok, true)));
  $$('[data-no]', page).forEach((b) => (b.onclick = () => review(b.dataset.no, false)));
  return { title: 'المدفوعات', sub: 'PAYMENTS' };
}
