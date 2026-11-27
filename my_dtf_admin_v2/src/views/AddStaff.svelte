<script>
  import { invokeAdmin, errMsg } from '../lib/sb.js';
  import { closeModal, toast } from '../lib/store.js';
  export let onDone = () => {};
  let full_name = '', phone = '', role = 'designer', email = '', password = Math.random().toString(36).slice(2, 10), err = '', busy = false, created = false;
  async function save() {
    busy = true; err = '';
    try { await invokeAdmin({ action: 'create_staff', full_name, phone, role, email, password }); created = true; toast('أُنشئ الحساب'); onDone(); }
    catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>
{#if created}
  <h2>أُنشئ الحساب</h2>
  <p class="muted" style="margin:8px 0">أعطِ هذه المعلومات للموظف. سيختار رمزه السري بنفسه عند أول دخول.</p>
  <div class="card ltr small" style="text-align:left">{location.origin}<br>{email}<br>{password}</div>
  <button class="btn block" style="margin-top:14px" on:click={closeModal}>حسناً</button>
{:else}
  <h2>إضافة عضو إلى الفريق</h2>
  <label for="n">الاسم الكامل</label><input id="n" bind:value={full_name} />
  <label for="p">الهاتف</label><input id="p" dir="ltr" inputmode="tel" bind:value={phone} />
  <label for="r">الدور</label>
  <select id="r" bind:value={role}><option value="designer">مصمّم</option><option value="printer">طابع</option><option value="manager">مسيّر</option></select>
  <label for="e">البريد الإلكتروني (للدخول)</label><input id="e" type="email" dir="ltr" bind:value={email} />
  <label for="w">كلمة السر المؤقتة</label><input id="w" dir="ltr" bind:value={password} />
  <p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
  <div class="row"><button class="btn grow" disabled={busy || !full_name || !email} on:click={save}>إنشاء الحساب</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
{/if}
