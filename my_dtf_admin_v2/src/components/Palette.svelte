<script>
  // Recherche rapide (Ctrl+K) : pages du menu + ouverture d'une commande par son numéro.
  import { createEventDispatcher, tick } from 'svelte';
  import { sb, q, errMsg } from '../lib/sb.js';
  import { openSheet, toast } from '../lib/store.js';
  import Icon from './Icon.svelte';
  import OrderSheet from '../views/OrderSheet.svelte';
  export let nav = [];
  const dispatch = createEventDispatcher();
  let text = '', sel = 0, input;
  tick().then(() => input?.focus());

  $: t = text.trim();
  $: items = [
    ...(/^\d+$/.test(t) ? [{ kind: 'order', icon: 'orders', t: `فتح الطلبية رقم ${t}`, code: +t }] : []),
    ...nav.filter(n => !t || n.t.includes(t)).map(n => ({ kind: 'page', icon: n.icon, t: n.t, id: n.id })),
  ];
  $: if (sel >= items.length) sel = 0;

  async function go(it) {
    if (!it) return;
    dispatch('close');
    if (it.kind === 'page') { location.hash = it.id; return; }
    try {
      const o = await q(sb.from('dtf_orders').select('id').eq('code', it.code).limit(1).maybeSingle());
      if (!o) return toast(`لا توجد طلبية بالرقم ${it.code}`, true);
      openSheet(OrderSheet, { id: o.id });
    } catch (e) { toast(errMsg(e), true); }
  }
  function key(e) {
    if (e.key === 'ArrowDown') { sel = (sel + 1) % Math.max(1, items.length); e.preventDefault(); }
    else if (e.key === 'ArrowUp') { sel = (sel - 1 + items.length) % Math.max(1, items.length); e.preventDefault(); }
    else if (e.key === 'Enter') go(items[sel]);
    else if (e.key === 'Escape') dispatch('close');
  }
</script>

<div class="back" on:click|self={() => dispatch('close')} role="presentation">
  <div class="pal card">
    <div class="in row"><Icon name="search" size={18} /><input bind:this={input} bind:value={text} on:keydown={key} placeholder="ابحث عن صفحة، أو اكتب رقم الطلبية…" /><kbd>Esc</kbd></div>
    <div class="res">
      {#each items as it, i}
        <button class="it row" class:on={i === sel} on:mouseenter={() => (sel = i)} on:click={() => go(it)}><Icon name={it.icon} size={18} /><span class="grow">{it.t}</span>{#if it.kind === 'page'}<span class="faint tiny">صفحة</span>{/if}</button>
      {:else}<div class="empty small">لا توجد نتيجة</div>{/each}
    </div>
  </div>
</div>

<style>
  .back { position: fixed; inset: 0; z-index: 120; background: #05070Bcc; backdrop-filter: blur(4px); display: grid; justify-items: center; align-items: start; padding: 12vh 16px 0; animation: fadeIn .15s; }
  .pal { width: min(560px, 100%); padding: 0; overflow: hidden; animation: rise .3s var(--spring); }
  .in { padding: 4px 14px; border-bottom: 1px solid var(--line); color: var(--muted); }
  .in input { border: 0; background: none; box-shadow: none; padding: 14px 4px; font-size: 15.5px; }
  .res { max-height: 50vh; overflow-y: auto; padding: 6px; }
  .it { width: 100%; padding: 10px 12px; border-radius: 10px; color: var(--muted); text-align: right; }
  .it.on { background: var(--accent-soft); color: var(--accent2); }
</style>
