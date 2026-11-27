<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast } from '../lib/store.js';
  import { da } from '../lib/fmt.js';
  export let kind; export let mode = 'buy'; export let s = null;
  const ink = kind === 'ink';
  const U = ink ? 'لتر' : 'كغ';
  let qty = '', total = '', supplier = '', note = '', err = '', busy = false;
  let alertV = s ? String(+(s.alert / 1000).toFixed(2)) : '';
  let real = s ? String(+(Math.max(0, s.stock) / 1000).toFixed(2)) : '';
  const n = v => +String(v).replace(',', '.');
  $: unitPrice = n(qty) > 0 && n(total) >= 0 ? n(total) / n(qty) : null;
  async function save() {
    busy = true; err = '';
    try {
      if (mode === 'buy') await rpc('dtf_add_supply', { p_kind: kind, p_qty: n(qty) * 1000, p_total: n(total), p_supplier: supplier, p_note: note });
      else if (mode === 'adjust') await rpc('dtf_adjust_supply', { p_kind: kind, p_real: n(real) * 1000, p_note: note });
      else await rpc('dtf_set_supply_alert', { p_kind: kind, p_alert: n(alertV) * 1000 });
      toast('تمّ'); liveTick.update(x => x + 1); closeModal();
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<h2>{mode === 'buy' ? 'شراء' : mode === 'adjust' ? 'جرد' : 'حدّ التنبيه'} — {ink ? 'الحبر' : 'البودرة'}</h2>
{#if mode === 'buy'}
  <div class="grid g2">
    <div><label for="q">الكمية ({U})</label><input id="q" dir="ltr" inputmode="decimal" bind:value={qty} /></div>
    <div><label for="t">السعر الإجمالي (دج)</label><input id="t" dir="ltr" inputmode="decimal" bind:value={total} /></div>
  </div>
  {#if unitPrice != null}<p class="faint small" style="margin-top:6px">= {da(unitPrice)} لل{U} · يُحدَّث ثمن ال{U} في الحسابات تلقائياً (متوسّط المخزون)</p>{/if}
  <label for="sp">المورّد</label><input id="sp" bind:value={supplier} />
{:else if mode === 'adjust'}
  <label for="r">الكمية الموجودة فعلاً ({U})</label><input id="r" dir="ltr" inputmode="decimal" bind:value={real} />
  <p class="faint small" style="margin-top:6px">يُسجَّل الفرق في السجلّ.</p>
{:else}
  <label for="a">نبّهني عندما يبقى أقل من ({U})</label><input id="a" dir="ltr" inputmode="decimal" bind:value={alertV} />
{/if}
{#if mode !== 'alert'}<label for="nt">ملاحظة</label><input id="nt" bind:value={note} />{/if}
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy} on:click={save}>حفظ</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
