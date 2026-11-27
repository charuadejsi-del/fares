<script>
  // Liste avec recherche (wilaya / commune) — s'ouvre en panneau au-dessus de tout (mobile : feuille plein écran).
  import { match } from '../lib/algeria.js';
  import { tick } from 'svelte';
  export let items = []; export let value = null; export let placeholder = 'اختر...'; export let label = '';
  export let disabled = false; export let hint = '';
  let open = false, term = '', input;
  $: shown = items.filter(x => match(x, term)).slice(0, 120);
  const name = x => `${x.c ? String(x.c).padStart(2, '0') + ' — ' : ''}${x.ar}${x.fr && x.fr !== x.ar ? ' · ' + x.fr : ''}`;
  async function show() { if (disabled) return; open = true; term = ''; await tick(); input?.focus(); }
  const pick = x => { value = x; open = false; };
  const key = e => { if (e.key === 'Escape') open = false; if (e.key === 'Enter' && shown[0]) pick(shown[0]); };
</script>

<div class="pk">
  {#if label}<label>{label}</label>{/if}
  <button type="button" class="field" {disabled} on:click={show}>
    <span class="grow" class:faint={!value}>{value ? name(value) : placeholder}</span>
    {#if value?.tag}<span class="tg" class:dk={value.tag === 'فيها مكتب'}>{value.tag}</span>{/if}<span class="faint">▾</span>
  </button>
</div>

{#if open}
  <div class="back" on:click|self={() => (open = false)} role="presentation">
    <div class="sheet card">
      <div class="hd"><b>{label || 'اختر'}</b><button type="button" class="x" aria-label="إغلاق" on:click={() => (open = false)}>✕</button></div>
      <input bind:this={input} bind:value={term} on:keydown={key} placeholder="اكتب بالعربية أو الفرنسية" />
      {#if hint}<div class="faint tiny" style="margin-top:6px">{hint}</div>{/if}
      <div class="list">
        {#each shown as x}
          <button type="button" class="opt" class:sel={value === x} on:click={() => pick(x)}>
            <span class="grow"><span>{name(x)}</span>{#if x.sub}<span class="faint tiny sb">{x.sub}</span>{/if}</span>
            {#if x.tag}<span class="tg" class:dk={x.tag === 'فيها مكتب'}>{x.tag}</span>{/if}
          </button>
        {:else}<div class="empty small">لا نتيجة</div>{/each}
      </div>
    </div>
  </div>
{/if}

<style>
  .pk { position: relative; min-width: 0; }
  .field { width: 100%; display: flex; gap: 8px; align-items: center; background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 11px 13px; text-align: right; min-width: 0; }
  .field .grow { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .field:disabled { opacity: .5; }
  .back { position: fixed; inset: 0; z-index: 400; background: #05070Bcc; backdrop-filter: blur(4px); display: grid; place-items: center; padding: 16px; animation: fadeIn .15s; }
  .sheet { width: min(520px, 100%); max-height: min(640px, 86vh); display: flex; flex-direction: column; padding: 14px; animation: rise .3s var(--spring); }
  .hd { display: flex; align-items: center; justify-content: space-between; margin-bottom: 10px; }
  .x { width: 34px; height: 34px; border-radius: 10px; color: var(--muted); background: var(--card2); }
  .list { flex: 1; overflow-y: auto; margin-top: 8px; -webkit-overflow-scrolling: touch; }
  .opt { display: flex; align-items: center; gap: 8px; width: 100%; text-align: right; padding: 11px 10px; border-radius: 10px; border-bottom: 1px solid var(--line); }
  .opt:hover, .opt.sel { background: var(--accent-soft); }
  .sb { display: block; margin-top: 2px; }
  .tg { flex-shrink: 0; font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 999px; color: var(--muted); background: #8E95A81A; white-space: nowrap; }
  .tg.dk { color: var(--green); background: #34D3991F; }
  @media (max-width: 640px) {
    .back { place-items: end stretch; padding: 0; }
    .sheet { width: 100%; max-height: 88vh; border-radius: 20px 20px 0 0; padding-bottom: calc(14px + env(safe-area-inset-bottom)); }
  }
</style>
