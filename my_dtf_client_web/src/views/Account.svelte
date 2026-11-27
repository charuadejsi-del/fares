<script>
  import { onMount, createEventDispatcher } from 'svelte';
  import { sb, q, errMsg } from '../lib/sb.js';
  import { me, settings, toast } from '../lib/store.js';
  import { loadDz } from '../lib/algeria.js';
  import Picker from '../components/Picker.svelte';
  export let param = '';
  const dispatch = createEventDispatcher();
  let p = { ...$me }, dz = null, wilaya = null, commune = null, busy = false;
  onMount(async () => { dz = await loadDz(); wilaya = dz.wilayas.find(w => w.fr === p.wilaya || w.ar === p.wilaya) || null;
    commune = wilaya ? dz.communes.find(c => c.w === wilaya.c && (c.fr === p.commune || c.ar === p.commune)) || null : null; });
  $: communes = dz && wilaya ? dz.communes.filter(c => c.w === wilaya.c) : [];
  async function save() {
    busy = true;
    try {
      const row = await q(sb.from('dtf_profiles').update({ full_name: p.full_name, phone: p.phone, wilaya: wilaya?.fr || null, commune: commune?.fr || null, address: p.address || null }).eq('id', p.id).select().single());
      me.set(row); toast('حُفظت معلوماتك');
    } catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
</script>
<div class="grid g2 stack">
  <div class="card">
    <div class="section-title">معلوماتي</div>
    <label for="n">الاسم</label><input id="n" bind:value={p.full_name} />
    <label for="ph">الهاتف</label><input id="ph" dir="ltr" bind:value={p.phone} />
    {#if dz}<div class="grid g2"><Picker label="الولاية" items={dz.wilayas} bind:value={wilaya} /><Picker label="البلدية" items={communes} bind:value={commune} disabled={!wilaya} /></div>{/if}
    <label for="a">العنوان</label><input id="a" bind:value={p.address} />
    <button class="btn block" style="margin-top:14px" disabled={busy} on:click={save}>حفظ</button>
  </div>
  <div class="card">
    <div class="section-title">الورشة</div>
    <b>{$settings?.workshop_name || 'My DTF'}</b>
    {#if $settings?.workshop_phone}<div><a class="ltr" href="tel:{$settings.workshop_phone}">{$settings.workshop_phone}</a></div>{/if}
    {#if $settings?.workshop_address}<div class="muted small">{$settings.workshop_address}</div>{/if}
    <div class="faint tiny" style="margin-top:10px">نفس الحساب يعمل في تطبيق الهاتف وفي هذا الموقع.</div>
    <button class="btn danger block" style="margin-top:16px" on:click={() => dispatch('logout')}>الخروج من الحساب</button>
  </div>
</div>
