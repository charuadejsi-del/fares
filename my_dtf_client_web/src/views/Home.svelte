<script>
  import { countUp } from '../lib/motion.js';
  import { me, orders, settings } from '../lib/store.js';
  import { da, num } from '../lib/fmt.js';
  import ShopStatus from '../components/ShopStatus.svelte';
  import OrderCard from '../components/OrderCard.svelte';
  import Icon from '../components/Icon.svelte';
  export let param = '';
  const done = ['delivered', 'rejected', 'cancelled'];
  $: active = $orders.filter(o => !done.includes(o.status));
  $: counted = $orders.filter(o => !['rejected', 'cancelled'].includes(o.status));
  $: total = counted.reduce((s, o) => s + +o.print_amount + +o.delivery_fee, 0);
  $: paid = $orders.reduce((s, o) => s + +(o.amount_paid || 0), 0);
  $: first = ($me?.full_name || '').split(' ')[0];
  $: sp = $me?.special_price; $: tiers = ($settings?.price_tiers || []).slice().sort((a, b) => a.min_m - b.min_m);
</script>
<div class="hero card accent fade-in">
  <div class="grow"><h1>مرحباً {first} 👋</h1><p class="muted small">ارفع صورك واحصل على السعر في ثوانٍ.</p></div>
  <a class="btn lg" href="#/new"><Icon name="plus" size={20} />طلبية جديدة</a>
</div>
<div style="margin-top:12px"><ShopStatus /></div>
<div class="grid g3" style="margin-top:12px">
  <div class="card kp"><span class="muted small">سعر المتر</span><b class="accent">{da(sp ?? $settings?.price_per_meter ?? 0)}</b>
    {#if sp != null}<span class="green tiny">سعر خاص بك</span>{:else}{#each tiers as t}<span class="faint tiny">من {num(t.min_m)} م: {da(t.price)}</span>{/each}{/if}</div>
  <div class="card kp"><span class="muted small">طلبياتي</span><b use:countUp={{ value: $orders.length, format: v => num(Math.round(v)) }}></b><span class="faint tiny">{num(active.length)} قيد التنفيذ</span></div>
  <div class="card kp"><span class="muted small">المتبقي للدفع</span><b use:countUp={{ value: Math.max(0, total - paid), format: da }}></b><span class="faint tiny">من أصل {da(total)}</span></div>
</div>
<div class="section-title" style="margin-top:20px">قيد التنفيذ</div>
{#if active.length}<div class="grid g2 stack">{#each active as o (o.id)}<OrderCard {o} />{/each}</div>
{:else}<div class="card empty"><Icon name="image" size={32} /><div style="margin:8px 0 12px">لا توجد طلبيات مفتوحة</div><a class="btn" href="#/new">ابدأ طلبيتك الأولى</a></div>{/if}
<style>
  .hero { display: flex; align-items: center; gap: 16px; flex-wrap: wrap; padding: 20px; }
  .kp { display: flex; flex-direction: column; gap: 3px; } .kp b { font-size: 22px; }
</style>
