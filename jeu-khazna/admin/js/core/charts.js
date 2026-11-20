// رسوم Chart.js بنفس هوية التصميم. كل رسم يُسجَّل ليُحذف عند مغادرة الصفحة.
let live = [];

export function disposeCharts() {
  live.forEach((c) => c.destroy());
  live = [];
}

const tooltip = {
  backgroundColor: 'rgba(10,17,18,.96)',
  borderColor: 'rgba(0,255,163,.3)',
  borderWidth: 1,
  padding: 10,
  cornerRadius: 10,
  titleFont: { weight: '600' },
  rtl: true,
  displayColors: false,
};

function ready() {
  const C = window.Chart;
  if (!C) return null;
  C.defaults.color = '#66807a';
  C.defaults.font.family = "'IBM Plex Sans Arabic', sans-serif";
  C.defaults.borderColor = 'rgba(255,255,255,.05)';
  return C;
}

function gradient(ctx, color) {
  const g = ctx.createLinearGradient(0, 0, 0, ctx.canvas.clientHeight || 260);
  g.addColorStop(0, color + '55');
  g.addColorStop(1, color + '00');
  return g;
}

export function lineChart(canvas, labels, data, color, { spark = false, bar = false, unit = '' } = {}) {
  const C = ready();
  if (!C || !canvas) return;
  const ctx = canvas.getContext('2d');
  live.push(
    new C(ctx, {
      type: bar ? 'bar' : 'line',
      data: {
        labels,
        datasets: [{
          data, borderColor: color, backgroundColor: bar ? color + 'b0' : gradient(ctx, color),
          fill: !bar, tension: 0.4, borderWidth: spark ? 2 : 2.5, pointRadius: spark ? 0 : 0,
          pointHoverRadius: 5, pointBackgroundColor: color, borderRadius: 6, maxBarThickness: 22,
        }],
      },
      options: {
        responsive: true, maintainAspectRatio: false, animation: { duration: 700 },
        interaction: { intersect: false, mode: 'index' },
        plugins: {
          legend: { display: false },
          tooltip: spark ? { enabled: false } : { ...tooltip, callbacks: { label: (c) => `${c.formattedValue}${unit}` } },
        },
        scales: spark
          ? { x: { display: false }, y: { display: false, beginAtZero: true } }
          : { x: { grid: { display: false }, ticks: { maxRotation: 0, autoSkipPadding: 12 } }, y: { beginAtZero: true, ticks: { precision: 0 }, border: { display: false } } },
      },
    }),
  );
}

export function ringChart(canvas, labels, data, colors) {
  const C = ready();
  if (!C || !canvas) return;
  live.push(
    new C(canvas, {
      type: 'doughnut',
      data: { labels, datasets: [{ data, backgroundColor: colors, borderWidth: 0, hoverOffset: 6 }] },
      options: { cutout: '74%', responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false }, tooltip } },
    }),
  );
}

export function stackedBars(canvas, labels, sets) {
  const C = ready();
  if (!C || !canvas) return;
  live.push(
    new C(canvas, {
      type: 'bar',
      data: { labels, datasets: sets.map((s) => ({ ...s, borderRadius: 6, maxBarThickness: 18 })) },
      options: {
        indexAxis: 'y', responsive: true, maintainAspectRatio: false,
        plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, boxHeight: 10 } }, tooltip },
        scales: { x: { stacked: true, beginAtZero: true, ticks: { precision: 0 } }, y: { stacked: true, grid: { display: false } } },
      },
    }),
  );
}
