// خلفية خفيفة: شبكة نقاط متحرّكة (تتوقّف عند إخفاء الصفحة لتوفير البطارية).
export function startFx() {
  const c = document.getElementById('fx');
  if (!c || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const x = c.getContext('2d');
  let W = 0, H = 0, pts = [], raf = 0;
  const init = () => {
    const dpr = Math.min(devicePixelRatio || 1, 2);
    W = innerWidth; H = innerHeight;
    c.width = W * dpr; c.height = H * dpr; c.style.width = W + 'px'; c.style.height = H + 'px';
    x.setTransform(dpr, 0, 0, dpr, 0, 0);
    pts = Array.from({ length: Math.min(60, Math.round(W / 24)) }, () => ({
      x: Math.random() * W, y: Math.random() * H, vx: (Math.random() - 0.5) * 0.22, vy: (Math.random() - 0.5) * 0.22,
    }));
  };
  const loop = () => {
    x.clearRect(0, 0, W, H);
    for (const p of pts) {
      p.x += p.vx; p.y += p.vy;
      if (p.x < 0 || p.x > W) p.vx *= -1;
      if (p.y < 0 || p.y > H) p.vy *= -1;
    }
    for (let i = 0; i < pts.length; i++)
      for (let j = i + 1; j < pts.length; j++) {
        const a = pts[i], b = pts[j], d = Math.hypot(a.x - b.x, a.y - b.y);
        if (d < 120) {
          x.strokeStyle = `rgba(0,255,163,${0.06 * (1 - d / 120)})`;
          x.beginPath(); x.moveTo(a.x, a.y); x.lineTo(b.x, b.y); x.stroke();
        }
      }
    x.fillStyle = 'rgba(0,255,163,.28)';
    for (const p of pts) x.fillRect(p.x - 1, p.y - 1, 2, 2);
    raf = requestAnimationFrame(loop);
  };
  addEventListener('resize', init);
  document.addEventListener('visibilitychange', () => {
    cancelAnimationFrame(raf);
    if (!document.hidden) loop();
  });
  init();
  loop();
}
