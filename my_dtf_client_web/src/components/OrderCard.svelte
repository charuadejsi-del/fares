<script>
  import { da, m, num, date } from '../lib/fmt.js';
  import Chip from './Chip.svelte';
  export let o;
  const STEPS = ['new', 'in_design', 'ready_to_print', 'printing', 'done', 'end'];
  const pos = s => s === 'new' ? 0 : s === 'in_design' ? 1 : s === 'ready_to_print' ? 2 : s === 'printing' ? 3 : ['printed', 'ready_pickup'].includes(s) ? 4 : s === 'shipped' ? 4.5 : s === 'delivered' ? 5 : -1;
  $: p = pos(o.status);
</script>
<a class="oc" href="#/order/{o.id}">
  <div class="row between"><b>طلبية {num(o.code)}</b><Chip status={o.status} /></div>
  <div class="row between small"><span class="muted">{m(o.billed_meters)} · {date(o.created_at)}</span><b class="accent">{da(+o.print_amount + +o.delivery_fee)}</b></div>
  {#if p >= 0 && p < 5}<div class="steps">{#each STEPS.slice(0, 5) as _, i}<i class:on={i <= p}></i>{/each}</div>{/if}
</a>
<style>
  .oc { display: flex; flex-direction: column; gap: 8px; padding: 14px; border-radius: 16px; background: var(--card); border: 1px solid var(--line); color: var(--text); }
  .oc:hover { border-color: var(--accent-line); }
  .steps { display: flex; gap: 4px; } .steps i { flex: 1; height: 5px; border-radius: 5px; background: var(--card3); } .steps i.on { background: linear-gradient(90deg, var(--accent), var(--accent2)); }
</style>
