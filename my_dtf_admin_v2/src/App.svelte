<script>
  import { onMount } from 'svelte';
  import { sb, rpc, q, errMsg } from './lib/sb.js';
  import { me, settings, staff, shift, badges, liveTick, tv, toast, openModal, closeSheet } from './lib/store.js';
  import { ROLE, time, dur, minsSince } from './lib/fmt.js';
  import Toast from './components/Toast.svelte';
  import Overlays from './components/Overlays.svelte';
  import PinPad from './components/PinPad.svelte';
  import ClockOut from './views/ClockOut.svelte';
  import Control from './views/Control.svelte';
  import Machines from './views/Machines.svelte';
  import Designer from './views/Designer.svelte';
  import Printer from './views/Printer.svelte';
  import Icon from './components/Icon.svelte';
  import Costs from './views/Costs.svelte';
  import Orders from './views/Orders.svelte';
  import Stock from './views/Stock.svelte';
  import Perf from './views/Perf.svelte';
  import Attendance from './views/Attendance.svelte';
  import Team from './views/Team.svelte';
  import Chat from './views/Chat.svelte';
  import Settings from './views/Settings.svelte';
  import Account from './views/Account.svelte';

  // Écrans : login | pinSetup | pinConfirm | clockIn | app | bye
  let stage = 'loading';
  let loginErr = '';
  let email = '', password = '', busy = false;
  let pinErr = '', firstPin = '';
  let pad;

  const NAV = [
    { id: 'dash', icon: 'control', t: 'مركز التحكّم', roles: ['admin', 'manager'] },
    { id: 'orders', icon: 'orders', t: 'الطلبيات', roles: ['admin', 'manager'] },
    { id: 'work', icon: 'design', t: 'مكتب التصميم', roles: ['designer'] },
    { id: 'work', icon: 'machine', t: 'محطة الطباعة', roles: ['printer'] },
    { id: 'machines', icon: 'machine', t: 'الآلات', roles: ['admin', 'manager', 'printer'] },
    { id: 'stock', icon: 'stock', t: 'المخزون', roles: ['admin', 'manager', 'printer'] },
    { id: 'chat', icon: 'chat', t: 'الدردشة', roles: ['admin', 'manager'] },
    { id: 'costs', icon: 'coins', t: 'التكاليف والأرباح', roles: ['admin'] },
    { id: 'perf', icon: 'trophy', t: 'الأداء', roles: ['admin', 'manager'] },
    { id: 'attendance', icon: 'clock', t: 'الحضور', roles: ['admin', 'manager'] },
    { id: 'team', icon: 'team', t: 'الفريق', roles: ['admin'] },
    { id: 'settings', icon: 'settings', t: 'الإعدادات', roles: ['admin'] },
    { id: 'account', icon: 'user', t: 'حسابي', roles: ['manager', 'designer', 'printer'] },
  ];
  $: VIEWS = { dash: Control, orders: Orders, work: $me?.role === 'printer' ? Printer : Designer, machines: Machines, costs: Costs, stock: Stock, perf: Perf, attendance: Attendance, team: Team, chat: Chat, settings: Settings, account: Account };

  $: nav = $me ? NAV.filter(n => n.roles.includes($me.role)) : [];
  $: mobileNav = nav.slice(0, 5);
  let view = '';
  function syncRoute() {
    const v = location.hash.slice(1);
    view = nav.find(n => n.id === v) ? v : nav[0]?.id;
    closeSheet();
  }
  $: if (nav.length && !view) syncRoute();

  async function boot() {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) { stage = 'login'; return; }
    try {
      const p = await q(sb.from('dtf_profiles').select('*').eq('id', session.user.id).maybeSingle());
      if (!p || p.role === 'client' || !p.active) { await sb.auth.signOut(); loginErr = 'هذا الحساب ليس من فريق الورشة'; stage = 'login'; return; }
      me.set(p);
      settings.set(await q(sb.from('dtf_settings').select('*').single()));
      staff.set(await q(sb.from('dtf_profiles').select('id,full_name,role,active,phone').neq('role', 'client').order('full_name')));
      if (p.role === 'admin') return enter();
      const st = (await rpc('dtf_pin_status'))[0];
      if (st.clocked_in) { shift.set({ since: st.since, end: st.work_end }); return enter(); }
      shift.set({ since: null, end: st.work_end });
      stage = st.has_pin ? 'clockIn' : 'pinSetup';
    } catch (e) { loginErr = errMsg(e); stage = 'login'; }
  }

  async function login() {
    busy = true; loginErr = '';
    const { error } = await sb.auth.signInWithPassword({ email: email.trim(), password });
    busy = false;
    if (error) { loginErr = errMsg(error); return; }
    stage = 'loading'; boot();
  }

  async function onPinSetup(e) { firstPin = e.detail; stage = 'pinConfirm'; pinErr = ''; }
  async function onPinConfirm(e) {
    if (e.detail !== firstPin) { stage = 'pinSetup'; pinErr = 'الرمزان غير متطابقين، أعد المحاولة'; return; }
    try { await rpc('dtf_pin_set', { p_new: e.detail }); toast('تم حفظ رمزك السري'); stage = 'clockIn'; pinErr = ''; }
    catch (err) { pad?.reset(errMsg(err)); }
  }
  async function onClockIn(e) {
    try {
      const a = await rpc('dtf_clock_in', { p_pin: e.detail });
      shift.update(s => ({ ...s, since: a.clock_in }));
      toast('سُجّل دخولك على الساعة ' + time(a.clock_in));
      enter();
    } catch (err) { pad?.reset(errMsg(err)); }
  }

  let channel, beat;
  function enter() {
    stage = 'app';
    syncRoute();
    refreshBadges();
    channel = sb.channel('admin-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_orders' }, bump)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_rolls' }, bump)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_machines' }, bump)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_machine_events' }, bump)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_messages' }, bump)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_notifications' }, bump)
      .subscribe();
    beat = setInterval(() => { now = Date.now(); refreshBadges(); }, 60000);
  }
  let bt;
  function bump() { clearTimeout(bt); bt = setTimeout(() => { liveTick.update(n => n + 1); refreshBadges(); }, 400); }

  async function refreshBadges() {
    const b = {};
    try {
      const r = $me?.role;
      if (r === 'admin' || r === 'manager') {
        const { count } = await sb.from('dtf_orders').select('id', { count: 'exact', head: true }).eq('status', 'new');
        b.orders = count || 0;
        const conv = await q(sb.from('dtf_conversations').select('unread'));
        b.chat = conv.reduce((s, c) => s + (+c.unread || 0), 0);
      } else if (r === 'designer' || r === 'printer') {
        const w = await rpc('dtf_work_orders');
        b.work = w.filter(o => (r === 'designer' ? o.status === 'in_design' : o.status === 'ready_to_print')).length;
      }
    } catch (_) {}
    badges.set(b);
  }

  // Rappel de pointage de sortie
  let now = Date.now();
  $: remind = (() => {
    if (!$shift?.since || !$shift?.end) return false;
    const [h, mn] = $shift.end.split(':').map(Number);
    const d = new Date(now); d.setHours(h, mn - 15, 0, 0);
    return now >= +d;
  })();
  function beforeUnload(e) { if ($shift?.since) { e.preventDefault(); e.returnValue = ''; } }

  async function logout() {
    if ($shift?.since && !confirm('لم تسجّل خروجك من العمل بعد. هل تريد الخروج من الحساب دون تسجيل الخروج؟')) return;
    await sb.auth.signOut(); location.hash = ''; location.reload();
  }
  function bye(e) { stage = 'bye'; byeInfo = e.detail; channel?.unsubscribe(); clearInterval(beat); }
  let byeInfo = null;
  let moreOpen = false;

  onMount(() => { boot(); });
  $: firstName = $me?.full_name?.split(' ')[0] || '';
  $: greeting = new Date().getHours() < 12 ? 'صباح الخير' : 'مساء الخير';
