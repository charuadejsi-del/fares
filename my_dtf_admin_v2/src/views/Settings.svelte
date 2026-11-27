<script>
  import { sb, q, errMsg } from '../lib/sb.js';
  import { settings, toast } from '../lib/store.js';
  import { m, da } from '../lib/fmt.js';
  let s = { ...$settings }, busy = false;
  $: example = (() => { const st = +s.meter_rounding_step; const mm = 1.512; const b = st > 0 ? Math.ceil(mm / st - 1e-9) * st : mm; return { b, p: Math.max(b * +s.price_per_meter, +s.min_order_amount) }; })();
  async function save() {
    busy = true;
    try {
      const row = await q(sb.from('dtf_settings').update({
        price_per_meter: +s.price_per_meter, min_order_amount: +s.min_order_amount, meter_rounding_step: +s.meter_rounding_step,
        film_width_cm: +s.film_width_cm, gap_cm: +s.gap_cm, roll_alert_m: +s.roll_alert_m, allow_rotation: !!s.allow_rotation,
        workshop_name: s.workshop_name, workshop_phone: s.workshop_phone || null, workshop_address: s.workshop_address || null,
        work_end_time: s.work_end_time || '18:00', updated_at: new Date().toISOString(),
      }).eq('id', 1).select().single());
      settings.set(row); s = { ...row }; toast('حُفظت الإعدادات');
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
