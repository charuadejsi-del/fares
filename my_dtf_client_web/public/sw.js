// My DTF — service worker : coquille de l'app en cache, données toujours en direct.
const CACHE = 'mydtf-client-v7';
self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin || u.pathname === '/__time') return; // Supabase, polices, heure : réseau direct
  if (u.pathname.startsWith('/assets/')) {
    // fichiers versionnés : cache d'abord
    e.respondWith(caches.open(CACHE).then(async c => (await c.match(e.request)) || fetch(e.request).then(r => { if (r.ok) c.put(e.request, r.clone()); return r; })));
    return;
  }
  // page : réseau d'abord, cache si hors ligne
  e.respondWith(fetch(e.request).then(r => { const cl = r.clone(); caches.open(CACHE).then(c => c.put(e.request, cl)); return r; }).catch(() => caches.match(e.request).then(r => r || caches.match('/'))));
});
