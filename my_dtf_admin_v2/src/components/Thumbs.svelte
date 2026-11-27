<script>
  export let list = []; export let max = 4; export let h = 64;
  $: more = list.length - max;
</script>
<div class="th" style="--h:{h}px">
  {#each list.slice(0, max) as i}<div class="t"><img class="thumb" src={i.url} alt="" loading="lazy" decoding="async" /><span class="q num">×{i.quantity}</span></div>{/each}
  {#if more > 0}<div class="t more num">+{more}</div>{/if}
  {#if !list.length}<div class="t more">—</div>{/if}
</div>
<style>
  .th { display: flex; gap: 6px; }
  .t { position: relative; width: var(--h); height: var(--h); flex-shrink: 0; border-radius: 10px; overflow: hidden; border: 1px solid var(--line); }
  .t img { width: 100%; height: 100%; border-radius: 0; }
  .q { position: absolute; bottom: 2px; left: 2px; font-size: 10px; background: #000a; color: #fff; border-radius: 6px; padding: 0 4px; }
  .more { display: grid; place-items: center; color: var(--muted); background: var(--card2); font-size: 13px; }
</style>
