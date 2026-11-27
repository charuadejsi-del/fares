<script>
  import { CONFIG } from './config.js';
  import { askNotify, notify } from './lib/notify.js';
  import { onMount } from 'svelte';
  import { sb, rpc, q, errMsg } from './lib/sb.js';
  import { me, settings, staff, shift, badges, liveTick, tv, toast, openModal, closeSheet, isMgr } from './lib/store.js';
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
  import OpenToggle from './components/OpenToggle.svelte';
  import Orders from './views/Orders.svelte';
  import Stock from './views/Stock.svelte';
  import Perf from './views/Perf.svelte';
  import Attendance from './views/Attendance.svelte';
  import Team from './views/Team.svelte';
  import Chat from './views/Chat.svelte';
  import Settings from './views/Settings.svelte';
  import Account from './views/Account.svelte';
  import Palette from './components/Palette.svelte';

  // Écrans : login | pinSetup | pinConfirm | clockIn | app | bye
  let stage = 'loading';
  let loginErr = '';
  let email = '', password = '', busy = false;
  let pinErr = '', firstPin = '';
  let pad;

  const NAV = [
    { id: 'dash', icon: 'control', t: 'مركز التحكّم', g: 'ws', roles: ['admin', 'manager'] },
    { id: 'orders', icon: 'orders', t: 'الطلبيات', g: 'ws', roles: ['admin', 'manager'] },
    { id: 'work', icon: 'design', t: 'مكتب التصميم', g: 'ws', roles: ['designer'] },
    { id: 'work', icon: 'machine', t: 'محطة الطباعة', g: 'ws', roles: ['printer'] },
    { id: 'machines', icon: 'machine', t: 'الآلات', g: 'ws', roles: ['admin', 'manager', 'printer'] },
    { id: 'stock', icon: 'stock', t: 'المخزون', g: 'biz', roles: ['admin', 'manager', 'printer'] },
    { id: 'costs', icon: 'coins', t: 'التكاليف والأرباح', g: 'biz', roles: ['admin'] },
    { id: 'chat', icon: 'chat', t: 'الدردشة', g: 'biz', roles: ['admin', 'manager'] },
    { id: 'perf', icon: 'trophy', t: 'الأداء', g: 'team', roles: ['admin', 'manager'] },
    { id: 'attendance', icon: 'clock', t: 'الحضور', g: 'team', roles: ['admin', 'manager'] },
    { id: 'team', icon: 'team', t: 'الفريق', g: 'team', roles: ['admin'] },
    { id: 'settings', icon: 'settings', t: 'الإعدادات', g: 'tools', roles: ['admin'] },
    { id: 'account', icon: 'user', t: 'حسابي', g: 'tools', roles: ['manager', 'designer', 'printer'] },
  ];
  const GROUPS = [['ws', 'الورشة'], ['biz', 'التجارة'], ['team', 'الفريق'], ['tools', 'أدوات']];
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
      settings.set(await q(sb.from('dtf_settings').select('*').limit(1).maybeSingle()));
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
    askNotify();
    channel = sb.channel('admin-live')
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_orders' }, e => { if (e.eventType === 'INSERT' && isMgr($me)) notify('طلبية جديدة رقم ' + e.new.code, (+e.new.billed_meters).toFixed(2) + ' م', 'o' + e.new.id); bump(); })
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_rolls' }, bump)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'dtf_machines' }, bump)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'dtf_settings' }, async () => { try { settings.set(await q(sb.from('dtf_settings').select('*').limit(1).maybeSingle())); } catch (_) {} bump(); })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_machine_events' }, bump)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_messages' }, e => { if (!e.new.from_staff && isMgr($me)) notify('رسالة جديدة من زبون', e.new.body?.slice(0, 120), 'm' + e.new.client_id); bump(); })
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'dtf_notifications' }, e => { if (e.new.user_id === $me.id) notify(e.new.title, e.new.body, 'n' + e.new.id); bump(); })
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
  // Coque « Ghania » : menu groupé repliable, recherche Ctrl+K, cloche, actualisation
  let collapsed = false; try { collapsed = localStorage.getItem('mydtf.side') === '1'; } catch (_) {}
  function toggleSide() { collapsed = !collapsed; try { localStorage.setItem('mydtf.side', collapsed ? '1' : '0'); } catch (_) {} }
  let palOpen = false, bellOpen = false, spin = false;
  $: total = Object.values($badges).reduce((s, v) => s + (+v || 0), 0);
  $: bellItems = [
    $badges.orders && { href: '#orders', icon: 'inbox', t: `${$badges.orders} طلبية جديدة تنتظر القبول` },
    $badges.chat && { href: '#chat', icon: 'chat', t: `${$badges.chat} رسالة من الزبائن لم تُقرأ` },
    $badges.work && { href: '#work', icon: 'orders', t: `${$badges.work} ملف في انتظارك` },
  ].filter(Boolean);
  function refresh() { spin = true; liveTick.update(n => n + 1); refreshBadges(); setTimeout(() => (spin = false), 700); }
  $: today = new Date(now).toLocaleDateString('ar-DZ', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
  function keys(e) {
    if (e.key === 'Escape') { if ($tv) tv.set(false); bellOpen = false; return; }
    if (stage !== 'app') return;
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); palOpen = !palOpen; return; }
    if ((e.altKey || e.ctrlKey) && /^[1-9]$/.test(e.key) && nav[+e.key - 1]) { e.preventDefault(); location.hash = nav[+e.key - 1].id; }
  }
