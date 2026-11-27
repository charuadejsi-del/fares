<script>
  // Encre et poudre : niveau, jours restants, achats, inventaire.
  import { sb, q } from '../lib/sb.js';
  import { me, liveTick, openModal, staffName } from '../lib/store.js';
  import { da, dt, num, ltr } from '../lib/fmt.js';
  import Icon from './Icon.svelte';
  import SupplyForm from '../views/SupplyForm.svelte';
  export let compact = false;
  let list = null, moves = [], use7 = {};
  async function load() {
    try {
      const since = new Date(Date.now() - 7 * 864e5).toISOString();
      const [s, mv] = await Promise.all([
        q(sb.from('dtf_supplies').select('*').order('kind')),
        q(sb.from('dtf_supply_moves').select('*').order('created_at', { ascending: false }).limit(compact ? 1 : 300)),
      ]);
      list = s; moves = mv;
      use7 = {};
      mv.filter(x => ['print', 'waste'].includes(x.move) && x.created_at >= since).forEach(x => (use7[x.kind] = (use7[x.kind] || 0) - +x.qty));
    } catch (_) { list = list || []; }
  }
  $: $liveTick, load();
  $: mgr = ['admin', 'manager'].includes($me?.role);
  const L = { ink: ['الحبر', 'لتر', 'roll'], powder: ['البودرة', 'كغ', 'stock'] };
  const MV = { purchase: 'شراء', print: 'طباعة', waste: 'هدر', adjust: 'جرد' };
  const fmtQ = (k, v) => ltr((v / 1000).toFixed(2)) + ' ' + L[k][1];
</script>
{#if list}
  <div class="grid g2 stack">
    {#each list as s (s.kind)}{@const low = +s.stock <= +s.alert}{@const daily = (use7[s.kind] || 0) / 7}{@const cap = Math.max(+s.alert * 4, +s.stock, 1)}
      <div class="card sup" class:low>
        <div class="row between"><div class="row"><span class="ic"><Icon name={s.kind === 'ink' ? 'sparkle' : 'stock'} size={18} /></span><b>{L[s.kind][0]}</b></div>
          {#if low}<span class="chip c-red">قارب على النفاد</span>{/if}</div>
        <div class="big num" class:red={low}>{fmtQ(s.kind, Math.max(0, +s.stock))}</div>
        <div class="bar" class:low class:ok={!low}><i style="width:{Math.min(100, (Math.max(0, s.stock) / cap) * 100)}%"></i></div>
        <div class="row between tiny muted">
          <span>{daily > 0 ? `يكفي حوالي ${ltr(String(Math.floor(Math.max(0, s.stock) / daily)))} يوم` : 'لا استهلاك في 7 أيام'}</span>
          <span>التنبيه تحت {fmtQ(s.kind, +s.alert)}</span>
        </div>
        {#if mgr && !compact}
          <div class="faint tiny">متوسّط السعر {da(s.avg_price)} لل{L[s.kind][1]}</div>
          <div class="row wrap" style="margin-top:4px">
            <button class="btn sm" on:click={() => openModal(SupplyForm, { kind: s.kind, mode: 'buy', s })}><Icon name="plus" size={15} />شراء</button>
            <button class="btn quiet sm" on:click={() => openModal(SupplyForm, { kind: s.kind, mode: 'adjust', s })}>جرد</button>
            <button class="btn quiet sm" on:click={() => openModal(SupplyForm, { kind: s.kind, mode: 'alert', s })}>حدّ التنبيه</button>
          </div>
        {/if}
      </div>
    {/each}
  </div>
  {#if !compact && moves.length}
    <div class="card table-wrap" style="margin-top:12px">
      <div class="section-title">حركات الحبر والبودرة</div>
      <table>
        <tr><th>التاريخ</th><th>المادة</th><th>النوع</th><th>الكمية</th>{#if mgr}<th>السعر</th>{/if}<th>بواسطة</th><th>ملاحظة</th></tr>
        {#each moves.slice(0, 80) as x (x.id)}
          <tr><td class="muted small">{dt(x.created_at)}</td><td>{L[x.kind][0]}</td><td>{MV[x.move]}</td>
            <td class:green={+x.qty > 0}><b class="num">{(+x.qty > 0 ? '+' : '') + (+x.qty / 1000).toFixed(3)}</b> {L[x.kind][1]}</td>
            {#if mgr}<td>{x.total_price != null ? da(x.total_price) : ''}</td>{/if}<td>{staffName(x.actor_id)}</td><td class="muted small">{x.supplier || x.note || ''}</td></tr>
        {/each}
      </table>
    </div>
  {/if}
{/if}
<style>
  .sup { display: flex; flex-direction: column; gap: 8px; }
  .sup.low { border-color: #F8717166; }
  .ic { width: 30px; height: 30px; border-radius: 9px; display: grid; place-items: center; background: var(--accent-soft); color: var(--accent2); }
  .big { font-size: 26px; font-weight: 700; }
</style>
