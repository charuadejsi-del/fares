<script>
  import { orders } from '../lib/store.js';
  import { cachedOrders } from '../lib/api.js';
  import OrderCard from '../components/OrderCard.svelte';
  export let param = '';
  let filter = 'all', term = '';
  $: list = ($orders.length ? $orders : cachedOrders()).filter(o =>
    (filter === 'all' || (filter === 'open' ? !['delivered', 'rejected', 'cancelled'].includes(o.status) : o.status === 'delivered')) &&
    (!term || String(o.code).includes(term.trim())));
</script>
<div class="row wrap between" style="margin-bottom:12px">
  <div class="seg"><button class:on={filter === 'all'} on:click={() => (filter = 'all')}>الكل</button><button class:on={filter === 'open'} on:click={() => (filter = 'open')}>المفتوحة</button><button class:on={filter === 'done'} on:click={() => (filter = 'done')}>المُسلَّمة</button></div>
  <input style="max-width:220px" placeholder="رقم الطلبية" inputmode="numeric" bind:value={term} />
</div>
{#if list.length}<div class="grid g2 stack">{#each list as o (o.id)}<OrderCard {o} />{/each}</div>
{:else}<div class="card empty">لا توجد طلبيات</div>{/if}
