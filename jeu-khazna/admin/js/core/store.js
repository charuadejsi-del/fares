// حالة مشتركة صغيرة مع اشتراكات (بلا إطار عمل).
const state = {
  me: null, // { id, nickname, email }
  pending: [], // طلبات الدفع المعلّقة (للجرس والشارات)
};
const subs = new Set();

export const store = {
  get: () => state,
  set(patch) {
    Object.assign(state, patch);
    subs.forEach((fn) => fn(state));
  },
  subscribe(fn) {
    subs.add(fn);
    return () => subs.delete(fn);
  },
};
