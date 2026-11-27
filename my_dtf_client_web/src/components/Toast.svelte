<script>
  import { toastMsg } from '../lib/store.js';
</script>
{#if $toastMsg}
  <div class="toast" class:err={$toastMsg.error} role="status">{$toastMsg.text}</div>
{/if}
<style>
  .toast { position: fixed; z-index: 300; left: 50%; transform: translateX(-50%); bottom: calc(84px + env(safe-area-inset-bottom));
    background: var(--card); border: 1px solid var(--gold); color: var(--text); padding: 11px 18px; border-radius: 12px;
    box-shadow: var(--shadow); font-weight: 500; max-width: 92vw; animation: up .2s ease; }
  .toast.err { border-color: var(--red); }
  @keyframes up { from { opacity: 0; transform: translate(-50%, 10px); } }
  @media (min-width: 901px) { .toast { bottom: 24px; } }
</style>
