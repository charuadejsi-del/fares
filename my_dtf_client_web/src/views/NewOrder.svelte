<script>
  import { countUp, confetti } from '../lib/motion.js';
  // Nouvelle commande en 4 étapes : images → film → livraison → confirmation.
  import { onMount } from 'svelte';
  import { sb, q, errMsg, BUCKET } from '../lib/sb.js';
  import { me, settings, toast } from '../lib/store.js';
  import { createOrder, loadAll } from '../lib/api.js';
  import { nest } from '../lib/nest.js';
  import { quote } from '../lib/pricing.js';
  import { loadShip, findPlace } from '../lib/ship.js';
  import { da, m, cm, num, MODE } from '../lib/fmt.js';
  import FilmCanvas from '../components/FilmCanvas.svelte';
  import Picker from '../components/Picker.svelte';
  import ShopStatus from '../components/ShopStatus.svelte';
  import Icon from '../components/Icon.svelte';
  export let param = '';

  let sent = false;
  let step = 0, images = [], seq = 0, dz = null, sending = false, progress = '', err = '';
  let mode = 'pickup', name = '', phone = '', wilaya = null, commune = null, address = '', note = '';
  let fileInput, dragging = false;

  // Frais : tarifs de la société de livraison (wilaya.home / wilaya.desk), recalculés aussi côté serveur.
  $: fee = mode === 'pickup' ? 0 : wilaya ? (mode === 'stopdesk' ? wilaya.desk : wilaya.home) || null : null;
  const modeFee = k => { if (k === 'pickup') return 'مجاني'; if (!wilaya) return 'اختر ولايتك لرؤية السعر';
    if (k === 'stopdesk' && dz?.live && !wilaya.hasDesk) return 'لا يوجد مكتب في ولايتك'; const v = k === 'stopdesk' ? wilaya.desk : wilaya.home; return v ? 'التوصيل ' + da(v) : 'سعر التوصيل يُحدَّد لاحقاً'; };

  onMount(async () => {
    dz = await loadShip();
    const p = $me; name = p?.full_name || ''; phone = p?.phone || ''; address = p?.address || '';
    ({ wilaya, commune } = findPlace(dz, p?.wilaya, p?.commune));
    if (param) reorder(param);
  });
  $: communes = dz && wilaya ? dz.communes.filter(c => c.w === wilaya.c && (mode !== 'stopdesk' || !dz.live || c.desk)) : [];
  $: if (commune && wilaya && !communes.includes(commune)) commune = null;
  $: if (wilaya && commune && commune.w !== wilaya.c) commune = null;

  function add(file, w = '', h = '', qty = 1) {
    if (!file.type.startsWith('image/')) return;
    if (file.size > 40 * 1024 * 1024) return toast(`${file.name}: الملف أكبر من 40 ميغا`, true);
    const id = 'i' + ++seq, url = URL.createObjectURL(file);
    const it = { id, file, url, w: String(w), h: String(h), q: String(qty), ratio: 1, lock: true };
    const img = new Image();
    img.onload = () => { it.ratio = img.naturalHeight / img.naturalWidth; if (!it.w) { it.w = '10'; it.h = String(+(10 * it.ratio).toFixed(1)); } images = images; };
    img.src = url;
    images = [...images, it];
  }
  function pick(files) { [...files].forEach(f => add(f)); }
  function setW(it, v) { it.w = v; const n = +String(v).replace(',', '.'); if (it.lock && n > 0) it.h = String(+(n * it.ratio).toFixed(1)); images = images; }
  function setH(it, v) { it.h = v; const n = +String(v).replace(',', '.'); if (it.lock && n > 0) it.w = String(+(n / it.ratio).toFixed(1)); images = images; }
  function remove(it) { URL.revokeObjectURL(it.url); images = images.filter(x => x !== it); }

  async function reorder(orderId) {
    try {
      const imgs = await q(sb.from('dtf_order_images').select('*').eq('order_id', orderId));
      progress = 'تحميل صور الطلبية السابقة...';
      for (const im of imgs) {
        const { data, error } = await sb.storage.from(BUCKET).download(im.storage_path);
        if (error) continue;
        add(new File([data], im.storage_path.split('/').pop().replace(/^\d+_/, ''), { type: data.type || 'image/png' }), +im.width_cm, +im.height_cm, im.quantity);
      }
      progress = ''; toast('أُعيدت صور الطلبية — يمكنك تعديلها');
    } catch (e) { progress = ''; err = errMsg(e); }
  }

  const n = v => +String(v).replace(',', '.');
  $: items = images.map(it => ({ id: it.id, width_cm: n(it.w), height_cm: n(it.h), quantity: Math.round(n(it.q)) }));
  $: valid = images.length > 0 && items.every(x => x.width_cm > 0 && x.height_cm > 0 && x.quantity >= 1);
  $: res = valid && $settings ? nest(items, +$settings.film_width_cm || 58, +$settings.gap_cm || 0.3, $settings.allow_rotation !== false) : null;
  $: tooWide = res?.error ? images.findIndex(i => i.id === res.error) + 1 : 0;
  $: Q = res && !res.error && res.length > 0 && $settings ? quote(res.length, $settings, $me?.special_price ?? null) : null;
  $: meta = Object.fromEntries(images.map((it, k) => [it.id, { url: it.url, index: k }]));
  $: copies = items.reduce((s, x) => s + (x.quantity || 0), 0);
  $: shipOk = mode === 'pickup' || (name.trim() && phone.replace(/\D/g, '').length >= 9 && wilaya && commune && (mode === 'stopdesk' || address.trim()));
  $: canNext = step === 0 ? valid && !tooWide && !!Q : step === 1 ? !!Q : step === 2 ? shipOk : true;

  async function send() {
    sending = true; err = '';
    try {
      const o = await createOrder({ lengthCm: res.length, mode,
        ship: mode === 'pickup' ? { name: name.trim(), phone: phone.trim() } : { name: name.trim(), phone: phone.trim(), wilaya: wilaya?.fr, commune: commune?.fr, address: address.trim() || null },
        note, images: images.map((it, k) => ({ file: it.file, w: items[k].width_cm, h: items[k].height_cm, q: items[k].quantity })) },
        (d, t) => (progress = `رفع الصور ${d}/${t}...`));
      sent = true; confetti(); navigator.vibrate?.([20, 40, 20]);
      await loadAll(); toast('أُرسلت طلبيتك بنجاح');
      setTimeout(() => (location.hash = '#/order/' + o.id), 1300);
    } catch (e) { err = errMsg(e); }
    sending = false; progress = '';
  }
  const STEPS = ['الصور', 'الفيلم', 'الاستلام', 'التأكيد'];
