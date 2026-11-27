// Moteur d'imbrication (même algorithme que l'app Android et le module Kotlin « core »).
const E = 1e-9;
function skyline(copies, W, g, greedy) {
  const binW = W + g; let sky = [[0, 0, binW]]; const out = [];
  for (const c of copies) {
    const opts = [[c.w, c.h, c.r]];
    if (greedy && Math.abs(c.w - c.h) > E) opts.push([c.h, c.w, !c.r]);
    let best = null;
    for (const [ow, oh, rot] of opts) {
      const w = ow + g, h = oh + g;
      if (w > binW + E) continue;
      for (let i = 0; i < sky.length; i++) {
        const x = sky[i][0]; if (x + w > binW + E) break;
        let y = 0, rem = w, j = i;
        while (j < sky.length && rem > E) { y = Math.max(y, sky[j][1]); rem -= sky[j][2]; j++; }
        const top = y + h;
        if (!best || top < best.top - E || (Math.abs(top - best.top) <= E && (y < best.y - E || (Math.abs(y - best.y) <= E && x < best.x))))
          best = { x, y, w, h, rot, top };
      }
    }
    if (!best) return null;
    out.push({ id: c.id, x: best.x, y: best.y, w: best.w - g, h: best.h - g, rot: best.rot });
    const res = [], end = best.x + best.w;
    for (const s of sky) { const se = s[0] + s[2];
      if (se <= best.x + E || s[0] >= end - E) { res.push(s); continue; }
      if (s[0] < best.x) res.push([s[0], s[1], best.x - s[0]]);
      if (se > end) res.push([end, s[1], se - end]); }
    res.push([best.x, best.top, best.w]); res.sort((a, b) => a[0] - b[0]);
    const merged = [];
    for (const s of res) { const l = merged[merged.length - 1]; if (l && Math.abs(l[1] - s[1]) < E) l[2] += s[2]; else merged.push([...s]); }
    sky = merged;
  }
  return { length: Math.round(Math.max(0, ...out.map(p => p.y + p.h)) * 1000) / 1000, placements: out };
}
export function nest(items, W = 58, g = 0.3, rotation = true) {
  const copies = [];
  for (const it of items) {
    const w = +it.width_cm, h = +it.height_cm, q = +it.quantity;
    if (!(w > 0 && h > 0 && q > 0)) continue;
    if (w > W && (!rotation || h > W)) return { error: it.id };
    for (let i = 0; i < q; i++) copies.push(w > W ? { id: it.id, w: h, h: w, r: true } : { id: it.id, w, h, r: false });
  }
  if (!copies.length) return { length: 0, placements: [], width: W };
  const orders = [(a, b) => b.h - a.h, (a, b) => b.w - a.w, (a, b) => b.w * b.h - a.w * a.h, (a, b) => Math.max(b.w, b.h) - Math.max(a.w, a.h)];
  const orient = (c, land) => { const t = land ? c.w < c.h : c.w > c.h; return t && c.h <= W ? { ...c, w: c.h, h: c.w, r: !c.r } : c; };
  const variants = [[copies, false]];
  if (rotation) variants.push([copies, true], [copies.map(c => orient(c, true)), false], [copies.map(c => orient(c, false)), false]);
  let best = null;
  for (const [cs, gr] of variants) for (const o of orders) { const r = skyline([...cs].sort(o), W, g, gr); if (r && (!best || r.length < best.length - E)) best = r; }
  const used = best.placements.reduce((s, p) => s + p.w * p.h, 0);
  return { ...best, width: W, fill: best.length ? used / (best.length * W) : 0 };
}
