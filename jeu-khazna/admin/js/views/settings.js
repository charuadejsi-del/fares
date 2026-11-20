import { api, errorText } from '../core/api.js';
import { icon } from '../core/icons.js';
import { esc } from '../core/format.js';
import { $, $$, toast } from '../core/ui.js';
import { REGIONS } from '../core/config.js';

let dirty = false;
addEventListener('beforeunload', (e) => { if (dirty) e.preventDefault(); });
export const settingsDirty = () => dirty;

const RULES = [
  ['signup_bonus_seconds', 'هدية التسجيل', 'min', 'gift', '', 'تُمنح مرّة واحدة لكل حساب جديد'],
  ['daily_free_seconds', 'الوقت المجاني اليومي', 'min', 'clock', 'info', 'يطالب به اللاعب مرّة في اليوم'],
  ['error_penalty_seconds', 'عقوبة كل خطأ', 'sec', 'alert', 'danger', 'تُخصم من اللاعبَين معاً'],
  ['max_penalty_per_stage_seconds', 'سقف العقوبة في المرحلة', 'sec', 'ban', 'danger', 'لا تتجاوزه العقوبات في مرحلة واحدة'],
  ['hint_cost_seconds', 'ثمن التلميح', 'min', 'zap', 'warn', 'يُدفع من الرصيد'],
];

