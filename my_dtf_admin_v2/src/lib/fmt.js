// Toutes les valeurs numériques sont isolées (gauche→droite) : elles ne s'inversent jamais dans le texte arabe.
const L = '⁦', R = '⁩';
export const ltr = s => L + s + R;
const group = n => String(Math.round(Math.abs(+n || 0))).replace(/\B(?=(\d{3})+(?!\d))/g, '\u202F');
export const da = v => ltr((v < 0 ? '-' : '') + group(v)) + ' دج';
export const m = (v, d = 2) => ltr((+v || 0).toFixed(d)) + ' م';
export const cm = v => ltr(String(+(+v || 0).toFixed(1))) + ' سم';
export const size = (w, h) => ltr(`${+w} × ${+h}`) + ' سم';
export const num = v => ltr(String(v ?? 0));
export const pct = v => ltr(Math.round(v) + '%');
const pad = x => String(x).padStart(2, '0');
export const time = iso => { if (!iso) return '—'; const d = new Date(iso); return ltr(`${pad(d.getHours())}:${pad(d.getMinutes())}`); };
export const date = iso => { if (!iso) return '—'; const d = new Date(iso); return ltr(`${pad(d.getDate())}/${pad(d.getMonth() + 1)}`); };
export const dt = iso => { if (!iso) return '—'; const d = new Date(iso); return ltr(`${pad(d.getDate())}/${pad(d.getMonth() + 1)} ${pad(d.getHours())}:${pad(d.getMinutes())}`); };
export const minsSince = iso => (Date.now() - new Date(iso)) / 60000;
export const dur = mn => mn < 60 ? ltr(String(Math.max(0, Math.round(mn)))) + ' د' : mn < 1440 ? ltr((mn / 60).toFixed(1)) + ' سا' : ltr((mn / 1440).toFixed(1)) + ' يوم';
export const ymd = d => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

export const ROLE = { admin: 'المدير', manager: 'المسيّر', designer: 'المصمّم', printer: 'الطابع', client: 'زبون' };
export const STATUS = {
  new: ['جديدة', 'blue'], in_design: ['في التصميم', 'violet'], ready_to_print: ['جاهزة للطباعة', 'amber'],
  printing: ['قيد الطباعة', 'orange'], printed: ['مطبوعة', 'teal'], ready_pickup: ['جاهزة للاستلام', 'teal'],
  shipped: ['عند شركة التوصيل', 'indigo'], delivered: ['مُسلَّمة', 'green'], rejected: ['مرفوضة', 'red'], cancelled: ['ملغاة', 'red'],
};
export const MODE = { pickup: 'استلام من الورشة', home: 'توصيل إلى المنزل', stopdesk: 'مكتب شركة التوصيل' };
export const clock = mn => { const t = Math.max(0, Math.floor(mn * 60)); const h = Math.floor(t / 3600), x = Math.floor((t % 3600) / 60), s = t % 60;
  return ltr(h ? `${h}:${pad(x)}:${pad(s)}` : `${pad(x)}:${pad(s)}`); };
export const ACT = {
  new: 'أرسل طلبية جديدة', in_design: 'حوّل إلى التصميم', ready_to_print: 'أنهى التصميم', printing: 'بدأ الطباعة',
  printed: 'أنهى الطباعة', ready_pickup: 'أنهى الطباعة — جاهزة للاستلام', shipped: 'سلّم لشركة التوصيل', delivered: 'سلّم للزبون',
  rejected: 'رفض', cancelled: 'ألغى', open: 'فتح الورشة', closed: 'أغلق الورشة', idle: 'الآلة جاهزة', running: 'الآلة تطبع', maintenance: 'صيانة', down: 'عطل',
};
