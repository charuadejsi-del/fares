<script>
  import { sb, q } from '../lib/sb.js';
  import { staff, staffName, liveTick } from '../lib/store.js';
  import { ROLE, time, dur, minsSince, ymd, ltr } from '../lib/fmt.js';
  let days = 7, rows = null;
  async function load() { rows = await q(sb.from('dtf_attendance').select('*').gte('work_date', ymd(new Date(Date.now() - (days - 1) * 864e5))).order('clock_in', { ascending: false })); }
  $: days, $liveTick, load();
  $: today = ymd(new Date());
  $: team = $staff.filter(s => s.role !== 'admin' && s.active);
</script>
{#if !rows}<div class="spinner"></div>{:else}
  <div class="section-title">اليوم</div>
  <div class="grid g4">
    {#each team as s (s.id)}{@const r = rows.find(a => a.user_id === s.id && a.work_date === today)}
      <div class="card">
        <div class="row between"><b>{s.full_name}</b><span class="dot" class:in={r && !r.clock_out} class:out={r && r.clock_out}></span></div>
        <div class="faint tiny">{ROLE[s.role]}</div>
        <div class="small" style="margin-top:6px">{#if r}دخل {time(r.clock_in)}{#if r.clock_out} · خرج {time(r.clock_out)}{:else} · منذ {dur(minsSince(r.clock_in))}{/if}{:else}<span class="red">لم يسجّل دخوله</span>{/if}</div>
      </div>
    {:else}<div class="card empty">لا يوجد موظفون</div>{/each}
  </div>
  <div class="row between" style="margin:18px 0 10px"><div class="section-title" style="margin:0">السجلّ</div>
    <div class="seg">{#each [[7, '7 أيام'], [30, '30 يوماً']] as [v, l]}<button class:on={days === v} on:click={() => (days = v)}>{l}</button>{/each}</div></div>
  <div class="card table-wrap">
    <table>
      <tr><th>اليوم</th><th>الموظف</th><th>الدخول</th><th>الخروج</th><th>المدّة</th><th></th></tr>
      {#each rows as a (a.id)}
        <tr><td class="ltr">{a.work_date}</td><td><b>{staffName(a.user_id)}</b></td><td>{time(a.clock_in)}</td><td>{#if a.clock_out}{time(a.clock_out)}{:else}<span class="teal">في العمل</span>{/if}</td>
          <td>{a.clock_out ? dur((new Date(a.clock_out) - new Date(a.clock_in)) / 60000) : '—'}</td><td>{#if a.auto_closed}<span class="chip c-red">نسي الخروج</span>{/if}</td></tr>
      {/each}
    </table>
    {#if !rows.length}<div class="empty">لا يوجد سجلّ في هذه الفترة</div>{/if}
  </div>
{/if}
<style>
  .dot { width: 10px; height: 10px; border-radius: 50%; background: var(--red); }
  .dot.in { background: var(--teal); } .dot.out { background: var(--faint); }
</style>
