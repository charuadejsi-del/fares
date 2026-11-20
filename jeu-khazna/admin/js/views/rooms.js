import { api } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc, ago, avatar } from '../core/format.js';
import { emptyState } from '../core/ui.js';

export async function renderRooms(page) {
  const rooms = await api.rooms();
  const playing = rooms.filter((r) => r.status === 'playing').length;
  page.innerHTML = `
  <div class="page-head">
    <div><h2>الغرف الحيّة</h2><p><span class="dot on"></span> ${rooms.length} غرفة مفتوحة · ${playing} قيد اللعب</p></div>
    <div class="end"><button class="btn btn-sm" data-reload>${icon('refresh')} تحديث</button></div>
  </div>
  ${rooms.length ? `<div class="room-grid">${rooms.map((r) => `
    <article class="card room">
      <div style="display:flex;align-items:center;justify-content:space-between"><span class="code ltr">${esc(r.code)}</span>
        <span class="tag ${r.status === 'playing' ? 'ok' : 'warn'}">${r.status === 'playing' ? '<span class="dot on"></span>يلعبون' : 'في الانتظار'}</span></div>
      <div class="faint" style="font-size:13px">${r.stage ? `المرحلة <b class="mono" style="color:var(--info)">${r.stage}</b> · ` : ''}${ago(r.updated_at)}</div>
      <div class="versus">${avatar(r.host, 32)}<b>${esc(r.host)}</b><span class="faint">×</span>${r.guest ? `${avatar(r.guest, 32)}<b>${esc(r.guest)}</b>` : '<span class="faint">بانتظار شريك…</span>'}</div>
    </article>`).join('')}</div>`
    : `<div class="card">${emptyState('rooms', 'لا توجد غرف مفتوحة الآن', 'تُسجَّل الغرف في الخادم مع مرحلة العداد')}</div>`}`;
  page.querySelector('[data-reload]').onclick = () => renderRooms(page);
  return { title: 'الغرف الحيّة', sub: 'LIVE ROOMS' };
}