</script>

<div class="steps">{#each STEPS as t, i}<button class:on={i === step} class:done={i < step} disabled={i > step} on:click={() => (step = i)}><span class="num">{i + 1}</span>{t}</button>{/each}</div>

{#if step === 0}
  <div class="drop" class:dragging role="button" tabindex="0" on:click={() => fileInput.click()} on:keydown={e => e.key === 'Enter' && fileInput.click()}
    on:dragover|preventDefault={() => (dragging = true)} on:dragleave={() => (dragging = false)} on:drop|preventDefault={e => { dragging = false; pick(e.dataTransfer.files); }}>
    <Icon name="image" size={34} /><b>اضغط أو اسحب صورك هنا</b><span class="faint small">PNG بخلفية شفافة هو الأفضل · حتى 40 ميغا للصورة</span>
  </div>
  <input bind:this={fileInput} type="file" accept="image/*" multiple hidden on:change={e => { pick(e.target.files); e.target.value = ''; }} />
  {#if progress}<p class="accent small" style="margin-top:10px">{progress}</p>{/if}
  <div class="col" style="margin-top:12px">
    {#each images as it, k (it.id)}
      <div class="img card flat">
        <div class="pv"><img class="thumb" src={it.url} alt="" /><span class="ix num">{k + 1}</span></div>
        <div class="grow">
          <div class="row between"><b class="small ell">{it.file.name}</b><button class="btn quiet sm" aria-label="حذف" on:click={() => remove(it)}><Icon name="x" size={16} /></button></div>
          <div class="sz">
            <div><label for="w{it.id}">العرض (سم)</label><input id="w{it.id}" dir="ltr" inputmode="decimal" value={it.w} on:input={e => setW(it, e.target.value)} /></div>
            <button class="lock" class:on={it.lock} title="الحفاظ على النسبة" on:click={() => { it.lock = !it.lock; images = images; }}>{it.lock ? '🔗' : '⛓️‍💥'}</button>
            <div><label for="h{it.id}">الطول (سم)</label><input id="h{it.id}" dir="ltr" inputmode="decimal" value={it.h} on:input={e => setH(it, e.target.value)} /></div>
            <div><label for="q{it.id}">الكمية</label><div class="qty"><button on:click={() => { it.q = String(Math.max(1, n(it.q) - 1)); images = images; }}>−</button><input dir="ltr" inputmode="numeric" bind:value={it.q} on:input={() => (images = images)} /><button on:click={() => { it.q = String(n(it.q) + 1); images = images; }}>+</button></div></div>
          </div>
        </div>
      </div>
    {/each}
  </div>
  {#if tooWide}<div class="notice bad small" style="margin-top:10px">الصورة رقم {tooWide} أعرض من الفيلم ({num(+$settings.film_width_cm)} سم) حتى بعد تدويرها.</div>{/if}

{:else if step === 1}
  <div class="card">
    <div class="section-title">ترتيب صورك على الفيلم<span class="end small muted">{cm(res.length)} · {num(copies)} نسخة</span></div>
    <FilmCanvas result={res} images={meta} height={460} />
    <p class="faint tiny" style="margin-top:8px">عرض الفيلم {cm(res.width)} · مسافة {cm(+$settings.gap_cm)} بين الصور. المصمّم يضبط الترتيب النهائي، وإن تغيّر السعر يصلك إشعار.</p>
  </div>

{:else if step === 2}
  <div class="grid g3 modes">
    {#each ['pickup', 'stopdesk', 'home'] as k}<button class="mode card" class:on={mode === k} disabled={k === 'stopdesk' && dz?.live && wilaya && !wilaya.hasDesk} on:click={() => (mode = k)}><Icon name={k === 'pickup' ? 'stock' : 'truck'} size={24} /><b>{MODE[k]}</b><span class="faint tiny">{modeFee(k, wilaya, dz)}</span></button>{/each}
  </div>
  <div class="card" style="margin-top:12px">
    <div class="grid g2"><div><label for="nm">الاسم</label><input id="nm" bind:value={name} /></div><div><label for="ph">الهاتف</label><input id="ph" dir="ltr" inputmode="tel" bind:value={phone} /></div></div>
    {#if mode !== 'pickup' && dz}
      <div class="grid g2"><Picker label="الولاية" items={dz.wilayas} bind:value={wilaya} /><Picker label={mode === 'stopdesk' ? 'مكتب الاستلام (البلدية)' : 'البلدية'} items={communes} bind:value={commune} disabled={!wilaya} hint={mode === 'stopdesk' ? 'تظهر فقط البلديات التي فيها مكتب لشركة التوصيل' : ''} /></div>
      {#if mode === 'stopdesk' && wilaya && dz.live && !wilaya.hasDesk}<div class="notice warn small" style="margin-top:8px">لا يوجد مكتب لشركة التوصيل في {wilaya.ar} — اختر التوصيل إلى المنزل.</div>{/if}
      {#if mode === 'home'}<label for="ad">العنوان</label><input id="ad" bind:value={address} />{/if}
    {/if}
  </div>

{:else}
  <div class="card">
    <div class="section-title">ملخّص الطلبية</div>
    <div class="kv"><span>الصور</span><b>{num(images.length)} صورة · {num(copies)} نسخة</b></div>
    <div class="kv"><span>الطول التقديري</span><b>{cm(res.length)}</b></div>
    <div class="kv"><span>الأمتار المحسوبة</span><b>{m(Q.meters)}</b></div>
    <div class="kv"><span>سعر المتر</span><b>{da(Q.ppm)}</b></div>
    <div class="kv"><span>الاستلام</span><b>{MODE[mode]}{mode !== 'pickup' ? ` — ${wilaya?.ar} / ${commune?.ar}` : ''}</b></div>
    <div class="kv"><span>سعر الطباعة</span><b>{da(Q.amount)}</b></div>
    {#if mode !== 'pickup'}<div class="kv"><span>التوصيل</span><b>{fee ? da(fee) : 'يُحدَّد لاحقاً'}</b></div>{/if}
    <div class="kv tot"><span>المجموع</span><b class="accent">{da(Q.amount + (fee || 0))}</b></div>
    {#if mode !== 'pickup'}<div class="faint tiny" style="margin-top:4px">تدفع المبلغ للموزّع عند الاستلام.</div>{/if}
    <label for="nt">ملاحظة للورشة (اختياري)</label><textarea id="nt" rows="3" bind:value={note} placeholder="مثال: اطبع الصورة 2 بالمرآة"></textarea>
  </div>
  {#if $settings?.is_open === false}<div style="margin-top:12px"><ShopStatus detail="الورشة مغلقة الآن، ستُعالَج طلبيتك عند الفتح" /></div>{/if}
{/if}

<div class="bar-bottom card">
  <div class="grow">
    <div class="muted tiny">{Q ? `${m(Q.meters)} · ${num(copies)} نسخة` : 'أضف صورك ومقاساتها'}</div>
    {#if Q}<div class="price" use:countUp={{ value: Q.amount + (fee || 0), format: v => da(Math.round(v)) }}></div>{#if fee}<div class="faint tiny">منها التوصيل {da(fee)}</div>{/if}{:else}<div class="price">—</div>{/if}
    {#if Q && (Q.ppm < Q.base || $me?.special_price != null)}<div class="green tiny">سعرك: {da(Q.ppm)} للمتر</div>{/if}
    {#if Q?.next}<div class="accent tiny">اطلب {m(Q.next.min, 0)} أو أكثر ويصبح المتر {da(Q.next.price)}</div>{/if}
  </div>
  {#if step > 0}<button class="btn quiet" disabled={sending} on:click={() => step--}>رجوع</button>{/if}
  {#if step < 3}<button class="btn lg" disabled={!canNext} on:click={() => step++}>{step === 2 ? 'مراجعة' : 'التالي'}</button>
  {:else}<button class="btn lg" class:done={sent} class:pop={sent} disabled={sending || sent} on:click={send}><Icon name="check" size={18} />{sent ? 'أُرسلت ✓' : sending ? progress || '...' : 'تأكيد الإرسال'}</button>{/if}
</div>
{#if err}<div class="notice bad small" style="margin-top:10px">{err}</div>{/if}

<style>
  .steps { display: flex; gap: 6px; margin-bottom: 14px; overflow-x: auto; }
  .steps button { flex: 1; min-width: 90px; display: flex; align-items: center; gap: 8px; justify-content: center; padding: 9px; border-radius: 12px; background: var(--card); border: 1px solid var(--line); color: var(--muted); font-size: 13.5px; }
  .steps button span { width: 22px; height: 22px; border-radius: 50%; display: grid; place-items: center; background: var(--card3); font-size: 12px; }
  .steps .on { border-color: var(--accent); color: var(--accent3); } .steps .on span, .steps .done span { background: var(--accent); color: #fff; }
  .drop { display: flex; flex-direction: column; align-items: center; gap: 8px; padding: 34px; border: 2px dashed var(--accent-line); border-radius: 18px; background: var(--accent-soft); color: var(--accent3); cursor: pointer; text-align: center; }
  .drop.dragging { border-color: var(--accent2); background: #E6B32526; }
  .img { display: flex; gap: 12px; padding: 12px; }
  .pv { position: relative; width: 96px; height: 96px; flex-shrink: 0; }
  .pv img { width: 100%; height: 100%; }
  .ix { position: absolute; top: 4px; right: 4px; background: var(--accent); color: #fff; border-radius: 7px; font-size: 11px; padding: 0 6px; }
  .ell { max-width: 220px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .sz { display: grid; grid-template-columns: 1fr auto 1fr 1.2fr; gap: 8px; align-items: end; }
  .sz label { margin-top: 4px; }
  .lock { padding: 10px 4px; font-size: 16px; opacity: .5; } .lock.on { opacity: 1; }
  .qty { display: flex; border: 1px solid var(--line); border-radius: 12px; overflow: hidden; }
  .qty input { border: 0; border-radius: 0; text-align: center; padding: 11px 4px; }
  .qty button { width: 34px; background: var(--card2); color: var(--accent2); font-size: 18px; }
  @media (max-width: 640px) { .sz { grid-template-columns: 1fr auto 1fr; } .sz > div:last-child { grid-column: 1 / -1; } .pv { width: 70px; height: 70px; } }
  .mode { display: flex; flex-direction: column; align-items: center; gap: 6px; text-align: center; color: var(--muted); }
  .mode.on { border-color: var(--accent); color: var(--accent2); background: linear-gradient(180deg, #1A1810, #10131B); }
  .mode:disabled { opacity: .45; cursor: not-allowed; }
  .kv { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid var(--line); font-size: 14px; } .kv span { color: var(--muted); }
  .kv.tot b { font-size: 20px; }
  .bar-bottom { position: sticky; bottom: 10px; margin-top: 16px; display: flex; align-items: center; gap: 10px; z-index: 30; border-color: var(--accent-line); }
  .price { font-size: 22px; font-weight: 700; color: var(--accent2); }
  @media (max-width: 800px) { .bar-bottom { bottom: calc(80px + env(safe-area-inset-bottom)); } }
</style>
