// Même règle que la fonction SQL dtf_price : pas d'arrondi, prix spécial > paliers > prix de base, minimum de commande.
export function quote(lengthCm, s, special = null) {
  const step = +s.meter_rounding_step;
  let m = lengthCm / 100;
  if (step > 0) m = Math.ceil(m / step - 1e-9) * step;
  m = Math.round(m * 1000) / 1000;
  const tiers = (s.price_tiers || []).map(t => ({ min: +t.min_m, price: +t.price })).sort((a, b) => a.min - b.min);
  const tier = [...tiers].reverse().find(t => t.min <= m + 1e-9);
  const ppm = special != null ? +special : tier ? tier.price : +s.price_per_meter;
  const next = special != null ? null : tiers.find(t => t.min > m + 1e-9 && t.price < ppm) || null;
  return { meters: m, ppm, amount: Math.round(Math.max(m * ppm, +s.min_order_amount)), next, base: +s.price_per_meter };
}
