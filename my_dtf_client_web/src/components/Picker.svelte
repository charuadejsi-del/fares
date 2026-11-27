<script>
  // Liste avec recherche (wilaya / commune).
  import { match } from '../lib/algeria.js';
  export let items = []; export let value = null; export let placeholder = 'ابحث...'; export let label = '';
  export let disabled = false;
  let open = false, term = '';
  $: shown = items.filter(x => match(x, term)).slice(0, 80);
  const pick = x => { value = x; open = false; term = ''; };
</script>
<div class="pk">
  {#if label}<label>{label}</label>{/if}
  <button type="button" class="field" {disabled} on:click={() => (open = !open)}>
    <span class:faint={!value}>{value ? `${value.c ? value.c + ' — ' : ''}${value.ar} · ${value.fr}` : placeholder}</span><span class="faint">▾</span>
  </button>
  {#if open}
    <div class="menu card">
      <!-- svelte-ignore a11y-autofocus -->
      <input autofocus bind:value={term} placeholder="اكتب بالعربية أو الفرنسية" />
      <div class="list">{#each shown as x}<button type="button" class="opt" class:sel={value === x} on:click={() => pick(x)}>{x.c ? x.c + ' — ' : ''}{x.ar} <span class="faint">· {x.fr}</span></button>
        {:else}<div class="empty small">لا نتيجة</div>{/each}</div>
    </div>
  {/if}
</div>
<style>
  .pk { position: relative; }
  .field { width: 100%; display: flex; justify-content: space-between; align-items: center; background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 11px 13px; text-align: right; }
  .field:disabled { opacity: .5; }
  .menu { position: absolute; z-index: 50; top: calc(100% + 6px); left: 0; right: 0; padding: 8px; }
  .list { max-height: 260px; overflow-y: auto; margin-top: 6px; }
  .opt { display: block; width: 100%; text-align: right; padding: 9px 10px; border-radius: 10px; }
  .opt:hover, .opt.sel { background: var(--accent-soft); }
</style>