</script>

<svelte:window on:hashchange={syncRoute} on:beforeunload={beforeUnload} on:keydown={e => e.key === "Escape" && $tv && tv.set(false)} />

{#if stage === 'loading'}
  <div class="center"><div class="spinner"></div></div>

{:else if stage === 'login'}
  <div class="center">
    <form class="card auth" on:submit|preventDefault={login}>
      <img src="/icon.svg" alt="" width="56" height="56" />
      <h1>My DTF</h1>
      <p class="muted small">لوحة إدارة الورشة</p>
      <label for="em">البريد الإلكتروني</label>
      <input id="em" type="email" dir="ltr" autocomplete="username" required bind:value={email} />
      <label for="pw">كلمة السر</label>
      <input id="pw" type="password" dir="ltr" autocomplete="current-password" required bind:value={password} />
      <p class="red small err">{loginErr}</p>
      <button class="btn lg block" disabled={busy}>{busy ? '...' : 'دخول'}</button>
    </form>
  </div>

{:else if stage === 'pinSetup'}
  <div class="center"><PinPad bind:this={pad} title="اختر رمزك السري" subtitle="من 4 إلى 6 أرقام، تستعمله كل يوم عند الدخول وعند الخروج" error={pinErr} initial={firstName[0]} on:submit={onPinSetup} /></div>
{:else if stage === 'pinConfirm'}
  <div class="center"><PinPad bind:this={pad} title="أعد كتابة الرمز للتأكيد" initial={firstName[0]} on:submit={onPinConfirm} /></div>
{:else if stage === 'clockIn'}
  <div class="center">
    <PinPad bind:this={pad} title="{greeting} {firstName}" subtitle="أدخل رمزك السري لتسجيل بداية العمل" initial={firstName[0]} on:submit={onClockIn}>
      <button class="btn quiet sm" style="margin-top:22px" on:click={logout}>الخروج من الحساب</button>
    </PinPad>
  </div>

{:else if stage === 'bye'}
  <div class="center"><div class="card auth">
    <h2>إلى اللقاء {firstName}</h2>
    <p class="muted" style="margin:8px 0 18px">سُجّل خروجك على الساعة {time(byeInfo?.clock_out)} · مدّة العمل اليوم {dur((new Date(byeInfo?.clock_out) - new Date(byeInfo?.clock_in)) / 60000)}</p>
    <button class="btn block" on:click={() => location.reload()}>دخول جديد</button>
  </div></div>

{:else}
  <div class="shell" class:tv={$tv}>
    <aside class="side">
      <div class="brand"><img src="/icon.svg" alt="" width="38" height="38" /><div><b>My DTF</b><div class="faint tiny">مركز تحكّم الورشة</div></div></div>
      <nav>
        {#each nav as n}
          <a href="#{n.id}" class="nl" class:on={view === n.id}>
            <Icon name={n.icon} size={20} />
            <span class="grow">{n.t}</span>
            {#if $badges[n.id]}<span class="badge">{$badges[n.id]}</span>{/if}
          </a>
        {/each}
      </nav>
      <div class="side-foot">
        {#if $shift?.since}
          <div class="card shift"><div class="faint tiny">بدأت العمل</div><div class="row between"><b class="gold">{time($shift.since)}</b><span class="faint tiny">{dur(minsSince($shift.since))}</span></div>
            <button class="btn danger sm block" style="margin-top:8px" on:click={() => openModal(ClockOut, { onDone: bye })}>تسجيل الخروج</button></div>
        {/if}
        <button class="btn quiet sm block" on:click={logout}><Icon name="logout" size={16} />الخروج من الحساب</button>
      </div>
    </aside>

    <main>
      <header class="top">
        <div class="grow"><h1>{nav.find(n => n.id === view)?.t || ''}</h1></div>
        {#if $shift?.since}<button class="btn danger sm mobile-only" on:click={() => openModal(ClockOut, { onDone: bye })}>خروج {time($shift.since)}</button>{/if}
        <div class="who"><div class="text-left"><b>{$me.full_name}</b><div class="faint tiny">{ROLE[$me.role]}</div></div><div class="avatar">{firstName[0] || '?'}</div></div>
      </header>
      {#if remind}
        <div class="notice row" style="margin-bottom:14px"><span class="grow">اقترب وقت نهاية العمل. لا تنسَ تسجيل خروجك بالرمز السري قبل المغادرة.</span>
          <button class="btn sm" on:click={() => openModal(ClockOut, { onDone: bye })}>تسجيل الخروج</button></div>
      {/if}
      {#key view}<svelte:component this={VIEWS[view]} />{/key}
    </main>

    <nav class="bottom">
      {#each mobileNav as n}
        <a href="#{n.id}" class="bl" class:on={view === n.id}>
          <span class="ic"><Icon name={n.icon} size={22} />{#if $badges[n.id]}<span class="badge dot">{$badges[n.id]}</span>{/if}</span>
          <span>{n.t}</span>
        </a>
      {/each}
      {#if nav.length > 5}
        <a href="#{nav[5].id}" class="bl" class:on={nav.slice(5).some(n => n.id === view)} on:click|preventDefault={() => (moreOpen = !moreOpen)}>
          <span class="ic"><Icon name="more" size={22} /></span><span>المزيد</span>
        </a>
      {/if}
    </nav>
    {#if moreOpen}
      <div class="more card" on:click={() => (moreOpen = false)} role="presentation">
        {#each nav.slice(5) as n}<a href="#{n.id}" class="row ml"><Icon name={n.icon} size={20} />{n.t}</a>{/each}
        <button class="row ml" on:click={logout}><Icon name="logout" size={20} />الخروج من الحساب</button>
      </div>
    {/if}
  </div>
{/if}

<Overlays />
<Toast />


<style>
  .center { min-height: 100vh; display: grid; place-items: center; padding: 20px; }
  .auth { width: min(400px, 100%); padding: 28px; text-align: center; }
  .auth img { margin: 0 auto 10px; display: block; }
  .auth form, .auth label, .auth input { text-align: right; }
  .err { min-height: 22px; margin: 8px 0; }
  .shell { display: flex; min-height: 100vh; }
  .side { width: 240px; flex-shrink: 0; position: sticky; top: 0; height: 100vh; display: flex; flex-direction: column;
    background: var(--bg2); border-left: 1px solid var(--line); padding: 18px 12px; }
  .brand { display: flex; align-items: center; gap: 10px; padding: 4px 8px 20px; }
  .nl { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 12px; color: var(--muted); margin-bottom: 2px; font-weight: 500; }
  .nl:hover { background: var(--card); color: var(--text); }
  .nl.on { background: linear-gradient(90deg, transparent, var(--accent-soft)); color: var(--accent3); box-shadow: inset -3px 0 0 var(--accent); }
  .shell.tv .side, .shell.tv .top, .shell.tv .bottom { display: none !important; }
  .shell.tv main { padding: 18px; }
  :global(.tv) { font-size: 16.5px; }
  .side-foot { margin-top: auto; display: flex; flex-direction: column; gap: 8px; }
  .shift { padding: 12px; }
  main { flex: 1; min-width: 0; padding: 22px 26px 40px; }
  .top { display: flex; align-items: center; gap: 12px; margin-bottom: 18px; }
  .who { display: flex; align-items: center; gap: 10px; }
  .text-left { text-align: left; }
  .avatar { width: 38px; height: 38px; border-radius: 50%; display: grid; place-items: center; font-weight: 700; background: var(--card2); color: var(--accent2); border: 1px solid var(--line2); }
  .bottom, .mobile-only { display: none; }
  .more { position: fixed; z-index: 90; bottom: calc(70px + env(safe-area-inset-bottom)); left: 12px; width: 220px; padding: 6px; }
  .ml { padding: 11px 12px; border-radius: 10px; color: var(--text); width: 100%; }
  .ml:hover { background: var(--card2); }
  @media (max-width: 900px) {
    .side { display: none; }
    main { padding: 14px 14px calc(86px + env(safe-area-inset-bottom)); }
    .who { display: none; }
    .mobile-only { display: inline-flex; }
    .bottom { display: flex; position: fixed; z-index: 80; left: 0; right: 0; bottom: 0; background: var(--bg2); border-top: 1px solid var(--line);
      padding: 6px 4px calc(6px + env(safe-area-inset-bottom)); }
    .bl { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 11.5px; color: var(--muted); padding: 4px 0; }
    .bl.on { color: var(--accent2); }
    .ic { position: relative; display: grid; place-items: center; width: 52px; height: 30px; border-radius: 15px; }
    .bl.on .ic { background: var(--accent-soft); }
    .badge.dot { position: absolute; top: -4px; left: 6px; }
  }
</style>
