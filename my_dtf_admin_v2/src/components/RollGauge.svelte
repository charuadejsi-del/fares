<script>
  import { m } from '../lib/fmt.js';
  export let s; // ligne dtf_stock_summary
  $: pct = s?.active_code ? Math.max(0, Math.min(100, (s.active_remaining_m / s.active_length_m) * 100)) : 0;
  $: low = s?.active_code && +s.active_remaining_m <= +s.alert_m;
</script>
{#if !s?.active_code}
  <div class="empty">لا يوجد رولو مركّب</div>
{:else}
  <div class="ring" style="--p:{pct * 3.6}deg; --c:{low ? 'var(--red)' : 'var(--gold)'}">
    <div class="in">
      <div class="faint tiny">الرولو رقم {s.active_code}</div>
      <div class="big" class:red={low}>{(+s.active_remaining_m).toFixed(1)}</div>
      <div class="faint tiny">متر من أصل {(+s.active_length_m).toFixed(0)}</div>
    </div>
  </div>
  <div class="row between small" style="margin-top:12px"><span class="muted">المجموع في المخزون</span><b>{@html m(s.total_remaining_m, 1)}</b></div>
  {#if low}<div class="notice bad small" style="margin-top:10px">الرولو قارب على الانتهاء — جهّز الرولو التالي.</div>{/if}
{/if}
<style>
  .ring { width: 150px; height: 150px; margin: 4px auto; border-radius: 50%; display: grid; place-items: center;
    background: conic-gradient(var(--c) var(--p), var(--card2) 0); }
  .in { width: 122px; height: 122px; border-radius: 50%; background: var(--card); display: grid; place-items: center; text-align: center; align-content: center; }
  .big { font-size: 28px; font-weight: 700; color: var(--gold); line-height: 1.1; direction: ltr; }
  .big.red { color: var(--red); }
</style>
