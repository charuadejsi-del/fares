<script>
  import { sb, q } from '../lib/sb.js';
  import { liveTick, staffName, openSheet } from '../lib/store.js';
  import { da, m, num, dur, minsSince, dt, STATUS } from '../lib/fmt.js';
  import Chip from '../components/Chip.svelte';
  import OrderSheet from './OrderSheet.svelte';

  const COLS = [['new'], ['in_design'], ['ready_to_print'], ['printing'], ['printed', 'ready_pickup'], ['shipped']];
  let list = null, search = '', tab = 'new', showArchive = false, archive = [];
  const SEL = 'id,code,status,billed_meters,print_amount,delivery_fee,delivery_mode,ship_name,ship_wilaya,designer_id,printer_id,created_at,updated_at,amount_paid,client:dtf_profiles!dtf_orders_client_id_fkey(full_name,phone)';
  async function load() {
    list = await q(sb.from('dtf_orders').select(SEL).not('status', 'in', '(delivered,rejected,cancelled)').order('created_at'));
    if (showArchive) archive = await q(sb.from('dtf_orders').select(SEL).in('status', ['delivered', 'rejected', 'cancelled']).order('created_at', { ascending: false }).limit(200));
  }
  $: $liveTick, showArchive, load();
  $: f = (o) => { const s = search.trim().toLowerCase(); return !s || String(o.code).includes(s) || (o.client?.full_name || '').toLowerCase().includes(s) || (o.client?.phone || '').includes(s); };
  $: filtered = (list || []).filter(f);
  $: late = o => { const a = minsSince(o.updated_at); return (o.status === 'new' && a > 60) || (['in_design', 'ready_to_print'].includes(o.status) && a > 240); };
  $: who = o => o.status === 'in_design' ? staffName(o.designer_id) : ['printing', 'printed', 'ready_pickup'].includes(o.status) && o.printer_id ? staffName(o.printer_id) : '';
  const open = o => openSheet(OrderSheet, { id: o.id });
</script>

<div class="row wrap tools">
  <input class="grow search" placeholder="ابحث برقم الطلبية أو اسم الزبون أو الهاتف" bind:value={search} />
  <button class="btn {showArchive ? '' : 'quiet'} sm" on:click={() => (showArchive = !showArchive)}>{showArchive ? 'الطلبيات المفتوحة' : 'الأرشيف'}</button>
</div>

{#if !list}<div class="spinner"></div>
{:else if showArchive}
  <div class="card table-wrap">
    <table>
      <tr><th>الرقم</th><th>الزبون</th><th>الأمتار</th><th>المبلغ</th><th>المدفوع</th><th>الحالة</th><th>التاريخ</th></tr>
      {#each archive.filter(f) as o (o.id)}
        <tr class="click" on:click={() => open(o)}>
          <td><b>{num(o.code)}</b></td><td>{o.client?.full_name || ''}<div class="faint tiny ltr">{o.client?.phone || ''}</div></td>
          <td>{m(o.billed_meters)}</td><td class="gold">{da(+o.print_amount + +o.delivery_fee)}</td><td>{da(o.amount_paid)}</td><td><Chip status={o.status} /></td><td class="muted small">{dt(o.created_at)}</td>
        </tr>
      {/each}
    </table>
    {#if !archive.length}<div class="empty">الأرشيف فارغ</div>{/if}
  </div>
{:else}
  <!-- Téléphone : onglets par étape -->
  <div class="tabs mobile">
    {#each COLS as c}{@const n = filtered.filter(o => c.includes(o.status)).length}
      <button class:on={tab === c[0]} on:click={() => (tab = c[0])}>{STATUS[c[0]][0]}{#if n}<span class="badge">{n}</span>{/if}</button>
    {/each}
  </div>
  <div class="kanban">
    {#each COLS as c}{@const items = filtered.filter(o => c.includes(o.status))}
      <section class="column" class:hide={tab !== c[0]}>
        <h4 class="row"><span class="chip c-{STATUS[c[0]][1]}">{STATUS[c[0]][0]}</span><span class="faint small">{num(items.length)}</span></h4>
        {#each items as o (o.id)}
          <button class="oc" class:late={late(o)} on:click={() => open(o)}>
            <div class="row between"><b>طلبية {num(o.code)}</b><span class="age">{dur(minsSince(o.updated_at))}</span></div>
            <div class="muted small">{o.client?.full_name || o.ship_name || ''} · {m(o.billed_meters)}</div>
            <div class="row between" style="margin-top:6px"><b class="gold">{da(+o.print_amount + +o.delivery_fee)}</b>
              <span class="faint tiny">{o.delivery_mode === 'pickup' ? 'استلام من الورشة' : (o.ship_wilaya || 'توصيل')}</span></div>
            {#if who(o)}<div class="faint tiny" style="margin-top:4px">{who(o)}</div>{/if}
          </button>
        {:else}<div class="empty small">لا شيء</div>{/each}
      </section>
    {/each}
  </div>
{/if}

<style>
  .tools { margin-bottom: 14px; }
  .search { max-width: 460px; }
  .click { cursor: pointer; } .click:hover td { background: var(--card2); }
  .kanban { display: grid; grid-template-columns: repeat(6, minmax(220px, 1fr)); gap: 10px; overflow-x: auto; padding-bottom: 8px; }
  .column { background: var(--bg2); border: 1px solid var(--line); border-radius: 16px; padding: 10px; min-height: 260px; }
  .column h4 { justify-content: space-between; margin: 2px 2px 10px; font-weight: 500; }
  .oc { display: block; width: 100%; text-align: right; background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 11px; margin-bottom: 8px; }
  .oc:hover { border-color: var(--gold); }
  .oc.late { border-right: 3px solid var(--red); }
  .age { font-size: 12px; color: var(--faint); }
  .oc.late .age { color: var(--red); }
  .tabs { display: none; }
  @media (max-width: 900px) {
    .tabs { display: flex; gap: 6px; overflow-x: auto; padding-bottom: 10px; margin: 0 -14px; padding-inline: 14px; }
    .tabs button { white-space: nowrap; padding: 7px 12px; border-radius: 999px; background: var(--card); border: 1px solid var(--line); font-size: 13px; display: flex; gap: 6px; align-items: center; color: var(--muted); }
    .tabs button.on { border-color: var(--gold); color: var(--gold); }
    .kanban { display: block; }
    .column { background: none; border: 0; padding: 0; min-height: 0; }
    .column.hide { display: none; }
    .column h4 { display: none; }
  }
</style>
