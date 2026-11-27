// Moteur des coûts — applique exactement les formules du patron.
const sum = l => (l || []).reduce((s, x) => s + (+x.amount || 0), 0);
export function unit(s) {
  const film = +s.roll_price / +s.roll_length_m;
  const ink = (+s.ink_price_l / 1000) * +s.ink_ml_per_m;
  const powder = (+s.powder_price_kg / 1000) * +s.powder_g_per_m;
  return { film, ink, powder, material: film + ink + powder, wagesDay: sum(s.wages), fixedMonth: sum(s.fixed_costs), workDays: +s.work_days };
}
// Une période : mètres, jours travaillés, gâche → coûts, recettes, bénéfice (par mètre et total).
export function period({ meters, waste = 0, days, revenueReal = null, value = null }, s, price, { fixedShare = 1 } = {}) {
  const u = unit(s);
  const film = u.film * meters, ink = u.ink * meters, powder = u.powder * meters;
  const wages = u.wagesDay * days;
  const fixed = u.fixedMonth * fixedShare;
  const wasteCost = s.waste_in_profit ? u.material * waste : 0;
  const cost = film + ink + powder + wages + fixed + wasteCost;
  const revenue = value != null ? value : meters * price;
  const avgPrice = meters > 0 ? revenue / meters : price;
  const profit = revenue - cost;
  const pm = v => (meters > 0 ? v / meters : null);
  return {
    meters, days, waste, revenue, revenueReal, film, ink, powder, wages, fixed, wasteCost, cost, profit,
    margin: revenue > 0 ? profit / revenue : null,
    per: { film: u.film, ink: u.ink, powder: u.powder, wages: pm(wages), fixed: pm(fixed), waste: pm(wasteCost), cost: pm(cost), profit: pm(profit), price: avgPrice },
  };
}
// Mois à partir des jours réels (+ projection fin de mois si le mois est en cours).
export function month(rows, s, price, ongoing) {
  const u = unit(s);
  const worked = rows.filter(r => +r.meters > 0 || +r.waste_m > 0);
  const M = rows.reduce((a, r) => a + +r.meters, 0), W = rows.reduce((a, r) => a + +r.waste_m, 0);
  const real = rows.reduce((a, r) => a + +r.revenue, 0);
  const hasV = rows.some(r => r.value != null);
  const V = hasV ? rows.reduce((a, r) => a + (r.value != null ? +r.value : +r.meters * price), 0) : null;
  const actual = period({ meters: M, waste: W, days: worked.length, revenueReal: real, value: V }, s, price);
  let projection = null;
  if (ongoing && worked.length) {
    const k = u.workDays / worked.length;
    projection = period({ meters: M * k, waste: W * k, days: u.workDays, value: V != null ? V * k : null }, s, price);
  }
  const days = rows.map(r => {
    const on = +r.meters > 0 || +r.waste_m > 0;
    return { day: r.day, on, orders: r.orders, ...period({ meters: +r.meters, waste: +r.waste_m, days: on ? 1 : 0, revenueReal: +r.revenue, value: r.value != null ? +r.value : null }, s, price, { fixedShare: on ? 1 / u.workDays : 0 }) };
  });
  return { actual, projection, days, worked: worked.length };
}
