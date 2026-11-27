<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { shift, toast, openModal } from '../lib/store.js';
  import { time, dur, minsSince } from '../lib/fmt.js';
  import ClockOut from './ClockOut.svelte';
  let oldPin = '', newPin = '', busy = false;
  async function save() {
    busy = true;
    try { await rpc('dtf_pin_set', { p_new: newPin, p_old: oldPin }); toast('تغيّر رمزك السري'); oldPin = newPin = ''; }
    catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
</script>
<div class="grid g2 stack">
  <div class="card">
    <div class="section-title">اليوم</div>
    {#if $shift?.since}<p>بدأت العمل على الساعة <b class="gold">{time($shift.since)}</b> — منذ {dur(minsSince($shift.since))}</p>
      <button class="btn danger" style="margin-top:12px" on:click={() => openModal(ClockOut, { onDone: () => location.reload() })}>تسجيل الخروج</button>
    {:else}<p class="muted">لم تسجّل دخولك اليوم.</p>{/if}
  </div>
  <div class="card">
    <div class="section-title">تغيير الرمز السري</div>
    <label for="o">الرمز الحالي</label><input id="o" type="password" inputmode="numeric" maxlength="6" dir="ltr" bind:value={oldPin} />
    <label for="n">الرمز الجديد (4 إلى 6 أرقام)</label><input id="n" type="password" inputmode="numeric" maxlength="6" dir="ltr" bind:value={newPin} />
    <button class="btn" style="margin-top:12px" disabled={busy || newPin.length < 4} on:click={save}>حفظ</button>
  </div>
</div>
