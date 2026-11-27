<script>
  // Interrupteur « l'atelier travaille / fermé » — administrateur et gérant.
  import { rpc, q, sb, errMsg } from '../lib/sb.js';
  import { me, settings, toast } from '../lib/store.js';
  import { time } from '../lib/fmt.js';
  export let compact = false;
  let asking = false, note = '', busy = false;
  $: can = ['admin', 'manager'].includes($me?.role);
  $: open = $settings?.is_open !== false;
  async function set(v) {
    busy = true;
    try {
      await rpc('dtf_set_open', { p_open: v, p_note: v ? null : note });
      settings.set(await q(sb.from('dtf_settings').select('*').single()));
      toast(v ? 'الورشة تعمل الآن — يرى الزبائن ذلك' : 'الورشة مغلقة — يرى الزبائن ذلك');
      asking = false; note = '';
    } catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
</script>
{#if can}
  <div class="wrap">
    <button class="tg" class:open class:compact disabled={busy} on:click={() => (open ? (asking = !asking) : set(true))} title={$settings?.open_changed_at ? 'منذ ' + time($settings.open_changed_at) : ''}>
      <span class="sw"><i></i></span>
      <span>{open ? 'الورشة تعمل' : 'الورشة مغلقة'}</span>
    </button>
    {#if asking}
      <div class="pop card">
        <b>إغلاق الورشة؟</b>
        <div class="faint tiny" style="margin:4px 0 8px">يرى الزبائن أن الورشة مغلقة، ويمكنهم إرسال طلبياتهم وتُعالج عند الفتح.</div>
        <input bind:value={note} placeholder="رسالة للزبائن (اختياري): نعود غداً 08:00" />
        <div class="row" style="margin-top:10px"><button class="btn danger sm grow" disabled={busy} on:click={() => set(false)}>إغلاق</button><button class="btn quiet sm" on:click={() => (asking = false)}>إلغاء</button></div>
      </div>
    {/if}
  </div>
{/if}
<style>
  .wrap { position: relative; }
  .tg { display: inline-flex; align-items: center; gap: 10px; padding: 7px 14px 7px 10px; border-radius: 999px; font-weight: 600; font-size: 13.5px;
    background: #F871711A; border: 1px solid #F8717155; color: var(--red); white-space: nowrap; }
  .tg.open { background: #4ADE801A; border-color: #4ADE8055; color: var(--green); }
  .tg.compact { padding: 6px 10px; font-size: 12.5px; }
  .sw { width: 38px; height: 22px; border-radius: 999px; background: #F8717140; position: relative; flex-shrink: 0; transition: background .2s; }
  .sw i { position: absolute; top: 3px; right: 3px; width: 16px; height: 16px; border-radius: 50%; background: var(--red); transition: right .2s, background .2s; }
  .open .sw { background: #4ADE8040; }
  .open .sw i { right: 19px; background: var(--green); box-shadow: 0 0 0 0 #4ADE8088; animation: pulse 1.8s infinite; }
  .pop { position: absolute; z-index: 60; top: calc(100% + 8px); left: 0; width: 290px; padding: 14px; }
</style>
