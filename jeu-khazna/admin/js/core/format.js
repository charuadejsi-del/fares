// تنسيق الأرقام والتواريخ والنصوص.
export const esc = (s) =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);

export const minutes = (sec) => Math.floor((sec || 0) / 60);
export const num = (n) => Number(n || 0).toLocaleString('fr-FR');
export const dzd = (n) => `${num(n)} دج`;
export const signed = (n) => `${n > 0 ? '+' : n < 0 ? '−' : ''}${num(Math.abs(n))}`;

export const date = (d) =>
  d ? new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—';
export const dateTime = (d) =>
  d ? new Date(d).toLocaleString('fr-FR', { day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit' }) : '—';
export const dayLabel = (d) => new Date(d).toLocaleDateString('fr-FR', { day: '2-digit', month: '2-digit' });

export function ago(d) {
  if (!d) return '—';
  const s = (Date.now() - new Date(d).getTime()) / 1000;
  if (s < 60) return 'الآن';
  if (s < 3600) return `منذ ${Math.floor(s / 60)} د`;
  if (s < 86400) return `منذ ${Math.floor(s / 3600)} سا`;
  if (s < 86400 * 30) return `منذ ${Math.floor(s / 86400)} يوم`;
  return date(d);
}

const HUES = ['#00ffa3', '#22c7ff', '#ffb547', '#9d8cff', '#ff7ab6', '#7dff5a', '#4fa3ff', '#ffd84d'];
export function avatar(name, size = 36) {
  const n = String(name || '?');
  let h = 0;
  for (const c of n) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const c = HUES[h % HUES.length];
  return `<span class="avatar" style="width:${size}px;height:${size}px;background:linear-gradient(140deg,${c},${c}99);box-shadow:0 6px 18px -6px ${c}88">${esc(n.trim().charAt(0).toUpperCase())}</span>`;
}

/** تصدير CSV (يفتح في Excel بالعربية بفضل BOM). */
export function downloadCsv(filename, rows) {
  const csv = rows.map((r) => r.map((v) => `"${String(v ?? '').replace(/"/g, '""')}"`).join(',')).join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob(['﻿' + csv], { type: 'text/csv;charset=utf-8' }));
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}
