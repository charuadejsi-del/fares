<script>
  import { onMount } from 'svelte';
  import { sb, errMsg } from './lib/sb.js';
  import { me, notifs, messages, liveTick, toast } from './lib/store.js';
  import { myProfile, loadAll, live, stopLive, STAFF_ONLY } from './lib/api.js';
  import Toast from './components/Toast.svelte';
  import Icon from './components/Icon.svelte';
  import Auth from './views/Auth.svelte';
  import CompleteProfile from './views/CompleteProfile.svelte';
  import Home from './views/Home.svelte';
  import NewOrder from './views/NewOrder.svelte';
  import OrderDetail from './views/OrderDetail.svelte';
  import Chat from './views/Chat.svelte';
  import Archive from './views/Archive.svelte';
  import Account from './views/Account.svelte';
  import Notifications from './views/Notifications.svelte';

  let stage = 'loading', authErr = '';
  let route = '', param = '';
  function sync() { const h = location.hash.replace(/^#\/?/, ''); [route, param] = [h.split('/')[0] || 'home', h.split('/')[1] || '']; window.scrollTo(0, 0); }
  const ROUTES = { home: Home, new: NewOrder, order: OrderDetail, chat: Chat, archive: Archive, account: Account, notifications: Notifications };

  async function boot() {
    const { data: { session } } = await sb.auth.getSession();
    if (!session) { stage = 'auth'; return; }
    try {
      const p = await myProfile();
      if (p && p.role !== 'client') { await sb.auth.signOut(); authErr = STAFF_ONLY; stage = 'auth'; return; }
      if (!p) { stage = 'profile'; return; }
      me.set(p); await loadAll(); live(); stage = 'app'; sync();
    } catch (e) { authErr = errMsg(e); stage = 'auth'; }
  }
  onMount(boot);
  async function logout() { stopLive(); await sb.auth.signOut(); me.set(null); location.hash = ''; stage = 'auth'; }
  $: unread = $notifs.filter(n => !n.read).length;
  $: unreadChat = $messages.filter(m => m.from_staff && !m.read_by_client).length;
  const NAV = [['home', 'control', 'الرئيسية'], ['new', 'plus', 'طلبية جديدة'], ['archive', 'orders', 'طلبياتي'], ['chat', 'chat', 'الدردشة'], ['account', 'user', 'حسابي']];
</script>

<svelte:window on:hashchange={sync} />

{#if stage === 'loading'}<div class="center"><div class="spinner"></div></div>
{:else if stage === 'auth'}<Auth err={authErr} on:done={() => { authErr = ''; stage = 'loading'; boot(); }} />
{:else if stage === 'profile'}<CompleteProfile on:done={() => { stage = 'loading'; boot(); }} on:logout={logout} />
{:else}
  <div class="shell">
    <header class="top">
      <a href="#/" class="brand"><img src="/icon.svg" alt="" width="34" height="34" /><b>My DTF</b></a>
      <nav class="desk">{#each NAV as [id, ic, t]}<a href="#/{id === 'home' ? '' : id}" class:on={route === id}><Icon name={ic} size={18} />{t}{#if id === 'chat' && unreadChat}<span class="badge">{unreadChat}</span>{/if}</a>{/each}</nav>
      <a class="bell" href="#/notifications" aria-label="الإشعارات"><Icon name="inbox" size={22} />{#if unread}<span class="badge">{unread}</span>{/if}</a>
    </header>
    <main>{#key route + param}<div class="page-in"><svelte:component this={ROUTES[route] || Home} {param} on:logout={logout} /></div>{/key}</main>
    <nav class="bottom">{#each NAV as [id, ic, t]}<a href="#/{id === 'home' ? '' : id}" class="bl" class:on={route === id} class:fab={id === 'new'}><span class="ic"><Icon name={ic} size={id === 'new' ? 26 : 22} />{#if id === 'chat' && unreadChat}<span class="badge dot">{unreadChat}</span>{/if}</span><span>{t}</span></a>{/each}</nav>
  </div>
{/if}
<Toast />

<style>
  :global(.center) { min-height: 100vh; display: grid; place-items: center; padding: 20px; }
  .shell { max-width: 1080px; margin: 0 auto; }
  .top { position: sticky; top: 0; z-index: 40; display: flex; align-items: center; gap: 16px; padding: 12px 18px; background: #090B11E6; backdrop-filter: blur(10px); border-bottom: 1px solid var(--line); }
  .brand { display: flex; align-items: center; gap: 10px; color: var(--text); font-size: 17px; }
  .desk { display: flex; gap: 4px; margin-right: auto; }
  .desk a { display: flex; align-items: center; gap: 7px; padding: 8px 12px; border-radius: 10px; color: var(--muted); font-weight: 500; font-size: 14px; }
  .desk a.on { background: var(--accent-soft); color: var(--accent3); }
  .bell { position: relative; color: var(--text); padding: 6px; }
  .bell .badge { position: absolute; top: -2px; left: -4px; }
  main { padding: 18px 18px 40px; }
  .bottom { display: none; }
  @media (max-width: 800px) {
    .desk { display: none; } .bell { margin-right: auto; }
    main { padding: 14px 14px calc(92px + env(safe-area-inset-bottom)); }
    .bottom { display: flex; position: fixed; z-index: 80; left: 0; right: 0; bottom: 0; background: var(--bg2); border-top: 1px solid var(--line); padding: 6px 4px calc(6px + env(safe-area-inset-bottom)); }
    .bl { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 2px; font-size: 11px; color: var(--muted); }
    .bl.on { color: var(--accent2); }
    .ic { position: relative; display: grid; place-items: center; width: 48px; height: 30px; border-radius: 15px; }
    .bl.on .ic { background: var(--accent-soft); }
    .bl.fab .ic { width: 52px; height: 52px; margin-top: -24px; border-radius: 50%; color: var(--accent-ink); background: linear-gradient(180deg, #F5CD52, #DCA414); box-shadow: 0 8px 22px #DCA41466; }
    .badge.dot { position: absolute; top: -4px; left: 4px; }
  }
</style>
