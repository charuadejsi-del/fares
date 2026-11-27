import './app.css';
import { installRipple } from './lib/motion.js';

// Horloge de l'appareil décalée → la session paraît expirée en boucle (déconnexions, « rate limit »).
// On aligne l'heure de l'application sur celle du serveur avant de démarrer Supabase.
async function syncClock() {
  try {
    const t0 = performance.now();
    const r = await fetch('/__time', { cache: 'no-store' });
    const { t } = await r.json();
    const off = t + (performance.now() - t0) / 2 - Date.now();
    window.__clockOffset = off;
    if (Math.abs(off) > 30000) {
      const realNow = Date.now.bind(Date);
      Date.now = () => realNow() + off;
      const RealDate = Date;
      // new Date() sans argument suit aussi l'heure corrigée.
      // eslint-disable-next-line no-global-assign
      Date = new Proxy(RealDate, { construct: (D, args) => (args.length ? new D(...args) : new D(D.now())) });
    }
  } catch (_) {}
}

installRipple();
syncClock().then(async () => {
  const { default: App } = await import('./App.svelte');
  new App({ target: document.getElementById('app') });
});

if ('serviceWorker' in navigator && import.meta.env.PROD) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
}
