<script>
  import { me, board, liveTick, openSheet, openModal, loadBoard } from '../lib/store.js';
  import { m, num } from '../lib/fmt.js';
  import MachineCard from '../components/MachineCard.svelte';
  import Icon from '../components/Icon.svelte';
  import MachineSheet from './MachineSheet.svelte';
  import MachineForm from './MachineForm.svelte';
  $: $liveTick, loadBoard();
  $: list = $board || [];
  $: admin = $me?.role === 'admin';
  $: tot7 = list.reduce((s, x) => s + +x.meters_7d, 0);
</script>
{#if !$board}<div class="spinner"></div>{:else}
  <div class="row between wrap" style="margin-bottom:14px">
    <div class="muted small">{num(list.filter(x => x.active).length)} آلة في الخدمة · {m(tot7, 1)} مطبوعة في 7 أيام</div>
    {#if admin}<button class="btn" on:click={() => openModal(MachineForm)}><Icon name="plus" size={18} />إضافة آلة</button>{/if}
  </div>
  {#if list.length}
    <div class="wall">{#each list as x (x.id)}<MachineCard {x} on:open={() => openSheet(MachineSheet, { id: x.id })} />{/each}</div>
    <div class="card table-wrap" style="margin-top:14px">
      <div class="section-title">المقارنة</div>
      <table>
        <tr><th>الآلة</th><th>الحالة</th><th>اليوم</th><th>هدر اليوم</th><th>7 أيام</th><th>حصّة الإنتاج</th><th>الرولو</th></tr>
        {#each list as x}<tr class="click" on:click={() => openSheet(MachineSheet, { id: x.id })}>
          <td><b>{x.name}</b><div class="faint tiny">{x.model || ''}</div></td><td><span class="dot {x.status === 'running' ? 'run' : x.status === 'down' ? 'down' : x.status === 'maintenance' ? 'maint' : 'idle'}"></span></td>
          <td>{m(x.meters_today, 1)}</td><td class:amber={+x.waste_today > 0}>{m(x.waste_today, 1)}</td><td><b>{m(x.meters_7d, 1)}</b></td>
          <td style="width:140px"><div class="bar"><i style="width:{tot7 ? (x.meters_7d / tot7) * 100 : 0}%"></i></div></td>
          <td>{x.roll_code ? num(x.roll_code) + ' · ' + m(x.roll_remaining, 1) : '—'}</td></tr>{/each}
      </table>
    </div>
  {:else}
    <button class="card empty addm" on:click={() => admin && openModal(MachineForm)}><Icon name="machine" size={40} /><h3>أضف آلاتك</h3><div class="small">كل آلة لها رولو خاص بها، حالة مباشرة، سجلّ صيانة وإحصائيات.</div></button>
  {/if}
{/if}
<style>
  .wall { display: grid; grid-template-columns: repeat(auto-fill, minmax(290px, 1fr)); gap: 12px; }
  .addm { width: 100%; display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--muted); border-style: dashed; padding: 50px; }
  .click { cursor: pointer; } .click:hover td { background: var(--card2); }
</style>
