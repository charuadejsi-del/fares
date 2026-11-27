<script>
  import { sb, q } from '../lib/sb.js';
  import { liveTick, staff, staffName, openSheet } from '../lib/store.js';
  import { da, m, num, pct, time, dur, minsSince, ymd, ROLE } from '../lib/fmt.js';
  import Kpi from '../components/Kpi.svelte';
  import Chip from '../components/Chip.svelte';
  import RollGauge from '../components/RollGauge.svelte';
  import OrderSheet from './OrderSheet.svelte';

  let d = null;
  async function load() {
    const since = new Date(Date.now() - 30 * 864e5).toISOString();
    const [ord, moves, stock, att, conv] = await Promise.all([
      q(sb.from('dtf_orders').select('id,code,status,print_amount,created_at,updated_at').gte('created_at', since)),
      q(sb.from('dtf_film_moves').select('meters,kind,created_at').gte('created_at', since)),
      q(sb.from('dtf_stock_summary').select('*').single()),
      q(sb.from('dtf_attendance').select('user_id,clock_in,clock_out,auto_closed,work_date').gte('work_date', ymd(new Date(Date.now() - 864e5)))),
      q(sb.from('dtf_conversations').select('unread')),
    ]);
    const t0 = new Date(); t0.setHours(0, 0, 0, 0);
    const valid = ord.filter(o => !['rejected', 'cancelled'].includes(o.status));
    const today = valid.filter(o => new Date(o.created_at) >= t0);
    const printed = moves.filter(x => x.kind === 'print').reduce((s, x) => s + +x.meters, 0);
    const waste = moves.filter(x => x.kind === 'waste').reduce((s, x) => s + +x.meters, 0);
    const days = [...Array(14)].map((_, i) => { const a = new Date(t0 - (13 - i) * 864e5); const b = new Date(+a + 864e5);
      return { day: a.getDate(), v: valid.filter(o => { const c = new Date(o.created_at); return c >= a && c < b; }).reduce((s, o) => s + +o.print_amount, 0) }; });
    const waiting = ord.filter(o => o.status === 'new');
    const alerts = [];
    if (waiting.length) alerts.push(`${waiting.length} طلبية جديدة تنتظر القبول، أقدمها منذ ${dur(Math.max(...waiting.map(o => minsSince(o.created_at))))}`);
    if (stock.active_code && +stock.active_remaining_m <= +stock.alert_m) alerts.push(`الرولو رقم ${stock.active_code} قارب على الانتهاء: بقي ${m(stock.active_remaining_m, 1)}`);
    if (+stock.rolls_in_stock === 0) alerts.push('لا يوجد رولو احتياطي في المخزون');
    const unread = conv.reduce((s, c) => s + (+c.unread || 0), 0);
    if (unread) alerts.push(`${unread} رسالة من الزبائن لم تُقرأ بعد`);
    att.filter(a => a.auto_closed).forEach(a => alerts.push(`${staffName(a.user_id)} نسي تسجيل الخروج يوم ${a.work_date}`));
    d = {
      revToday: today.reduce((s, o) => s + +o.print_amount, 0), nToday: today.length,
      rev30: valid.reduce((s, o) => s + +o.print_amount, 0), n30: valid.length,
      printed, waste, stock, days, max: Math.max(1, ...days.map(x => x.v)), alerts,
      active: ord.filter(o => ['new', 'in_design', 'ready_to_print', 'printing'].includes(o.status)).sort((a, b) => new Date(a.updated_at) - new Date(b.updated_at)).slice(0, 8),
      present: att.filter(a => a.work_date === ymd(new Date()) && !a.clock_out),
    };
  }
  $: $liveTick, load();
</script>

{#if !d}<div class="spinner"></div>{:else}
  <div class="grid g4">
    <Kpi label="مداخيل اليوم" value={da(d.revToday)} sub="{d.nToday} طلبية" />
    <Kpi label="مداخيل آخر 30 يوماً" value={da(d.rev30)} sub="{d.n30} طلبية" />
    <Kpi label="الأمتار المطبوعة (30 يوماً)" value={m(d.printed, 1)} sub="الهدر {m(d.waste, 1)} · {pct(d.printed + d.waste ? (d.waste / (d.printed + d.waste)) * 100 : 0)}" />
    <Kpi label="الفيلم المتبقي" value={m(d.stock.total_remaining_m, 0)} sub="{d.stock.rolls_in_stock} رولو احتياطي" warn={d.stock.active_code && +d.stock.active_remaining_m <= +d.stock.alert_m} />
  </div>

  <div class="grid two" style="margin-top:12px">
    <div class="card">
      <div class="section-title">المداخيل اليومية — آخر 14 يوماً</div>
      <div class="bars" dir="ltr">
        {#each d.days as x}<div title={da(x.v)}><i style="height:{(x.v / d.max) * 100}%"></i><small>{x.day}</small></div>{/each}
      </div>
    </div>
    <div class="card">
      <div class="section-title">تنبيهات</div>
      {#if d.alerts.length}<div class="list">{#each d.alerts as a}<div class="item small">{a}</div>{/each}</div>
      {:else}<div class="empty">كل شيء على ما يرام</div>{/if}
    </div>
  </div>

  <div class="grid g3" style="margin-top:12px">
    <div class="card">
      <div class="section-title">قيد التنفيذ</div>
      {#if d.active.length}<div class="list">{#each d.active as o}
        <button class="item row between full" on:click={() => openSheet(OrderSheet, { id: o.id })}><b>طلبية {num(o.code)}</b><Chip status={o.status} /></button>{/each}</div>
      {:else}<div class="empty">لا توجد طلبيات مفتوحة</div>{/if}
    </div>
    <div class="card">
      <div class="section-title">الحاضرون الآن</div>
      {#if d.present.length}<div class="list">{#each d.present as a}{@const p = $staff.find(s => s.id === a.user_id)}
        <div class="item row between"><span><b>{p?.full_name || '—'}</b> <span class="faint tiny">{ROLE[p?.role] || ''}</span></span><span class="muted small">منذ {time(a.clock_in)}</span></div>{/each}</div>
      {:else}<div class="empty">لم يسجّل أحد دخوله بعد</div>{/if}
    </div>
    <div class="card"><div class="section-title">الرولو الحالي</div><RollGauge s={d.stock} /></div>
  </div>
{/if}

<style>
  .two { grid-template-columns: 2fr 1fr; }
  @media (max-width: 1000px) { .two { grid-template-columns: 1fr; } }
  .bars { display: flex; align-items: flex-end; gap: 6px; height: 160px; }
  .bars > div { flex: 1; height: 100%; display: flex; flex-direction: column; justify-content: flex-end; align-items: center; gap: 4px; }
  .bars i { width: 100%; max-width: 30px; min-height: 2px; border-radius: 6px 6px 2px 2px; background: var(--gold); }
  .bars small { font-size: 11px; color: var(--faint); }
  .full { width: 100%; text-align: right; }
</style>
