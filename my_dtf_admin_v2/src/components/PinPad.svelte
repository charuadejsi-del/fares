<script>
  // Clavier PIN toujours ordonné 1-2-3 (gauche → droite), comme un téléphone.
  import { createEventDispatcher } from 'svelte';
  export let title; export let subtitle = ''; export let error = ''; export let initial = '?';
  const dispatch = createEventDispatcher();
  let v = ''; let shake = false;
  export function reset(msg = '') { v = ''; error = msg; if (msg) { shake = true; setTimeout(() => (shake = false), 400); } }
  function press(k) {
    if (k === 'del') v = v.slice(0, -1);
    else if (k === 'ok') { if (v.length >= 4) dispatch('submit', v); return; }
    else if (v.length < 6) v += k;
    if (v.length === 6) dispatch('submit', v);
  }
  function key(e) {
    if (/^\d$/.test(e.key)) press(e.key);
    else if (e.key === 'Backspace') press('del');
    else if (e.key === 'Enter') press('ok');
  }
  $: dots = Math.max(4, v.length);
</script>
<svelte:window on:keydown={key} />
<div class="wrap">
  <div class="avatar">{initial}</div>
  <h2>{title}</h2>
  {#if subtitle}<p class="muted small">{subtitle}</p>{/if}
  <div class="dots" class:shake>{#each Array(dots) as _, i}<i class:f={i < v.length}></i>{/each}</div>
  <p class="red small err">{error}</p>
  <div class="pad" dir="ltr">
    {#each ['1','2','3','4','5','6','7','8','9'] as k}<button on:click={() => press(k)}>{k}</button>{/each}
    <button class="fn" on:click={() => press('del')} aria-label="مسح">⌫</button>
    <button on:click={() => press('0')}>0</button>
    <button class="ok" on:click={() => press('ok')} disabled={v.length < 4}>تأكيد</button>
  </div>
  <slot />
</div>
<style>
  .wrap { text-align: center; }
  .avatar { width: 64px; height: 64px; border-radius: 50%; margin: 0 auto 12px; display: grid; place-items: center; font-size: 24px; font-weight: 700;
    background: var(--card2); color: var(--gold); border: 1px solid var(--line2); }
  .dots { display: flex; justify-content: center; gap: 14px; margin: 18px 0 6px; direction: ltr; }
  .dots i { width: 14px; height: 14px; border-radius: 50%; border: 2px solid var(--gold); transition: background .12s; }
  .dots i.f { background: var(--gold); }
  .err { min-height: 22px; }
  .pad { display: grid; grid-template-columns: repeat(3, 74px); gap: 12px; justify-content: center; margin-top: 6px; }
  .pad button { height: 64px; border-radius: 18px; background: var(--card); border: 1px solid var(--line); font-size: 22px; font-weight: 600; }
  .pad button:active { background: var(--card2); }
  .pad .fn { font-size: 20px; color: var(--muted); }
  .pad .ok { background: var(--gold); color: var(--gold-ink); font-size: 15px; border: 0; }
  .pad .ok:disabled { opacity: .4; }
  .shake { animation: sh .35s; }
  @keyframes sh { 25%, 75% { transform: translateX(-8px); } 50% { transform: translateX(8px); } }
</style>
