import './app.css';
import App from './App.svelte';
import { installRipple } from './lib/motion.js';
installRipple();

const app = new App({ target: document.getElementById('app') });

if ('serviceWorker' in navigator && import.meta.env.PROD) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
}
export default app;
