import { auth, errorText } from '../core/api.js';
import { icon } from '../core/icons.js';
import { $ } from '../core/ui.js';

export function renderLogin(root, { message = '', onSuccess }) {
  const blips = Array.from({ length: 4 }, (_, i) => {
    const a = Math.random() * Math.PI * 2, r = 18 + Math.random() * 28;
    return `<span class="blip" style="top:${50 + Math.sin(a) * r}%;left:${50 + Math.cos(a) * r}%;animation-delay:${i * 0.7}s"></span>`;
  }).join('');
  root.innerHTML = `
  <div class="auth">
    <section class="auth-art" aria-hidden="true">
      <div class="radar">${blips}<div class="core">${icon('vault')}</div></div>
      <div class="caption">SECURE UPLINK · HQ-07 · ENCRYPTED</div>
    </section>
    <section class="auth-form">
      <form class="auth-box" novalidate>
        <div style="display:flex;align-items:center;gap:12px">
          <span class="brand-mark" style="width:44px;height:44px;border-radius:13px;display:grid;place-items:center;background:linear-gradient(135deg,var(--accent),var(--info));color:var(--accent-ink)">${icon('vault')}</span>
          <span class="mono faint" style="font-size:12px;letter-spacing:.12em">COMMAND CENTER</span>
        </div>
        <h1>الخزنة</h1>
        <p class="lead">لوحة إدارة اللعبة — الدخول بحساب المدير.</p>
        <div class="field"><label for="em">البريد الإلكتروني</label>
          <div class="input-wrap">${icon('mail')}<input class="input ltr" id="em" type="email" autocomplete="username" placeholder="admin@example.com" required></div></div>
        <div class="field"><label for="pw">كلمة السر</label>
          <div class="input-wrap">${icon('lock')}<input class="input ltr" id="pw" type="password" autocomplete="current-password" placeholder="••••••••" required></div></div>
        <div class="err" id="err" role="alert">${message}</div>
        <button class="btn btn-primary btn-lg btn-block" id="go" type="submit">دخول آمن</button>
        <p class="legal">AUTHORIZED PERSONNEL ONLY</p>
      </form>
    </section>
  </div>`;
  const form = $('form', root);
  const btn = $('#go', root);
  $('#em', root).focus();
  form.onsubmit = async (e) => {
    e.preventDefault();
    btn.disabled = true;
    btn.innerHTML = `${icon('refresh', 'style="animation:spin 1s linear infinite"')} جارٍ التحقّق…`;
    try {
      await auth.signIn($('#em', root).value.trim(), $('#pw', root).value);
      await onSuccess();
    } catch (err) {
      $('#err', root).textContent = errorText(err);
      btn.disabled = false;
      btn.textContent = 'دخول آمن';
    }
  };
}
