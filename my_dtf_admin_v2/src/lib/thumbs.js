// Miniatures des commandes (une requête + une signature groupée).
import { sb, q, signedUrls } from './sb.js';
const cache = new Map();
export async function orderThumbs(ids) {
  const need = ids.filter(id => !cache.has(id));
  if (need.length) {
    const imgs = await q(sb.from('dtf_order_images').select('order_id,storage_path,thumb_path,width_cm,height_cm,quantity').in('order_id', need));
    const urls = await signedUrls(imgs.map(i => i.thumb_path || i.storage_path));
    need.forEach(id => cache.set(id, imgs.filter(i => i.order_id === id).map(i => ({ ...i, url: urls[i.thumb_path || i.storage_path] }))));
  }
  return Object.fromEntries(ids.map(id => [id, cache.get(id) || []]));
}