export async function renderSettings(page) {
  const [settings, stages, packages] = await Promise.all([api.settings(), api.stageConfig(), api.packages()]);
  const sv = Object.fromEntries(settings.map((r) => [r.key, r.value]));
  dirty = false;
  page.innerHTML = `
  <div class="page-head"><div><h2>الإعدادات</h2><p>تُطبَّق فوراً على كل اللاعبين بعد الحفظ</p></div></div>
  <div class="stack">
    <div class="card"><div class="card-head"><span class="chip-icon">${icon('settings')}</span><div><h3>قواعد الوقت</h3><p>اقتصاد اللعبة</p></div></div>
      <div class="card-body"><div class="settings-grid">${RULES.map(([k, label, unit, ic, tone, hint]) => `
        <div class="card setting" style="background:var(--surface-2)">
          <div class="head"><span class="chip-icon ${tone}">${icon(ic)}</span><b>${label}</b></div>
          <div class="input-wrap"><input class="input has-suffix num" type="number" min="0" step="${unit === 'min' ? '0.5' : '1'}" data-k="${k}" data-u="${unit}" value="${unit === 'min' ? (Number(sv[k]) || 0) / 60 : Number(sv[k]) || 0}"><span class="suffix">${unit === 'min' ? 'دقيقة' : 'ثانية'}</span></div>
          <span class="hint">${hint}</span>
        </div>`).join('')}</div></div></div>

    <div class="card"><div class="card-head"><span class="chip-icon warn">${icon('bank')}</span><div><h3>حساب بريدي موب</h3><p>يظهر للعميل في شاشة الشراء</p></div></div>
      <div class="card-body"><div class="grid-2-even">
        <div class="field"><label>RIP</label><input class="input mono ltr" data-k="baridimob_rip" data-u="text" placeholder="00799999 0000000000 00" value="${esc(sv.baridimob_rip ?? '')}"></div>
        <div class="field"><label>اسم صاحب الحساب</label><input class="input" data-k="baridimob_name" data-u="text" placeholder="الاسم كما في البطاقة" value="${esc(sv.baridimob_name ?? '')}"></div>
      </div></div></div>

    <div class="card"><div class="card-head"><span class="chip-icon warn">${icon('coin')}</span><div><h3>باقات المتجر</h3><p>السعر لكل دقيقة يُحسب تلقائياً</p></div>
      <div class="end"><button class="btn btn-sm" data-add>${icon('plus')} باقة جديدة</button></div></div>
      <div class="card-body"><div class="pkg-grid">${packages.map((p) => `
        <div class="card pkg ${p.active ? '' : 'off'}" data-id="${p.id}" style="background:var(--surface-2)">
          <div style="display:flex;align-items:center;justify-content:space-between"><span class="tag ${p.active ? 'ok' : ''}" data-state>${p.active ? 'ظاهرة' : 'مخفيّة'}</span><button class="switch ${p.active ? 'on' : ''}" aria-label="تفعيل"></button></div>
          <div class="big num"><span data-m>${p.minutes}</span> <small>دقيقة</small></div>
          <div class="grid-2-even" style="gap:10px">
            <div class="field"><label>الدقائق</label><input class="input num" type="number" min="1" data-pm value="${p.minutes}"></div>
            <div class="field"><label>السعر (دج)</label><input class="input num" type="number" min="1" data-pp value="${p.price_dzd}"></div>
          </div>
          <span class="faint" style="font-size:12.5px" data-rate>${(p.price_dzd / p.minutes).toFixed(2)} دج / دقيقة</span>
        </div>`).join('')}</div></div></div>

    <div class="card"><div class="card-head"><span class="chip-icon info">${icon('flag')}</span><div><h3>وقت كل مرحلة</h3><p>بالدقائق · ★ = مرحلة الزعيم</p></div></div>
      <div class="card-body">
        <div class="toolbar" style="padding:0 0 14px;border:0">
          <span class="muted">تعديل جماعي من</span><input class="input num" id="b1" type="number" value="1" style="width:76px">
          <span class="muted">إلى</span><input class="input num" id="b2" type="number" value="60" style="width:76px">
          <input class="input num" id="bv" type="number" step="0.5" placeholder="دقائق" style="width:96px"><button class="btn btn-sm" id="bulk">تطبيق</button>
        </div>
        ${REGIONS.map((r) => `<div class="region"><h4><i style="background:${r.color};box-shadow:0 0 10px ${r.color}"></i>${r.name} <span class="faint">(${r.from}–${r.to})</span></h4>
          <div class="stage-grid">${stages.filter((s) => s.stage >= r.from && s.stage <= r.to).map((s) => `
            <label class="stage ${s.stage === r.to ? 'boss' : ''}"><small>${s.stage === r.to ? '★ ' : ''}${s.stage}</small>
              <input class="input" type="number" step="0.5" min="1" max="120" data-s="${s.stage}" value="${s.time_limit_seconds / 60}"></label>`).join('')}</div></div>`).join('')}
      </div></div>

    <div class="card savebar"><span id="dirty" class="faint" style="flex:1">لا تغييرات</span><button class="btn btn-primary" id="save">${icon('save')} حفظ التغييرات</button></div>
  </div>`;

  const mark = () => { dirty = true; $('#dirty', page).innerHTML = '<span style="color:var(--warn)">● تغييرات غير محفوظة</span>'; };
  $$('input', page).forEach((i) => i.addEventListener('input', mark));
  $$('.pkg', page).forEach((c) => {
    const upd = () => {
      const m = +$('[data-pm]', c).value, pr = +$('[data-pp]', c).value;
      $('[data-m]', c).textContent = m || 0;
      $('[data-rate]', c).textContent = m > 0 ? `${(pr / m).toFixed(2)} دج / دقيقة` : '—';
    };
    $('[data-pm]', c).addEventListener('input', upd);
    $('[data-pp]', c).addEventListener('input', upd);
    $('.switch', c).onclick = (e) => {
      const on = e.currentTarget.classList.toggle('on');
      c.classList.toggle('off', !on);
      const t = $('[data-state]', c);
      t.className = `tag ${on ? 'ok' : ''}`;
      t.textContent = on ? 'ظاهرة' : 'مخفيّة';
      mark();
    };
  });
  $('#bulk', page).onclick = () => {
    const a = +$('#b1', page).value, b = +$('#b2', page).value, v = parseFloat($('#bv', page).value);
    if (!(v > 0)) return toast('اكتب عدد الدقائق', 'err');
    $$('[data-s]', page).forEach((i) => { const s = +i.dataset.s; if (s >= a && s <= b) i.value = v; });
    mark();
  };
  $('[data-add]', page).onclick = async () => {
    try { await api.addPackage({ minutes: 60, price_dzd: 100, active: false, sort: packages.length + 1 }); renderSettings(page); }
    catch (e) { toast(errorText(e), 'err'); }
  };
  $('#save', page).onclick = async (ev) => {
    const btn = ev.currentTarget;
    btn.disabled = true;
    try {
      const now = new Date().toISOString();
      const rows = $$('[data-k]', page).map((i) => {
        const u = i.dataset.u, raw = i.value.trim();
        return { key: i.dataset.k, value: u === 'text' ? raw : u === 'min' ? Math.round(parseFloat(raw || 0) * 60) : parseInt(raw || 0, 10), updated_at: now };
      });
      const st = $$('[data-s]', page).map((i) => ({ stage: +i.dataset.s, time_limit_seconds: Math.round(parseFloat(i.value) * 60), updated_at: now }));
      if (st.some((r) => !(r.time_limit_seconds >= 60 && r.time_limit_seconds <= 7200))) throw new Error('وقت كل مرحلة بين 1 و 120 دقيقة');
      const pk = $$('.pkg', page).map((c) => ({ id: +c.dataset.id, minutes: +$('[data-pm]', c).value, price_dzd: +$('[data-pp]', c).value, active: $('.switch', c).classList.contains('on') }));
      if (pk.some((p) => !(p.minutes > 0 && p.price_dzd > 0))) throw new Error('الدقائق والسعر يجب أن تكون أكبر من صفر');
      await api.saveSettings(rows);
      await api.saveStages(st);
      for (const p of pk) await api.updatePackage(p.id, { minutes: p.minutes, price_dzd: p.price_dzd, active: p.active });
      dirty = false;
      $('#dirty', page).innerHTML = '<span class="pos">✓ كل شيء محفوظ</span>';
      toast('حُفظت الإعدادات');
    } catch (e) { toast(errorText(e), 'err'); }
    btn.disabled = false;
  };
  return { title: 'الإعدادات', sub: 'SETTINGS' };
}
