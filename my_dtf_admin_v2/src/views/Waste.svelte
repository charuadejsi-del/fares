<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast } from '../lib/store.js';
  let meters = '', note = '', err = '', busy = false;
  async function save() {
    busy = true; err = '';
    try { await rpc('dtf_record_waste', { p_meters: +String(meters).replace(',', '.'), p_note: note || null }); toast('سُجّل الهدر'); liveTick.update(n => n + 1); closeModal(); }
    catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<h2>تسجيل هدر أو تجربة</h2>
<label for="wm">عدد الأمتار</label><input id="wm" inputmode="decimal" dir="ltr" bind:value={meters} />
<label for="wn">السبب</label><input id="wn" bind:value={note} placeholder="تجربة ألوان، خطأ في الطباعة..." />
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy || !(+meters > 0)} on:click={save}>خصم من الرولو</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
