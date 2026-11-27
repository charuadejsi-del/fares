<script>
  // Bureau du designer : fichiers avec miniatures, temps d'attente, aperçu du film, envoi à l'impression.
  import { rpc, errMsg } from '../lib/sb.js';
  import { liveTick, openSheet, toast } from '../lib/store.js';
  import { m, cm, num, dur, minsSince } from '../lib/fmt.js';
  import { orderThumbs } from '../lib/thumbs.js';
  import Ring from '../components/Ring.svelte';
  import Thumbs from '../components/Thumbs.svelte';
  import Chip from '../components/Chip.svelte';
  import Icon from '../components/Icon.svelte';
  import OrderSheet from './OrderSheet.svelte';

  let list = null, th = {};
  async function load() {
    try { list = await rpc('dtf_work_orders'); th = await orderThumbs(list.filter(o => o.status === 'in_design').map(o => o.id)); }
    catch (e) { toast(errMsg(e), true); list = list || []; }
  }
  $: $liveTick, load();
  $: todo = (list || []).filter(o => o.status === 'in_design').sort((a, b) => new Date(a.updated_at) - new Date(b.updated_at));
  $: today = new Date().toDateString();
  $: sent = (list || []).filter(o => o.status !== 'in_design' && new Date(o.updated_at).toDateString() === today);
  $: sentM = sent.reduce((s, o) => s + +o.billed_meters, 0);
  $: todoM = todo.reduce((s, o) => s + +o.estimated_length_cm / 100, 0);
  const LIMIT = 240;
  const tone = mn => mn > LIMIT ? 'var(--red)' : mn > LIMIT / 2 ? 'var(--amber)' : 'var(--green)';
  const open = o => openSheet(OrderSheet, { id: o.id, work: true });
</script>

{#if !list}<div class="spinner"></div>{:else}
  <div class="top card accent">
    <Ring value={sent.length + todo.length ? sent.length / (sent.length + todo.length) : 0} size={96} stroke={9}>
      <div><b class="num" style="font-size:22px">{sent.length}</b><div class="faint tiny">من {num(sent.length + todo.length)}</div></div>
    </Ring>
    <div class="grow"><h2>تقدّم اليوم</h2><div class="muted small">أرسلت {num(sent.length)} ملف إلى الطباعة ({m(sentM, 1)}) · بقي {num(todo.length)} ملف (~{m(todoM, 1)})</div></div>
    {#if todo[0]}<button class="btn lg" on:click={() => open(todo[0])}><Icon name="play" size={18} />ابدأ بالأقدم</button>{/if}
  </div>

  <div class="section-title" style="margin-top:20px">ملفات تنتظر التصميم<span class="end faint small">الأقدم أوّلاً</span></div>
  <div class="cards">
    {#each todo as o (o.id)}{@const w = minsSince(o.updated_at)}
      <button class="jc" on:click={() => open(o)}>
        <div class="row between">
          <div><h3>طلبية {num(o.code)}</h3><div class="faint tiny">{o.client_name}</div></div>
          <Ring value={Math.min(1, w / LIMIT)} size={54} stroke={5} color={tone(w)}><span class="tiny num" style="color:{tone(w)}">{dur(w)}</span></Ring>
        </div>
        <Thumbs list={th[o.id]} max={4} h={66} />
        <div class="row between small"><span class="muted">تقديري {cm(o.estimated_length_cm)}</span><span class="faint">{num((th[o.id] || []).reduce((s, i) => s + i.quantity, 0))} قطعة</span></div>
        {#if o.client_note}<div class="notice small">{o.client_note}</div>{/if}
        <span class="btn block">فتح الملف</span>
      </button>
    {:else}<div class="card empty"><Icon name="sparkle" size={30} /><div>لا توجد ملفات حالياً — عمل ممتاز</div></div>{/each}
  </div>

  {#if sent.length}
    <div class="section-title" style="margin-top:20px">أرسلتها اليوم</div>
    <div class="card list">{#each sent as o (o.id)}<div class="item row between"><span><b>طلبية {num(o.code)}</b> <span class="faint small">{m(o.billed_meters)}</span></span><Chip status={o.status} /></div>{/each}</div>
  {/if}
{/if}

<style>
  .top { display: flex; align-items: center; gap: 18px; flex-wrap: wrap; }
  .cards { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 12px; }
  .jc { display: flex; flex-direction: column; gap: 12px; text-align: right; padding: 15px; border-radius: 18px; background: linear-gradient(180deg, #18191F, #131418); border: 1px solid var(--line); transition: border-color .2s, transform .15s; }
  .jc:hover { border-color: var(--accent-line); transform: translateY(-2px); }
</style>
