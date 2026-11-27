<script>
  // Aperçu du film avec les vraies miniatures, dans un cadre fixe (rien ne déborde).
  import { onMount, afterUpdate } from 'svelte';
  export let result;           // sortie de nest()
  export let images = {};      // id -> { url, index }
  export let height = 380;
  let box, canvas, w = 300;
  const cache = {};
  function img(url) {
    if (!url) return null;
    if (!cache[url]) { const i = new Image(); i.crossOrigin = 'anonymous'; i.onload = draw; i.src = url; cache[url] = i; }
    return cache[url].complete && cache[url].naturalWidth ? cache[url] : null;
  }
  const COLORS = ['#8B5CF6', '#2DD4BF', '#F472B6', '#FBBF24', '#60A5FA', '#4ADE80', '#FB923C', '#A78BFA'];
  function draw() {
    if (!canvas || !result) return;
    const dpr = window.devicePixelRatio || 1;
    const ruler = 22, W = result.width || 58, L = Math.max(1, result.length);
    const s = (w - ruler) / W;
    const h = Math.max(height, Math.min(4000, L * s + ruler + 8));
    canvas.width = w * dpr; canvas.height = h * dpr; canvas.style.height = h + 'px';
    const g = canvas.getContext('2d'); g.setTransform(dpr, 0, 0, dpr, 0, 0);
    g.fillStyle = '#0B0C0F'; g.fillRect(0, 0, w, h);
    g.save(); g.translate(ruler, ruler);
    g.fillStyle = '#15161B'; g.fillRect(0, 0, W * s, L * s);
    g.strokeStyle = '#ffffff0a'; g.lineWidth = 1;
    for (let x = 0; x <= W; x += 5) { g.beginPath(); g.moveTo(x * s, 0); g.lineTo(x * s, L * s); g.stroke(); }
    for (let y = 0; y <= L; y += 5) { g.beginPath(); g.moveTo(0, y * s); g.lineTo(W * s, y * s); g.stroke(); }
    for (const p of result.placements) {
      const meta = images[p.id] || {}; const c = COLORS[(meta.index || 0) % COLORS.length];
      const x = p.x * s, y = p.y * s, pw = p.w * s, ph = p.h * s;
      g.fillStyle = c + '33'; g.fillRect(x, y, pw, ph);
      const im = img(meta.url);
      if (im) {
        g.save(); g.beginPath(); g.rect(x, y, pw, ph); g.clip();
        g.translate(x + pw / 2, y + ph / 2); if (p.rot) g.rotate(Math.PI / 2);
        const bw = p.rot ? ph : pw, bh = p.rot ? pw : ph;
        const k = Math.min(bw / im.naturalWidth, bh / im.naturalHeight);
        g.drawImage(im, -im.naturalWidth * k / 2, -im.naturalHeight * k / 2, im.naturalWidth * k, im.naturalHeight * k);
        g.restore();
      }
      g.strokeStyle = c; g.lineWidth = 1.2; g.strokeRect(x + .5, y + .5, pw - 1, ph - 1);
      if (pw > 18 && ph > 14) { g.fillStyle = c; g.fillRect(x, y, 16, 14); g.fillStyle = '#fff'; g.font = '600 10px sans-serif'; g.fillText(String((meta.index || 0) + 1), x + 4, y + 11); }
    }
    g.strokeStyle = '#E6B325'; g.lineWidth = 1.5; g.strokeRect(0, 0, W * s, L * s);
    g.restore();
    g.fillStyle = '#101116'; g.fillRect(0, 0, w, ruler); g.fillRect(0, 0, ruler, h);
    g.fillStyle = '#6C6E78'; g.strokeStyle = '#6C6E78'; g.font = '9px sans-serif';
    for (let cm = 0; cm <= W; cm += 5) { const x = ruler + cm * s; g.beginPath(); g.moveTo(x, ruler); g.lineTo(x, ruler - (cm % 10 ? 5 : 10)); g.stroke(); if (cm % 10 === 0 && cm) g.fillText(cm, x + 2, 10); }
    for (let cm = 0; cm <= L; cm += 5) { const y = ruler + cm * s; g.beginPath(); g.moveTo(ruler, y); g.lineTo(ruler - (cm % 10 ? 5 : 10), y); g.stroke(); if (cm % 10 === 0 && cm) g.fillText(cm, 2, y + 10); }
    g.fillStyle = '#E6B325'; g.fillRect(0, 0, ruler, ruler);
  }
  onMount(() => {
    const ro = new ResizeObserver(() => { w = box.clientWidth; draw(); }); ro.observe(box);
    return () => ro.disconnect();
  });
  afterUpdate(draw);
</script>
<div class="film" bind:this={box} style="max-height:{height}px"><canvas bind:this={canvas} style="width:100%"></canvas></div>
<style>
  .film { overflow-y: auto; border-radius: 14px; border: 1px solid var(--accent-line); background: #0B0C0F; }
  canvas { display: block; }
</style>
