<script>
  import { sb, q, rpc, signedUrls, errMsg, invokeDhd } from '../lib/sb.js';
  import ShipForm from './ShipForm.svelte';
  import { me, staff, staffName, settings, liveTick, toast, closeSheet, openModal } from '../lib/store.js';
  import { da, m, cm, size, num, dt, MODE, STATUS } from '../lib/fmt.js';
  import Chip from '../components/Chip.svelte';
  import FilmCanvas from '../components/FilmCanvas.svelte';
  import Icon from '../components/Icon.svelte';
  import { nest } from '../lib/nest.js';
  import { board, loadBoard, myMachine } from '../lib/store.js';

  export let id;
  export let work = false; // vue designer/imprimeur : pas de prix
  let rating = null, spEdit = null;
  async function saveSpecial() {
    try { await rpc('dtf_set_client_price', { p_client: o.client_id, p_price: spEdit === '' ? null : +String(spEdit).replace(',', '.') }); toast(spEdit === '' ? 'أُلغي السعر الخاص' : 'حُفظ السعر الخاص لهذا الزبون'); }
    catch (e) { toast(errMsg(e), true); }
  }
  let o = null, imgs = [], thumbs = {}, full = {}, ev = [], issues = [], busy = false, err = '';
  let designerSel = '', finalLen = '', carrier = 'DHD', tracking = '', paid = '', reason = '', machineSel = '', load2 = {};
  const REJECT = ['الصور غير واضحة أو بدقّة ضعيفة', 'المقاسات غير مناسبة للطباعة', 'الصورة تحتاج خلفية شفافة', 'محتوى غير مسموح بطباعته'];

  $: role = $me?.role;
  $: mgr = role === 'admin' || role === 'manager';
  $: designers = $staff.filter(s => s.role === 'designer' && s.active);

  async function load() {
    try {
      if (mgr) {
        o = await q(sb.from('dtf_orders').select('*,client:dtf_profiles!dtf_orders_client_id_fkey(full_name,phone,special_price)').eq('id', id).maybeSingle());
        if (!o) { toast('هذه الطلبية لم تعد موجودة', true); closeSheet(); return; }
      } else {
        o = (await rpc('dtf_work_orders')).find(x => x.id === id) || null;
        if (!o) { err = 'لم تعد هذه الطلبية في قائمتك'; return; }
      }
      [imgs, ev] = await Promise.all([
        q(sb.from('dtf_order_images').select('*').eq('order_id', id)),
        q(sb.from('dtf_order_events').select('*').eq('order_id', id).order('created_at')),
      ]);
      if (mgr) {
        [issues, rating] = await Promise.all([
          q(sb.from('dtf_issues').select('*').eq('order_id', id).order('created_at')),
          q(sb.from('dtf_ratings').select('*').eq('order_id', id).maybeSingle()).catch(() => null),
        ]);
        if (spEdit === null) spEdit = o.client?.special_price != null ? String(+o.client.special_price) : '';
      }
      thumbs = await signedUrls(imgs.map(i => i.thumb_path || i.storage_path));
      full = await signedUrls(imgs.map(i => i.storage_path), true);
      if (!finalLen) finalLen = String(+(o.final_length_cm || o.estimated_length_cm));
      if (mgr && o.status === 'new') {
        const [busyD, att] = await Promise.all([
          q(sb.from('dtf_orders').select('designer_id').eq('status', 'in_design')),
          q(sb.from('dtf_attendance').select('user_id').is('clock_out', null)),
        ]);
        load2 = Object.fromEntries(designers.map(d => [d.id, { n: busyD.filter(x => x.designer_id === d.id).length, here: att.some(a => a.user_id === d.id) }]));
        const best = [...designers].sort((a, b) => (load2[b.id].here - load2[a.id].here) || (load2[a.id].n - load2[b.id].n))[0];
        if (!designerSel) designerSel = best?.id || '';
      }
      if (['ready_to_print', 'printing'].includes(o.status) && !$board) loadBoard();
      if (!designerSel) designerSel = o.designer_id || designers[0]?.id || '';
      if (!paid && o.print_amount != null) paid = String(+o.print_amount + +o.delivery_fee);
    } catch (e) { err = errMsg(e); }
  }
  $: id, $liveTick, load();

  $: machines = ($board || []).filter(x => x.active && !['down', 'maintenance'].includes(x.status));
  $: if (machines.length && !machines.find(x => x.id === machineSel)) machineSel = machines.find(x => x.id === $myMachine)?.id || machines[0].id;
  $: imgMeta = Object.fromEntries(imgs.map((im, k) => [im.id, { url: thumbs[im.thumb_path || im.storage_path], index: k }]));
  $: film = imgs.length && $settings ? nest(imgs, +$settings.film_width_cm || 58, +$settings.gap_cm || 0.3, $settings.allow_rotation !== false) : null;
  $: suggested = designers.length ? [...designers].sort((a, b) => ((load2[b.id]?.here || 0) - (load2[a.id]?.here || 0)) || ((load2[a.id]?.n || 0) - (load2[b.id]?.n || 0)))[0]?.id : null;
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
        await rpc('dtf_start_printing', { p_order: id, p_machine: machineSel || null }); toast('بدأت الطباعة وخُصم الفيلم من رولو الآلة'); loadBoard();
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
  let manualShip = false;
  const SHIP = { created: ['أُنشئ الطرد', 'blue'], pending: ['جاهز للإرسال', 'blue'], picked: ['استلمته DHD', 'indigo'], transit: ['في الطريق', 'violet'],
    hub: ['في المركز / المكتب', 'violet'], out: ['خرج للتوصيل', 'amber'], attempt: ['محاولة فاشلة', 'orange'], hold: ['معلّق', 'orange'],
    delivered: ['سُلّم', 'green'], returned: ['مرتجع', 'red'], cancelled: ['ملغى', 'gray'], unknown: ['—', 'gray'] };
  async function label() {
    busy = true;
    try {
      const r = await invokeDhd({ action: 'label', order_id: o.id });
      const bin = Uint8Array.from(atob(r.pdf), c => c.charCodeAt(0));
      const u = URL.createObjectURL(new Blob([bin], { type: 'application/pdf' }));
      const w = window.open(u, '_blank'); if (!w) { const a = document.createElement('a'); a.href = u; a.download = `DHD-${r.tracking}.pdf`; a.click(); }
      setTimeout(() => URL.revokeObjectURL(u), 60000);
    } catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
  async function trackNow() { busy = true; try { const r = await invokeDhd({ action: 'track' }); toast(`حُدّثت الحالة (${r.updated} تغيير)`); liveTick.update(n => n + 1); } catch (e) { toast(errMsg(e), true); } busy = false; }
  async function cancelShip() {
    if (!confirm('إلغاء الطرد عند DHD؟ تعود الطلبية إلى «مطبوعة» ويُحذف رقم التتبّع.')) return;
    busy = true; try { await invokeDhd({ action: 'cancel', order_id: o.id }); toast('أُلغي الطرد'); liveTick.update(n => n + 1); } catch (e) { toast(errMsg(e), true); } busy = false;
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
          <label>اختر المصمّم</label>
          <div class="dz">{#each designers as d}{@const l = load2[d.id] || {}}
            <button class="dsel" class:on={designerSel === d.id} on:click={() => (designerSel = d.id)}>
              <span class="dot {l.here ? 'run' : ''}"></span><b class="grow">{d.full_name}</b>
              <span class="faint tiny">{l.here ? 'حاضر' : 'غائب'} · {num(l.n || 0)} ملف</span>
              {#if d.id === suggested}<span class="chip c-violet">مقترح</span>{/if}
            </button>{/each}</div>
          <button class="btn lg block" style="margin-top:10px" disabled={busy || !designerSel} on:click={() => act('assign')}><Icon name="check" size={18} />قبول وتحويل إلى التصميم</button>
        {:else}<div class="notice small">لا يوجد أي مصمّم بعد. أضف مصمّماً من صفحة «الفريق» ثم عُد إلى هذه الطلبية.</div>{/if}
        <label for="rs">أو رفض الطلبية (السبب يظهر للزبون)</label>
        <div class="row wrap" style="margin-bottom:8px">{#each REJECT as r}<button class="btn quiet sm" on:click={() => (reason = r)}>{r}</button>{/each}</div>
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
        {#if machines.length > 1}<label for="msel">الآلة</label>
          <select id="msel" bind:value={machineSel}>{#each machines as x}<option value={x.id}>{x.name} — {x.roll_code ? `رولو ${x.roll_code}: ${(+x.roll_remaining).toFixed(1)} م` : 'بدون رولو'}</option>{/each}</select>{/if}
        <button class="btn lg block" style="margin-top:10px" disabled={busy} on:click={() => act('start')}><Icon name="play" size={18} />بدء الطباعة — يُخصم {m(o.billed_meters)}</button>
      {:else if canFinish}
        <button class="btn lg block" disabled={busy} on:click={() => act('finish')}>انتهت الطباعة</button>
      {/if}
      {#if mgr && o.status === 'printed' && o.delivery_mode !== 'pickup'}
        <button class="btn lg block" disabled={busy} on:click={() => openModal(ShipForm, { o })}><Icon name="truck" size={18} />إرسال إلى DHD</button>
        <button class="btn quiet sm" style="margin-top:8px" on:click={() => (manualShip = !manualShip)}>شركة أخرى / إدخال رقم التتبّع يدوياً</button>
        {#if manualShip}
          <div class="grid g2 stack"><div><label for="cr">شركة التوصيل</label><input id="cr" bind:value={carrier} /></div>
            <div><label for="tk">رقم التتبّع</label><input id="tk" dir="ltr" bind:value={tracking} /></div></div>
          <button class="btn quiet block" style="margin-top:10px" disabled={busy} on:click={() => act('ship')}>تسليم إلى شركة التوصيل</button>
        {/if}
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
    {#if mgr && o.tracking_number}
      <div class="dhd">
        <div class="row between"><span class="row"><Icon name="truck" size={18} /><b>{o.carrier}</b> · <b class="ltr">{o.tracking_number}</b></span>
          {#if o.ship_status}<span class="chip c-{SHIP[o.ship_status]?.[1] || 'gray'}">{SHIP[o.ship_status]?.[0] || o.ship_status}</span>{/if}</div>
        {#if o.ship_status_raw}<div class="faint tiny" style="margin-top:4px">{o.ship_status_raw}{#if o.ship_synced_at} · آخر تحديث {dt(o.ship_synced_at)}{/if}{#if o.ship_cod != null} · يُحصَّل {da(o.ship_cod)}{/if}</div>{/if}
        {#if o.carrier === 'DHD'}
          <div class="row wrap" style="margin-top:10px">
            <button class="btn ghost sm" disabled={busy} on:click={label}><Icon name="file" size={15} />طباعة الملصق</button>
            <button class="btn quiet sm" disabled={busy} on:click={trackNow}><Icon name="refresh" size={15} />تحديث الحالة</button>
            {#if !o.ship_status || o.ship_status === 'created'}<button class="btn danger sm" disabled={busy} on:click={cancelShip}>إلغاء الطرد</button>{/if}
          </div>
          {#if o.ship_events?.length}<div class="evs">{#each [...o.ship_events].reverse().slice(0, 8) as e}<div class="tiny"><span class="faint ltr">{e.d}</span> · {e.s}{e.w ? ' — ' + e.w : ''}</div>{/each}</div>{/if}
        {/if}
      </div>
    {/if}
    {#if mgr}
      <label for="spc">سعر خاص لهذا الزبون (دج للمتر) — فارغ = السعر العادي/الجملة</label>
      <div class="row"><input id="spc" dir="ltr" inputmode="decimal" placeholder="—" bind:value={spEdit} /><button class="btn quiet sm" on:click={saveSpecial}>حفظ</button></div>
      <p class="faint tiny" style="margin-top:4px">يُطبَّق على طلبياته القادمة وعند إدخال الطول الحقيقي.</p>
    {/if}
    {#if mgr}<a class="btn quiet sm" style="margin-top:10px" href="#chat" on:click={() => { sessionStorage.setItem('chatWith', o.client_id); closeSheet(); }}>مراسلة الزبون</a>{/if}
  </div>

  {#if film && !film.error && ['new', 'in_design', 'ready_to_print'].includes(o.status)}
    <div class="card" style="margin-top:12px">
      <div class="section-title">ترتيب مقترح على الفيلم<span class="end small muted">{cm(film.length)} · امتلاء <span class="num">{Math.round(film.fill * 100)}%</span></span></div>
      <FilmCanvas result={film} images={imgMeta} height={340} />
      <p class="faint tiny" style="margin-top:6px">عرض {cm(film.width)} · فراغ {cm(+$settings.gap_cm)} · الترتيب النهائي يُضبط في فوتوشوب ويُدخل الطول الحقيقي أعلاه.</p>
    </div>
  {/if}

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

  {#if rating}
    <div class="card" style="margin-top:12px;{rating.stars <= 2 ? 'border-color:var(--red)' : ''}">
      <div class="section-title">تقييم الزبون</div>
      <div class="stars">{#each [1, 2, 3, 4, 5] as k}<span class:on={k <= rating.stars}>★</span>{/each}</div>
      {#if rating.comment}<p class="small" style="margin-top:6px">{rating.comment}</p>{/if}
    </div>
  {/if}
  {#if issues.length}
    <div class="card" style="margin-top:12px;border-color:var(--red)">
      <div class="section-title">مشاكل أبلغ عنها الزبون</div>
      {#each issues as i}<div class="small" style="padding:4px 0">{i.description} <span class="faint">{dt(i.created_at)}</span></div>{/each}
    </div>
  {/if}
{/if}

<style>
  .dhd { margin-top: 10px; padding: 12px; border-radius: 12px; background: var(--card2); border: 1px solid var(--line2); }
  .evs { margin-top: 10px; display: flex; flex-direction: column; gap: 4px; border-top: 1px solid var(--line); padding-top: 8px; }
  .total { font-size: 22px; font-weight: 700; color: var(--gold); }
  .stars span { font-size: 24px; color: var(--card3); } .stars span.on { color: var(--amber); }
  .dz { display: flex; flex-direction: column; gap: 6px; }
  .dsel { display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 12px; background: var(--bg2); border: 1px solid var(--line); text-align: right; }
  .dsel.on { border-color: var(--accent); background: var(--accent-soft); }
  .imgs { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px; margin-top: 10px; }
  .im { background: var(--bg2); border: 1px solid var(--line); border-radius: 12px; padding: 6px; text-align: center; }
  .im img { width: 100%; height: 100px; object-fit: contain; border-radius: 8px; background: repeating-conic-gradient(var(--card2) 0 25%, var(--bg2) 0 50%) 50% / 14px 14px; }
  .tl { border-right: 2px solid var(--line2); padding-right: 14px; margin-right: 4px; }
  .tl > div { position: relative; padding: 5px 0; }
  .tl > div::before { content: ''; position: absolute; right: -20px; top: 12px; width: 10px; height: 10px; border-radius: 50%; background: var(--gold); }
</style>
