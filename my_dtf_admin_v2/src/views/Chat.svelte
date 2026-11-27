<script>
  import { onMount, tick } from 'svelte';
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { me, liveTick, staffName, openSheet, toast } from '../lib/store.js';
  import { dt, num } from '../lib/fmt.js';
  import OrderSheet from './OrderSheet.svelte';

  let convs = null, sel = null, msgs = [], client = null, orders = [], text = '', orderId = '', search = '', thread;
  async function loadConvs() { convs = await q(sb.from('dtf_conversations').select('*').order('last_at', { ascending: false })); }
  async function open(cid) {
    sel = cid;
    [msgs, client, orders] = await Promise.all([
      q(sb.from('dtf_messages').select('*').eq('client_id', cid).order('created_at')),
      q(sb.from('dtf_profiles').select('full_name,phone,wilaya').eq('id', cid).maybeSingle()),
      q(sb.from('dtf_orders').select('id,code').eq('client_id', cid).order('created_at', { ascending: false }).limit(20)),
    ]);
    await tick(); if (thread) thread.scrollTop = thread.scrollHeight;
    rpc('dtf_chat_mark_read', { p_client: cid }).then(loadConvs).catch(() => {});
  }
  async function send() {
    const body = text.trim(); if (!body) return;
    text = '';
    try { await q(sb.from('dtf_messages').insert({ client_id: sel, sender_id: $me.id, from_staff: true, body, order_id: orderId || null })); await open(sel); }
    catch (e) { toast(errMsg(e), true); text = body; }
  }
  onMount(() => {
    loadConvs().then(() => { const w = sessionStorage.getItem('chatWith'); if (w) { sessionStorage.removeItem('chatWith'); open(w); } });
    let first = true;
    return liveTick.subscribe(() => { if (first) { first = false; return; } loadConvs(); if (sel) open(sel); });
  });
  $: codes = Object.fromEntries(orders.map(o => [o.id, o.code]));
  $: shown = (convs || []).filter(c => !search || (c.full_name + ' ' + c.phone).toLowerCase().includes(search.toLowerCase()));
</script>

<div class="chat" class:has={sel}>
  <div class="card lst">
    <input placeholder="بحث" bind:value={search} style="margin-bottom:8px" />
    {#if !convs}<div class="spinner"></div>{:else}
      {#each shown as c (c.client_id)}
        <button class="conv" class:on={sel === c.client_id} on:click={() => open(c.client_id)}>
          <div class="row between"><b>{c.full_name}</b>{#if +c.unread}<span class="badge">{c.unread}</span>{:else}<span class="faint tiny">{dt(c.last_at)}</span>{/if}</div>
          <div class="muted small ell">{c.last_body}</div>
        </button>
      {:else}<div class="empty">لا توجد محادثات بعد</div>{/each}
    {/if}
  </div>
  <div class="card pane">
    {#if !sel}<div class="empty" style="margin:auto">اختر محادثة</div>{:else}
      <div class="head row">
        <button class="btn quiet sm back" on:click={() => (sel = null)}>رجوع</button>
        <div class="grow"><b>{client?.full_name}</b><div class="faint tiny"><span class="ltr">{client?.phone}</span> · {client?.wilaya || ''}</div></div>
        {#each orders.slice(0, 3) as o}<button class="btn ghost sm" on:click={() => openSheet(OrderSheet, { id: o.id })}>{num(o.code)}</button>{/each}
      </div>
      <div class="thread" bind:this={thread}>
        {#each msgs as x (x.id)}
          <div class="bub" class:me={x.from_staff}>
            {#if x.order_id}<div class="tiny strong">طلبية {num(codes[x.order_id] || '')}</div>{/if}
            {x.body}
            <div class="meta">{x.from_staff ? staffName(x.sender_id) + ' · ' : ''}{dt(x.created_at)}</div>
          </div>
        {/each}
      </div>
      <div class="compose row">
        <select bind:value={orderId} style="width:120px"><option value="">بدون طلبية</option>{#each orders as o}<option value={o.id}>طلبية {o.code}</option>{/each}</select>
        <textarea rows="1" placeholder="اكتب ردّك..." bind:value={text} on:keydown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } }}></textarea>
        <button class="btn" disabled={!text.trim()} on:click={send}>إرسال</button>
      </div>
    {/if}
  </div>
</div>

<style>
  .chat { display: grid; grid-template-columns: 300px 1fr; gap: 12px; height: calc(100vh - 120px); }
  .lst { overflow-y: auto; padding: 10px; }
  .conv { display: block; width: 100%; text-align: right; padding: 10px; border-radius: 12px; }
  .conv:hover { background: var(--card2); } .conv.on { background: var(--gold-soft); }
  .ell { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pane { display: flex; flex-direction: column; padding: 12px; min-height: 0; }
  .head { padding-bottom: 10px; border-bottom: 1px solid var(--line); }
  .back { display: none; }
  .thread { flex: 1; overflow-y: auto; display: flex; flex-direction: column; gap: 8px; padding: 12px 2px; }
  .bub { max-width: 78%; align-self: flex-end; background: var(--card2); padding: 9px 13px; border-radius: 16px 16px 16px 4px; white-space: pre-wrap; word-break: break-word; }
  .bub.me { align-self: flex-start; background: var(--gold); color: var(--gold-ink); border-radius: 16px 16px 4px 16px; }
  .meta { font-size: 11px; opacity: .7; margin-top: 2px; }
  .strong { font-weight: 700; }
  .compose { border-top: 1px solid var(--line); padding-top: 10px; }
  .compose textarea { resize: none; }
  @media (max-width: 900px) {
    .chat { grid-template-columns: 1fr; height: calc(100vh - 170px); }
    .chat.has .lst { display: none; } .chat:not(.has) .pane { display: none; }
    .back { display: inline-flex; }
  }
</style>
