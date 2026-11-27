<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { shift, closeModal } from '../lib/store.js';
  import { time } from '../lib/fmt.js';
  import PinPad from '../components/PinPad.svelte';
  export let onDone = () => {};
  let pad;
  async function go(e) {
    try {
      const a = await rpc('dtf_clock_out', { p_pin: e.detail });
      shift.set(null); closeModal(); onDone({ detail: a });
    } catch (err) { pad.reset(errMsg(err)); }
  }
</script>
<PinPad bind:this={pad} title="تسجيل الخروج" subtitle="بدأت العمل على الساعة {time($shift?.since)} — أدخل رمزك السري" initial="⏏" on:submit={go}>
  <button class="btn quiet sm" style="margin-top:16px" on:click={closeModal}>إلغاء</button>
</PinPad>
