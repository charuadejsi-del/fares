<script>
  // Espace designer / imprimeur : aucune information de prix.
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { me, liveTick, openSheet, openModal, toast } from '../lib/store.js';
  import { m, cm, num, dur, minsSince } from '../lib/fmt.js';
  import Kpi from '../components/Kpi.svelte';
  import Chip from '../components/Chip.svelte';
  import RollGauge from '../components/RollGauge.svelte';
  import OrderSheet from './OrderSheet.svelte';
  import Waste from './Waste.svelte';

  let list = null, stock = null, busy = '';
  $: printer = $me?.role === 'printer';
  async function load() {
    try {
      list = await rpc('dtf_work_orders');
      if (printer) stock = await q(sb.from('dtf_stock_summary').select('*').single());
    } catch (e) { toast(errMsg(e), true); list = list || []; }
  }
  $: $liveTick, load();
  $: todo = (list || []).filter(o => printer ? o.status === 'ready_to_print' : o.status === 'in_design');
  $: mine = (list || []).filter(o => printer && o.status === 'printing' && o.printer_id === $me.id);
  $: doneToday = (list || []).filter(o => printer && ['printed', 'ready_pickup'].includes(o.status) && o.printer_id === $me.id && new Date(o.updated_at).toDateString() === new Date().toDateString());
  $: sent = (list || []).filter(o => !printer && o.status !== 'in_design');
  $: need = todo.reduce((s, o) => s + +o.billed_meters, 0);

  async function quick(kind, o) {
    busy = o.id;
    try {
      await rpc(kind === 'start' ? 'dtf_start_printing' : 'dtf_finish_printing', { p_order: o.id });
      toast(kind === 'start' ? 'بدأت الطباعة وخُصم الفيلم' : 'انتهت الطباعة');
      liveTick.update(n => n + 1);
    } catch (e) { toast(errMsg(e), true); }
    busy = '';
  }
  async function newRoll() {
    if (!confirm('تركيب الرولو التالي من المخزون؟ سيُعتبر الرولو الحالي منتهياً.')) return;
    try { const r = await rpc('dtf_activate_roll', {}); toast(`رُكّب الرولو رقم ${r.code}`); liveTick.update(n => n + 1); }
    catch (e) { toast(errMsg(e), true); }
  }
  const open = o => openSheet(OrderSheet, { id: o.id, work: true });
</script>

{#if !list}<div class="spinner"></div>
{:else if printer}
  <div class="grid g3">
    <Kpi label="في الطابور" value={num(todo.length)} sub="ملف · {m(need, 1)}" />
    <Kpi label="قيد الطباعة عندي" value={num(mine.length)} sub="ملف" />
    <Kpi label="طبعت اليوم" value={num(doneToday.length)} sub="ملف" />
  </div>
  <div class="grid split" style="margin-top:12px">
    <div class="card">
      <div class="section-title">الرولو الحالي</div>
      <RollGauge s={stock} />
      <div class="row" style="margin-top:12px"><button class="btn quiet sm grow" on:click={newRoll}>تركيب رولو جديد</button><button class="btn quiet sm grow" on:click={() => openModal(Waste)}>تسجيل هدر</button></div>
      {#if stock?.active_code && need > +stock.active_remaining_m}<div class="notice small" style="margin-top:10px">الطابور يحتاج {m(need, 1)} والرولو فيه {m(stock.active_remaining_m, 1)} فقط.</div>{/if}
    </div>
    <div class="col">
      {#if mine.length}
        <div class="card"><div class="section-title">قيد الطباعة</div>
          <div class="list">{#each mine as o (o.id)}
            <div class="item row"><div class="grow"><b>طلبية {num(o.code)}</b><div class="muted small">{m(o.billed_meters)} · منذ {dur(minsSince(o.updated_at))}</div></div>
              <button class="btn quiet sm" on:click={() => open(o)}>الصور</button>
              <button class="btn sm" disabled={busy === o.id} on:click={() => quick('finish', o)}>انتهت</button></div>{/each}</div></div>
      {/if}
      <div class="card"><div class="section-title">طابور الطباعة</div>
        {#if todo.length}<div class="list">{#each todo as o (o.id)}
          <div class="item row"><div class="grow"><b>طلبية {num(o.code)}</b><div class="muted small">{m(o.billed_meters)} · ينتظر منذ {dur(minsSince(o.updated_at))}</div></div>
            <button class="btn quiet sm" on:click={() => open(o)}>الصور</button>
            <button class="btn sm" disabled={busy === o.id} on:click={() => quick('start', o)}>بدء الطباعة</button></div>{/each}</div>
        {:else}<div class="empty">الطابور فارغ</div>{/if}
      </div>
    </div>
  </div>
{:else}
  <div class="grid g3">
    <Kpi label="ملفات تنتظر التصميم" value={num(todo.length)} sub="ملف" />
    <Kpi label="أرسلتها إلى الطباعة" value={num(sent.length)} sub="ملف لم يُطبع بعد" />
    <Kpi label="أقدم ملف" value={todo.length ? dur(Math.max(...todo.map(o => minsSince(o.updated_at)))) : '—'} sub="مدّة الانتظار" />
  </div>
  <div class="section-title" style="margin-top:18px">ملفاتي</div>
  <div class="grid g3">
    {#each todo as o (o.id)}
      <button class="card job" on:click={() => open(o)}>
        <div class="row between"><h3>طلبية {num(o.code)}</h3><span class="faint small">{dur(minsSince(o.updated_at))}</span></div>
        <div class="muted small">الطول التقديري {cm(o.estimated_length_cm)} · {o.client_name}</div>
        {#if o.client_note}<div class="notice small" style="margin-top:8px">{o.client_note}</div>{/if}
        <span class="btn sm" style="margin-top:10px">فتح الملف</span>
      </button>
    {:else}<div class="card empty">لا توجد ملفات حالياً</div>{/each}
  </div>
  {#if sent.length}
    <div class="section-title" style="margin-top:18px">في الطباعة</div>
    <div class="card list">{#each sent as o (o.id)}<div class="item row between"><b>طلبية {num(o.code)}</b><Chip status={o.status} /></div>{/each}</div>
  {/if}
{/if}

<style>
  .split { grid-template-columns: 300px 1fr; }
  @media (max-width: 900px) { .split { grid-template-columns: 1fr; } }
  .job { text-align: right; width: 100%; }
  .job:hover { border-color: var(--gold); }
</style>
