<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast, loadBoard, liveOrphans } from '../lib/store.js';
  export let x = null;
  let name = x?.name || '', width = String(+(x?.width_cm || 60)), model = x?.model || '', active = x ? x.active : true, err = '', busy = false, pe = x?.printexp_id || '';
  async function save() {
    busy = true; err = '';
    try {
      await rpc('dtf_save_machine', { p_id: x?.id || null, p_name: name, p_width: +String(width).replace(',', '.') || 60, p_model: model || null, p_active: active });
      if (x && pe.trim() !== (x.printexp_id || '')) await rpc('dtf_set_printexp_id', { p_machine: x.id, p_key: pe.trim() || null });
      toast(x ? 'حُفظت الآلة' : 'أُضيفت الآلة'); await loadBoard(); liveTick.update(n => n + 1); closeModal();
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<h2>{x ? 'تعديل الآلة' : 'إضافة آلة DTF'}</h2>
<label for="mn">اسم الآلة</label><input id="mn" bind:value={name} placeholder="مثال: الآلة 1" />
<div class="grid g2">
  <div><label for="mw">عرض الطباعة (سم)</label><input id="mw" inputmode="decimal" dir="ltr" bind:value={width} /></div>
  <div><label for="mm">الموديل</label><input id="mm" bind:value={model} placeholder="Epson i3200 ..." /></div>
</div>
{#if x}
  <label for="pe">معرّف الطابعة في PrintExp (للربط مع برنامج الحاسوب)</label>
  <input id="pe" dir="ltr" bind:value={pe} placeholder="AUDLEY-1" list="pe-keys" />
  <datalist id="pe-keys">{#each $liveOrphans as o}<option value={o.printer_key}>{o.printer_name || ''}</option>{/each}</datalist>
  <p class="muted small" style="margin:6px 2px 0">اتركه فارغاً إن لم تكن الآلة موصولة بـ PrintExp. {#if $liveOrphans.length}طابعات تُرسل قراءات ولم تُربط: <b dir="ltr">{$liveOrphans.map(o => o.printer_key).join('، ')}</b>{/if}</p>
{/if}
{#if x}<label class="row" style="gap:8px;margin-top:14px"><input type="checkbox" style="width:auto" bind:checked={active} /> الآلة في الخدمة</label>{/if}
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy || !name.trim()} on:click={save}>حفظ</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
