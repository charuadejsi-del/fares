<script>
  import { settings } from '../lib/store.js';
  export let detail = null;
  $: s = $settings; $: open = s?.is_open !== false;
</script>
{#if s}
  <div class="ss" class:open>
    <span class="dot {open ? 'run' : 'down'}"></span>
    <div><b>{open ? 'الورشة تعمل الآن' : 'الورشة مغلقة حالياً'}</b>
      <div class="muted small">{!open && s.open_note ? s.open_note : detail || (open ? 'طلبيتك تُعالج مباشرة' : 'يمكنك إرسال طلبيتك، وتُعالج عند الفتح')}</div></div>
  </div>
{/if}
<style>
  .ss { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-radius: 16px; background: #F871711A; border: 1px solid #F8717155; }
  .ss b { color: var(--red); } .ss.open { background: #4ADE801A; border-color: #4ADE8055; } .ss.open b { color: var(--green); }
</style>
