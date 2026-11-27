<script>
  export let value = 0; export let size = 120; export let stroke = 10; export let color = 'var(--accent)';
  $: r = (size - stroke) / 2; $: c = 2 * Math.PI * r; $: v = Math.max(0, Math.min(1, value || 0));
</script>
<div class="ring" style="width:{size}px;height:{size}px">
  <svg width={size} height={size} viewBox="0 0 {size} {size}">
    <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="var(--card3)" stroke-width={stroke} />
    <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={color} stroke-width={stroke} stroke-linecap="round"
      stroke-dasharray={c} stroke-dashoffset={c * (1 - v)} transform="rotate(-90 {size / 2} {size / 2})" style="transition: stroke-dashoffset .6s" />
  </svg>
  <div class="in"><slot /></div>
</div>
<style>
  .ring { position: relative; flex-shrink: 0; }
  .in { position: absolute; inset: 0; display: grid; place-items: center; text-align: center; align-content: center; }
</style>
