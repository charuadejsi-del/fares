// عناصر واجهة مشتركة: إشعارات، نوافذ تأكيد، لوحة جانبية، تكبير صورة، عدّاد متحرّك.
import { icon } from './icons.js';
import { esc } from './format.js';

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
export const html = (strings, ...vals) => strings.reduce((a, s, i) => a + s + (i < vals.length ? vals[i] ?? '' : ''), '');

export function toast(message, kind = 'ok') {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = `${icon(kind === 'ok' ? 'check' : 'alert')}<span>${esc(message)}</span>`;
  $('#toasts').appendChild(el);
  setTimeout(() => {
    el.style.transition = 'opacity .25s, transform .25s';
    el.style.opacity = '0';
    el.style.transform = 'translateY(6px)';
    setTimeout(() => el.remove(), 260);
  }, 3000);
}

/** نافذة تأكيد / إدخال. تُرجع true/false أو النص (null عند الإلغاء). */
export function dialog({ title, body = '', input = null, confirm = 'تأكيد', tone = 'primary' }) {
  return new Promise((resolve) => {
    const host = document.createElement('div');
    host.innerHTML = html`<div class="scrim"></div>
      <div class="dialog-wrap"><div class="dialog" role="dialog" aria-modal="true">
        <h3>${esc(title)}</h3>${body ? `<div class="desc">${body}</div>` : ''}
        ${input ? `<div class="field"><label>${esc(input.label || '')}</label>
          <input class="input" id="dlg-in" ${input.type ? `type="${input.type}"` : ''} placeholder="${esc(input.placeholder || '')}" value="${esc(input.value || '')}" autocomplete="off"></div>` : ''}
        <div class="actions"><button class="btn btn-${tone}" data-ok>${esc(confirm)}</button><button class="btn btn-ghost" data-no>إلغاء</button></div>
      </div></div>`;
    $('#overlay').appendChild(host);
    const field = $('#dlg-in', host);
    const done = (v) => {
      host.remove();
      removeEventListener('keydown', onKey);
      resolve(v);
    };
    const onKey = (e) => {
      if (e.key === 'Escape') done(input ? null : false);
      if (e.key === 'Enter') done(input ? field.value : true);
    };
    addEventListener('keydown', onKey);
    $('[data-ok]', host).onclick = () => done(input ? field.value : true);
    $('[data-no]', host).onclick = () => done(input ? null : false);
    $('.dialog-wrap', host).onclick = (e) => e.target === e.currentTarget && done(input ? null : false);
    (field || $('[data-ok]', host)).focus();
  });
}

/** لوحة جانبية (أسفل الشاشة على الهاتف). تُرجع { body, close }. */
export function sheet({ title, subtitle = '', onClose } = {}) {
  const host = document.createElement('div');
  host.innerHTML = html`<div class="scrim"></div>
    <aside class="sheet" role="dialog" aria-modal="true">
      <div class="sheet-head"><div style="flex:1;min-width:0"><b>${esc(title || '')}</b>
        ${subtitle ? `<div class="faint" style="font-size:12.5px">${esc(subtitle)}</div>` : ''}</div>
        <button class="btn btn-ghost icon-btn" data-close aria-label="إغلاق">${icon('x')}</button></div>
      <div class="sheet-body"><div class="skeleton" style="height:120px"></div></div>
    </aside>`;
  $('#overlay').appendChild(host);
  const close = () => {
    host.remove();
    removeEventListener('keydown', onKey);
    onClose?.();
  };
  const onKey = (e) => e.key === 'Escape' && close();
  addEventListener('keydown', onKey);
  $('.scrim', host).onclick = close;
  $('[data-close]', host).onclick = close;
  return { body: $('.sheet-body', host), close };
}

export function zoomImage(src) {
  const z = document.createElement('div');
  z.className = 'zoom';
  z.innerHTML = `<img src="${esc(src)}" alt="">`;
  z.onclick = () => z.remove();
  $('#overlay').appendChild(z);
}

export function countUp(el, to, fmt = (n) => n.toLocaleString('fr-FR')) {
  if (!el) return;
  const t0 = performance.now();
  const step = (t) => {
    const k = Math.min(1, (t - t0) / 800);
    el.textContent = fmt(Math.round(to * (1 - Math.pow(1 - k, 3))));
    if (k < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

export function beep() {
  try {
    const a = new AudioContext();
    [880, 1320].forEach((f, i) => {
      const o = a.createOscillator();
      const g = a.createGain();
      o.type = 'triangle';
      o.frequency.value = f;
      o.connect(g);
      g.connect(a.destination);
      const t = a.currentTime + i * 0.14;
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime(0.16, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, t + 0.3);
      o.start(t);
      o.stop(t + 0.32);
    });
  } catch {}
}

export const emptyState = (ic, title, hint = '') =>
  `<div class="empty">${icon(ic)}<b>${esc(title)}</b>${hint ? `<span>${esc(hint)}</span>` : ''}</div>`;
