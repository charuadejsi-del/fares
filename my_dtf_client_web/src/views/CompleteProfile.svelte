<script>
  import { createEventDispatcher, onMount } from 'svelte';
  import { errMsg } from '../lib/sb.js';
  import { createProfile } from '../lib/api.js';
  import { loadShip } from '../lib/ship.js';
  import Picker from '../components/Picker.svelte';
  const dispatch = createEventDispatcher();
  let name = '', phone = '', wilaya = null, commune = null, address = '', err = '', busy = false, dz = null;
  onMount(async () => (dz = await loadShip()));
  $: communes = dz && wilaya ? dz.communes.filter(c => c.w === wilaya.c) : [];
  $: if (wilaya && commune && commune.w !== wilaya.c) commune = null;
  async function save() {
    busy = true; err = '';
    try {
      if (!name.trim() || phone.replace(/\D/g, '').length < 9) throw new Error('اكتب اسمك ورقم هاتف صحيح');
      await createProfile({ full_name: name.trim(), phone: phone.trim(), wilaya: wilaya?.fr || null, commune: commune?.fr || null, address: address.trim() || null });
      dispatch('done');
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
<div class="center"><div class="card" style="width:min(440px,100%);padding:26px">
  <h2>أكمل معلوماتك</h2><p class="muted small">مرة واحدة فقط، لنتواصل معك ونوصل طلبياتك.</p>
  <label for="n">الاسم الكامل</label><input id="n" bind:value={name} />
  <label for="p">رقم الهاتف</label><input id="p" dir="ltr" inputmode="tel" bind:value={phone} />
  {#if dz}<div class="grid g2"><Picker label="الولاية" items={dz.wilayas} bind:value={wilaya} hint={dz.live ? 'الولايات التي تصلها شركة التوصيل، مع سعر المكتب والمنزل' : ''} /><Picker label="البلدية" items={communes} bind:value={commune} disabled={!wilaya} hint={dz.live ? '«فيها مكتب»: يمكنك الاستلام من مكتب الشركة · «منزل فقط»: التوصيل إلى البيت' : ''} /></div>
    {#if wilaya?.sub}<div class="faint tiny" style="margin-top:6px">التوصيل إلى {wilaya.ar}: {wilaya.sub}{wilaya.hasDesk ? '' : ' — لا يوجد مكتب في هذه الولاية'}</div>{/if}{/if}
  <label for="a">العنوان</label><input id="a" bind:value={address} />
  {#if err}<p class="red small" style="margin-top:8px">{err}</p>{/if}
  <button class="btn lg block" style="margin-top:16px" disabled={busy} on:click={save}>متابعة</button>
  <button class="btn quiet sm block" style="margin-top:8px" on:click={() => dispatch('logout')}>الخروج</button>
</div></div>
