<script>
  import { onMount } from 'svelte';
  import { notifs } from '../lib/store.js';
  import { markNotifsRead, loadAll } from '../lib/api.js';
  import { dt } from '../lib/fmt.js';
  export let param = '';
  onMount(async () => { try { await markNotifsRead(); await loadAll(); } catch (_) {} });
</script>
<div class="card list">
  {#each $notifs as n (n.id)}
    <a class="item row" href={n.order_id ? '#/order/' + n.order_id : '#/'}><span class="dot" class:run={!n.read}></span><div class="grow"><b>{n.title}</b>{#if n.body}<div class="muted small">{n.body}</div>{/if}</div><span class="faint tiny">{dt(n.created_at)}</span></a>
  {:else}<div class="empty">لا توجد إشعارات</div>{/each}
</div>
<style>.item { color: var(--text); }</style>
