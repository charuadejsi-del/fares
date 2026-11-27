<script>
  // Panneau (bas sur mobile, côté sur ordinateur) et fenêtre modale — sans flou, légers.
  import { sheet, modal, closeSheet, closeModal } from '../lib/store.js';
  function key(e) { if (e.key === 'Escape') { $modal ? closeModal() : closeSheet(); } }
</script>
<svelte:window on:keydown={key} />
{#if $sheet}
  <div class="scrim" on:click={closeSheet} role="presentation"></div>
  <aside class="sheet" role="dialog" aria-modal="true">
    <div class="grab"></div>
    <svelte:component this={$sheet.component} {...$sheet.props} />
  </aside>
{/if}
{#if $modal}
  <div class="scrim top" on:click={closeModal} role="presentation"></div>
  <div class="modal" role="dialog" aria-modal="true">
    <svelte:component this={$modal.component} {...$modal.props} />
  </div>
{/if}
<style>
  .scrim { position: fixed; inset: 0; background: #0008; z-index: 100; }
  .scrim.top { z-index: 200; }
  .sheet { position: fixed; z-index: 110; background: var(--bg); overflow-y: auto; overflow-x: hidden; overscroll-behavior: contain; overflow-wrap: anywhere;
    left: 0; right: 0; bottom: 0; max-height: 92vh; border-radius: 22px 22px 0 0; border-top: 1px solid var(--line);
    padding: 8px 16px calc(20px + env(safe-area-inset-bottom)); animation: slideUp .22s ease; }
  .grab { width: 44px; height: 5px; border-radius: 9px; background: var(--line2); margin: 4px auto 10px; }
  @keyframes slideUp { from { transform: translateY(40px); opacity: .4; } }
  @media (min-width: 901px) {
    .sheet { top: 0; bottom: 0; left: 0; right: auto; width: 520px; max-height: none; border-radius: 0; border-top: 0;
      border-right: 1px solid var(--line); padding: 20px; animation: slideIn .22s ease; }
    .grab { display: none; }
    @keyframes slideIn { from { transform: translateX(-30px); opacity: .4; } }
  }
  .modal { position: fixed; z-index: 210; left: 50%; top: 50%; transform: translate(-50%, -50%); width: min(440px, calc(100vw - 24px));
    max-height: calc(100vh - 40px); overflow-y: auto; overflow-x: hidden; overflow-wrap: anywhere; background: var(--card); border: 1px solid var(--line); border-radius: 20px; padding: 20px; box-shadow: var(--shadow); }
  .sheet :global(input), .sheet :global(select), .modal :global(input), .modal :global(select) { min-width: 0; }
  .sheet :global(.grid > *), .modal :global(.grid > *) { min-width: 0; }
  @media (max-width: 640px) { .modal { top: auto; bottom: 0; transform: translateX(-50%); width: 100vw; max-height: 92vh; border-radius: 20px 20px 0 0; padding-bottom: calc(20px + env(safe-area-inset-bottom)); } }
</style>
