<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast, board, myMachine, loadBoard } from '../lib/store.js';
  export let machine = null;
  let mid = machine || $myMachine || '', meters = '', note = '', err = '', busy = false;
  const REASONS = ['تجربة ألوان', 'خطأ في الطباعة', 'تنظيف الرأس', 'فيلم تالف'];
  $: list = ($board || []).filter(x => x.active);
  $: if (!mid && list.length) mid = list[0].id;
  async function save() {
    busy = true; err = '';
    try {
      await rpc('dtf_record_waste', { p_meters: +String(meters).replace(',', '.'), p_note: note || null, p_machine: mid });
      toast('سُجّل الهدر وخُصم من رولو الآلة'); await loadBoard(); liveTick.update(n => n + 1); closeModal();
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<h2>تسجيل هدر أو تجربة</h2>
<label for="wmc">الآلة</label>
<select id="wmc" bind:value={mid}>{#each list as x}<option value={x.id}>{x.name}{x.roll_code ? ` — الرولو ${x.roll_code}` : ''}</option>{/each}</select>
<label for="wm">عدد الأمتار</label>
<div class="row wrap">{#each [0.5, 1, 2] as v}<button class="btn quiet sm" class:sel={+meters === v} on:click={() => (meters = String(v))}><span class="num">{v}</span> م</button>{/each}
  <input id="wm" class="grow" style="min-width:100px" inputmode="decimal" dir="ltr" placeholder="أو اكتب" bind:value={meters} /></div>
<label for="wn">السبب</label>
<div class="row wrap" style="margin-bottom:8px">{#each REASONS as r}<button class="btn quiet sm" class:sel={note === r} on:click={() => (note = r)}>{r}</button>{/each}</div>
<input id="wn" bind:value={note} placeholder="سبب آخر..." />
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy || !mid || !(+String(meters).replace(',', '.') > 0)} on:click={save}>خصم من الرولو</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
<style>.sel { border-color: var(--accent) !important; color: var(--accent3) !important; background: var(--accent-soft) !important; }</style>
