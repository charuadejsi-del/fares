<script>
  // Fiche machine : état, rouleau, maintenance, journal, statistiques.
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { me, board, liveTick, toast, closeSheet, openModal, loadBoard, MSTATUS, staffName } from '../lib/store.js';
  import { m, num, dt, dur, minsSince, ACT } from '../lib/fmt.js';
  import MachineCard from '../components/MachineCard.svelte';
  import Icon from '../components/Icon.svelte';
  import MachineForm from './MachineForm.svelte';
  import Waste from './Waste.svelte';

  export let id;
  let ev = [], days = [], busy = false, err = '', mode = '', note = '', stockRolls = [], rollSel = '';
  $: x = ($board || []).find(b => b.id === id);
  $: admin = $me?.role === 'admin';
  async function load() {
    try {
      const since = new Date(Date.now() - 14 * 864e5).toISOString();
      const [e, f, r] = await Promise.all([
        q(sb.from('dtf_machine_events').select('*').eq('machine_id', id).order('created_at', { ascending: false }).limit(40)),
        q(sb.from('dtf_film_moves').select('meters,kind,created_at').eq('machine_id', id).gte('created_at', since)),
        q(sb.from('dtf_rolls').select('id,code,length_m,supplier').eq('status', 'stock').order('purchased_at').order('code').limit(50)),
      ]);
      ev = e; stockRolls = r; if (!rollSel && r[0]) rollSel = r[0].id;
      const t0 = new Date(); t0.setHours(0, 0, 0, 0);
      days = [...Array(14)].map((_, i) => { const a = new Date(+t0 - (13 - i) * 864e5), b = new Date(+a + 864e5);
        const inD = f.filter(z => { const c = new Date(z.created_at); return c >= a && c < b; });
        return { d: a.getDate(), p: inD.filter(z => z.kind === 'print').reduce((s, z) => s + +z.meters, 0), w: inD.filter(z => z.kind === 'waste').reduce((s, z) => s + +z.meters, 0) }; });
    } catch (e) { err = errMsg(e); }
  }
  $: id, $liveTick, load();
  $: max = Math.max(1, ...days.map(d => d.p + d.w));
  $: tot = days.reduce((s, d) => s + d.p, 0); $: totW = days.reduce((s, d) => s + d.w, 0);

  async function run(fn, args, ok) {
    busy = true; err = '';
    try { await rpc(fn, args); toast(ok); mode = ''; note = ''; await loadBoard(); liveTick.update(n => n + 1); }
    catch (e) { err = errMsg(e); }
    busy = false;
  }
  const setStatus = s => run('dtf_set_machine_status', { p_machine: id, p_status: s, p_note: note || null }, 'تغيّرت حالة الآلة');
  const mount = () => run('dtf_activate_roll', { p_machine: id, p_roll: rollSel || null }, 'رُكّب الرولو على الآلة');
  const maint = () => run('dtf_log_maintenance', { p_machine: id, p_note: note }, 'سُجّلت الصيانة');
  const KIND = { status: 'الحالة', maintenance: 'صيانة', roll: 'رولو' };
</script>

