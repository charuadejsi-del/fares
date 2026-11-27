<script>
  import { sb, q, rpc, invokeAdmin, errMsg } from '../lib/sb.js';
  import { staff, openModal, toast } from '../lib/store.js';
  import { ROLE } from '../lib/fmt.js';
  import AddStaff from './AddStaff.svelte';
  async function reload() { staff.set(await q(sb.from('dtf_profiles').select('id,full_name,role,active,phone').neq('role', 'client').order('full_name'))); }
  async function setRole(id, role) { try { await q(sb.from('dtf_profiles').update({ role }).eq('id', id)); toast('تم تغيير الدور'); reload(); } catch (e) { toast(errMsg(e), true); } }
  async function setActive(s) {
    if (s.active && !confirm(`إيقاف حساب ${s.full_name}؟ لن يستطيع الدخول.`)) return;
    try { await q(sb.from('dtf_profiles').update({ active: !s.active }).eq('id', s.id)); toast(s.active ? 'أُوقف الحساب' : 'فُعّل الحساب'); reload(); } catch (e) { toast(errMsg(e), true); }
  }
  async function resetPin(s) { if (!confirm(`إعادة تعيين الرمز السري لـ ${s.full_name}؟ سيختار رمزاً جديداً عند دخوله.`)) return; try { await rpc('dtf_pin_reset', { p_user: s.id }); toast('أُعيد تعيين الرمز'); } catch (e) { toast(errMsg(e), true); } }
  async function setPass(s) { const p = prompt(`كلمة سر جديدة لـ ${s.full_name} (6 أحرف على الأقل):`); if (!p) return; try { await invokeAdmin({ action: 'set_password', user_id: s.id, password: p }); toast('تم تغيير كلمة السر'); } catch (e) { toast(errMsg(e), true); } }
  $: team = $staff.filter(s => s.role !== 'admin');
</script>
<div class="row between" style="margin-bottom:14px"><span class="muted">{team.length} عضو في الفريق</span><button class="btn" on:click={() => openModal(AddStaff, { onDone: reload })}>إضافة عضو</button></div>
<div class="grid g3">
  {#each team as s (s.id)}
    <div class="card" class:off={!s.active}>
      <div class="row"><div class="av">{s.full_name[0]}</div><div class="grow"><h3>{s.full_name}</h3><div class="faint tiny ltr">{s.phone}</div></div><span class="chip c-amber">{ROLE[s.role]}</span></div>
      <div class="row wrap" style="margin-top:12px;gap:6px">
        <select value={s.role} on:change={e => setRole(s.id, e.currentTarget.value)} style="width:auto;padding:6px 10px">
          {#each ['manager', 'designer', 'printer'] as r}<option value={r}>{ROLE[r]}</option>{/each}
        </select>
        <button class="btn quiet sm" on:click={() => resetPin(s)}>إعادة الرمز السري</button>
        <button class="btn quiet sm" on:click={() => setPass(s)}>كلمة السر</button>
        <button class="btn {s.active ? 'danger' : 'ghost'} sm" on:click={() => setActive(s)}>{s.active ? 'إيقاف' : 'تفعيل'}</button>
      </div>
    </div>
  {:else}<div class="card empty">أضف المسيّرين والمصمّمين والطابعين</div>{/each}
</div>
<style>
  .off { opacity: .55; }
  .av { width: 40px; height: 40px; border-radius: 50%; display: grid; place-items: center; background: var(--card2); color: var(--gold); font-weight: 700; }
</style>
