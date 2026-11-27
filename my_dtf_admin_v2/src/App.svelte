<script>
  import { onMount } from 'svelte';
  import { sb, rpc, q, errMsg } from './lib/sb.js';
  import { me, settings, staff, shift, badges, liveTick, toast, openModal, closeSheet } from './lib/store.js';
  import { ROLE, time, dur, minsSince } from './lib/fmt.js';
  import Toast from './components/Toast.svelte';
  import Overlays from './components/Overlays.svelte';
  import PinPad from './components/PinPad.svelte';
  import ClockOut from './views/ClockOut.svelte';
  import Dashboard from './views/Dashboard.svelte';
  import Orders from './views/Orders.svelte';
  import Work from './views/Work.svelte';
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
    { id: 'dash', icon: 'M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z', t: 'الرئيسية', roles: ['admin', 'manager'] },
    { id: 'orders', icon: 'M19 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z', t: 'الطلبيات', roles: ['admin', 'manager'] },
    { id: 'work', icon: 'M12 3a9 9 0 0 0 0 18c.8 0 1.5-.7 1.5-1.5 0-.4-.2-.7-.4-1-.2-.3-.4-.6-.4-1 0-.8.7-1.5 1.5-1.5H16a5 5 0 0 0 5-5c0-4.4-4-8-9-8zm-5.5 9a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm3-4a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm5 0a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3zm3 4a1.5 1.5 0 1 1 0-3 1.5 1.5 0 0 1 0 3z', t: 'ملفاتي', roles: ['designer'] },
    { id: 'work', icon: 'M19 8H5a3 3 0 0 0-3 3v6h4v4h12v-4h4v-6a3 3 0 0 0-3-3zm-3 11H8v-5h8v5zm3-7a1 1 0 1 1 0-2 1 1 0 0 1 0 2zm-1-9H6v4h12V3z', t: 'الطباعة', roles: ['printer'] },
    { id: 'stock', icon: 'M20 6h-4V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v2H4a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2zM10 4h4v2h-4V4z', t: 'المخزون', roles: ['admin', 'manager', 'printer'] },
    { id: 'chat', icon: 'M20 2H4a2 2 0 0 0-2 2v18l4-4h14a2 2 0 0 0 2-2V4a2 2 0 0 0-2-2z', t: 'الدردشة', roles: ['admin', 'manager'] },
    { id: 'perf', icon: 'M7 21h10v-2H7v2zM17 4V2H7v2H2v5c0 2.5 1.8 4.6 4.3 5 .7 1.8 2.3 3.1 4.2 3.5V19h3v-1.5c1.9-.4 3.5-1.7 4.2-3.5 2.5-.4 4.3-2.5 4.3-5V4h-5zM4 9V6h3v5.8C5.3 11.4 4 10.3 4 9zm16 0c0 1.3-1.3 2.4-3 2.8V6h3v3z', t: 'الأداء', roles: ['admin', 'manager'] },
    { id: 'attendance', icon: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 11h-5V11h3V6h2v7z', t: 'الحضور', roles: ['admin', 'manager'] },
    { id: 'team', icon: 'M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm-8 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-2.3 0-7 1.2-7 3.5V19h14v-2.5C15 14.2 10.3 13 8 13zm8 0c-.3 0-.6 0-1 .1 1.2.8 2 2 2 3.4V19h6v-2.5c0-2.3-4.7-3.5-7-3.5z', t: 'الفريق', roles: ['admin'] },
    { id: 'settings', icon: 'M19.4 13a7.6 7.6 0 0 0 0-2l2.1-1.6-2-3.5-2.5 1a7.7 7.7 0 0 0-1.7-1L15 3h-4l-.3 2.9a7.7 7.7 0 0 0-1.7 1l-2.5-1-2 3.5L6.6 11a7.6 7.6 0 0 0 0 2l-2.1 1.6 2 3.5 2.5-1a7.7 7.7 0 0 0 1.7 1L11 21h4l.3-2.9a7.7 7.7 0 0 0 1.7-1l2.5 1 2-3.5-2.1-1.6zM13 15.5a3.5 3.5 0 1 1 0-7 3.5 3.5 0 0 1 0 7z', t: 'الإعدادات', roles: ['admin'] },
    { id: 'account', icon: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zm0 2c-2.7 0-8 1.3-8 4v2h16v-2c0-2.7-5.3-4-8-4z', t: 'حسابي', roles: ['manager', 'designer', 'printer'] },
  ];
  const VIEWS = { dash: Dashboard, orders: Orders, work: Work, stock: Stock, perf: Perf, attendance: Attendance, team: Team, chat: Chat, settings: Settings, account: Account };

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

<svelte:window on:hashchange={syncRoute} on:beforeunload={beforeUnload} />

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
  <div class="shell">
    <aside class="side">
      <div class="brand"><img src="/icon.svg" alt="" width="38" height="38" /><div><b>My DTF</b><div class="faint tiny">{ROLE[$me.role]}</div></div></div>
      <nav>
        {#each nav as n}
          <a href="#{n.id}" class:on={view === n.id}>
            <svg viewBox="0 0 24 24" width="20" height="20"><path d={n.icon} fill="currentColor" /></svg>
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
        <button class="btn quiet sm block" on:click={logout}>الخروج من الحساب</button>
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
        <a href="#{n.id}" class:on={view === n.id}>
          <span class="ic"><svg viewBox="0 0 24 24" width="22" height="22"><path d={n.icon} fill="currentColor" /></svg>{#if $badges[n.id]}<span class="badge dot">{$badges[n.id]}</span>{/if}</span>
          <span>{n.t}</span>
        </a>
      {/each}
      {#if nav.length > 5}
        <a href="#{nav[5].id}" class:on={nav.slice(5).some(n => n.id === view)} on:click|preventDefault={() => (moreOpen = !moreOpen)}>
          <span class="ic"><svg viewBox="0 0 24 24" width="22" height="22"><path d="M6 10a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm6 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4zm6 0a2 2 0 1 0 0 4 2 2 0 0 0 0-4z" fill="currentColor" /></svg></span><span>المزيد</span>
        </a>
      {/if}
    </nav>
    {#if moreOpen}
      <div class="more card" on:click={() => (moreOpen = false)} role="presentation">
        {#each nav.slice(5) as n}<a href="#{n.id}" class="row"><svg viewBox="0 0 24 24" width="20" height="20"><path d={n.icon} fill="currentColor" /></svg>{n.t}</a>{/each}
        <button class="row" on:click={logout}>الخروج من الحساب</button>
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
  .side nav a { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 12px; color: var(--muted); margin-bottom: 2px; font-weight: 500; }
  .side nav a:hover { background: var(--card); color: var(--text); }
  .side nav a.on { background: var(--gold-soft); color: var(--gold); }
  .side-foot { margin-top: auto; display: flex; flex-direction: column; gap: 8px; }
  .shift { padding: 12px; }
  main { flex: 1; min-width: 0; padding: 22px 26px 40px; }
  .top { display: flex; align-items: center; gap: 12px; margin-bottom: 18px; }
  .who { display: flex; align-items: center; gap: 10px; }
  .text-left { text-align: left; }
  .avatar { width: 38px; height: 38px; border-radius: 50%; display: grid; place-items: center; font-weight: 700; background: var(--card2); color: var(--gold); border: 1px solid var(--line2); }
  .bottom, .mobile-only { display: none; }
  .more { position: fixed; z-index: 90; bottom: calc(70px + env(safe-area-inset-bottom)); left: 12px; width: 220px; padding: 6px; }
  .more a, .more button { padding: 11px 12px; border-radius: 10px; color: var(--text); width: 100%; }
  .more a:hover, .more button:hover { background: var(--card2); }
  @media (max-width: 900px) {
    .side { display: none; }
    main { padding: 14px 14px calc(86px + env(safe-area-inset-bottom)); }
    .who { display: none; }
    .mobile-only { display: inline-flex; }
    .bottom { display: flex; position: fixed; z-index: 80; left: 0; right: 0; bottom: 0; background: var(--bg2); border-top: 1px solid var(--line);
      padding: 6px 4px calc(6px + env(safe-area-inset-bottom)); }
    .bottom a { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 11.5px; color: var(--muted); padding: 4px 0; }
    .bottom a.on { color: var(--gold); }
    .ic { position: relative; display: grid; place-items: center; width: 52px; height: 30px; border-radius: 15px; }
    .bottom a.on .ic { background: var(--gold-soft); }
    .badge.dot { position: absolute; top: -4px; left: 6px; }
  }
</style>
