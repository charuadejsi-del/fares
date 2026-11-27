<script>
  import { STATUS } from '../lib/fmt.js';
  export let status;
  $: s = STATUS[status] || [status, 'blue'];
</script>
<span class="chip c-{s[1]}">{s[0]}</span>
