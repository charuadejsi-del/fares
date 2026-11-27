<script>
  // Poste d'impression : choisir sa machine, prendre un fichier du tableau commun, chronométrer, gérer le rouleau.
  import { rpc, errMsg } from '../lib/sb.js';
  import { me, board, myMachine, liveTick, openSheet, openModal, toast, loadBoard } from '../lib/store.js';
  import { m, num, dur, minsSince } from '../lib/fmt.js';
  import { orderThumbs } from '../lib/thumbs.js';
  import MachineCard from '../components/MachineCard.svelte';
  import LiveTimer from '../components/LiveTimer.svelte';
  import Thumbs from '../components/Thumbs.svelte';
  import Icon from '../components/Icon.svelte';
  import OrderSheet from './OrderSheet.svelte';
  import MachineSheet from './MachineSheet.svelte';
  import Waste from './Waste.svelte';

  let list = null, th = {}, busy = '';
  async function load() {
    try {
      const [w] = await Promise.all([rpc('dtf_work_orders'), loadBoard()]);
      list = w; th = await orderThumbs(w.filter(o => ['ready_to_print', 'printing'].includes(o.status)).map(o => o.id));
    } catch (e) { toast(errMsg(e), true); list = list || []; }
  }
  $: $liveTick, load();
  $: machines = ($board || []).filter(x => x.active);
  $: if (machines.length && !machines.find(x => x.id === $myMachine)) myMachine.set(machines[0].id);
  $: cur = machines.find(x => x.id === $myMachine);
  $: queue = (list || []).filter(o => o.status === 'ready_to_print');
  $: mine = (list || []).filter(o => o.status === 'printing' && o.printer_id === $me.id);
  $: done = (list || []).filter(o => ['printed', 'ready_pickup'].includes(o.status) && o.printer_id === $me.id && new Date(o.updated_at).toDateString() === new Date().toDateString());
  $: doneM = done.reduce((s, o) => s + +o.billed_meters, 0);
  $: need = queue.reduce((s, o) => s + +o.billed_meters, 0);
  $: blocked = cur && (cur.status === 'down' || cur.status === 'maintenance');
  const mName = id => machines.find(x => x.id === id)?.name || '';

  async function start(o) {
    if (!cur) return toast('اختر الآلة أولاً', true);
    if (cur.roll_code && +o.billed_meters > +cur.roll_remaining && !confirm(`الرولو فيه ${(+cur.roll_remaining).toFixed(1)} م فقط والطلبية تحتاج ${(+o.billed_meters).toFixed(2)} م. سيُكمل من الرولو التالي تلقائياً. متابعة؟`)) return;
    busy = o.id;
    try { await rpc('dtf_start_printing', { p_order: o.id, p_machine: cur.id }); toast(`بدأت الطباعة على ${cur.name} وخُصم ${(+o.billed_meters).toFixed(2)} م`); liveTick.update(n => n + 1); }
    catch (e) { toast(errMsg(e), true); }
    busy = '';
  }
  async function finish(o) {
    busy = o.id;
    try { await rpc('dtf_finish_printing', { p_order: o.id }); toast('انتهت الطباعة'); liveTick.update(n => n + 1); }
    catch (e) { toast(errMsg(e), true); }
    busy = '';
  }
</script>

