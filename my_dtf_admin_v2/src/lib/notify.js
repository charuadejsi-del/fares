// Notifications système (Windows / navigateur) pour l'administration — seulement quand la fenêtre n'est pas au premier plan.
export function askNotify() { try { if ('Notification' in window && Notification.permission === 'default') Notification.requestPermission(); } catch (_) {} }
export function notify(title, body, tag) {
  try {
    if (!('Notification' in window) || Notification.permission !== 'granted') return;
    if (document.visibilityState === 'visible' && document.hasFocus()) return;
    const n = new Notification(title, { body: body || '', tag, icon: '/icon-192.png', lang: 'ar', dir: 'rtl' });
    n.onclick = () => { window.focus(); n.close(); };
  } catch (_) {}
}
