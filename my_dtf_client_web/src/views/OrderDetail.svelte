<script>
  import { sb, q, rpc, errMsg } from '../lib/sb.js';
  import { orders, liveTick, toast } from '../lib/store.js';
  import { signedUrls } from '../lib/api.js';
  import { da, m, cm, size, num, dt, STATUS, MODE } from '../lib/fmt.js';
  import Chip from '../components/Chip.svelte';
  import Icon from '../components/Icon.svelte';
  export let param;
  let o = null, ev = [], imgs = [], urls = {}, err = '', rating = null, stars = 0, comment = '', busy = false, report = '', showReport = false;
  async function load() {
    try {
      o = await q(sb.from('dtf_orders').select('*').eq('id', param).maybeSingle()) || $orders.find(x => x.id === param);
      if (!o) { err = 'الطلبية غير موجودة'; return; }
      [ev, imgs, rating] = await Promise.all([
        q(sb.from('dtf_order_events').select('*').eq('order_id', param).order('created_at')),
        imgs.length ? imgs : q(sb.from('dtf_order_images').select('*').eq('order_id', param)),
        q(sb.from('dtf_ratings').select('*').eq('order_id', param).maybeSingle()).catch(() => null),
      ]);
      if (!Object.keys(urls).length) urls = await signedUrls(imgs.map(i => i.thumb_path || i.storage_path));
      if (rating && !stars) { stars = rating.stars; comment = rating.comment || ''; }
    } catch (e) { err = errMsg(e); }
  }
  $: param, $liveTick, load();
  async function rate() {
    busy = true;
    try { await rpc('dtf_rate_order', { p_order: o.id, p_stars: stars, p_comment: comment }); rating = { stars, comment }; toast('شكراً على تقييمك'); }
    catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
  async function sendReport() {
    busy = true;
    try { await rpc('dtf_report_issue', { p_order: o.id, p_description: report }); toast('وصل بلاغك إلى الورشة'); showReport = false; report = ''; }
    catch (e) { toast(errMsg(e), true); }
    busy = false;
  }
  const FLOW = ['new', 'in_design', 'ready_to_print', 'printing', 'printed', 'delivered'];
  const TXT = { new: 'استُلمت الطلبية', in_design: 'في التصميم', ready_to_print: 'تنتظر الطباعة', printing: 'تُطبع الآن', printed: 'انتهت الطباعة', delivered: 'سُلّمت' };
  $: reached = s => ev.some(e => e.to_status === s || (s === 'printed' && ['ready_pickup', 'shipped'].includes(e.to_status))) || (s === 'new');
</script>

{#if !o}{#if err}<div class="card empty">{err}</div>{:else}<div class="spinner"></div>{/if}
{:else}
  <div class="row between wrap" style="margin-bottom:12px"><h1>طلبية {num(o.code)}</h1><Chip status={o.status} /></div>
  <div class="grid two">
    <div class="col">
      <div class="card accent">
        <div class="muted small">المبلغ الإجمالي</div><div class="total">{da(+o.print_amount + +o.delivery_fee)}</div>
        <div class="kv"><span>{o.final_length_cm ? 'الأمتار النهائية' : 'الأمتار التقديرية'}</span><b>{m(o.billed_meters)}</b></div>
        <div class="kv"><span>الطباعة</span><b>{da(o.print_amount)}</b></div>
        <div class="kv"><span>التوصيل</span><b>{o.delivery_mode === 'pickup' ? 'مجاني' : +o.delivery_fee ? da(o.delivery_fee) : 'يُحدَّد لاحقاً'}</b></div>
        {#if +o.amount_paid}<div class="kv"><span>المدفوع</span><b class="green">{da(o.amount_paid)}</b></div>{/if}
        {#if o.status === 'rejected' && o.reject_reason}<div class="notice bad small" style="margin-top:8px">سبب الرفض: {o.reject_reason}</div>{/if}
      </div>
      {#if !['rejected', 'cancelled'].includes(o.status)}
        <div class="card"><div class="section-title">المتابعة</div>
          <div class="tl">{#each FLOW as s}{@const e = ev.find(x => x.to_status === s || (s === 'printed' && ['ready_pickup', 'shipped'].includes(x.to_status)))}
            <div class:on={reached(s)}><b>{s === 'printed' && o.status === 'ready_pickup' ? 'جاهزة للاستلام من الورشة' : s === 'printed' && ['shipped'].includes(o.status) ? 'عند شركة التوصيل' : TXT[s]}</b>{#if e}<span class="faint tiny"> {dt(e.created_at)}</span>{/if}</div>{/each}</div>
          {#if o.tracking_number}<div class="small" style="margin-top:8px">{o.carrier} · رقم التتبّع <b class="ltr">{o.tracking_number}</b></div>{/if}
        </div>
      {/if}
      {#if o.status === 'delivered'}
        <div class="card" class:accent={!rating}>
          <div class="section-title">{rating ? 'تقييمك' : 'كيف كانت طلبيتك؟'}</div>
          <div class="stars">{#each [1, 2, 3, 4, 5] as k}<button class:on={k <= stars} aria-label="{k}" on:click={() => { stars = k; rating = null; }}>★</button>{/each}</div>
          {#if !rating}<textarea rows="2" bind:value={comment} placeholder="ملاحظة (اختياري)" style="margin-top:8px"></textarea>
            <button class="btn block" style="margin-top:8px" disabled={!stars || busy} on:click={rate}>إرسال التقييم</button>
          {:else if comment}<p class="muted small">{comment}</p>{/if}
        </div>
      {/if}
    </div>
    <div class="col">
      <div class="card"><div class="section-title">الصور ({num(imgs.length)})</div>
        <div class="imgs">{#each imgs as im}<div class="im"><img class="thumb" src={urls[im.thumb_path || im.storage_path]} alt="" loading="lazy" /><div class="tiny">{size(im.width_cm, im.height_cm)}</div><div class="accent tiny num">× {im.quantity}</div></div>{/each}</div>
      </div>
      <div class="card"><div class="section-title">الاستلام</div><b>{MODE[o.delivery_mode]}</b>
        {#if o.delivery_mode !== 'pickup'}<div class="muted small">{o.ship_name} · <span class="ltr">{o.ship_phone}</span> · {o.ship_wilaya} / {o.ship_commune} {o.ship_address || ''}</div>{/if}
        {#if o.client_note}<div class="notice small" style="margin-top:8px">ملاحظتك: {o.client_note}</div>{/if}
      </div>
      <a class="btn lg block" href="#/new/{o.id}"><Icon name="orders" size={18} />أعِد نفس الطلبية</a>
      <a class="btn quiet block" href="#/chat" on:click={() => sessionStorage.setItem('chatOrder', o.id)}><Icon name="chat" size={18} />مراسلة الورشة عن هذه الطلبية</a>
      {#if ['printed', 'ready_pickup', 'shipped', 'delivered'].includes(o.status)}
        {#if showReport}<div class="card"><label for="rp">صف المشكل</label><textarea id="rp" rows="3" bind:value={report}></textarea>
          <div class="row" style="margin-top:8px"><button class="btn danger grow" disabled={busy || !report.trim()} on:click={sendReport}>إرسال البلاغ</button><button class="btn quiet" on:click={() => (showReport = false)}>إلغاء</button></div></div>
        {:else}<button class="btn quiet block" on:click={() => (showReport = true)}><Icon name="alert" size={18} />التبليغ عن مشكل في الطباعة</button>{/if}
      {/if}
    </div>
  </div>
{/if}
<style>
  .two { grid-template-columns: 1fr 1fr; } @media (max-width: 800px) { .two { grid-template-columns: 1fr; } }
  .total { font-size: 28px; font-weight: 700; color: var(--accent2); margin-bottom: 6px; }
  .kv { display: flex; justify-content: space-between; padding: 6px 0; font-size: 14px; } .kv span { color: var(--muted); }
  .tl { border-right: 2px solid var(--line2); padding-right: 16px; margin-right: 4px; }
  .tl > div { position: relative; padding: 6px 0; color: var(--faint); }
  .tl > div::before { content: ''; position: absolute; right: -23px; top: 12px; width: 12px; height: 12px; border-radius: 50%; background: var(--card3); border: 2px solid var(--bg); }
  .tl > div.on { color: var(--text); } .tl > div.on::before { background: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
  .stars button { font-size: 34px; color: var(--card3); padding: 0 2px; } .stars button.on { color: var(--amber); }
  .imgs { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
  .im { text-align: center; } .im img { width: 100%; height: 96px; }
</style>
