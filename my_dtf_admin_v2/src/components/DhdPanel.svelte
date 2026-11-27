<script>
  // Réglages DHD : état de la connexion, synchronisation des communes et tarifs, suivi.
  import { sb, q, invokeDhd, errMsg } from '../lib/sb.js';
  import { toast } from '../lib/store.js';
  import { da, dt, num } from '../lib/fmt.js';
  import Icon from './Icon.svelte';
  let st = null, rates = [], wil = {}, busy = '', open = false, err = '';
  async function load() {
    try {
      st = await invokeDhd({ action: 'status' });
      const [r, w] = await Promise.all([q(sb.from('dtf_ship_rates').select('*').order('wilaya_code')), q(sb.from('dtf_wilayas').select('code,ar'))]);
      rates = r; wil = Object.fromEntries(w.map(x => [x.code, x.ar]));
    } catch (e) { err = errMsg(e); }
  }
  load();
  async function run(action, msg) {
    busy = action; err = '';
    try { const r = await invokeDhd({ action }); toast(msg(r)); await load(); }
    catch (e) { err = errMsg(e); }
    busy = '';
  }
</script>

<div class="card" style="margin-top:12px">
  <div class="section-title"><div>التوصيل DHD<span class="sub">الإرسال من {st?.origin || 'عين الدفلى'} — تأخذ الطرود بنفسك إلى مكتب DHD</span></div>
    <span class="end">{#if st}<span class="chip {st.configured ? 'c-green' : 'c-red'}">{st.configured ? 'المفتاح مضاف' : 'المفتاح غير مضاف'}</span>{/if}</span></div>
  {#if st && !st.configured}
    <div class="notice warn small">أضف مفتاح DHD في Supabase: <b>Edge Functions ← Secrets ← Add new secret</b>، الاسم <b class="ltr">DHD_TOKEN</b> والقيمة مفتاحك من حساب DHD. لا ترسل المفتاح في الدردشة.</div>
  {/if}
  {#if st}
    <div class="grid g3" style="margin-top:12px">
      <div class="tint k-gold"><Icon name="coins" size={20} /><div><b class="v num">{num(st.rates)}</b><div class="l">ولاية لها سعر</div></div></div>
      <div class="tint k-blue"><Icon name="refresh" size={20} /><div><b class="v small">{st.last_sync ? dt(st.last_sync) : '—'}</b><div class="l">آخر مزامنة للأسعار</div></div></div>
      <div class="tint k-teal"><Icon name="truck" size={20} /><div><b class="v small">{st.last_track ? dt(st.last_track) : '—'}</b><div class="l">آخر تحديث للطرود (كل 30 د)</div></div></div>
    </div>
    {#if st.last_error}<div class="notice bad small" style="margin-top:10px">آخر خطأ: {st.last_error}</div>{/if}
  {/if}
  {#if err}<div class="notice bad small" style="margin-top:10px">{err}</div>{/if}
  <div class="row wrap" style="margin-top:12px">
    <button class="btn ghost sm" disabled={!!busy || !st?.configured} on:click={() => run('test', r => 'الاتصال بـ DHD يعمل (' + (r.host || '') + ')')}>{busy === 'test' ? '...' : 'اختبار الاتصال'}</button>
    <button class="btn sm" disabled={!!busy || !st?.configured} on:click={() => run('sync', r => `جُلبت أسعار ${r.rates} ولاية و${r.communes} بلدية`)}>{busy === 'sync' ? '...' : 'مزامنة البلديات والأسعار'}</button>
    <button class="btn quiet sm" disabled={!!busy || !st?.configured} on:click={() => run('track', r => `فُحص ${r.checked} طرد — ${r.updated} تغيير`)}>{busy === 'track' ? '...' : 'تحديث حالة الطرود الآن'}</button>
    {#if rates.length}<button class="btn quiet sm" on:click={() => (open = !open)}>{open ? 'إخفاء' : 'عرض'} الأسعار</button>{/if}
  </div>
  <p class="faint tiny" style="margin-top:8px">سعر التوصيل يُحسب تلقائياً عند الطلب من أسعار DHD (المنزل أو المكتب) ويدفعه الزبون. تُحدَّث الأسعار وحدها كل ليلة.</p>
  {#if open}
    <div class="table-wrap" style="margin-top:10px;max-height:340px;overflow-y:auto"><table>
      <tr><th>الولاية</th><th>المنزل</th><th>المكتب</th><th>الإرجاع</th></tr>
      {#each rates as r}<tr><td>{String(r.wilaya_code).padStart(2, '0')} {wil[r.wilaya_code] || r.name || ''}</td><td>{r.home != null ? da(r.home) : '—'}</td><td>{r.desk != null ? da(r.desk) : '—'}</td><td>{r.retour != null ? da(r.retour) : '—'}</td></tr>{/each}
    </table></div>
  {/if}
</div>
