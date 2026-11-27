<script>
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { me, settings, liveTick, staffName, openModal, toast } from '../lib/store.js';
  import { da, m, num, dt } from '../lib/fmt.js';
  import Kpi from '../components/Kpi.svelte';
  import RollGauge from '../components/RollGauge.svelte';
  import Waste from './Waste.svelte';
  import BuyRolls from './BuyRolls.svelte';

  let d = null;
  $: mgr = ['admin', 'manager'].includes($me?.role);
  async function load() {
    const [s, rolls, moves] = await Promise.all([
      q(sb.from('dtf_stock_summary').select('*').single()),
      q(sb.from('dtf_rolls').select('*').order('code', { ascending: false }).limit(200)),
      q(sb.from('dtf_film_moves').select('*,roll:dtf_rolls(code),ord:dtf_orders(code)').order('created_at', { ascending: false }).limit(60)),
    ]);
    const bought = rolls.reduce((a, r) => a + +r.unit_price, 0), boughtM = rolls.reduce((a, r) => a + +r.length_m, 0);
    d = { s, rolls, moves, cpm: boughtM ? bought / boughtM : 0 };
  }
  $: $liveTick, load();
  $: ppm = +($settings?.price_per_meter || 0);
  async function newRoll() {
    if (!confirm('تركيب الرولو التالي من المخزون؟ سيُعتبر الرولو الحالي منتهياً.')) return;
    try { const r = await rpc('dtf_activate_roll', {}); toast(`رُكّب الرولو رقم ${r.code}`); liveTick.update(n => n + 1); }
    catch (e) { toast(errMsg(e), true); }
  }
  const ST = { stock: 'في المخزون', active: 'مركّب الآن', finished: 'انتهى' };
  const KIND = { print: 'طباعة', waste: 'هدر', adjust: 'تعديل' };
</script>

{#if !d}<div class="spinner"></div>{:else}
  <div class="grid g4">
    <Kpi label="الفيلم المتبقي" value={m(d.s.total_remaining_m, 1)} sub="{d.s.rolls_in_stock} رولو احتياطي" />
    <Kpi label="الرولو المركّب" value={d.s.active_code ? m(d.s.active_remaining_m, 1) : '—'} sub={d.s.active_code ? `الرولو رقم ${d.s.active_code}` : 'لا يوجد'} warn={d.s.active_code && +d.s.active_remaining_m <= +d.s.alert_m} />
    {#if mgr}
      <Kpi label="تكلفة المتر" value={da(d.cpm)} sub="متوسط سعر الشراء" />
      <Kpi label="ربح المتر" value={da(ppm - d.cpm)} sub={ppm ? `سعر البيع ${da(ppm)}` : 'حدّد سعر المتر في الإعدادات'} />
    {/if}
  </div>
  <div class="grid split" style="margin-top:12px">
    <div class="card">
      <div class="section-title">الرولو المركّب</div>
      <RollGauge s={d.s} />
      <div class="col" style="margin-top:14px">
        {#if mgr}<button class="btn" on:click={() => openModal(BuyRolls)}>تسجيل شراء رولوات</button>{/if}
        <button class="btn quiet" on:click={newRoll}>تركيب الرولو التالي</button>
        <button class="btn quiet" on:click={() => openModal(Waste)}>تسجيل هدر أو تجربة</button>
      </div>
    </div>
    <div class="card table-wrap">
      <div class="section-title">الرولوات</div>
      <table>
        <tr><th>الرقم</th><th>الحالة</th><th>المتبقي</th><th></th>{#if mgr}<th>السعر</th>{/if}<th>المورّد</th><th>الشراء</th></tr>
        {#each d.rolls as r (r.id)}{@const p = (r.remaining_m / r.length_m) * 100}
          <tr><td><b>{num(r.code)}</b></td><td>{ST[r.status]}</td><td class="ltr">{(+r.remaining_m).toFixed(1)} / {(+r.length_m).toFixed(0)}</td>
            <td style="width:110px"><div class="bar" class:low={p < 15}><i style="width:{p}%"></i></div></td>
            {#if mgr}<td>{da(r.unit_price)}</td>{/if}<td>{r.supplier || ''}</td><td class="muted small">{dt(r.purchased_at)}</td></tr>
        {/each}
      </table>
      {#if !d.rolls.length}<div class="empty">لم يُسجَّل أي شراء بعد</div>{/if}
    </div>
  </div>
  <div class="card table-wrap" style="margin-top:12px">
    <div class="section-title">حركات الفيلم</div>
    <table>
      <tr><th>التاريخ</th><th>النوع</th><th>الأمتار</th><th>الرولو</th><th>الطلبية</th><th>بواسطة</th><th>ملاحظة</th></tr>
      {#each d.moves as x (x.id)}
        <tr><td class="muted small">{dt(x.created_at)}</td><td>{KIND[x.kind]}</td><td><b>{m(x.meters)}</b></td><td>{x.roll ? num(x.roll.code) : '—'}</td><td>{x.ord ? num(x.ord.code) : ''}</td><td>{staffName(x.actor_id)}</td><td class="muted small">{x.note || ''}</td></tr>
      {/each}
    </table>
    {#if !d.moves.length}<div class="empty">لا توجد حركات بعد</div>{/if}
  </div>
{/if}

<style>
  .split { grid-template-columns: 300px 1fr; }
  @media (max-width: 900px) { .split { grid-template-columns: 1fr; } }
</style>
