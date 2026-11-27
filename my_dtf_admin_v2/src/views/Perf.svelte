<script>
  import { rpc, errMsg } from '../lib/sb.js';
  import { ROLE, m, num, dur, pct, ymd } from '../lib/fmt.js';
  let range = '7', rows = null, err = '';
  async function load() {
    rows = null; err = '';
    try {
      const to = new Date(), from = new Date(Date.now() - (+range - 1) * 864e5);
      const r = await rpc('dtf_staff_stats', { p_from: ymd(from), p_to: ymd(to) });
      rows = score(r);
    } catch (e) { err = errMsg(e); rows = []; }
  }
  // Note /100 : qualité 40 · vitesse 30 (par rapport à la moyenne du même rôle) · volume 20 · discipline 10
  function score(r) {
    return r.map(x => {
      const peers = r.filter(p => p.role === x.role && p.orders_done > 0);
      const avgT = peers.length ? peers.reduce((a, p) => a + +p.avg_minutes, 0) / peers.length : 0;
      const maxN = Math.max(1, ...r.filter(p => p.role === x.role).map(p => p.orders_done));
      const quality = x.orders_done ? Math.max(0, 1 - (x.issues / x.orders_done) * 3) : (x.issues ? 0 : 1);
      const speed = x.orders_done && avgT > 0 ? Math.max(0, Math.min(1, (avgT / Math.max(+x.avg_minutes, 1)) * 0.7)) : 0.5;
      const volume = x.orders_done / maxN;
      const disc = x.days_worked ? Math.max(0, 1 - (x.late_days * 0.5 + x.forgot_out) / x.days_worked) : 0.5;
      return { ...x, quality, speed, volume, disc, score: Math.round(quality * 40 + speed * 30 + volume * 20 + disc * 10) };
    }).sort((a, b) => b.score - a.score);
  }
  $: range, load();
  $: working = (rows || []).filter(x => x.orders_done > 0);
  $: fastest = working.filter(x => x.role !== 'manager').sort((a, b) => a.avg_minutes - b.avg_minutes)[0];
  $: precise = working.filter(x => x.issues === 0).sort((a, b) => b.orders_done - a.orders_done)[0];
  $: watch = (rows || []).filter(x => x.active && x.days_worked > 0 && (x.score < 50 || x.issues >= 3 || x.forgot_out >= 2));
  const parts = [['quality', 'الدقّة'], ['speed', 'السرعة'], ['volume', 'حجم العمل'], ['disc', 'الانضباط']];
</script>

<div class="row wrap" style="margin-bottom:14px">
  <div class="seg">{#each [['1', 'اليوم'], ['7', '7 أيام'], ['30', '30 يوماً'], ['90', '3 أشهر']] as [v, l]}<button class:on={range === v} on:click={() => (range = v)}>{l}</button>{/each}</div>
  <span class="faint small">النقطة من 100: الدقّة 40 · السرعة 30 · حجم العمل 20 · الانضباط 10</span>
</div>
{#if err}<div class="notice bad">{err}</div>{/if}
{#if !rows}<div class="spinner"></div>{:else}
  <div class="grid g3">
    <div class="card accent"><div class="muted small">الأسرع</div><h2>{fastest?.full_name || '—'}</h2><div class="faint small">{fastest ? `${ROLE[fastest.role]} · ${dur(fastest.avg_minutes)} للملف` : 'لا توجد بيانات كافية بعد'}</div></div>
    <div class="card accent"><div class="muted small">الأدق</div><h2>{precise?.full_name || '—'}</h2><div class="faint small">{precise ? `${precise.orders_done} ملف بدون أي مشكل` : 'لا توجد بيانات كافية بعد'}</div></div>
    <div class="card" style={watch.length ? 'border-color:var(--red)' : ''}><div class="muted small">يحتاج متابعة</div><h2 class:red={watch.length}>{watch.length ? watch.map(w => w.full_name).join('، ') : 'لا أحد'}</h2><div class="faint small">{watch.length ? 'نقطة منخفضة أو أخطاء متكرّرة أو نسيان تسجيل الخروج' : 'الفريق في مستوى جيد'}</div></div>
  </div>
  <div class="grid g3" style="margin-top:12px">
    {#each rows as x, i (x.user_id)}
      <div class="card" class:accent={i === 0 && x.orders_done > 0}>
        <div class="row"><div class="rank">{i + 1}</div><div class="grow"><h3>{x.full_name}</h3><div class="faint tiny">{ROLE[x.role]}{x.active ? '' : ' · موقوف'}</div></div><div class="score">{num(x.score)}</div></div>
        {#each parts as [k, l]}
          <div class="row between tiny" style="margin-top:8px"><span class="muted">{l}</span><span>{pct(x[k] * 100)}</span></div>
          <div class="bar"><i style="width:{x[k] * 100}%"></i></div>
        {/each}
        <div class="grid g2 tiny stats">
          <span>الملفات: {num(x.orders_done)}</span><span>الأمتار: {m(x.meters, 1)}</span>
          <span>المعدّل: {x.orders_done ? dur(x.avg_minutes) : '—'}</span><span class:red={x.issues}>المشاكل: {num(x.issues)}</span>
          <span>أيام العمل: {num(x.days_worked)}</span><span class:red={x.late_days || x.forgot_out}>تأخير {num(x.late_days)} · نسيان {num(x.forgot_out)}</span>
        </div>
      </div>
    {:else}<div class="card empty">أضف أعضاء الفريق أولاً</div>{/each}
  </div>
{/if}
<style>
  .rank { width: 32px; height: 32px; border-radius: 50%; display: grid; place-items: center; background: var(--card2); color: var(--gold); font-weight: 700; }
  .score { font-size: 28px; font-weight: 700; color: var(--gold); }
  .stats { margin-top: 12px; gap: 6px; color: var(--muted); }
</style>
