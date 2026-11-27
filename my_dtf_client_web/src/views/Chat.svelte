<script>
  import { onMount, afterUpdate } from 'svelte';
  import { messages, orders, settings, toast } from '../lib/store.js';
  import { sendMessage, markChatRead, loadAll } from '../lib/api.js';
  import { errMsg } from '../lib/sb.js';
  import { dt, num } from '../lib/fmt.js';
  import ShopStatus from '../components/ShopStatus.svelte';
  export let param = '';
  let text = '', orderId = sessionStorage.getItem('chatOrder') || '', busy = false, box;
  sessionStorage.removeItem('chatOrder');
  onMount(markChatRead);
  $: $messages.length, markChatRead();
  afterUpdate(() => { if (box) box.scrollTop = box.scrollHeight; });
  $: codes = Object.fromEntries($orders.map(o => [o.id, o.code]));
  async function send() {
    if (!text.trim()) return; busy = true;
    try { await sendMessage(text.trim(), orderId || null); text = ''; await loadAll(); } catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
</script>
<div class="chat card">
  {#if $settings?.is_open === false}<ShopStatus detail="قد يتأخر الرد حتى فتح الورشة" />{/if}
  <div class="msgs" bind:this={box}>
    {#each $messages as x (x.id)}
      <div class="m" class:mine={!x.from_staff}><div class="b">{#if x.order_id}<div class="tiny faint">طلبية {num(codes[x.order_id] || '')}</div>{/if}{x.body}<div class="tiny faint t">{dt(x.created_at)}</div></div></div>
    {:else}<div class="empty">مرحباً بك 👋 اكتب لنا أي سؤال، ونردّ عليك هنا.</div>{/each}
  </div>
  <div class="row compose">
    <select style="width:auto;max-width:150px" bind:value={orderId}><option value="">بدون طلبية</option>{#each $orders as o}<option value={o.id}>طلبية {o.code}</option>{/each}</select>
    <input class="grow" placeholder="اكتب رسالتك..." bind:value={text} on:keydown={e => e.key === 'Enter' && send()} />
    <button class="btn" disabled={busy || !text.trim()} on:click={send}>إرسال</button>
  </div>
</div>
<style>
  .chat { display: flex; flex-direction: column; gap: 10px; height: calc(100vh - 160px); min-height: 420px; }
  .msgs { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 4px; }
  .m { display: flex; justify-content: flex-end; } .m.mine { justify-content: flex-start; }
  .b { max-width: 78%; padding: 10px 13px; border-radius: 16px 16px 16px 4px; background: var(--card2); white-space: pre-wrap; }
  .mine .b { border-radius: 16px 16px 4px 16px; background: linear-gradient(180deg, #F5CD52, #DCA414); color: var(--accent-ink); }
  .mine .faint { color: #ffffffaa; } .t { margin-top: 4px; }
  @media (max-width: 800px) { .chat { height: calc(100vh - 190px); } .compose select { display: none; } }
</style>
