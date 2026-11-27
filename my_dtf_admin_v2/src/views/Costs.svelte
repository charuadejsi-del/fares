<script>
  import { countUp } from '../lib/motion.js';
  // Coûts et bénéfices : par mètre, par jour, par mois — mètres réels des commandes.
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { settings, liveTick, toast } from '../lib/store.js';
  import { da, m, num, pct, ltr, ymd } from '../lib/fmt.js';
  import { month, unit, simulate } from '../lib/costs.js';
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
      cs = await q(sb.from('dtf_cost_settings').select('*').limit(1).maybeSingle());
      if (!form) form = JSON.parse(JSON.stringify(cs));
      const from = new Date(Y, M - 1, 1), last = new Date(Y, M, 0);
      const to = ongoing ? now : last;
      rows = await rpc('dtf_cost_days2', { p_from: ymd(from), p_to: ymd(to) });
      if (dayIdx === null || dayIdx >= rows.length) dayIdx = rows.length - 1;
    } catch (e) { err = errMsg(e); }
  }
  $: ym, $liveTick, load();

  $: R = cs && rows ? month(rows, cs, price, ongoing) : null;
  $: ref = R ? (R.projection || R.actual) : null;          // base « par mètre » (mois complet / projection)
  $: D = R && dayIdx !== null ? R.days[dayIdx] : null;
  $: maxAbs = R ? Math.max(1, ...R.days.map(d => Math.abs(d.profit))) : 1;
  $: U = form ? unit(form) : null;
  $: preview = form && price ? simulate(form, price, 50) : null;

  const LINES = [['film', 'الفيلم'], ['ink', 'الحبر'], ['powder', 'البودرة'], ['wages', 'الأجور'], ['fixed', 'المصاريف الثابتة'], ['wasteCost', 'الهدر']];
  const v = (x, k) => x?.per?.[k === 'wasteCost' ? 'waste' : k];
  const mnames = ['جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان', 'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
  $: months = [...Array(12)].map((_, i) => { const d = new Date(now.getFullYear(), now.getMonth() - i, 1); return { v: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`, t: `${mnames[d.getMonth()]} ${d.getFullYear()}` }; });

  async function save() {
    busy = true; err = '';
    try {
      const f = { ...form }; delete f.id; f.updated_at = new Date().toISOString();
      ['roll_price', 'roll_length_m', 'ink_price_l', 'ink_ml_per_m', 'powder_price_kg', 'powder_g_per_m', 'work_days'].forEach(k => (f[k] = +String(f[k]).replace(',', '.')));
      const clean = w => ({ name: w.name.trim(), amount: +w.amount || 0, ...(w.from ? { from: w.from } : {}) });
      f.wages = f.wages.filter(w => w.name?.trim()).map(clean);
      f.fixed_costs = f.fixed_costs.filter(w => w.name?.trim()).map(clean);
      f.start_date = f.start_date || null;
      if (!(f.roll_length_m > 0) || !(f.work_days >= 1 && f.work_days <= 31)) throw new Error('طول الرولو وأيام العمل يجب أن تكون أكبر من صفر');
      await q(sb.from('dtf_cost_settings').update(f).eq('id', 1));
      toast('حُفظت الإعدادات'); form = null; liveTick.update(n => n + 1); tab = 'board';
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
  $: mlabel = months.find(x => x.v === ym)?.t || ym;
  function csv() {
    const head = ['اليوم', 'الأمتار', 'الفيلم', 'الحبر', 'البودرة', 'الأجور', 'المصاريف الثابتة', 'الهدر', 'التكاليف', 'المداخيل', 'المفوتر', 'الربح'];
    const r2 = x => (x == null ? '' : Math.round(+x * 100) / 100);
    const lines = [head, ...R.days.filter(d => d.on).map(d => [d.day, r2(d.meters), r2(d.film), r2(d.ink), r2(d.powder), r2(d.wages), r2(d.fixed), r2(d.wasteCost), r2(d.cost), r2(d.revenue), r2(d.revenueReal), r2(d.profit)])];
    const blob = new Blob(['\ufeff' + lines.map(l => l.join(';')).join('\n')], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = `mydtf-couts-${ym}.csv`; a.click(); setTimeout(() => URL.revokeObjectURL(a.href), 2000);
  }
  const num2 = x => (x == null ? '—' : da(x));
  const dname = d => { const x = new Date(d + 'T12:00:00'); return ltr(String(x.getDate())); };
</script>

<div class="utabs">
  <button class:on={tab === 'board'} on:click={() => (tab = 'board')}><Icon name="chart" size={19} />الإحصائيات</button>
  <button class:on={tab === 'set'} on:click={() => { form = JSON.parse(JSON.stringify(cs)); tab = 'set'; }}><Icon name="settings" size={19} />الإعدادات</button>
</div>
{#if err}<div class="notice bad small" style="margin-bottom:12px">{err}</div>{/if}

{#if !R}<div class="spinner"></div>
{:else if tab === 'board'}
  <div class="row between wrap" style="margin-bottom:6px">
    <div class="seg">
      <button class:on={ym === months[0].v} on:click={() => (ym = months[0].v)}>هذا الشهر</button>
      <button class:on={ym === months[1].v} on:click={() => (ym = months[1].v)}>الشهر الماضي</button>
      <select class="msel" class:on={ym !== months[0].v && ym !== months[1].v} bind:value={ym}>{#each months as x}<option value={x.v}>{x.t}</option>{/each}</select>
    </div>
    <button class="btn ghost sm" on:click={csv}><Icon name="download" size={16} />تصدير CSV</button>
  </div>
  <div class="faint tiny" style="margin-bottom:14px">من {R.days[0]?.day || '—'} إلى {R.days[R.days.length - 1]?.day || '—'}</div>

  <div class="top2">
    <div class="hero-g">
      <span class="tag">{ongoing ? 'هذا الشهر — حتى اليوم' : mlabel}</span>
      <div class="lbl" style="margin-top:10px">الربح الصافي</div>
      <div class="big num" class:neg={R.actual.profit < 0} use:countUp={{ value: R.actual.profit, format: da }}></div>
      <div class="mini">
        <span><Icon name="roll" size={15} />{m(R.actual.meters, 1)}</span>
        <span><Icon name="calendar" size={15} />{num(R.worked)} يوم عمل</span>
        <span><Icon name="wallet" size={15} />مداخيل {da(R.actual.revenue)}</span>
        {#if R.projection}<span><Icon name="trend" size={15} />التوقّع {da(R.projection.profit)}</span>{/if}
      </div>
    </div>
    <div class="tiles">
      <div class="tile k-green"><span class="ic"><Icon name="wallet" size={19} /></span><b class="v">{num2(ref.per.profit)}</b><span class="l">الربح للمتر</span></div>
      <div class="tile k-amber"><span class="ic"><Icon name="coins" size={19} /></span><b class="v">{num2(ref.per.cost)}</b><span class="l">التكلفة للمتر</span><span class="s">البيع {da(price)}</span></div>
      <div class="tile k-blue"><span class="ic"><Icon name="trend" size={19} /></span><b class="v">{ref.margin == null ? '—' : pct(ref.margin * 100)}</b><span class="l">الهامش</span></div>
      <div class="tile k-red"><span class="ic"><Icon name="scissors" size={19} /></span><b class="v">{m(R.actual.waste || 0, 1)}</b><span class="l">الهدر</span><span class="s">{da(R.actual.wasteCost || 0)}</span></div>
    </div>
  </div>
  {#if !R.worked}<div class="notice warn small" style="margin-top:12px">لا توجد أمتار مطبوعة في هذا الشهر بعد. الأرقام تظهر عندما تبدأ الطباعة.</div>{/if}

  <div class="card" style="margin-top:14px">
    <div class="section-title"><div>المداخيل والتكاليف<span class="sub">مجموع الشهر {ongoing ? '(حتى اليوم)' : ''}</span></div></div>
    <div class="grid g4">
      <div class="tint k-green"><Icon name="wallet" size={22} /><div><b class="v">{da(R.actual.revenue)}</b><div class="l">المداخيل (الأمتار × السعر)</div></div></div>
      <div class="tint k-blue"><Icon name="file" size={22} /><div><b class="v">{da(R.actual.revenueReal)}</b><div class="l">المفوتر فعلاً للزبائن</div></div></div>
      <div class="tint k-red"><Icon name="trend" size={22} /><div><b class="v">{da(R.actual.cost)}</b><div class="l">مجموع التكاليف</div></div></div>
      <div class="tint k-teal"><Icon name="team" size={22} /><div><b class="v">{da((R.actual.wages || 0) + (R.actual.fixed || 0))}</b><div class="l">الأجور + المصاريف الثابتة</div></div></div>
    </div>
  </div>

  <div class="card" style="margin-top:12px">
    <div class="section-title"><div>الربح اليومي<span class="sub">اضغط على يوم لرؤية تفاصيله</span></div></div>
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
      <tr><td>المداخيل (أمتار × سعر كل طلبية)</td><td>{da(price)}</td><td>{D?.on ? da(D.revenue) : '—'}</td><td>{da(R.actual.revenue)}</td></tr>
      <tr class="faint"><td>المبالغ المفوترة فعلاً للزبائن</td><td>—</td><td>{D?.on ? da(D.revenueReal) : '—'}</td><td>{da(R.actual.revenueReal)}</td></tr>
      <tr class="tot"><td>الربح الصافي</td><td class:red={ref.per.profit < 0}>{num2(ref.per.profit)}</td><td class:red={D?.profit < 0}>{D?.on ? da(D.profit) : '—'}</td><td class:red={R.actual.profit < 0}>{da(R.actual.profit)}</td></tr>
      <tr><td>الهامش</td><td>{ref.margin == null ? '—' : pct(ref.margin * 100)}</td><td>{D?.on && D.margin != null ? pct(D.margin * 100) : '—'}</td><td>{R.actual.margin == null ? '—' : pct(R.actual.margin * 100)}</td></tr>
    </table>
    <p class="faint tiny" style="margin-top:10px">المصاريف الثابتة: في عمود الشهر بقدر الأيام التي كانت فيها سارية{cs.start_date ? ` (منذ ${cs.start_date})` : ''}، و1/{num(cs.work_days)} منها في كل يوم عمل. الأجور تُحسب في الأيام التي فيها طباعة، ابتداءً من تاريخ كل عامل.</p>
  </div>

{:else if form}
  <div class="grid g2 stack">
    <div class="card">
      <div class="section-title">بداية الحساب</div>
      <label for="sd">تاريخ بداية عمل الورشة — لا يُحسب شيء قبله</label><input id="sd" type="date" bind:value={form.start_date} />
      <p class="faint tiny" style="margin-top:6px">بجانب كل أجرة وكل مصروف تاريخ «يبدأ من» خاص به: يُحسب المصروف الشهري بقدر أيامه في الشهر الأول، والأجرة من يوم بدايتها.</p>
      <div class="section-title" style="margin-top:16px">المواد</div>
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
            <div class="row" style="margin-bottom:8px"><input class="grow" bind:value={w.name} /><input style="width:110px" dir="ltr" inputmode="numeric" bind:value={w.amount} />
              <input type="date" style="width:150px" title="يبدأ من (فارغ = منذ البداية)" bind:value={w.from} />
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
  .top2 { display: grid; grid-template-columns: 1.15fr 1fr; gap: 12px; }
  .tiles { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .hero-g { display: flex; flex-direction: column; justify-content: center; min-height: 190px; }
  .hero-g .big.neg { color: #FFB4B4; }
  .msel { width: auto; border-radius: 999px; padding: 6px 14px; font-size: 13.5px; background: var(--card); border-color: var(--line2); }
  .msel.on { border-color: var(--accent); color: var(--accent2); }
  @media (max-width: 1100px) { .top2 { grid-template-columns: 1fr; } }
  .chart { display: flex; gap: 3px; height: 220px; align-items: stretch; }
  .chart .col { flex: 1; min-width: 8px; display: flex; flex-direction: column; align-items: center; border-radius: 6px; padding: 2px 0; gap: 0; }
  .chart .col.sel { background: var(--accent-soft); }
  .up, .dn { flex: 1; width: 100%; max-width: 22px; display: flex; }
  .up { align-items: flex-end; border-bottom: 1px solid var(--line2); } .dn { align-items: flex-start; }
  .up i, .dn i { display: block; width: 100%; }
  .pos { background: linear-gradient(180deg, var(--chart2), #7C6CF055); border-radius: 5px 5px 0 0; }
  .neg { background: linear-gradient(0deg, #F87171, #F8717166); border-radius: 0 0 5px 5px; }
  .col.off small { opacity: .4; }
  .chart small { font-size: 10px; color: var(--faint); margin-top: 2px; }
  .bd td:not(:first-child), .bd th:not(:first-child) { text-align: left; }
  .bd .tot td { font-weight: 700; border-top: 2px solid var(--line2); }
  .bd .sub td { color: var(--muted); }
  .ro { padding: 11px 0; }
  .pv { display: flex; flex-direction: column; gap: 4px; } .pv b { font-size: 17px; }
</style>
