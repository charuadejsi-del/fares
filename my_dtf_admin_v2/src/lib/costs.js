// Moteur des coûts — formules du patron + dates de début (atelier, chaque salaire, chaque charge mensuelle).
// Charge mensuelle : montant × (jours actifs du mois / jours du mois). Salaires : comptés les jours imprimés, à partir de leur date.
const amt = x => +x.amount || 0;
const pad = n => String(n).padStart(2, '0');
const iso = (y, m, d) => `${y}-${pad(m)}-${pad(d)}`;
const activeFrom = (item, start) => [item?.from, start].filter(Boolean).sort().pop() || null;

export function unit(s) {
  const film = +s.roll_price / +s.roll_length_m;
  const ink = (+s.ink_price_l / 1000) * +s.ink_ml_per_m;
  const powder = (+s.powder_price_kg / 1000) * +s.powder_g_per_m;
  return { film, ink, powder, material: film + ink + powder, workDays: +s.work_days };
}
export const wagesOn = (s, day) => (s.wages || []).filter(w => !activeFrom(w, s.start_date) || day >= activeFrom(w, s.start_date)).reduce((a, w) => a + amt(w), 0);
export const fixedOn = (s, day) => (s.fixed_costs || []).filter(f => !activeFrom(f, s.start_date) || day >= activeFrom(f, s.start_date)).reduce((a, f) => a + amt(f), 0);
/** Charges fixes du mois, au prorata des jours où chaque charge est active. */
export function fixedForMonth(s, y, m) {
  const dim = new Date(y, m, 0).getDate();
  return (s.fixed_costs || []).reduce((a, f) => {
    const from = activeFrom(f, s.start_date); let n = 0;
    for (let d = 1; d <= dim; d++) if (!from || iso(y, m, d) >= from) n++;
    return a + amt(f) * n / dim;
  }, 0);
}
function activeCalendarDays(s, y, m) {
  const dim = new Date(y, m, 0).getDate(); let n = 0;
  for (let d = 1; d <= dim; d++) if (!s.start_date || iso(y, m, d) >= s.start_date) n++;
  return { n, dim };
}
// Une période à partir de montants explicites.
export function period({ meters, waste = 0, days, wages = 0, fixed = 0, revenueReal = null, value = null }, s, price) {
  const u = unit(s);
  const film = u.film * meters, ink = u.ink * meters, powder = u.powder * meters;
  const wasteCost = s.waste_in_profit ? u.material * waste : 0;
  const cost = film + ink + powder + wages + fixed + wasteCost;
  const revenue = value != null ? value : meters * price;
  const profit = revenue - cost;
  const pm = v => (meters > 0 ? v / meters : null);
  return {
    meters, days, waste, revenue, revenueReal, film, ink, powder, wages, fixed, wasteCost, cost, profit,
    margin: revenue > 0 ? profit / revenue : null,
    per: { film: u.film, ink: u.ink, powder: u.powder, wages: pm(wages), fixed: pm(fixed), waste: pm(wasteCost), cost: pm(cost), profit: pm(profit), price: meters > 0 ? revenue / meters : price },
  };
}
/** Simulation « X m par jour » sur un mois complet (aperçu des réglages). */
export function simulate(s, price, perDay = 50) {
  const u = unit(s), M = perDay * u.workDays;
  return period({ meters: M, days: u.workDays, wages: (s.wages || []).reduce((a, w) => a + amt(w), 0) * u.workDays, fixed: (s.fixed_costs || []).reduce((a, f) => a + amt(f), 0) }, s, price);
}
// Mois réel (+ projection fin de mois si en cours). rows : [{ day: 'AAAA-MM-JJ', meters, waste_m, revenue, value }]
export function month(rows, s, price, ongoing) {
  if (!rows.length) return { actual: period({ meters: 0, days: 0 }, s, price), projection: null, days: [], worked: 0 };
  const [y, m] = rows[0].day.split('-').map(Number);
  const u = unit(s);
  const active = d => !s.start_date || d >= s.start_date;
  const isOn = r => active(r.day) && (+r.meters > 0 || +r.waste_m > 0);
  const worked = rows.filter(isOn);
  const M = rows.reduce((a, r) => a + +r.meters, 0), W = rows.reduce((a, r) => a + +r.waste_m, 0);
  const real = rows.reduce((a, r) => a + +r.revenue, 0);
  const V = rows.some(r => r.value != null) ? rows.reduce((a, r) => a + (r.value != null ? +r.value : +r.meters * price), 0) : null;
  const fixedM = fixedForMonth(s, y, m);
  const wagesM = worked.reduce((a, r) => a + wagesOn(s, r.day), 0);
  const actual = period({ meters: M, waste: W, days: worked.length, wages: wagesM, fixed: fixedM, revenueReal: real, value: V }, s, price);
  let projection = null;
  if (ongoing && worked.length) {
    const { n, dim } = activeCalendarDays(s, y, m);
    const eff = Math.max(worked.length, u.workDays * n / dim);   // jours de travail possibles ce mois
    const k = eff / worked.length;
    const lastDay = iso(y, m, dim);
    projection = period({ meters: M * k, waste: W * k, days: eff, wages: wagesOn(s, lastDay) * eff, fixed: fixedM, value: V != null ? V * k : null }, s, price);
  }
  const days = rows.map(r => {
    const on = isOn(r);
    return { day: r.day, on, orders: r.orders, ...period({ meters: +r.meters, waste: +r.waste_m, days: on ? 1 : 0, wages: on ? wagesOn(s, r.day) : 0, fixed: on ? fixedOn(s, r.day) / u.workDays : 0, revenueReal: +r.revenue, value: r.value != null ? +r.value : null }, s, price) };
  });
  return { actual, projection, days, worked: worked.length };
}