{#if !list}<div class="spinner"></div>
{:else if !machines.length}
  <div class="card empty"><Icon name="machine" size={38} /><h3 style="margin-top:8px">لا توجد آلة مسجّلة</h3><div class="small">اطلب من المدير إضافة الآلات من صفحة «الآلات».</div></div>
{:else}
  <div class="pick">
    <span class="muted small">آلتي:</span>
    {#each machines as x}<button class="mp" class:on={x.id === $myMachine} on:click={() => myMachine.set(x.id)}><span class="dot {x.status === 'running' ? 'run' : x.status === 'down' ? 'down' : x.status === 'maintenance' ? 'maint' : 'idle'}"></span>{x.name}</button>{/each}
  </div>

  <div class="station">
    <div class="col">
      {#if cur}<MachineCard x={cur} big selected on:open={() => openSheet(MachineSheet, { id: cur.id })} />{/if}
      <div class="grid g2">
        <button class="btn quiet lg" on:click={() => openSheet(MachineSheet, { id: cur.id })}><Icon name="roll" size={20} />الرولو والحالة</button>
        <button class="btn quiet lg" on:click={() => openModal(Waste, { machine: cur?.id })}><Icon name="scissors" size={20} />هدر</button>
      </div>
      <div class="card stats">
        <div><span class="faint tiny">طبعت اليوم</span><b class="num">{done.length}</b><span class="faint tiny">{m(doneM, 1)}</span></div>
        <div><span class="faint tiny">في الطابور</span><b class="num">{queue.length}</b><span class="faint tiny">{m(need, 1)}</span></div>
        <div><span class="faint tiny">عندي الآن</span><b class="num green">{mine.length}</b><span class="faint tiny">ملف</span></div>
      </div>
      {#if cur?.roll_code && need > +cur.roll_remaining}<div class="notice warn small">الطابور يحتاج {m(need, 1)} ورولو {cur.name} فيه {m(cur.roll_remaining, 1)} — جهّز الرولو التالي.</div>{/if}
      {#if cur && !cur.roll_code}<div class="notice warn small">لا يوجد رولو مركّب على {cur.name}. ركّب رولو قبل الطباعة.</div>{/if}
    </div>

    <div class="col">
      {#if mine.length}
        <div class="section-title">قيد الطباعة عندي</div>
        {#each mine as o (o.id)}
          <div class="tile live">
            <Thumbs list={th[o.id]} max={3} h={58} />
            <div class="grow"><b>طلبية {num(o.code)}</b><div class="muted small">{m(o.billed_meters)} · {mName(o.machine_id)}</div></div>
            <div class="timer"><LiveTimer since={o.print_started_at || o.updated_at} /></div>
            <button class="btn ok lg" disabled={busy === o.id} on:click={() => finish(o)}><Icon name="check" size={20} />انتهت</button>
          </div>
        {/each}
      {/if}
      <div class="section-title" style="margin-top:6px">طابور الطباعة<span class="end faint small">مشترك بين كل الطابعين</span></div>
      {#each queue as o, i (o.id)}
        <div class="tile" class:first={i === 0}>
          <button class="tb" on:click={() => openSheet(OrderSheet, { id: o.id, work: true })}><Thumbs list={th[o.id]} max={3} h={58} /></button>
          <div class="grow"><b>طلبية {num(o.code)}</b> <span class="faint tiny">{o.client_name}</span>
            <div class="muted small"><b class="accent">{m(o.billed_meters)}</b> · ينتظر منذ {dur(minsSince(o.updated_at))}</div>
            {#if o.client_note}<div class="faint tiny note">{o.client_note}</div>{/if}</div>
          <button class="btn lg" disabled={busy === o.id || blocked || !cur} on:click={() => start(o)}><Icon name="play" size={18} />اطبع على {cur?.name || '...'}</button>
        </div>
      {:else}<div class="card empty"><Icon name="check" size={28} /><div>الطابور فارغ</div></div>{/each}
      {#if blocked}<div class="notice bad small">{cur.name} في {cur.status === 'down' ? 'عطل' : 'صيانة'} — اختر آلة أخرى أو أعدها للعمل.</div>{/if}
    </div>
  </div>
{/if}

<style>
  .pick { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 14px; }
  .mp { display: inline-flex; align-items: center; gap: 8px; padding: 9px 16px; border-radius: 999px; background: var(--card); border: 1px solid var(--line); font-weight: 600; }
  .mp.on { border-color: var(--accent); background: var(--accent-soft); color: var(--accent3); }
  .station { display: grid; grid-template-columns: 360px 1fr; gap: 16px; align-items: start; }
  @media (max-width: 1000px) { .station { grid-template-columns: 1fr; } }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; text-align: center; }
  .stats > div { display: flex; flex-direction: column; } .stats b { font-size: 24px; }
  .tile { display: flex; align-items: center; gap: 14px; padding: 12px; border-radius: 16px; background: var(--card); border: 1px solid var(--line); }
  .tile.first { border-color: var(--accent-line); }
  .tile.live { border-color: #4ADE8055; background: linear-gradient(90deg, #4ADE800D, var(--card)); }
  .tb { flex-shrink: 0; }
  .timer { font-size: 24px; font-weight: 700; color: var(--green); }
  .note { max-width: 360px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  @media (max-width: 640px) { .tile { flex-wrap: wrap; } .tile .btn { width: 100%; } }
</style>
