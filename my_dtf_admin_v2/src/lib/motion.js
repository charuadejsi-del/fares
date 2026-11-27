// Effets partagés : ondulation sur les boutons, compteur animé, confettis.
const reduce = () => window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
export function installRipple() {
  document.addEventListener('pointerdown', e => {
    const b = e.target.closest?.('.btn'); if (!b || b.disabled || reduce()) return;
    const r = b.getBoundingClientRect(), s = Math.max(r.width, r.height);
    const sp = document.createElement('span'); sp.className = 'ripple';
    sp.style.cssText = `width:${s}px;height:${s}px;left:${e.clientX - r.left - s / 2}px;top:${e.clientY - r.top - s / 2}px`;
    b.appendChild(sp); setTimeout(() => sp.remove(), 650);
    navigator.vibrate?.(8);
  }, { passive: true });
}
/** use:countUp={{ value, format }} — le nombre défile jusqu'à sa valeur. */
export function countUp(node, { value, format = v => String(Math.round(v)) }) {
  let cur = 0, raf;
  const run = (to, fmt) => {
    cancelAnimationFrame(raf);
    if (reduce()) { cur = to; node.textContent = fmt(to); return; }
    const from = cur, t0 = performance.now(), d = 700;
    const step = t => { const k = Math.min(1, (t - t0) / d), e = 1 - Math.pow(1 - k, 3); cur = from + (to - from) * e; node.textContent = fmt(cur); if (k < 1) raf = requestAnimationFrame(step); };
    raf = requestAnimationFrame(step);
  };
  run(+value || 0, format);
  return { update(p) { format = p.format || format; run(+p.value || 0, format); }, destroy() { cancelAnimationFrame(raf); } };
}
export function confetti(n = 110) {
  if (reduce()) return;
  const c = document.createElement('canvas'); c.style.cssText = 'position:fixed;inset:0;pointer-events:none;z-index:500';
  c.width = innerWidth * devicePixelRatio; c.height = innerHeight * devicePixelRatio; document.body.appendChild(c);
  const g = c.getContext('2d'); g.scale(devicePixelRatio, devicePixelRatio);
  const col = ['#A78BFA', '#C4B5FD', '#8B5CF6', '#2DD4BF', '#F472B6', '#FBBF24', '#4ADE80'];
  const P = Array.from({ length: n }, () => ({ x: innerWidth / 2, y: innerHeight * .45, vx: (Math.random() - .5) * 16, vy: -Math.random() * 15 - 4, r: Math.random() * 6.28, vr: (Math.random() - .5) * .4, c: col[Math.random() * col.length | 0], w: 6 + Math.random() * 6 }));
  const t0 = performance.now();
  (function f(t) {
    const k = (t - t0) / 1800; g.clearRect(0, 0, innerWidth, innerHeight);
    P.forEach(p => { p.vy += .45; p.vx *= .985; p.x += p.vx; p.y += p.vy; p.r += p.vr; g.save(); g.globalAlpha = Math.max(0, 1 - k); g.translate(p.x, p.y); g.rotate(p.r); g.fillStyle = p.c; g.fillRect(-p.w / 2, -3, p.w, 6); g.restore(); });
    if (k < 1) requestAnimationFrame(f); else c.remove();
  })(t0);
}