{#if !x}<div class="spinner"></div>{:else}
  <div class="row between"><h2>{x.name}</h2>
    <div class="row">{#if admin}<button class="btn quiet sm" on:click={() => openModal(MachineForm, { x })}>تعديل</button>{/if}<button class="btn quiet sm" on:click={closeSheet}>إغلاق</button></div></div>
  <div style="margin-top:12px"><MachineCard {x} big /></div>
  {#if err}<div class="notice bad small" style="margin-top:10px">{err}</div>{/if}

  <div class="card" style="margin-top:12px">
    <div class="section-title">التحكّم</div>
    <div class="grid g2">
      {#if x.status !== 'idle' && x.status !== 'running'}<button class="btn ok" disabled={busy} on:click={() => setStatus('idle')}><Icon name="check" size={18} />الآلة عادت للعمل</button>{/if}
      {#if x.status !== 'maintenance'}<button class="btn quiet" on:click={() => (mode = mode === 'maintenance' ? '' : 'maintenance')}><Icon name="wrench" size={18} />وضع صيانة</button>{/if}
      {#if x.status !== 'down'}<button class="btn danger" on:click={() => (mode = mode === 'down' ? '' : 'down')}><Icon name="alert" size={18} />الإبلاغ عن عطل</button>{/if}
      <button class="btn quiet" on:click={() => (mode = mode === 'roll' ? '' : 'roll')}><Icon name="roll" size={18} />تركيب رولو</button>
      <button class="btn quiet" on:click={() => openModal(Waste, { machine: id })}><Icon name="scissors" size={18} />تسجيل هدر</button>
      <button class="btn quiet" on:click={() => (mode = mode === 'log' ? '' : 'log')}><Icon name="plus" size={18} />سجلّ صيانة</button>
    </div>
    {#if mode === 'maintenance' || mode === 'down' || mode === 'log'}
      <label for="mnote">{mode === 'log' ? 'ما الذي تمّ؟ (تنظيف رأس، تغيير حبر...)' : 'السبب'}</label>
      <div class="row"><input id="mnote" bind:value={note} placeholder={mode === 'down' ? 'مثال: الرأس لا يطبع اللون الأبيض' : ''} />
        <button class="btn" disabled={busy || !note.trim()} on:click={() => (mode === 'log' ? maint() : setStatus(mode))}>تأكيد</button></div>
    {:else if mode === 'roll'}
      {#if stockRolls.length}
        <label for="rs">الرولو من المخزون {x.roll_code ? `(الرولو ${x.roll_code} الحالي سيُعتبر منتهياً)` : ''}</label>
        <div class="row"><select id="rs" bind:value={rollSel}>{#each stockRolls as r}<option value={r.id}>رولو {r.code} — {+r.length_m} م {r.supplier ? '· ' + r.supplier : ''}</option>{/each}</select>
          <button class="btn" disabled={busy} on:click={mount}>تركيب</button></div>
      {:else}<div class="notice warn small" style="margin-top:10px">لا يوجد رولو في المخزون. سجّل شراء رولوات من صفحة المخزون.</div>{/if}
    {/if}
  </div>

  <div class="card" style="margin-top:12px">
    <div class="section-title">الإنتاج — آخر 14 يوماً<span class="end small muted">{m(tot, 1)} · هدر {m(totW, 1)}</span></div>
    <div class="bars" dir="ltr">{#each days as d}<div title="{d.p.toFixed(1)} / {d.w.toFixed(1)}"><span class="stack"><i class="w" style="height:{(d.w / max) * 100}%"></i><i style="height:{(d.p / max) * 100}%"></i></span><small>{d.d}</small></div>{/each}</div>
  </div>

  <div class="card" style="margin-top:12px">
    <div class="section-title">سجلّ الآلة</div>
    {#if ev.length}<div class="list">{#each ev as e}
      <div class="item row"><span class="chip c-{e.kind === 'maintenance' ? 'amber' : e.kind === 'roll' ? 'teal' : (MSTATUS[e.to_status]?.[2] || 'gray')}">{e.kind === 'status' ? (MSTATUS[e.to_status]?.[0] || '') : KIND[e.kind]}</span>
        <div class="grow small">{e.note || (e.kind === 'status' ? ACT[e.to_status] : '')}</div><span class="faint tiny">{staffName(e.actor_id)} · {dt(e.created_at)}</span></div>{/each}</div>
    {:else}<div class="empty">لا شيء بعد</div>{/if}
  </div>
{/if}

<style>
  .bars { display: flex; align-items: flex-end; gap: 5px; height: 120px; }
  .bars > div { flex: 1; height: 100%; display: flex; flex-direction: column; align-items: center; gap: 4px; }
  .stack { flex: 1; width: 100%; max-width: 22px; display: flex; flex-direction: column-reverse; justify-content: flex-start; }
  .stack i { display: block; width: 100%; background: linear-gradient(180deg, var(--accent2), var(--accent)); border-radius: 4px 4px 2px 2px; min-height: 0; }
  .stack i.w { background: var(--amber); border-radius: 2px; }
  .bars small { font-size: 10.5px; color: var(--faint); }
</style>
