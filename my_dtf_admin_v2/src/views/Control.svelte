<script>
  import { countUp } from '../lib/motion.js';
  // Centre de contrôle de l'atelier : machines en direct, chaîne de production, activité, équipe.
  import { onDestroy } from 'svelte';
  import { sb, q, rpc } from '../lib/sb.js';
  import { me, staff, board, liveTick, tv, openSheet, openModal, loadBoard, MSTATUS } from '../lib/store.js';
  import { da, m, num, pct, time, dur, minsSince, ymd, ROLE, STATUS, ACT, ltr } from '../lib/fmt.js';
  import MachineCard from '../components/MachineCard.svelte';
  import Ring from '../components/Ring.svelte';
  import Icon from '../components/Icon.svelte';
  import MachineSheet from './MachineSheet.svelte';
  import MachineForm from './MachineForm.svelte';
  import OrderSheet from './OrderSheet.svelte';

  let d = null, feed = [], clockNow = new Date();
  const ck = setInterval(() => (clockNow = new Date()), 1000); onDestroy(() => clearInterval(ck));
  const STAGES = [
    { k: ['new'], t: 'جديدة', icon: 'inbox', limit: 60 },
    { k: ['in_design'], t: 'التصميم', icon: 'design', limit: 240 },
    { k: ['ready_to_print'], t: 'طابور الطباعة', icon: 'orders', limit: 180 },
    { k: ['printing'], t: 'تُطبع', icon: 'machine', limit: 90 },
    { k: ['printed', 'ready_pickup'], t: 'جاهزة', icon: 'check', limit: 1440 },
    { k: ['shipped'], t: 'عند التوصيل', icon: 'truck', limit: 4320 },
  ];

  async function load() {
    const since = new Date(Date.now() - 30 * 864e5).toISOString();
    const t0 = new Date(); t0.setHours(0, 0, 0, 0);
    const [ord, open, att, conv, stock, act] = await Promise.all([
      q(sb.from('dtf_orders').select('id,code,status,print_amount,billed_meters,created_at').gte('created_at', since)),
      q(sb.from('dtf_orders').select('id,code,status,billed_meters,updated_at,designer_id,printer_id,machine_id,ship_status,ship_status_raw,client:dtf_profiles!dtf_orders_client_id_fkey(full_name)').in('status', STAGES.flatMap(s => s.k))),
      q(sb.from('dtf_attendance').select('user_id,clock_in,clock_out,auto_closed,work_date').gte('work_date', ymd(new Date(Date.now() - 864e5)))),
      q(sb.from('dtf_conversations').select('unread')),
      q(sb.from('dtf_stock_summary').select('*').limit(1).maybeSingle()),
      rpc('dtf_activity', { p_limit: 30 }).catch(() => []),
      loadBoard(),
    ]);
    feed = act;
    const valid = ord.filter(o => !['rejected', 'cancelled'].includes(o.status));
    const today = valid.filter(o => new Date(o.created_at) >= t0);
    const days = [...Array(14)].map((_, i) => { const a = new Date(+t0 - (13 - i) * 864e5), b = new Date(+a + 864e5);
      const inD = valid.filter(o => { const c = new Date(o.created_at); return c >= a && c < b; });
      return { day: a.getDate(), v: inD.reduce((s, o) => s + +o.print_amount, 0), n: inD.length, today: i === 13 }; });
    const pipe = STAGES.map(s => { const items = open.filter(o => s.k.includes(o.status));
      const oldest = items.length ? Math.max(...items.map(o => minsSince(o.updated_at))) : 0;
      return { ...s, items, n: items.length, m: items.reduce((a, o) => a + +o.billed_meters, 0), oldest, load: items.length ? oldest / s.limit : 0 }; });
    const worst = pipe.slice(0, 4).reduce((a, b) => (b.load > a.load ? b : a), pipe[0]);
    const presentIds = att.filter(a => a.work_date === ymd(new Date()) && !a.clock_out);
    const team = presentIds.map(a => { const p = $staff.find(s => s.id === a.user_id) || {};
      const doing = p.role === 'designer' ? open.filter(o => o.status === 'in_design' && o.designer_id === p.id)
        : p.role === 'printer' ? open.filter(o => o.status === 'printing' && o.printer_id === p.id) : [];
      return { ...p, since: a.clock_in, doing }; });
    const unread = conv.reduce((s, c) => s + (+c.unread || 0), 0);
    const alerts = [];
    ($board || []).filter(x => x.active && x.status === 'down').forEach(x => alerts.push({ lvl: 'bad', icon: 'alert', t: `${x.name} معطّلة: ${x.status_note || ''}`, mach: x.id }));
    ($board || []).filter(x => x.active && x.roll_code && +x.roll_remaining <= +x.alert_m).forEach(x => alerts.push({ lvl: 'warn', icon: 'roll', t: `رولو ${x.name} قارب على الانتهاء — بقي ${(+x.roll_remaining).toFixed(1)} م`, mach: x.id }));
    ($board || []).filter(x => x.active && !x.roll_code).forEach(x => alerts.push({ lvl: 'warn', icon: 'roll', t: `لا يوجد رولو مركّب على ${x.name}`, mach: x.id }));
    if (+stock.rolls_in_stock === 0) alerts.push({ lvl: 'bad', icon: 'stock', t: 'لا يوجد أي رولو احتياطي في المخزون', href: '#stock' });
    if (pipe[0].n) alerts.push({ lvl: pipe[0].oldest > 60 ? 'bad' : 'warn', icon: 'inbox', t: `${pipe[0].n} طلبية تنتظر القبول — أقدمها منذ ${dur(pipe[0].oldest)}`, href: '#orders' });
    open.filter(o => ['returned', 'attempt', 'hold'].includes(o.ship_status)).forEach(o => alerts.push({ lvl: o.ship_status === 'returned' ? 'bad' : 'warn', icon: 'truck', t: `طلبية ${o.code}: ${o.ship_status === 'returned' ? 'طرد مرتجع' : o.ship_status === 'attempt' ? 'محاولة توصيل فاشلة — اتصل بالزبون' : 'طرد معلّق عند شركة التوصيل'}`, href: '#orders' }));
    if (unread) alerts.push({ lvl: 'warn', icon: 'chat', t: `${unread} رسالة من الزبائن لم تُقرأ`, href: '#chat' });
    att.filter(a => a.auto_closed).forEach(a => alerts.push({ lvl: 'warn', icon: 'clock', t: `${$staff.find(s => s.id === a.user_id)?.full_name || '—'} نسي تسجيل الخروج (${a.work_date})`, href: '#attendance' }));
    if (!($board || []).length) alerts.push({ lvl: 'warn', icon: 'machine', t: 'لم تُضف أي آلة بعد — أضف آلاتك ليعمل مركز التحكّم بالكامل' });
    d = { revToday: today.reduce((s, o) => s + +o.print_amount, 0), nToday: today.length,
      rev30: valid.reduce((s, o) => s + +o.print_amount, 0), rev14: days.reduce((s, x) => s + x.v, 0), n14: days.reduce((s, x) => s + x.n, 0), days, max: Math.max(1, ...days.map(x => x.v)),
      pipe, worst: worst.load > 0.5 ? worst.t : null, team, alerts, stock, inWork: open.filter(o => o.status !== 'shipped').length };
  }
  $: $liveTick, load();

  $: act = ($board || []).filter(x => x.active);
  $: running = act.filter(x => x.status === 'running').length;
  $: metersToday = act.reduce((s, x) => s + +x.meters_today, 0);
  $: wasteToday = act.reduce((s, x) => s + +x.waste_today, 0);
  $: m7 = act.map(x => ({ n: x.name, v: +x.meters_7d })); $: m7max = Math.max(1, ...m7.map(x => x.v));
  $: hh = String(clockNow.getHours()).padStart(2, '0') + ':' + String(clockNow.getMinutes()).padStart(2, '0');
  $: admin = $me?.role === 'admin';
  const feedIcon = f => f.kind === 'workshop' ? 'bolt' : f.kind.startsWith('machine') ? (f.kind === 'machine_roll' ? 'roll' : f.kind === 'machine_maintenance' ? 'wrench' : 'machine') : f.kind === 'client' ? 'user' : 'orders';
  const feedText = f => f.kind === 'workshop' ? `${ACT[f.to_status]}${f.note ? ' — ' + f.note : ''}` : f.kind === 'machine_roll' || f.kind === 'machine_maintenance' ? f.note : f.kind === 'machine_status' ? `${ACT[f.to_status] || ''}${f.note ? ' — ' + f.note : ''}` : `${ACT[f.to_status] || f.to_status}${f.order_code ? ' · طلبية ' + f.order_code : ''}${f.machine ? ' على ' + f.machine : ''}`;
