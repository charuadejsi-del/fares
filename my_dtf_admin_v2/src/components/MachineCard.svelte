<script>
  // Carte vivante d'une machine : voyant, travail en cours + chrono, opérateur, rouleau, mètres du jour.
  import { onDestroy, createEventDispatcher } from 'svelte';
  import { MSTATUS } from '../lib/store.js';
  import { m, num, clock, dur, minsSince } from '../lib/fmt.js';
  import Icon from './Icon.svelte';
  export let x; export let big = false; export let selected = false; export let compact = false;
  const dispatch = createEventDispatcher();
  let n = 0; const t = setInterval(() => n++, 1000); onDestroy(() => clearInterval(t));
  $: st = MSTATUS[x.status] || MSTATUS.idle;
  $: rp = x.roll_code ? Math.max(0, Math.min(100, (x.roll_remaining / x.roll_length) * 100)) : 0;
  $: low = x.roll_code && +x.roll_remaining <= +x.alert_m;
  $: elapsed = (n, x.job_started ? clock(minsSince(x.job_started)) : '');
  $: since = (n, dur(minsSince(x.status_since)));
</script>
<button class="mc s-{x.status}" class:big class:selected class:off={!x.active} on:click={() => dispatch('open', x)}>
  <div class="head">
    <span class="dot {st[1]}"></span>
    <div class="grow"><b class="name">{x.name}</b><div class="faint tiny">{x.model || 'DTF'} · {num(+x.width_cm)} سم</div></div>
    <span class="chip c-{st[2]}">{st[0]}</span>
  </div>
  {#if x.status === 'running' && x.job_code}
    <div class="job">
      <div class="grow"><div class="faint tiny">يطبع الآن</div><b>طلبية {num(x.job_code)}</b> <span class="muted small">{m(x.job_meters)}</span>
        {#if x.jobs_running > 1}<span class="faint tiny"> +{num(x.jobs_running - 1)}</span>{/if}</div>
      <div class="timer num">{elapsed}</div>
    </div>
  {:else if x.status === 'down' || x.status === 'maintenance'}
    <div class="job warnbox"><Icon name={x.status === 'down' ? 'alert' : 'wrench'} size={18} /><div class="grow small">{x.status_note || '—'}</div><span class="faint tiny">{since}</span></div>
  {:else if !compact}
    <div class="job idlebox"><span class="faint small">في انتظار ملف · منذ {since}</span></div>
  {/if}
  <div class="roll">
    <div class="row between tiny"><span class="muted">{x.roll_code ? `الرولو ${x.roll_code}` : 'لا يوجد رولو مركّب'}</span>
      {#if x.roll_code}<b class:red={low} class="num">{(+x.roll_remaining).toFixed(1)} / {(+x.roll_length).toFixed(0)} م</b>{/if}</div>
    <div class="bar" class:low class:ok={!low && rp > 0}><i style="width:{rp}%"></i></div>
  </div>
  {#if !compact}
    <div class="foot tiny">
      <span><span class="faint">اليوم</span> <b>{m(x.meters_today, 1)}</b></span>
      <span><span class="faint">هدر</span> <b class:amber={+x.waste_today > 0}>{m(x.waste_today, 1)}</b></span>
      <span><span class="faint">المشغّل</span> <b>{x.operator_name || '—'}</b></span>
    </div>
  {/if}
</button>
<style>
  .mc { display: flex; flex-direction: column; gap: 12px; width: 100%; text-align: right; padding: 15px; border-radius: 18px;
    background: linear-gradient(180deg, #18191F, #131418); border: 1px solid var(--line); position: relative; overflow: hidden; transition: border-color .2s, transform .15s; }
  .mc:hover { border-color: var(--line2); transform: translateY(-1px); }
  .mc::after { content: ''; position: absolute; inset: 0 0 auto 0; height: 3px; background: var(--blue); opacity: .7; }
  .mc.s-running::after { background: linear-gradient(90deg, var(--green), var(--teal)); background-size: 200% 100%; animation: flow 2s linear infinite; }
  .mc.s-down { border-color: #F8717166; } .mc.s-down::after { background: var(--red); }
  .mc.s-maintenance::after { background: var(--amber); }
  .mc.selected { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
  .mc.off { opacity: .5; }
  @keyframes flow { to { background-position: -200% 0; } }
  .head { display: flex; align-items: center; gap: 10px; }
  .name { font-size: 15.5px; }
  .job { display: flex; align-items: center; gap: 10px; background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 10px 12px; min-height: 54px; }
  .warnbox { color: var(--amber); } .s-down .warnbox { color: var(--red); }
  .timer { font-size: 22px; font-weight: 700; color: var(--green); letter-spacing: .5px; }
  .big .timer { font-size: 30px; }
  .roll { display: flex; flex-direction: column; gap: 6px; }
  .foot { display: flex; justify-content: space-between; gap: 6px; border-top: 1px solid var(--line); padding-top: 10px; }
</style>
