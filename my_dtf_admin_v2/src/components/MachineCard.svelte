<script>
  // Carte vivante d'une machine. Deux faits distincts : l'état déclaré (تطبع / متوقفة / صيانة / عطل)
  // et l'aptitude réelle à imprimer (rouleau monté, restant) — un blocage s'affiche en clair avec l'action à faire.
  import { onDestroy, createEventDispatcher } from 'svelte';
  import { MSTATUS, readiness } from '../lib/store.js';
  import { m, num, clock, dur, minsSince } from '../lib/fmt.js';
  import Icon from './Icon.svelte';
  export let x; export let big = false; export let selected = false; export let compact = false;
  const dispatch = createEventDispatcher();
  let n = 0; const t = setInterval(() => n++, 1000); onDestroy(() => clearInterval(t));
  $: st = MSTATUS[x.status] || MSTATUS.idle;
  $: rd = readiness(x);
  $: rp = x.roll_code ? Math.max(0, Math.min(100, (x.roll_remaining / x.roll_length) * 100)) : 0;
  $: low = x.roll_code && +x.roll_remaining <= +x.alert_m;
  $: elapsed = (n, x.job_started ? clock(minsSince(x.job_started)) : '');
  $: since = (n, dur(minsSince(x.status_since)));
</script>
<button class="mc s-{x.status} r-{rd.c}" class:big class:selected class:off={!x.active} class:blocked={rd.block} on:click={() => dispatch('open', x)}>
  <div class="head">
    <span class="dot {st[1]}"></span>
    <div class="grow"><b class="name">{x.name}</b><div class="sub">{x.model || 'DTF'} · <span class="num">{num(+x.width_cm)}</span> سم · الحالة: <b>{st[0]}</b></div></div>
    <span class="chip c-{rd.c}">{rd.t}</span>
  </div>
  {#if x.status === 'running' && x.job_code}
    <div class="job">
      <div class="grow"><div class="lbl">يطبع الآن</div><b>طلبية <span class="num">{num(x.job_code)}</span></b> <span class="muted">{m(x.job_meters)}</span>
        {#if x.jobs_running > 1}<span class="muted"> +{num(x.jobs_running - 1)}</span>{/if}</div>
      <div class="timer num">{elapsed}</div>
    </div>
  {:else if rd.block || rd.why}
    <div class="job warnbox" class:bad={rd.c === 'red'}><Icon name={x.status === 'down' ? 'alert' : x.status === 'maintenance' ? 'wrench' : 'roll'} size={20} />
      <div class="grow">{rd.why}</div>{#if rd.block}<span class="muted since">منذ {since}</span>{/if}</div>
  {:else if !compact}
    <div class="job idlebox"><Icon name="check" size={18} /><span class="grow">جاهزة — في انتظار ملف</span><span class="muted since">منذ {since}</span></div>
  {/if}
  <div class="roll">
    <div class="row between rl"><span>{x.roll_code ? `الرولو ${x.roll_code}` : 'لا يوجد رولو مركّب'}</span>
      {#if x.roll_code}<b class:red={low} class="num">{(+x.roll_remaining).toFixed(1)} / {(+x.roll_length).toFixed(0)} م</b>{/if}</div>
    <div class="bar" class:low class:ok={!low && rp > 0}><i style="width:{rp}%"></i></div>
  </div>
  {#if !compact}
    <div class="foot">
      <span><span class="muted">اليوم</span> <b>{m(x.meters_today, 1)}</b></span>
      <span><span class="muted">هدر</span> <b class:amber={+x.waste_today > 0}>{m(x.waste_today, 1)}</b></span>
      <span class="op"><span class="muted">المشغّل</span> <b>{x.operator_name || '—'}</b></span>
    </div>
  {/if}
</button>
<style>
  .mc { display: flex; flex-direction: column; gap: 12px; width: 100%; text-align: right; padding: 16px; border-radius: 18px;
    background: linear-gradient(180deg, #151925, #11141D); border: 1px solid var(--line); position: relative; overflow: hidden; transition: border-color .2s, transform .15s; }
  .mc:hover { border-color: var(--line2); transform: translateY(-1px); }
  .mc::after { content: ''; position: absolute; inset: 0 0 auto 0; height: 3px; background: var(--blue); opacity: .8; }
  .mc.r-green::after { background: var(--green); }
  .mc.s-running::after { background: linear-gradient(90deg, var(--green), var(--teal)); background-size: 200% 100%; animation: flow 2s linear infinite; }
  .mc.r-amber { border-color: #FBBF2455; } .mc.r-amber::after { background: var(--amber); }
  .mc.r-red { border-color: #F05A5A77; } .mc.r-red::after { background: var(--red); }
  .mc.selected { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
  .mc.off { opacity: .55; }
  @keyframes flow { to { background-position: -200% 0; } }
  .head { display: flex; align-items: center; gap: 10px; }
  .head .chip { font-size: 13px; padding: 4px 11px; }
  .name { font-size: 16.5px; }
  .sub { font-size: 13px; color: var(--muted); margin-top: 1px; }
  .sub b { color: var(--text); font-weight: 600; }
  .job { display: flex; align-items: center; gap: 10px; background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 11px 13px; min-height: 56px; font-size: 14px; }
  .lbl { font-size: 12.5px; color: var(--muted); }
  .idlebox { color: var(--text); } .idlebox :global(svg) { color: var(--green); }
  .warnbox { color: #FCD34D; background: #FBBF2410; border-color: #FBBF2440; font-weight: 600; }
  .warnbox.bad { color: #FCA5A5; background: #F05A5A12; border-color: #F05A5A55; }
  .since { font-size: 12.5px; font-weight: 400; white-space: nowrap; }
  .timer { font-size: 22px; font-weight: 700; color: var(--green); letter-spacing: .5px; }
  .big .timer { font-size: 30px; }
  .roll { display: flex; flex-direction: column; gap: 7px; }
  .rl { font-size: 13.5px; color: var(--muted); }
  .rl b { color: var(--text); }
  .foot { display: flex; justify-content: space-between; gap: 8px; flex-wrap: wrap; border-top: 1px solid var(--line); padding-top: 10px; font-size: 13.5px; }
  .op b { display: inline-block; max-width: 120px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; vertical-align: bottom; }
  .big .name { font-size: 20px; } .big .job { font-size: 16px; }
</style>