</script>

<svelte:window on:mydtfsessionlost={() => { if (stage === 'app') { loginErr = 'انتهت جلستك — أعد الدخول بحسابك'; channel?.unsubscribe(); stage = 'login'; } }} on:mydtfhealed={() => liveTick.update(n => n + 1)} on:hashchange={syncRoute} on:beforeunload={beforeUnload} on:keydown={keys} />

{#if stage === 'loading'}
  <div class="center"><div class="spinner"></div></div>

{:else if stage === 'login'}
  <div class="center">
    <form class="card auth" on:submit|preventDefault={login}>
      <img src="/icon.svg" alt="" width="56" height="56" />
      <h1>{CONFIG.appName}</h1>
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
    <aside class="side" class:mini={collapsed}>
      <div class="brand"><span class="logo"><Icon name="roll" size={20} stroke={2.2} /></span><div class="bt"><b>{CONFIG.appName}</b><div class="gold tiny">تسيير الورشة</div></div></div>
      <nav>
        {#each GROUPS as [g, gt]}
          {#if nav.some(n => n.g === g)}
            <div class="gl">{gt}</div>
            {#each nav.filter(n => n.g === g) as n}
              {@const k = nav.indexOf(n) + 1}
              <a href="#{n.id}" class="nl" class:on={view === n.id} title={n.t}>
                <span class="ni"><Icon name={n.icon} size={19} />{#if $badges[n.id] && collapsed}<span class="badge dot">{$badges[n.id]}</span>{/if}</span>
                <span class="grow lt">{n.t}</span>
                {#if $badges[n.id]}<span class="badge lt">{$badges[n.id]}</span>{:else if k < 10}<kbd class="lt kb">Alt+{k}</kbd>{/if}
              </a>
            {/each}
          {/if}
        {/each}
      </nav>
      <div class="side-foot">
        {#if $shift?.since}
          <div class="card shift lt"><div class="faint tiny">بدأت العمل</div><div class="row between"><b class="gold">{time($shift.since)}</b><span class="faint tiny">{dur(minsSince($shift.since))}</span></div>
            <button class="btn danger sm block" style="margin-top:8px" on:click={() => openModal(ClockOut, { onDone: bye })}>تسجيل الخروج</button></div>
        {/if}
        <div class="ucard">
          <div class="avatar">{(firstName[0] || '?') + (($me.full_name.split(' ')[1] || '')[0] || '')}</div>
          <div class="grow lt"><b class="un">{$me.full_name}</b><div class="faint tiny">{ROLE[$me.role]}</div></div>
          <button class="ib lt" title="الخروج من الحساب" on:click={logout}><Icon name="logout" size={17} /></button>
          {#if $me.role === 'admin'}<a class="ib lt" href="#settings" title="الإعدادات"><Icon name="settings" size={17} /></a>{/if}
          <button class="ib" title={collapsed ? 'توسيع القائمة' : 'طيّ القائمة'} on:click={toggleSide}><Icon name={collapsed ? 'expand' : 'collapse'} size={17} /></button>
        </div>
      </div>
    </aside>

    <main>
      <header class="top">
        <div class="ttl grow">
          <span class="ti"><Icon name={nav.find(n => n.id === view)?.icon || 'control'} size={20} /></span>
          <div><h1>{nav.find(n => n.id === view)?.t || ''}</h1><div class="faint tiny">{greeting} {firstName} · {today}</div></div>
        </div>
        <button class="search" on:click={() => (palOpen = true)}><Icon name="search" size={17} /><span class="grow">ابحث، افتح طلبية…</span><kbd>Ctrl K</kbd></button>
        <OpenToggle compact={false} />
        <div class="bellw">
          <button class="ib big" title="التنبيهات" on:click={() => (bellOpen = !bellOpen)}><Icon name="bell" size={19} />{#if total}<span class="badge dot">{total}</span>{/if}</button>
          {#if bellOpen}
            <div class="drop card" on:click={() => (bellOpen = false)} role="presentation">
              <div class="section-title" style="margin-bottom:8px">التنبيهات</div>
              {#each bellItems as b}<a class="row ml" href={b.href}><Icon name={b.icon} size={18} /><span class="grow">{b.t}</span></a>
              {:else}<div class="empty small">لا يوجد شيء جديد</div>{/each}
            </div>
          {/if}
        </div>
        <button class="ib big" class:spin title="تحديث" on:click={refresh}><Icon name="refresh" size={18} /></button>
        {#if $shift?.since}<button class="btn danger sm mobile-only" on:click={() => openModal(ClockOut, { onDone: bye })}>خروج {time($shift.since)}</button>{/if}
      </header>
      {#if remind}
        <div class="notice row" style="margin-bottom:14px"><span class="grow">اقترب وقت نهاية العمل. لا تنسَ تسجيل خروجك بالرمز السري قبل المغادرة.</span>
          <button class="btn sm" on:click={() => openModal(ClockOut, { onDone: bye })}>تسجيل الخروج</button></div>
      {/if}
      {#key view}<div class="page-in"><svelte:component this={VIEWS[view]} /></div>{/key}
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

{#if palOpen}<Palette {nav} on:close={() => (palOpen = false)} />{/if}
<Overlays />
<Toast />


<style>
  .center { min-height: 100vh; display: grid; place-items: center; padding: 20px; }
  .auth { width: min(400px, 100%); padding: 28px; text-align: center; }
  .auth img { margin: 0 auto 10px; display: block; }
  .auth form, .auth label, .auth input { text-align: right; }
  .err { min-height: 22px; margin: 8px 0; }
  .shell { display: flex; min-height: 100vh; }
  .side { width: 250px; flex-shrink: 0; position: sticky; top: 0; height: 100vh; display: flex; flex-direction: column; transition: width .3s var(--ease);
    background: linear-gradient(180deg, #0B0E15, #090B11); border-left: 1px solid var(--line); padding: 16px 12px; }
  .side nav { flex: 1; overflow-y: auto; overflow-x: hidden; margin: 0 -4px; padding: 0 4px; }
  .brand { display: flex; align-items: center; gap: 10px; padding: 2px 6px 18px; }
  .logo { width: 40px; height: 40px; flex-shrink: 0; border-radius: 12px; display: grid; place-items: center; color: var(--accent-ink);
    background: linear-gradient(145deg, #F7D45E, #D99F10); box-shadow: 0 6px 18px #D99F1040, 0 1px 0 #ffffff60 inset; }
  .brand b { font-size: 16px; }
  .gl { font-size: 11px; color: var(--faint); padding: 14px 12px 6px; font-weight: 600; }
  .nl { display: flex; align-items: center; gap: 12px; padding: 9px 12px; border-radius: 12px; color: var(--muted); margin-bottom: 2px; font-weight: 500; border: 1px solid transparent; transition: background .2s, color .2s, border-color .2s; }
  .nl:hover { background: var(--card); color: var(--text); }
  .nl.on { background: linear-gradient(270deg, #E6B32522, #E6B32508); color: var(--accent2); border-color: #E6B32566; font-weight: 700; box-shadow: 0 0 22px #E6B32512; }
  .ni { position: relative; display: grid; place-items: center; }
  .kb { opacity: 0; transition: opacity .2s; } .nl:hover .kb, .nl.on .kb { opacity: 1; }
  .shell.tv .side, .shell.tv .top, .shell.tv .bottom { display: none !important; }
  .shell.tv main { padding: 18px; }
  :global(.tv) { font-size: 16.5px; }
  .side-foot { margin-top: 10px; display: flex; flex-direction: column; gap: 8px; }
  .shift { padding: 12px; }
  .ucard { display: flex; align-items: center; gap: 8px; padding: 10px; border-radius: 14px; background: var(--card); border: 1px solid var(--line); }
  .un { display: block; font-size: 13.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ib { width: 32px; height: 32px; flex-shrink: 0; border-radius: 10px; display: grid; place-items: center; color: var(--muted); position: relative; transition: background .2s, color .2s; }
  .ib:hover { background: var(--card2); color: var(--text); }
  .ib.big { width: 40px; height: 40px; }
  .ib.spin :global(svg) { animation: spin .7s var(--ease); }
  .side.mini { width: 78px; }
  .side.mini .lt, .side.mini .bt, .side.mini .gl { display: none; }
  .side.mini .nl { justify-content: center; padding: 11px 0; }
  .side.mini .gl + .nl, .side.mini nav > .nl:first-child { margin-top: 10px; }
  .side.mini .brand { justify-content: center; padding-inline: 0; }
  .side.mini .ucard { flex-direction: column; padding: 8px 4px; }
  .badge.dot { position: absolute; top: -6px; left: -8px; font-size: 10px; min-width: 16px; line-height: 16px; padding: 0 4px; }
  main { flex: 1; min-width: 0; padding: 0 26px 40px; }
  .top { position: sticky; top: 0; z-index: 50; display: flex; align-items: center; gap: 10px; margin: 0 -26px 18px; padding: 14px 26px; flex-wrap: wrap;
    background: #090B11e0; backdrop-filter: blur(12px); border-bottom: 1px solid var(--line); }
  .ttl { display: flex; align-items: center; gap: 12px; }
  .ti { width: 40px; height: 40px; border-radius: 50%; display: grid; place-items: center; color: var(--accent2); background: var(--accent-soft); border: 1px solid var(--accent-line); flex-shrink: 0; }
  .top h1 { font-size: 21px; line-height: 1.2; }
  .search { display: flex; align-items: center; gap: 10px; width: 300px; padding: 9px 12px; border-radius: 12px; background: var(--card); border: 1px solid var(--line); color: var(--faint); font-size: 13.5px; text-align: right; transition: border-color .2s; }
  .search:hover { border-color: var(--accent-line); }
  .bellw { position: relative; }
  .drop { position: absolute; top: 46px; left: 0; width: 300px; z-index: 60; padding: 12px; animation: rise .25s var(--spring); }
  .avatar { width: 36px; height: 36px; border-radius: 11px; display: grid; place-items: center; font-weight: 700; font-size: 13px; flex-shrink: 0; color: #fff; background: linear-gradient(145deg, #A99BFF, #6D5DE8); }
  .bottom, .mobile-only { display: none; }
  .more { position: fixed; z-index: 90; bottom: calc(70px + env(safe-area-inset-bottom)); left: 12px; width: 220px; padding: 6px; }
  .ml { padding: 11px 12px; border-radius: 10px; color: var(--text); width: 100%; }
  .ml:hover { background: var(--card2); }
  @media (max-width: 900px) {
    .side { display: none; }
    main { padding: 0 14px calc(86px + env(safe-area-inset-bottom)); }
    .top { margin: 0 -14px 14px; padding: 10px 14px; }
    .search { width: auto; flex: 0 0 auto; } .search span, .search kbd { display: none; }
    .ttl .ti { display: none; }
    .mobile-only { display: inline-flex; }
    .bottom { display: flex; position: fixed; z-index: 80; left: 0; right: 0; bottom: 0; background: var(--bg2); border-top: 1px solid var(--line);
      padding: 6px 4px calc(6px + env(safe-area-inset-bottom)); }
    .bl { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 11.5px; color: var(--muted); padding: 4px 0; }
    .bl.on { color: var(--accent2); }
    .ic { position: relative; display: grid; place-items: center; width: 52px; height: 30px; border-radius: 15px; }
    .bl.on .ic { background: var(--accent-soft); }
    .bl .badge.dot { top: -4px; left: 6px; }
  }
</style>
