<script>
  import { sb, q, rpc, signedUrls, errMsg } from '../lib/sb.js';
  import { me, staff, staffName, settings, liveTick, toast, closeSheet } from '../lib/store.js';
  import { da, m, cm, size, num, dt, MODE, STATUS } from '../lib/fmt.js';
  import Chip from '../components/Chip.svelte';

  export let id;
  export let work = false; // vue designer/imprimeur : pas de prix
  let o = null, imgs = [], thumbs = {}, full = {}, ev = [], issues = [], busy = false, err = '';
  let designerSel = '', finalLen = '', carrier = 'DHD', tracking = '', paid = '', reason = '';

  $: role = $me?.role;
  $: mgr = role === 'admin' || role === 'manager';
  $: designers = $staff.filter(s => s.role === 'designer' && s.active);

  async function load() {
    try {
      if (mgr) {
        o = await q(sb.from('dtf_orders').select('*,client:dtf_profiles!dtf_orders_client_id_fkey(full_name,phone)').eq('id', id).single());
      } else {
        o = (await rpc('dtf_work_orders')).find(x => x.id === id) || null;
        if (!o) { err = 'لم تعد هذه الطلبية في قائمتك'; return; }
      }
      [imgs, ev] = await Promise.all([
        q(sb.from('dtf_order_images').select('*').eq('order_id', id)),
        q(sb.from('dtf_order_events').select('*').eq('order_id', id).order('created_at')),
      ]);
      if (mgr) issues = await q(sb.from('dtf_issues').select('*').eq('order_id', id).order('created_at'));
      thumbs = await signedUrls(imgs.map(i => i.thumb_path || i.storage_path));
      full = await signedUrls(imgs.map(i => i.storage_path), true);
      if (!finalLen) finalLen = String(+(o.final_length_cm || o.estimated_length_cm));
      if (!designerSel) designerSel = o.designer_id || designers[0]?.id || '';
      if (!paid && o.print_amount != null) paid = String(+o.print_amount + +o.delivery_fee);
    } catch (e) { err = errMsg(e); }
  }
  $: id, $liveTick, load();

  $: preview = (() => {
    const s = $settings; const L = +String(finalLen).replace(',', '.');
    if (!s || !(L > 0)) return null;
    const step = +s.meter_rounding_step; const mm = L / 100;
    const billed = step > 0 ? Math.ceil(mm / step - 1e-9) * step : mm;
    return { billed, price: Math.max(billed * s.price_per_meter, s.min_order_amount) };
  })();

  async function act(kind) {
    busy = true; err = '';
    try {
      if (kind === 'assign') {
        if (!designerSel) throw new Error('لا يوجد مصمّم. أضف مصمّماً من صفحة الفريق أولاً.');
        await rpc('dtf_assign_designer', { p_order: id, p_designer: designerSel }); toast('حُوّلت الطلبية إلى المصمّم');
      } else if (kind === 'reject') {
        if (!reason.trim()) throw new Error('اكتب سبب الرفض ليراه الزبون');
        await rpc('dtf_reject_order', { p_order: id, p_reason: reason.trim() }); toast('رُفضت الطلبية');
      } else if (kind === 'design') {
        const L = +String(finalLen).replace(',', '.');
        if (!(L > 0)) throw new Error('أدخل الطول الحقيقي بالسنتيمتر');
        await rpc('dtf_design_done', { p_order: id, p_final_length_cm: L }); toast('التصميم جاهز، أُرسل إلى طابور الطباعة');
        if (!mgr) { closeSheet(); liveTick.update(n => n + 1); return; }
      } else if (kind === 'start') {
        await rpc('dtf_start_printing', { p_order: id }); toast('بدأت الطباعة وخُصم الفيلم من الرولو');
      } else if (kind === 'finish') {
        await rpc('dtf_finish_printing', { p_order: id }); toast('انتهت الطباعة');
      } else if (kind === 'ship') {
        if (!tracking.trim()) throw new Error('أدخل رقم التتبّع');
        await rpc('dtf_mark_shipped', { p_order: id, p_carrier: carrier.trim() || 'DHD', p_tracking: tracking.trim() }); toast('سُلّمت إلى شركة التوصيل');
      } else if (kind === 'deliver') {
        await rpc('dtf_mark_delivered', { p_order: id, p_amount_paid: +paid || 0 }); toast('تم التسليم');
      }
      liveTick.update(n => n + 1);
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
  function downloadAll() {
    imgs.forEach((im, k) => setTimeout(() => { const a = document.createElement('a'); a.href = full[im.storage_path]; a.download = ''; document.body.appendChild(a); a.click(); a.remove(); }, k * 400));
  }
  $: canDesign = o?.status === 'in_design' && (mgr || (role === 'designer' && o.designer_id === $me.id));
  $: canStart = o?.status === 'ready_to_print' && (mgr || role === 'printer');
  $: canFinish = o?.status === 'printing' && (mgr || (role === 'printer' && o.printer_id === $me.id));
  $: actorName = e => e.actor_id && e.actor_id === o?.client_id ? 'الزبون' : staffName(e.actor_id);
</script>

{#if !o}
  {#if err}<p class="red">{err}</p>{:else}<div class="spinner"></div>{/if}
{:else}
  <div class="row between"><h2>طلبية {num(o.code)}</h2><button class="btn quiet sm" on:click={closeSheet} aria-label="إغلاق">إغلاق</button></div>
  <div class="row" style="margin:6px 0 14px"><Chip status={o.status} /><span class="faint small">{dt(o.created_at)}</span></div>

  {#if mgr}
    <div class="card accent">
      <div class="row between"><span class="muted">المجموع</span><span class="total">{da(+o.print_amount + +o.delivery_fee)}</span></div>
      <div class="row between small"><span class="muted">{o.final_length_cm ? 'الأمتار النهائية' : 'الأمتار التقديرية'}</span><b>{m(o.billed_meters)}</b></div>
      <div class="row between small"><span class="muted">الطباعة / التوصيل</span><span>{da(o.print_amount)} / {da(o.delivery_fee)}</span></div>
    </div>
  {:else}
    <div class="card accent"><div class="row between"><span class="muted">الأمتار</span><span class="total">{m(o.billed_meters)}</span></div>
      <div class="faint small">الطول التقديري {cm(o.estimated_length_cm)}</div></div>
  {/if}

  {#if err}<div class="notice bad small" style="margin-top:12px">{err}</div>{/if}

  {#if (o.status === 'new' && mgr) || canDesign || canStart || canFinish || (mgr && ['printed', 'shipped', 'ready_pickup'].includes(o.status))}
    <div class="card" style="margin-top:12px">
      <div class="section-title">الخطوة التالية</div>
      {#if o.status === 'new' && mgr}
        {#if designers.length}
          <label for="ds">اختر المصمّم</label>
          <div class="row"><select id="ds" bind:value={designerSel}>{#each designers as d}<option value={d.id}>{d.full_name}</option>{/each}</select>
            <button class="btn" disabled={busy} on:click={() => act('assign')}>قبول وتحويل</button></div>
        {:else}<div class="notice small">لا يوجد أي مصمّم بعد. أضف مصمّماً من صفحة «الفريق» ثم عُد إلى هذه الطلبية.</div>{/if}
        <label for="rs">أو رفض الطلبية (السبب يظهر للزبون)</label>
        <div class="row"><input id="rs" bind:value={reason} placeholder="مثال: الصور غير واضحة" /><button class="btn danger" disabled={busy} on:click={() => act('reject')}>رفض</button></div>
      {:else if canDesign}
        {#if mgr && designers.length > 1}
          <label for="ds2">المصمّم المكلّف</label>
          <div class="row"><select id="ds2" bind:value={designerSel}>{#each designers as d}<option value={d.id}>{d.full_name}</option>{/each}</select>
            <button class="btn quiet sm" disabled={busy} on:click={() => act('assign')}>تغيير</button></div>
        {/if}
        <label for="fl">الطول الحقيقي بعد التصميم (بالسنتيمتر)</label>
        <input id="fl" inputmode="decimal" dir="ltr" bind:value={finalLen} />
        {#if preview}<p class="faint small" style="margin-top:6px">= {m(preview.billed)}{#if mgr} · {da(preview.price)} (يصل للزبون إشعار إن تغيّر السعر){/if}</p>{/if}
        <button class="btn lg block" style="margin-top:12px" disabled={busy} on:click={() => act('design')}>التصميم جاهز — إرسال إلى الطباعة</button>
        <p class="faint tiny" style="margin-top:6px">يدخل الملف طابور الطباعة، ويأخذه أي طابع حاضر.</p>
      {:else if canStart}
        <button class="btn lg block" disabled={busy} on:click={() => act('start')}>بدء الطباعة — يُخصم {m(o.billed_meters)} من الرولو</button>
      {:else if canFinish}
        <button class="btn lg block" disabled={busy} on:click={() => act('finish')}>انتهت الطباعة</button>
      {/if}
      {#if mgr && o.status === 'printed' && o.delivery_mode !== 'pickup'}
        <div class="grid g2 stack"><div><label for="cr">شركة التوصيل</label><input id="cr" bind:value={carrier} /></div>
          <div><label for="tk">رقم التتبّع</label><input id="tk" dir="ltr" bind:value={tracking} /></div></div>
        <button class="btn block" style="margin-top:10px" disabled={busy} on:click={() => act('ship')}>تسليم إلى شركة التوصيل</button>
      {/if}
      {#if mgr && ['printed', 'shipped', 'ready_pickup'].includes(o.status)}
        <label for="pd">المبلغ المدفوع</label>
        <div class="row"><input id="pd" inputmode="numeric" dir="ltr" bind:value={paid} /><button class="btn quiet" disabled={busy} on:click={() => act('deliver')}>تم التسليم والدفع</button></div>
      {/if}
    </div>
  {/if}

  <div class="card" style="margin-top:12px">
    <div class="section-title">{mgr ? 'الزبون والاستلام' : 'الاستلام'}</div>
    {#if mgr}<div class="row between"><b>{o.client?.full_name}</b><a class="ltr" href="tel:{o.client?.phone}">{o.client?.phone}</a></div>
    {:else}<div><b>{o.client_name}</b></div>{/if}
    <div class="muted small" style="margin-top:4px">{MODE[o.delivery_mode]}{#if mgr && o.delivery_mode !== 'pickup'} — {o.ship_name} · <span class="ltr">{o.ship_phone}</span> · {o.ship_wilaya} / {o.ship_commune} {o.ship_address || ''}{/if}</div>
    {#if o.client_note}<div class="notice small" style="margin-top:10px">ملاحظة الزبون: {o.client_note}</div>{/if}
    {#if mgr && o.tracking_number}<div class="small" style="margin-top:6px">{o.carrier} · <b class="ltr">{o.tracking_number}</b></div>{/if}
    {#if mgr}<a class="btn quiet sm" style="margin-top:10px" href="#chat" on:click={() => { sessionStorage.setItem('chatWith', o.client_id); closeSheet(); }}>مراسلة الزبون</a>{/if}
  </div>

  <div class="card" style="margin-top:12px">
    <div class="row between"><div class="section-title" style="margin:0">الصور ({num(imgs.length)})</div>{#if imgs.length}<button class="btn ghost sm" on:click={downloadAll}>تنزيل الكل</button>{/if}</div>
    <div class="imgs">
      {#each imgs as im}
        <div class="im">
          <a href={full[im.storage_path]} target="_blank" rel="noopener"><img src={thumbs[im.thumb_path || im.storage_path]} alt="" loading="lazy" decoding="async" /></a>
          <div class="small">{size(im.width_cm, im.height_cm)}</div>
          <div class="gold small">{num('× ' + im.quantity)}</div>
          <a class="tiny" href={full[im.storage_path]}>تنزيل الأصل</a>
        </div>
      {/each}
    </div>
  </div>

  <div class="card" style="margin-top:12px">
    <div class="section-title">السجلّ</div>
    <div class="tl">{#each ev as e}<div><b>{STATUS[e.to_status]?.[0] || e.to_status}</b> <span class="faint small">{dt(e.created_at)} · {actorName(e)}</span></div>{/each}</div>
    {#if mgr}<div class="faint small" style="margin-top:8px">المصمّم: {staffName(o.designer_id)} · الطابع: {staffName(o.printer_id)}</div>{/if}
  </div>

  {#if issues.length}
    <div class="card" style="margin-top:12px;border-color:var(--red)">
      <div class="section-title">مشاكل أبلغ عنها الزبون</div>
      {#each issues as i}<div class="small" style="padding:4px 0">{i.description} <span class="faint">{dt(i.created_at)}</span></div>{/each}
    </div>
  {/if}
{/if}

<style>
  .total { font-size: 22px; font-weight: 700; color: var(--gold); }
  .imgs { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-top: 10px; }
  .im { background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 6px; text-align: center; }
  .im img { width: 100%; height: 100px; object-fit: contain; border-radius: 8px; background: repeating-conic-gradient(var(--card2) 0 25%, var(--bg2) 0 50%) 50% / 14px 14px; }
  .tl { border-right: 2px solid var(--line2); padding-right: 14px; margin-right: 4px; }
  .tl > div { position: relative; padding: 5px 0; }
  .tl > div::before { content: ''; position: absolute; right: -20px; top: 12px; width: 10px; height: 10px; border-radius: 50%; background: var(--gold); }
</style>
