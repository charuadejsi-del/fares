<script>
  import { CONFIG } from '../config.js';
  import { onMount, createEventDispatcher } from 'svelte';
  import { sb, q, errMsg } from '../lib/sb.js';
  import { me, settings, toast } from '../lib/store.js';
  import { loadShip, findPlace } from '../lib/ship.js';
  import Picker from '../components/Picker.svelte';
  export let param = '';
  const dispatch = createEventDispatcher();
  let p = { ...$me }, dz = null, wilaya = null, commune = null, busy = false;
  onMount(async () => { dz = await loadShip(); ({ wilaya, commune } = findPlace(dz, p.wilaya, p.commune)); });
  $: communes = dz && wilaya ? dz.communes.filter(c => c.w === wilaya.c) : [];
  $: if (wilaya && commune && commune.w !== wilaya.c) commune = null;
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
    {#if dz}<div class="grid g2"><Picker label="الولاية" items={dz.wilayas} bind:value={wilaya} /><Picker label="البلدية" items={communes} bind:value={commune} disabled={!wilaya} /></div>
      {#if wilaya?.sub}<div class="faint tiny" style="margin-top:6px">التوصيل إلى {wilaya.ar}: {wilaya.sub}</div>{/if}
      {#if p.wilaya && dz.live && !wilaya}<div class="notice warn small" style="margin-top:8px">ولايتك المسجّلة ({p.wilaya}) غير موجودة عند شركة التوصيل — اختر من القائمة.</div>{/if}{/if}
    <label for="a">العنوان</label><input id="a" bind:value={p.address} />
    <button class="btn block" style="margin-top:14px" disabled={busy} on:click={save}>حفظ</button>
  </div>
  <div class="card">
    <div class="section-title">الورشة</div>
    <b>{$settings?.workshop_name || CONFIG.appName}</b>
    {#if $settings?.workshop_phone}<div><a class="ltr" href="tel:{$settings.workshop_phone}">{$settings.workshop_phone}</a></div>{/if}
    {#if $settings?.workshop_address}<div class="muted small">{$settings.workshop_address}</div>{/if}
    <div class="faint tiny" style="margin-top:10px">نفس الحساب يعمل في تطبيق الهاتف وفي هذا الموقع.</div>
    <button class="btn danger block" style="margin-top:16px" on:click={() => dispatch('logout')}>الخروج من الحساب</button>
  </div>
</div>