</script>

{#if !d}<div class="spinner"></div>{:else}
  <div class="hero hero-g">
    <div class="clock"><div class="num big">{hh}</div><div class="faint small">{clockNow.toLocaleDateString('ar-DZ', { weekday: 'long', day: 'numeric', month: 'long' })}</div></div>
    <div class="hk"><span class="faint tiny">مداخيل اليوم</span><b class="accent" use:countUp={{ value: d.revToday, format: da }}></b><span class="faint tiny">{num(d.nToday)} طلبية</span></div>
    <div class="hk"><span class="faint tiny">أمتار اليوم</span><b use:countUp={{ value: metersToday, format: v => m(v, 1) }}></b><span class="faint tiny">هدر {m(wasteToday, 1)}</span></div>
    <div class="hk"><span class="faint tiny">في الإنتاج</span><b use:countUp={{ value: d.inWork, format: v => num(Math.round(v)) }}></b><span class="faint tiny">طلبية مفتوحة</span></div>
    <div class="hk ringk"><Ring value={act.length ? running / act.length : 0} size={70} stroke={7} color="var(--green)"><b class="num">{running}/{act.length}</b></Ring><span class="faint tiny">آلات تطبع</span></div>
    <button class="btn quiet sm tvb" on:click={() => tv.update(v => !v)}><Icon name="tv" size={16} />{$tv ? 'خروج من وضع الشاشة' : 'وضع الشاشة'}</button>
  </div>

  <div class="section-title" style="margin-top:20px">الآلات<span class="end">{#if admin}<button class="btn ghost sm" on:click={() => openModal(MachineForm)}><Icon name="plus" size={16} />آلة</button>{/if}</span></div>
  {#if act.length}
    <div class="wall">{#each act as x (x.id)}<MachineCard {x} big={$tv} on:open={() => openSheet(MachineSheet, { id: x.id })} />{/each}</div>
  {:else}
    <button class="card empty addm" on:click={() => admin && openModal(MachineForm)}><Icon name="machine" size={34} /><div>لا توجد آلات بعد{admin ? ' — اضغط لإضافة أول آلة' : ''}</div></button>
  {/if}

  <div class="section-title" style="margin-top:20px">سلسلة الإنتاج{#if d.worst}<span class="end chip c-red">الاختناق: {d.worst}</span>{/if}</div>
  <div class="pipe">
    {#each d.pipe as s, i}
      <a class="stage" href="#orders" class:hot={s.t === d.worst} class:warm={s.load > 0.5 && s.t !== d.worst}>
        <div class="row between"><span class="si"><Icon name={s.icon} size={18} /></span><b class="num n">{s.n}</b></div>
        <div class="st">{s.t}</div>
        <div class="faint tiny">{s.n ? `${m(s.m, 1)} · أقدم ${dur(s.oldest)}` : 'فارغة'}</div>
        <div class="bar" class:low={s.load > 1}><i style="width:{Math.min(100, s.load * 100)}%"></i></div>
      </a>
      {#if i < d.pipe.length - 1}<span class="arrow">‹</span>{/if}
    {/each}
  </div>

  <div class="grid two" style="margin-top:20px">
    <div class="card">
      <div class="section-title"><div>المداخيل اليومية — آخر 14 يوماً<span class="sub">مبلغ الطباعة حسب يوم استلام الطلبية، دون المرفوضة والملغاة · اليوم بلون أفتح</span></div></div>
      <div class="revk">
        <div><span class="muted">مجموع آخر 14 يوماً (الرسم)</span><b class="num">{da(d.rev14)}</b><span class="muted">{num(d.n14)} طلبية</span></div>
        <div><span class="muted">مجموع آخر 30 يوماً</span><b class="num">{da(d.rev30)}</b></div>
      </div>
      <div class="bars" dir="ltr">
        {#each d.days as x}<div title="{x.n} — {Math.round(x.v)}"><span class="val">{x.v ? ltr(x.v >= 1000 ? (x.v / 1000).toFixed(1) + 'k' : Math.round(x.v)) : ''}</span><i class:today={x.today} style="height:{(x.v / d.max) * 100}%"></i><small>{x.day}</small></div>{/each}
      </div>
    </div>
    <div class="card">
      <div class="section-title">تنبيهات<span class="end badge">{d.alerts.length}</span></div>
      {#if d.alerts.length}<div class="col">{#each d.alerts as a}
        {#if a.mach}<button class="al {a.lvl}" on:click={() => openSheet(MachineSheet, { id: a.mach })}><Icon name={a.icon} size={18} /><span class="grow">{a.t}</span></button>
        {:else}<a class="al {a.lvl}" href={a.href || '#dash'}><Icon name={a.icon} size={18} /><span class="grow">{a.t}</span></a>{/if}
      {/each}</div>
      {:else}<div class="empty"><Icon name="check" size={28} /><div>كل شيء على ما يرام</div></div>{/if}
    </div>
  </div>

  <div class="grid three" style="margin-top:12px">
    <div class="card">
      <div class="section-title">الفريق الآن<span class="end faint small">{num(d.team.length)} حاضر</span></div>
      {#if d.team.length}<div class="list">{#each d.team as p}
        <div class="item row"><span class="av">{(p.full_name || '?')[0]}</span>
          <div class="grow"><b>{p.full_name}</b> <span class="faint tiny">{ROLE[p.role] || ''}</span>
            <div class="small {p.doing.length ? 'green' : 'muted'}">{p.doing.length ? (p.role === 'designer' ? `يصمّم ${p.doing.length} ملف` : `يطبع طلبية ${p.doing.map(o => o.code).join('، ')}`) : 'متاح'}</div></div>
          <span class="faint tiny">منذ {time(p.since)}</span></div>{/each}</div>
      {:else}<div class="empty">لم يسجّل أحد دخوله بعد</div>{/if}
    </div>
    <div class="card">
      <div class="section-title">النشاط المباشر</div>
      {#if feed.length}<div class="feed">{#each feed.slice(0, 14) as f}
        <div class="fi"><span class="fic k-{f.kind.split('_')[0]}"><Icon name={feedIcon(f)} size={15} /></span>
          <div class="grow small"><b>{f.actor || (f.kind === 'client' ? 'زبون' : 'النظام')}</b> {feedText(f)}</div><span class="faint tiny">{dur(minsSince(f.at))}</span></div>{/each}</div>
      {:else}<div class="empty">لا يوجد نشاط بعد</div>{/if}
    </div>
    <div class="card">
      <div class="section-title">أمتار كل آلة — 7 أيام</div>
      {#if m7.length}<div class="col">{#each m7 as x}<div><div class="row between small"><span>{x.n}</span><b class="num">{x.v.toFixed(1)} م</b></div><div class="bar"><i style="width:{(x.v / m7max) * 100}%"></i></div></div>{/each}</div>
      {:else}<div class="empty">—</div>{/if}
      <div class="row between small" style="margin-top:16px;border-top:1px solid var(--line);padding-top:12px"><span class="muted">الفيلم في المخزون</span><b>{m(d.stock.total_remaining_m, 0)}</b></div>
      <div class="row between small"><span class="muted">رولوات احتياطية</span><b class:red={+d.stock.rolls_in_stock === 0}>{num(d.stock.rolls_in_stock)}</b></div>
    </div>
  </div>
{/if}

<style>
  .hero { display: flex; align-items: center; gap: 26px; flex-wrap: wrap; padding: 18px 22px; }
  .clock .big { font-size: 40px; font-weight: 700; line-height: 1; letter-spacing: 1px; color: #fff; }
  .hk { display: flex; flex-direction: column; gap: 2px; padding-right: 22px; border-right: 1px solid #ffffff22; }
  .hk b { font-size: 22px; color: #fff; } .hero :global(.faint) { color: #ffffffa0; } .hero :global(.accent) { color: var(--accent3); }
  .ringk { flex-direction: row; align-items: center; gap: 10px; }
  .tvb { margin-right: auto; }
  /* auto-fit : les cartes occupent toute la largeur disponible (pas de colonnes vides à droite) */
  .wall { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr)); gap: 14px; }
  @media (min-width: 1700px) { .wall { grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); } }
  :global(.tv) .wall { grid-template-columns: repeat(auto-fit, minmax(380px, 1fr)); }
  .addm { width: 100%; display: flex; flex-direction: column; align-items: center; gap: 8px; color: var(--muted); border-style: dashed; }
  .pipe { display: flex; align-items: stretch; gap: 6px; overflow-x: auto; padding-bottom: 4px; }
  .stage { flex: 1; min-width: 140px; display: flex; flex-direction: column; gap: 6px; padding: 13px; border-radius: 16px; background: var(--card); border: 1px solid var(--line); color: var(--text); }
  .stage:hover { border-color: var(--line2); }
  .stage .n { font-size: 26px; line-height: 1; }
  .stage .st { font-weight: 600; }
  .si { width: 32px; height: 32px; border-radius: 10px; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent2); }
  .stage.warm { border-color: #FBBF2466; } .stage.warm .si { background: #FBBF241F; color: var(--amber); }
  .stage.hot { border-color: #F87171; background: linear-gradient(180deg, #2A1618, var(--card)); } .stage.hot .si { background: #F871712A; color: var(--red); }
  .arrow { align-self: center; color: var(--muted); font-size: 24px; }
  .stage .faint { color: var(--muted); font-size: 13px; }
  /* Téléphone : la chaîne se lit de haut en bas dans l'ordre des étapes */
  @media (max-width: 640px) { .pipe { flex-direction: column; overflow: visible; } .stage { min-width: 0; } .arrow { transform: rotate(-90deg); line-height: 1; } }
  .two { grid-template-columns: 1.7fr 1fr; } .three { grid-template-columns: repeat(3, minmax(0, 1fr)); }
  @media (max-width: 1100px) { .two, .three { grid-template-columns: 1fr; } .hk { border: 0; padding: 0; } .tvb { margin: 0; } }
  .bars { display: flex; align-items: flex-end; gap: 6px; height: 190px; }
  .bars > div { flex: 1; height: 100%; display: flex; flex-direction: column; justify-content: flex-end; align-items: center; gap: 4px; }
  .bars i { width: 100%; max-width: 32px; min-height: 2px; border-radius: 7px 7px 2px 2px; background: linear-gradient(180deg, #7C6CF0CC, #7C6CF022); transition: height .5s; }
  .bars i.today { background: linear-gradient(180deg, var(--chart2), var(--chart)); box-shadow: 0 0 18px #7C6CF077; }
  .bars small { font-size: 12.5px; color: var(--muted); } .val { font-size: 11.5px; color: var(--text); opacity: .85; }
  .revk { display: flex; gap: 12px; flex-wrap: wrap; margin-bottom: 14px; }
  .revk > div { flex: 1; min-width: 170px; display: flex; flex-direction: column; gap: 2px; padding: 10px 12px; border-radius: 12px; background: var(--bg2); border: 1px solid var(--line); font-size: 13px; }
  .revk b { font-size: 19px; color: var(--accent2); }
  .al { display: flex; align-items: center; gap: 10px; text-align: right; width: 100%; padding: 10px 12px; border-radius: 12px; font-size: 13.5px; color: var(--text); background: #FBBF2412; border: 1px solid #FBBF2440; }
  .al :global(svg) { color: var(--amber); flex-shrink: 0; }
  .al.bad { background: #F8717114; border-color: #F8717150; } .al.bad :global(svg) { color: var(--red); }
  .av { width: 34px; height: 34px; border-radius: 50%; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent3); font-weight: 700; flex-shrink: 0; }
  .feed { display: flex; flex-direction: column; gap: 10px; max-height: 340px; overflow-y: auto; }
  .fi { display: flex; gap: 10px; align-items: flex-start; }
  .fic { width: 28px; height: 28px; border-radius: 9px; display: grid; place-items: center; flex-shrink: 0; background: var(--accent-soft); color: var(--accent2); }
  .fic.k-machine { background: #4ADE801A; color: var(--green); } .fic.k-client { background: #60A5FA1A; color: var(--blue); }
</style>
