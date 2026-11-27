<script>
  import { sb, q, errMsg } from '../lib/sb.js';
  import { settings, toast } from '../lib/store.js';
  import { m, da } from '../lib/fmt.js';
  import DhdPanel from '../components/DhdPanel.svelte';
  let s = { ...$settings, price_tiers: JSON.parse(JSON.stringify($settings?.price_tiers || [])) }, busy = false;
  $: example = (() => { const st = +s.meter_rounding_step; const mm = 1.512; const b = st > 0 ? Math.ceil(mm / st - 1e-9) * st : mm; return { b, p: Math.max(b * +s.price_per_meter, +s.min_order_amount) }; })();
  async function save() {
    busy = true;
    try {
      await q(sb.from('dtf_settings').update({
        price_per_meter: +s.price_per_meter, min_order_amount: +s.min_order_amount, meter_rounding_step: +s.meter_rounding_step,
        film_width_cm: +s.film_width_cm, gap_cm: +s.gap_cm, roll_alert_m: +s.roll_alert_m, allow_rotation: !!s.allow_rotation,
        workshop_name: s.workshop_name, workshop_phone: s.workshop_phone || null, workshop_address: s.workshop_address || null,
        work_end_time: s.work_end_time || '18:00',
        price_tiers: s.price_tiers.filter(t => +t.min_m > 0 && +t.price > 0).map(t => ({ min_m: +t.min_m, price: +t.price })).sort((a, b) => a.min_m - b.min_m),
        updated_at: new Date().toISOString(),
      }).eq('id', 1));
      const fresh = await q(sb.from('dtf_settings').select('*').eq('id', 1).maybeSingle());
      if (!fresh) throw new Error('تعذّر قراءة الإعدادات بعد الحفظ');
      const row = fresh; settings.set(row); s = { ...row, price_tiers: JSON.parse(JSON.stringify(row.price_tiers || [])) }; toast('حُفظت الإعدادات');
    } catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
</script>
<div class="grid g2 stack">
  <div class="card accent">
    <div class="section-title">الأسعار</div>
    <div class="grid g2">
      <div><label for="a">سعر المتر (دج)</label><input id="a" inputmode="decimal" dir="ltr" bind:value={s.price_per_meter} /></div>
      <div><label for="b">الحد الأدنى للطلبية (دج)</label><input id="b" inputmode="decimal" dir="ltr" bind:value={s.min_order_amount} /></div>
      <div><label for="c">تدوير الأمتار (متر)</label><input id="c" inputmode="decimal" dir="ltr" bind:value={s.meter_rounding_step} /></div>
    </div>
    <div class="notice small" style="margin-top:12px">مثال: ملف طوله 151.2 سم يُحسب {m(example.b)} = {da(example.p)}</div>
    <div class="section-title" style="margin-top:18px">أسعار الجملة (حسب الكمية)</div>
    {#each s.price_tiers as t, i}
      <div class="row" style="margin-bottom:8px"><span class="small muted">من</span><input style="width:90px" dir="ltr" inputmode="decimal" bind:value={t.min_m} /><span class="small muted">م فأكثر</span>
        <input style="width:110px" dir="ltr" inputmode="decimal" bind:value={t.price} /><span class="small muted">دج للمتر</span>
        <button class="btn quiet sm" on:click={() => { s.price_tiers.splice(i, 1); s = s; }}>حذف</button></div>
    {/each}
    <button class="btn ghost sm" on:click={() => { s.price_tiers = [...s.price_tiers, { min_m: '', price: '' }]; }}>+ درجة</button>
    <p class="faint tiny" style="margin-top:8px">تُطبَّق تلقائياً حسب أمتار الطلبية. السعر الخاص لزبون معيّن (من صفحة الطلبية) يتقدّم على الدرجات.</p>
  </div>
  <div class="card">
    <div class="section-title">الآلة والفيلم</div>
    <div class="grid g2">
      <div><label for="d">العرض المفيد (سم)</label><input id="d" inputmode="decimal" dir="ltr" bind:value={s.film_width_cm} /></div>
      <div><label for="e">المسافة بين الصور (سم)</label><input id="e" inputmode="decimal" dir="ltr" bind:value={s.gap_cm} /></div>
      <div><label for="f">تنبيه انتهاء الرولو (متر)</label><input id="f" inputmode="decimal" dir="ltr" bind:value={s.roll_alert_m} /></div>
      <div><label for="g">تدوير الصور</label><select id="g" bind:value={s.allow_rotation}><option value={true}>مسموح</option><option value={false}>غير مسموح</option></select></div>
    </div>
  </div>
  <div class="card">
    <div class="section-title">الورشة</div>
    <label for="h">الاسم</label><input id="h" bind:value={s.workshop_name} />
    <label for="i">الهاتف</label><input id="i" dir="ltr" bind:value={s.workshop_phone} />
    <label for="j">العنوان</label><input id="j" bind:value={s.workshop_address} />
  </div>
  <div class="card">
    <div class="section-title">الحضور</div>
    <label for="k">ساعة نهاية العمل</label><input id="k" type="time" dir="ltr" bind:value={s.work_end_time} />
    <p class="faint small" style="margin-top:8px">يظهر للموظف تذكير بتسجيل الخروج قبل هذه الساعة بربع ساعة. من ينسى يُغلق يومه تلقائياً على 23:59 ويصلك تنبيه.</p>
  </div>
</div>
<button class="btn lg" style="margin-top:14px;min-width:220px" disabled={busy} on:click={save}>حفظ الإعدادات</button>
<DhdPanel />
