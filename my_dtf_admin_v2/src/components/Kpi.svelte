<script>
  export let label; export let value; export let sub = ''; export let warn = false;
</script>
<div class="card kpi" class:warn>
  <div class="muted small">{label}</div>
  <div class="v" class:red={warn}>{value}</div>
  {#if sub}<div class="faint tiny">{sub}</div>{/if}
</div>
<style>
  .kpi .v { font-size: 24px; font-weight: 700; margin: 4px 0 2px; color: var(--gold); }
  .kpi.warn { border-color: color-mix(in srgb, var(--red) 50%, var(--line)); }
  .kpi .v.red { color: var(--red); }
</style>
