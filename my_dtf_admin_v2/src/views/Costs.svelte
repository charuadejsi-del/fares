<script>
  // Coûts et bénéfices : par mètre, par jour, par mois — mètres réels des commandes.
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { settings, liveTick, toast } from '../lib/store.js';
  import { da, m, num, pct, ltr, ymd } from '../lib/fmt.js';
  import { month, unit } from '../lib/costs.js';
  import Icon from '../components/Icon.svelte';

  let tab = 'board', cs = null, rows = null, err = '', busy = false, form = null;
  const now = new Date();
  let ym = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
  let dayIdx = null;
  $: price = +($settings?.price_per_meter || 0);
  $: [Y, M] = ym.split('-').map(Number);
  $: ongoing = Y === now.getFullYear() && M === now.getMonth() + 1;

  async function load() {
    try {
      cs = await q(sb.from('dtf_cost_settings').select('*').single());
      if (!form) form = JSON.parse(JSON.stringify(cs));
      const from = new Date(Y, M - 1, 1), last = new Date(Y, M, 0);
      const to = ongoing ? now : last;
      rows = await rpc('dtf_cost_days', { p_from: ymd(from), p_to: ymd(to) });
      if (dayIdx === null || dayIdx >= rows.length) dayIdx = rows.length - 1;
    } catch (e) { err = errMsg(e); }
  }
  $: ym, $liveTick, load();

  $: R = cs && rows ? month(rows, cs, price, ongoing) : null;
  $: ref = R ? (R.projection || R.actual) : null;          // base « par mètre » (mois complet / projection)
  $: D = R && dayIdx !== null ? R.days[dayIdx] : null;
  $: maxAbs = R ? Math.max(1, ...R.days.map(d => Math.abs(d.profit))) : 1;
  $: U = form ? unit(form) : null;
  $: preview = form && price ? month([...Array(form.work_days)].map((_, i) => ({ day: i, meters: 50, waste_m: 0, revenue: 0, orders: 0 })), form, price, false).actual : null;

  const LINES = [['film', 'الفيلم'], ['ink', 'الحبر'], ['powder', 'البودرة'], ['wages', 'الأجور'], ['fixed', 'المصاريف الثابتة'], ['wasteCost', 'الهدر']];
  const v = (x, k) => x?.per?.[k === 'wasteCost' ? 'waste' : k];
  const mnames = ['جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  $: months = [...Array(12)].map((_, i) => { const d = new Date(now.getFullYear(), now.getMonth() - i, 1); return { v: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, t: `${mnames[d.getMonth()]} ${d.getFullYear()}` }; });

  async function save() {
    busy = true; err = '';
    try {
      const f = { ...form }; delete f.id; f.updated_at = new Date().toISOString();
      ['roll_price', 'roll_length_m', 'ink_price_l', 'ink_ml_per_m', 'powder_price_kg', 'powder_g_per_m', 'work_days'].forEach(k => (f[k] = +String(f[k]).replace(',', '.')));
      f.wages = f.wages.filter(w => w.name?.trim()).map(w => ({ name: w.name.trim(), amount: +w.amount || 0 }));
      f.fixed_costs = f.fixed_costs.filter(w => w.name?.trim()).map(w => ({ name: w.name.trim(), amount: +w.amount || 0 }));
      if (!(f.roll_length_m > 0) || !(f.work_days >= 1 && f.work_days <= 31)) throw new Error('طول الرولو وأيام العمل يجب أن تكون أكبر من صفر');
      await q(sb.from('dtf_cost_settings').update(f).eq('id', 1));
      toast('حُفظت الإعدادات'); form = null; liveTick.update(n => n + 1); tab = 'board';
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
  const num2 = x => (x == null ? '—' : da(x));
  const dname = d => { const x = new Date(d + 'T12:00:00'); return ltr(String(x.getDate())); };
</script>

<div class="row between wrap" style="margin-bottom:14px">
  <div class="seg"><button class:on={tab === 'board'} on:click={() => (tab = 'board')}>اللوحة</button><button class:on={tab === 'set'} on:click={() => { form = JSON.parse(JSON.stringify(cs)); tab = 'set'; }}>الإعدادات</button></div>
  {#if tab === 'board'}<select style="width:auto" bind:value={ym}>{#each months as x}<option value={x.v}>{x.t}</option>{/each}</select>{/if}
</div>
{#if err}<div class="notice bad small" style="margin-bottom:12px">{err}</div>{/if}

{#if !R}<div class="spinner"></div>
{:else if tab === 'board'}
  <div class="grid g4">
    <div class="card accent kp"><span class="muted small">الربح الصافي — {ongoing ? 'حتى اليوم' : 'الشهر'}</span><b class:red={R.actual.profit < 0} class:green={R.actual.profit >= 0}>{da(R.actual.profit)}</b><span class="faint tiny">{m(R.actual.meters, 1)} في {num(R.worked)} يوم عمل</span></div>
    <div class="card kp"><span class="muted small">التكلفة للمتر</span><b>{num2(ref.per.cost)}</b><span class="faint tiny">سعر البيع {da(price)}</span></div>
    <div class="card kp"><span class="muted small">الربح للمتر</span><b class:red={ref.per.profit < 0}>{num2(ref.per.profit)}</b><span class="faint tiny">الهامش {ref.margin == null ? '—' : pct(ref.margin * 100)}</span></div>
    <div class="card kp"><span class="muted small">{R.projection ? 'التوقّع لنهاية الشهر' : 'المداخيل'}</span><b class="accent">{R.projection ? da(R.projection.profit) : da(R.actual.revenue)}</b><span class="faint tiny">{R.projection ? `${m(R.projection.meters, 0)} على ${num(cs.work_days)} يوم` : `المفوتر فعلاً ${da(R.actual.revenueReal)}`}</span></div>
  </div>
  {#if !R.worked}<div class="notice warn small" style="margin-top:12px">لا توجد أمتار مطبوعة في هذا الشهر بعد. الأرقام تظهر عندما تبدأ الطباعة.</div>{/if}

  <div class="card" style="margin-top:12px">
    <div class="section-title">الربح اليومي<span class="end faint small">اضغط على يوم لرؤية تفاصيله</span></div>
    <div class="chart" dir="ltr">
      {#each R.days as d, i}
        <button class="col" class:sel={i === dayIdx} class:off={!d.on} on:click={() => (dayIdx = i)} title={Math.round(d.profit)}>
          <div class="up">{#if d.profit > 0}<i class="pos" style="height:{(d.profit / maxAbs) * 100}%"></i>{/if}</div>
          <div class="dn">{#if d.profit < 0}<i class="neg" style="height:{(-d.profit / maxAbs) * 100}%"></i>{/if}</div>
          <small>{dname(d.day)}</small>
        </button>
      {/each}
    </div>
  </div>

  <div class="card table-wrap" style="margin-top:12px">
    <div class="section-title">التفصيل</div>
    <table class="bd">
      <tr><th></th><th>للمتر{R.projection ? ' (حسب التوقّع)' : ''}</th><th>اليوم {D ? dname(D.day) : ''}</th><th>الشهر {ongoing ? '(حتى اليوم)' : ''}</th></tr>
      <tr class="sub"><td>الأمتار المطبوعة</td><td>—</td><td>{m(D?.meters || 0)}</td><td>{m(R.actual.meters)}</td></tr>
      {#each LINES as [k, t]}{#if k !== 'wasteCost' || cs.waste_in_profit}
        <tr><td>{t}</td><td>{num2(v(ref, k))}</td><td>{D?.on ? da(D[k]) : '—'}</td><td>{da(R.actual[k])}</td></tr>
      {/if}{/each}
      <tr class="tot"><td>مجموع التكاليف</td><td>{num2(ref.per.cost)}</td><td>{D?.on ? da(D.cost) : '—'}</td><td>{da(R.actual.cost)}</td></tr>
      <tr><td>المداخيل (أمتار × {da(price)})</td><td>{da(price)}</td><td>{D?.on ? da(D.revenue) : '—'}</td><td>{da(R.actual.revenue)}</td></tr>
      <tr class="faint"><td>المبالغ المفوترة فعلاً للزبائن</td><td>—</td><td>{D?.on ? da(D.revenueReal) : '—'}</td><td>{da(R.actual.revenueReal)}</td></tr>
      <tr class="tot"><td>الربح الصافي</td><td class:red={ref.per.profit < 0}>{num2(ref.per.profit)}</td><td class:red={D?.profit < 0}>{D?.on ? da(D.profit) : '—'}</td><td class:red={R.actual.profit < 0}>{da(R.actual.profit)}</td></tr>
      <tr><td>الهامش</td><td>{ref.margin == null ? '—' : pct(ref.margin * 100)}</td><td>{D?.on && D.margin != null ? pct(D.margin * 100) : '—'}</td><td>{R.actual.margin == null ? '—' : pct(R.actual.margin * 100)}</td></tr>
    </table>
    <p class="faint tiny" style="margin-top:10px">المصاريف الثابتة: الشهر كاملاً في عمود الشهر، و1/{num(cs.work_days)} منها في كل يوم عمل. الأجور تُحسب في الأيام التي فيها طباعة. يوم بلا طباعة لا يُحسب يوم عمل.</p>
  </div>

{:else if form}
  <div class="grid g2 stack">
    <div class="card">
      <div class="section-title">المواد</div>
      <div class="grid g2">
        <div><label>ثمن رول الفيلم (دج)</label><input dir="ltr" inputmode="decimal" bind:value={form.roll_price} /></div>
        <div><label>طول الرول (م)</label><input dir="ltr" inputmode="decimal" bind:value={form.roll_length_m} /></div>
        <div><label>ثمن لتر الحبر (دج)</label><input dir="ltr" inputmode="decimal" bind:value={form.ink_price_l} /></div>
        <div><label>استهلاك الحبر للمتر (مل)</label><input dir="ltr" inputmode="decimal" bind:value={form.ink_ml_per_m} /></div>
        <div><label>ثمن كيلو البودرة (دج)</label><input dir="ltr" inputmode="decimal" bind:value={form.powder_price_kg} /></div>
        <div><label>استهلاك البودرة للمتر (غ)</label><input dir="ltr" inputmode="decimal" bind:value={form.powder_g_per_m} /></div>
        <div><label>أيام العمل في الشهر</label><input dir="ltr" inputmode="numeric" bind:value={form.work_days} /></div>
        <div><label>سعر البيع للمتر</label><div class="ro">{da(price)} <a href="#settings" class="tiny">تعديل في الإعدادات</a></div></div>
      </div>
      <label class="row" style="gap:8px;margin-top:14px"><input type="checkbox" style="width:auto" bind:checked={form.waste_in_profit} /> خصم تكلفة الهدر من الربح</label>
    </div>
    <div class="col">
      {#each [['wages', 'الأجور اليومية'], ['fixed_costs', 'المصاريف الشهرية']] as [k, t]}
        <div class="card">
          <div class="section-title">{t}<span class="end num small muted">{da(form[k].reduce((s, x) => s + (+x.amount || 0), 0))}</span></div>
          {#each form[k] as w, i}
            <div class="row" style="margin-bottom:8px"><input class="grow" bind:value={w.name} /><input style="width:120px" dir="ltr" inputmode="numeric" bind:value={w.amount} />
              <button class="btn quiet sm" aria-label="حذف" on:click={() => { form[k].splice(i, 1); form = form; }}><Icon name="x" size={16} /></button></div>
          {/each}
          <button class="btn ghost sm" on:click={() => { form[k] = [...form[k], { name: '', amount: 0 }]; }}><Icon name="plus" size={16} />إضافة</button>
        </div>
      {/each}
    </div>
  </div>
  {#if U && preview}
    <div class="card accent" style="margin-top:12px">
      <div class="section-title">النتيجة بهذه الأرقام (مثال: 50 م في اليوم)</div>
      <div class="grid g4">
        <div class="pv"><span class="faint tiny">الفيلم / الحبر / البودرة</span><b class="num">{U.film.toFixed(1)} / {U.ink.toFixed(1)} / {U.powder.toFixed(1)}</b></div>
        <div class="pv"><span class="faint tiny">التكلفة للمتر</span><b>{da(preview.per.cost)}</b></div>
        <div class="pv"><span class="faint tiny">الربح للمتر · الهامش</span><b class="green">{da(preview.per.profit)} · {pct(preview.margin * 100)}</b></div>
        <div class="pv"><span class="faint tiny">الربح الشهري</span><b class="accent">{da(preview.profit)}</b></div>
      </div>
    </div>
  {/if}
  <div class="row" style="margin-top:14px"><button class="btn lg" disabled={busy} on:click={save}>حفظ</button><button class="btn quiet lg" on:click={() => (tab = 'board')}>إلغاء</button></div>
{/if}

<style>
  .kp { display: flex; flex-direction: column; gap: 4px; } .kp b { font-size: 22px; }
  .chart { display: flex; gap: 3px; height: 220px; align-items: stretch; }
  .chart .col { flex: 1; min-width: 8px; display: flex; flex-direction: column; align-items: center; border-radius: 6px; padding: 2px 0; gap: 0; }
  .chart .col.sel { background: var(--accent-soft); }
  .up, .dn { flex: 1; width: 100%; max-width: 22px; display: flex; }
  .up { align-items: flex-end; border-bottom: 1px solid var(--line2); } .dn { align-items: flex-start; }
  .up i, .dn i { display: block; width: 100%; }
  .pos { background: linear-gradient(180deg, #4ADE80, #10B98166); border-radius: 5px 5px 0 0; }
  .neg { background: linear-gradient(0deg, #F87171, #F8717166); border-radius: 0 0 5px 5px; }
  .col.off small { opacity: .4; }
  .chart small { font-size: 10px; color: var(--faint); margin-top: 2px; }
  .bd td:not(:first-child), .bd th:not(:first-child) { text-align: left; }
  .bd .tot td { font-weight: 700; border-top: 2px solid var(--line2); }
  .bd .sub td { color: var(--muted); }
  .ro { padding: 11px 0; }
  .pv { display: flex; flex-direction: column; gap: 4px; } .pv b { font-size: 17px; }
</style>
