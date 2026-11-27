<script>
  import { CONFIG } from '../config.js';
  import { createEventDispatcher, onMount } from 'svelte';
  import { sb, errMsg } from '../lib/sb.js';
  import { myProfile, STAFF_ONLY } from '../lib/api.js';
  import { loadShip } from '../lib/ship.js';
  import Picker from '../components/Picker.svelte';
  export let err = '';
  const dispatch = createEventDispatcher();
  let tab = 'login', email = '', password = '', name = '', phone = '', wilaya = null, commune = null, address = '', busy = false, info = '';
  let dz = null; onMount(async () => (dz = await loadShip()));
  $: communes = dz && wilaya ? dz.communes.filter(c => c.w === wilaya.c) : [];
  $: if (wilaya && commune && commune.w !== wilaya.c) commune = null;
  async function login() {
    busy = true; err = '';
    const { error } = await sb.auth.signInWithPassword({ email: email.trim(), password });
    if (error) { err = errMsg(error); busy = false; return; }
    try { const p = await myProfile(); if (p && p.role !== 'client') { await sb.auth.signOut(); err = STAFF_ONLY; busy = false; return; } } catch (_) {}
    busy = false; dispatch('done');
  }
  async function signup() {
    busy = true; err = ''; info = '';
    const miss = [!name.trim() && 'الاسم', phone.replace(/\D/g, '').length < 9 && 'رقم هاتف صحيح', !wilaya && 'الولاية', !commune && 'البلدية', !email.includes('@') && 'بريد إلكتروني صحيح', password.length < 6 && 'كلمة سر من 6 أحرف على الأقل'].filter(Boolean);
    if (miss.length) { err = 'أكمل: ' + miss.join('، '); busy = false; return; }
    const { data, error } = await sb.auth.signUp({ email: email.trim(), password,
      options: { data: { dtf: { full_name: name.trim(), phone: phone.trim(), wilaya: wilaya?.fr || null, commune: commune?.fr || null, address: address.trim() || null } } } });
    busy = false;
    if (error) { err = errMsg(error); return; }
    if (data.session) dispatch('done');
    else info = 'أُنشئ حسابك. افتح بريدك الإلكتروني وأكّد الحساب، ثم ادخل.';
  }
</script>
<div class="center">
  <div class="card auth fade-in">
    <img src="/icon.svg" alt="" width="58" height="58" class="logo" />
    <h1>{CONFIG.appName}</h1>
    <p class="muted small">ارفع صورك، احصل على السعر فوراً، وتابع طلبيتك مباشرة</p>
    <div class="seg" style="margin:18px auto 4px;display:flex;width:max-content"><button class:on={tab === 'login'} on:click={() => (tab = 'login')}>دخول</button><button class:on={tab === 'signup'} on:click={() => (tab = 'signup')}>حساب جديد</button></div>
    <form on:submit|preventDefault={tab === 'login' ? login : signup}>
      {#if tab === 'signup'}
        <label for="nm">الاسم الكامل</label><input id="nm" bind:value={name} autocomplete="name" required />
        <label for="ph">رقم الهاتف</label><input id="ph" dir="ltr" inputmode="tel" bind:value={phone} autocomplete="tel" required />
        {#if dz}<div class="grid g2"><Picker label="الولاية" items={dz.wilayas} bind:value={wilaya} placeholder="اختر" hint={dz.live ? 'الولايات التي تصلها شركة التوصيل، مع سعر المكتب والمنزل' : ''} /><Picker label="البلدية" items={communes} bind:value={commune} placeholder="اختر" disabled={!wilaya} hint={dz.live ? '«فيها مكتب»: استلام من مكتب الشركة · «منزل فقط»: توصيل إلى البيت' : ''} /></div>{/if}
        <label for="ad">العنوان (اختياري)</label><input id="ad" bind:value={address} />
      {/if}
      <label for="em">البريد الإلكتروني</label><input id="em" type="email" dir="ltr" autocomplete="username" required bind:value={email} />
      <label for="pw">كلمة السر</label><input id="pw" type="password" dir="ltr" minlength="6" autocomplete={tab === 'login' ? 'current-password' : 'new-password'} required bind:value={password} />
      {#if err}<p class="red small msg">{err}</p>{/if}
      {#if info}<p class="green small msg">{info}</p>{/if}
      <button class="btn lg block" style="margin-top:16px" disabled={busy}>{busy ? '...' : tab === 'login' ? 'دخول' : 'إنشاء الحساب'}</button>
    </form>
  </div>
</div>
<style>
  .auth { width: min(440px, 100%); padding: 28px; text-align: center; }
  .logo { display: block; margin: 0 auto 10px; border-radius: 14px; box-shadow: 0 0 0 1px var(--line2); }
  form { text-align: right; }
  .msg { margin-top: 10px; }
</style>
