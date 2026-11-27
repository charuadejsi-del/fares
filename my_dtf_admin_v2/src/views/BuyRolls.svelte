<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast } from '../lib/store.js';
  import { da, m } from '../lib/fmt.js';
  let count = 6, length = 200, price = '', supplier = '', note = '', err = '', busy = false;
  $: total = (+count || 0) * (+length || 0);
  async function save() {
    busy = true; err = '';
    try {
      await rpc('dtf_add_rolls', { p_count: +count, p_length_m: +length, p_unit_price: +price || 0, p_supplier: supplier || null, p_note: note || null });
      toast('أُضيفت الرولوات إلى المخزون'); liveTick.update(n => n + 1); closeModal();
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<h2>تسجيل شراء رولوات</h2>
<div class="grid g2">
  <div><label for="bc">عدد الرولوات</label><input id="bc" inputmode="numeric" dir="ltr" bind:value={count} /></div>
  <div><label for="bl">طول الرولو (متر)</label><input id="bl" inputmode="numeric" dir="ltr" bind:value={length} /></div>
</div>
<label for="bp">سعر الرولو الواحد (دج)</label><input id="bp" inputmode="numeric" dir="ltr" bind:value={price} />
<label for="bs">المورّد</label><input id="bs" bind:value={supplier} />
<label for="bn">ملاحظة</label><input id="bn" bind:value={note} />
<div class="notice small" style="margin-top:12px">المجموع: <b>{m(total, 0)}</b> · <b class="gold">{da((+count || 0) * (+price || 0))}</b> · تكلفة المتر {da((+price || 0) / (+length || 1))}</div>
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy || !(count > 0 && length > 0)} on:click={save}>حفظ</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
