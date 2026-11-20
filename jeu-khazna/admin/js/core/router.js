// موجّه بسيط بالـ hash: #/players/<id> ← { name: 'players', param: '<id>' }
const listeners = new Set();

export function current() {
  const [, name = 'dashboard', param = null] = (location.hash || '#/dashboard').split('/');
  return { name, param: param && decodeURIComponent(param) };
}

export const go = (name, param) => {
  const h = `#/${name}${param ? `/${encodeURIComponent(param)}` : ''}`;
  if (location.hash === h) listeners.forEach((fn) => fn(current()));
  else location.hash = h;
};

export function onRoute(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

addEventListener('hashchange', () => listeners.forEach((fn) => fn(current())));
