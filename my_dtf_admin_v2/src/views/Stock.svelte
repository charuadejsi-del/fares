<script>
  import { sb, q } from '../lib/sb.js';
  import { me, settings, liveTick, staffName, openModal, openSheet, board, loadBoard } from '../lib/store.js';
  import { da, m, num, dt } from '../lib/fmt.js';
  import Kpi from '../components/Kpi.svelte';
  import MachineSheet from './MachineSheet.svelte';
  import Icon from '../components/Icon.svelte';
  import Supplies from '../components/Supplies.svelte';
  import Waste from './Waste.svelte';
  import BuyRolls from './BuyRolls.svelte';

  let d = null;
  $: mgr = ['admin', 'manager'].includes($me?.role);
  async function load() {
    const [s, rolls, , moves] = await Promise.all([
      q(sb.from('dtf_stock_summary').select('*').single()),
      q(sb.from('dtf_rolls').select('*').order('code', { ascending: false }).limit(200)),
      loadBoard(),
      q(sb.from('dtf_film_moves').select('*,roll:dtf_rolls(code),ord:dtf_orders(code),mach:dtf_machines(name)').order('created_at', { ascending: false }).limit(60)),
    ]);
    const bought = rolls.reduce((a, r) => a + +r.unit_price, 0), boughtM = rolls.reduce((a, r) => a + +r.length_m, 0);
    d = { s, rolls, moves, cpm: boughtM ? bought / boughtM : 0 };
  }
  $: $liveTick, load();
  $: ppm = +($settings?.price_per_meter || 0);
  $: machs = ($board || []).filter(x => x.active);
  $: mname = id => ($board || []).find(x => x.id === id)?.name || '';
  const ST = { stock: 'في المخزون', active: 'مركّب الآن', finished: 'انتهى' };
  const KIND = { print: 'طباعة', waste: 'هدر', adjust: 'تعديل' };
</script>

{#if !d}<div class="spinner"></div>{:else}
  <div class="grid g4">
    <Kpi label="الفيلم المتبقي" value={m(d.s.total_remaining_m, 1)} sub="{d.s.rolls_in_stock} رولو احتياطي" />
    <Kpi label="على الآلات" value={m(d.s.active_remaining_m, 1)} sub="{num(machs.filter(x => x.roll_code).length)} رولو مركّب" warn={machs.some(x => x.roll_code && +x.roll_remaining <= +x.alert_m)} />
    {#if mgr}
      <Kpi label="تكلفة المتر" value={da(d.cpm)} sub="متوسط سعر الشراء" />
      <Kpi label="ربح المتر" value={da(ppm - d.cpm)} sub={ppm ? `سعر البيع ${da(ppm)}` : 'حدّد سعر المتر في الإعدادات'} />
    {/if}
  </div>
  <div class="section-title" style="margin-top:18px">الحبر والبودرة</div>
  <Supplies />
  <div class="section-title" style="margin-top:18px">الفيلم</div>
  <div class="grid split">
    <div class="card">
      <div class="section-title">رولو كل آلة</div>
      <div class="col">
        {#each machs as x}{@const p = x.roll_code ? (x.roll_remaining / x.roll_length) * 100 : 0}{@const low = x.roll_code && +x.roll_remaining <= +x.alert_m}
          <button class="mr" on:click={() => openSheet(MachineSheet, { id: x.id })}>
            <div class="row between small"><b>{x.name}</b><span class:red={low} class="num">{x.roll_code ? `${(+x.roll_remaining).toFixed(1)} / ${(+x.roll_length).toFixed(0)} م` : 'بدون رولو'}</span></div>
            <div class="bar" class:low class:ok={!low && p > 0}><i style="width:{p}%"></i></div>
            <div class="faint tiny">{x.roll_code ? `الرولو ${x.roll_code} · اضغط لتغييره` : 'اضغط لتركيب رولو'}</div>
          </button>
        {:else}<div class="empty small">أضف الآلات من صفحة «الآلات»</div>{/each}
      </div>
      <div class="col" style="margin-top:14px">
        {#if mgr}<button class="btn" on:click={() => openModal(BuyRolls)}><Icon name="plus" size={18} />تسجيل شراء رولوات</button>{/if}
        <button class="btn quiet" on:click={() => openModal(Waste)}><Icon name="scissors" size={18} />تسجيل هدر أو تجربة</button>
      </div>
    </div>
    <div class="card table-wrap">
      <div class="section-title">الرولوات</div>
      <table>
        <tr><th>الرقم</th><th>الحالة</th><th>المتبقي</th><th></th>{#if mgr}<th>السعر</th>{/if}<th>المورّد</th><th>الشراء</th></tr>
        {#each d.rolls as r (r.id)}{@const p = (r.remaining_m / r.length_m) * 100}
          <tr><td><b>{num(r.code)}</b></td><td>{ST[r.status]}{#if r.status === 'active' && r.machine_id}<div class="faint tiny">{mname(r.machine_id)}</div>{/if}</td><td class="ltr">{(+r.remaining_m).toFixed(1)} / {(+r.length_m).toFixed(0)}</td>
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
      <tr><th>التاريخ</th><th>النوع</th><th>الأمتار</th><th>الآلة</th><th>الرولو</th><th>الطلبية</th><th>بواسطة</th><th>ملاحظة</th></tr>
      {#each d.moves as x (x.id)}
        <tr><td class="muted small">{dt(x.created_at)}</td><td>{KIND[x.kind]}</td><td><b>{m(x.meters)}</b></td><td>{x.mach?.name || '—'}</td><td>{x.roll ? num(x.roll.code) : '—'}</td><td>{x.ord ? num(x.ord.code) : ''}</td><td>{staffName(x.actor_id)}</td><td class="muted small">{x.note || ''}</td></tr>
      {/each}
    </table>
    {#if !d.moves.length}<div class="empty">لا توجد حركات بعد</div>{/if}
  </div>
{/if}

<style>
  .split { grid-template-columns: 320px 1fr; }
  .mr { display: flex; flex-direction: column; gap: 6px; text-align: right; padding: 11px; border-radius: 12px; background: var(--bg2); border: 1px solid var(--line); }
  .mr:hover { border-color: var(--accent-line); }
  @media (max-width: 900px) { .split { grid-template-columns: 1fr; } }
</style>
