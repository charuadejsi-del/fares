<script>
  // Envoi d'une commande à DHD : les champs sont pré-remplis depuis la commande, communes et tarifs viennent de DHD.
  import { sb, q, invokeDhd, errMsg } from '../lib/sb.js';
  import { closeModal, liveTick, toast } from '../lib/store.js';
  import { da } from '../lib/fmt.js';
  import Icon from '../components/Icon.svelte';
  export let o;

  const fold = s => (s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9؀-ۿ]+/g, ' ').trim();
  let wilayas = [], rates = [], communes = [], err = '', busy = false, ready = false;
  let name = o.ship_name || o.client?.full_name || '', phone = o.ship_phone || o.client?.phone || '', address = o.ship_address || '';
  let desk = o.delivery_mode === 'stopdesk', wc = o.ship_wilaya_code || null, commune = '', note = '', weight = '';
  let amount = String(Math.round(+o.print_amount + +o.delivery_fee - (+o.amount_paid || 0)));

  (async () => {
    try {
      [wilayas, rates] = await Promise.all([q(sb.from('dtf_wilayas').select('*').order('code')), q(sb.from('dtf_ship_rates').select('*'))]);
      if (!wc && o.ship_wilaya) wc = wilayas.find(w => fold(w.fr) === fold(o.ship_wilaya) || w.ar === o.ship_wilaya)?.code || null;
      ready = true;
    } catch (e) { err = errMsg(e); }
  })();
  let lastWc = null;
  $: if (ready && wc !== lastWc) { lastWc = wc; loadCommunes(); }
  async function loadCommunes() {
    communes = wc ? await q(sb.from('dtf_ship_communes').select('*').eq('wilaya_code', wc).order('name')).catch(() => []) : [];
    const want = fold(o.ship_commune);
    const hit = communes.find(c => fold(c.name) === want) || communes.find(c => want && (fold(c.name).includes(want) || want.includes(fold(c.name))));
    commune = hit?.name || '';
  }
  $: list = desk ? communes.filter(c => c.has_desk) : communes;
  $: if (desk && commune && !list.some(c => c.name === commune)) commune = '';
  $: rate = rates.find(r => r.wilaya_code === +wc);
  $: fee = rate ? +(desk ? rate.desk : rate.home) || 0 : null;
  $: noData = ready && !rates.length;

  async function send() {
    busy = true; err = '';
    try {
      const c = communes.find(x => x.name === commune);
      const r = await invokeDhd({ action: 'create', order_id: o.id, name, phone, address, wilaya_code: +wc, commune: commune || null,
        stop_desk: desk, code_postal: c?.code_postal || null, amount: +String(amount).replace(/\s/g, '') || 0, note, weight: +weight || null });
      toast('أُرسل الطرد إلى DHD — رقم التتبع ' + r.tracking);
      if (r.warning) alert(r.warning);
      liveTick.update(n => n + 1); closeModal();
    } catch (e) { err = errMsg(e); }
    busy = false;
  }
</script>

<h2 class="row"><Icon name="truck" size={22} />إرسال إلى DHD — طلبية #{o.code}</h2>
{#if noData}<div class="notice warn small" style="margin-top:10px">لم تُجلب بلديات وأسعار DHD بعد. اذهب إلى الإعدادات ← التوصيل DHD واضغط «مزامنة»، أو اكتب البلدية كما هي عند DHD.</div>{/if}
<div class="seg" style="margin-top:12px"><button class:on={!desk} on:click={() => (desk = false)}>توصيل إلى المنزل</button><button class:on={desk} on:click={() => (desk = true)}>مكتب DHD (Stop desk)</button></div>
<div class="grid g2">
  <div><label for="sn">اسم المستلم</label><input id="sn" bind:value={name} /></div>
  <div><label for="sp">الهاتف</label><input id="sp" dir="ltr" inputmode="tel" bind:value={phone} /></div>
  <div><label for="sw">الولاية</label><select id="sw" bind:value={wc}><option value={null}>—</option>{#each wilayas as w}<option value={w.code}>{String(w.code).padStart(2, '0')} — {w.ar} / {w.fr}</option>{/each}</select></div>
  <div><label for="sc">{desk ? 'مكتب DHD (البلدية)' : 'البلدية'}</label>
    {#if list.length}<select id="sc" bind:value={commune}><option value="">— اختر —</option>{#each list as c}<option value={c.name}>{c.name}</option>{/each}</select>
    {:else}<input id="sc" dir="ltr" placeholder="كما تُكتب عند DHD" bind:value={commune} />{/if}</div>
</div>
{#if !desk}<label for="sa">العنوان</label><input id="sa" bind:value={address} />{/if}
<div class="grid g2">
  <div><label for="sm">المبلغ الذي يدفعه الزبون للموزّع (دج)</label><input id="sm" dir="ltr" inputmode="numeric" bind:value={amount} /></div>
  <div><label for="sg">الوزن (كغ) — اختياري</label><input id="sg" dir="ltr" inputmode="decimal" bind:value={weight} /></div>
</div>
<label for="sr">ملاحظة للموزّع</label><input id="sr" bind:value={note} placeholder="مثلاً: الاتصال قبل التوصيل" />
<div class="notice small" style="margin-top:12px">
  الطباعة {da(o.print_amount)} + التوصيل المسجّل {da(o.delivery_fee)}{#if +o.amount_paid} − المدفوع {da(o.amount_paid)}{/if}
  {#if fee != null}<div style="margin-top:4px">سعر DHD لهذه الولاية: <b class="gold">{da(fee)}</b>{#if fee !== +o.delivery_fee} — <span class="amber">يختلف عن المسجّل في الطلبية، عدّل المبلغ إن لزم</span>{/if}</div>{/if}
  <div class="faint tiny" style="margin-top:4px">بعد الإرسال: خذ الطرد إلى مكتب DHD واطبع الملصق من الطلبية.</div>
</div>
<p class="red small" style="min-height:20px;margin-top:8px">{err}</p>
<div class="row"><button class="btn grow" disabled={busy || !name.trim() || !wc || !commune} on:click={send}>{busy ? '...' : 'إنشاء الطرد عند DHD'}</button><button class="btn quiet" on:click={closeModal}>إلغاء</button></div>
