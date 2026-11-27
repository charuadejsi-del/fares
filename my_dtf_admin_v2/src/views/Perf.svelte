<script>
  import { rpc, sb, q, errMsg } from '../lib/sb.js';
  import { staffName } from '../lib/store.js';
  import { dt } from '../lib/fmt.js';
  let ratings = [];
  q(sb.from('dtf_ratings').select('*,ord:dtf_orders(code,designer_id,printer_id),cl:dtf_profiles(full_name)').order('created_at', { ascending: false }).limit(30)).then(r => (ratings = r)).catch(() => {});
  $: avgStars = ratings.length ? ratings.reduce((a, r) => a + r.stars, 0) / ratings.length : null;
  import { ROLE, m, num, dur, pct, ymd } from '../lib/fmt.js';
  let range = '7', rows = null, err = '';
  async function load() {
    rows = null; err = '';
    try {
      const to = new Date(), from = new Date(Date.now() - (+range - 1) * 864e5);
      const [r, rt] = await Promise.all([rpc('dtf_staff_stats', { p_from: ymd(from), p_to: ymd(to) }), rpc('dtf_staff_ratings', { p_from: ymd(from), p_to: ymd(to) }).catch(() => [])]);
      rows = score(r.map(x => { const k = rt.find(y => y.user_id === x.user_id); return { ...x, stars: k ? +k.avg_stars : null, nstars: k ? k.n : 0 }; }));
    } catch (e) { err = errMsg(e); rows = []; }
  }
  // Note /100 : qualité 40 · vitesse 30 (par rapport à la moyenne du même rôle) · volume 20 · discipline 10
  function score(r) {
    return r.map(x => {
      const peers = r.filter(p => p.role === x.role && p.orders_done > 0);
      const avgT = peers.length ? peers.reduce((a, p) => a + +p.avg_minutes, 0) / peers.length : 0;
      const maxN = Math.max(1, ...r.filter(p => p.role === x.role).map(p => p.orders_done));
      const q0 = x.orders_done ? Math.max(0, 1 - (x.issues / x.orders_done) * 3) : (x.issues ? 0 : 1);
      const quality = x.stars != null ? q0 * 0.5 + ((x.stars - 1) / 4) * 0.5 : q0;
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
  import Icon from '../components/Icon.svelte';
  const COLORS = ['#34D399', '#E6B325', '#7C6CF0', '#2DD4BF', '#5B9DF9', '#F05A5A', '#FB923C', '#A99BFF'];
  $: totM = (rows || []).reduce((a, x) => a + (+x.meters || 0), 0);
  $: share = (rows || []).map((x, i) => ({ ...x, c: COLORS[i % COLORS.length], p: totM ? (+x.meters || 0) / totM : 0 })).filter(x => x.p > 0);
  $: cone = (() => { let acc = 0; return share.map(x => { const a = acc; acc += x.p * 100; return `${x.c} ${a}% ${acc}%`; }).join(', '); })();
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
  <div class="grid duo" style="margin-top:12px">
    <div class="card">
      <div class="section-title"><div>ترتيب العمال<span class="sub">حسب النقطة من 100</span></div></div>
      {#each rows as x, i (x.user_id)}
        <div class="rk">
          <div class="row"><span class="av" style="--c:{COLORS[i % COLORS.length]}">{(x.full_name || '?')[0]}</span>
            <div class="grow"><div class="row between"><b>{x.full_name}{#if i === 0 && x.orders_done > 0} <span class="cup"><Icon name="trophy" size={16} /></span>{/if}</b><b class="num gold">{num(x.score)} نقطة</b></div>
              <div class="bar" style="margin:6px 0 4px"><i style="width:{x.score}%;background:{COLORS[i % COLORS.length]}"></i></div>
              <div class="faint tiny">{ROLE[x.role]} · {num(x.orders_done)} ملف · {m(x.meters, 1)}</div></div></div>
        </div>
      {:else}<div class="empty">أضف أعضاء الفريق أولاً</div>{/each}
    </div>
    <div class="card">
      <div class="section-title"><div>التوزيع<span class="sub">نصيب كل عامل من الأمتار</span></div></div>
      {#if totM > 0}
        <div class="dn">
          <div class="donut" style="background:conic-gradient({cone})"><div class="hole"><b class="num">{m(totM, 1)}</b><span class="faint tiny">المجموع</span></div></div>
          <div class="col lg">{#each share as x}<div class="row small"><span class="sw" style="background:{x.c}"></span><span class="grow">{x.full_name}</span><b class="num">{pct(x.p * 100)}</b></div>{/each}</div>
        </div>
      {:else}<div class="empty">لا توجد أمتار في هذه الفترة</div>{/if}
    </div>
  </div>
  <div class="section-title" style="margin-top:20px">التفاصيل</div>
  <div class="grid g3">
    {#each rows as x, i (x.user_id)}
      <div class="card" class:accent={i === 0 && x.orders_done > 0}>
        <div class="row"><div class="rank">{i + 1}</div><div class="grow"><h3>{x.full_name}</h3><div class="faint tiny">{ROLE[x.role]}{x.active ? '' : ' · موقوف'}</div></div><div class="score">{num(x.score)}</div></div>
        {#each parts as [k, l]}
          <div class="row between tiny" style="margin-top:8px"><span class="muted">{l}</span><span>{pct(x[k] * 100)}</span></div>
          <div class="bar"><i style="width:{x[k] * 100}%"></i></div>
        {/each}
        <div class="grid g2 tiny stats">
          <span>الملفات: {num(x.orders_done)}</span><span>الأمتار: {m(x.meters, 1)}</span>
          <span>المعدّل: {x.orders_done ? dur(x.avg_minutes) : '—'}</span><span class:red={x.issues}>المشاكل: {num(x.issues)}</span>{#if x.stars != null}<span class:red={x.stars < 3}>التقييم: <b class="num">{x.stars.toFixed(1)}★</b> ({num(x.nstars)})</span>{/if}
          <span>أيام العمل: {num(x.days_worked)}</span><span class:red={x.late_days || x.forgot_out}>تأخير {num(x.late_days)} · نسيان {num(x.forgot_out)}</span>
        </div>
      </div>
    {:else}<div class="card empty">أضف أعضاء الفريق أولاً</div>{/each}
  </div>
  <div class="card" style="margin-top:12px">
    <div class="section-title">آخر تقييمات الزبائن{#if avgStars != null}<span class="end"><b class="num">{avgStars.toFixed(1)}★</b> <span class="faint small">من {num(ratings.length)}</span></span>{/if}</div>
    {#if ratings.length}<div class="list">{#each ratings as r}
      <div class="item row"><span class="st" class:red={r.stars <= 2}><b class="num">{r.stars}★</b></span>
        <div class="grow small"><b>طلبية {num(r.ord?.code)}</b> · {r.cl?.full_name || ''}{#if r.comment}<div class="muted">{r.comment}</div>{/if}
          <div class="faint tiny">المصمّم {staffName(r.ord?.designer_id)} · الطابع {staffName(r.ord?.printer_id)}</div></div>
        <span class="faint tiny">{dt(r.created_at)}</span></div>{/each}</div>
    {:else}<div class="empty">لا توجد تقييمات بعد — تظهر بعد تسليم الطلبيات</div>{/if}
  </div>
{/if}
<style>
  .duo { grid-template-columns: 1.3fr 1fr; } @media (max-width: 1100px) { .duo { grid-template-columns: 1fr; } }
  .rk + .rk { margin-top: 14px; }
  .av { width: 38px; height: 38px; border-radius: 12px; display: grid; place-items: center; font-weight: 700; color: #0B0D12; background: var(--c); flex-shrink: 0; }
  .cup { color: var(--accent2); vertical-align: -2px; }
  .dn { display: flex; align-items: center; gap: 24px; flex-wrap: wrap; justify-content: center; padding: 6px 0; }
  .donut { width: 190px; height: 190px; border-radius: 50%; display: grid; place-items: center; animation: rise .6s var(--spring); }
  .hole { width: 128px; height: 128px; border-radius: 50%; background: var(--card); display: flex; flex-direction: column; align-items: center; justify-content: center; }
  .hole b { font-size: 19px; }
  .lg { min-width: 160px; gap: 8px; } .sw { width: 10px; height: 10px; border-radius: 50%; }
  .st { min-width: 44px; color: var(--amber); }
  .rank { width: 32px; height: 32px; border-radius: 50%; display: grid; place-items: center; background: var(--card2); color: var(--gold); font-weight: 700; }
  .score { font-size: 28px; font-weight: 700; color: var(--gold); }
  .stats { margin-top: 12px; gap: 6px; color: var(--muted); }
</style>
