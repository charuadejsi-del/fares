<script>
  import { onDestroy } from 'svelte';
  import { clock, minsSince } from '../lib/fmt.js';
  export let since;
  let n = 0; const t = setInterval(() => n++, 1000); onDestroy(() => clearInterval(t));
  $: label = (n, since ? clock(minsSince(since)) : '—');
</script>
<span class="num">{label}</span>
