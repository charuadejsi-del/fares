// يتحقّق أن قنوات Supabase Realtime تعمل: عميلان على نفس القناة، الأول يرسل والثاني يستقبل.
import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'node:fs';

const src = readFileSync(process.env.GITHUB_WORKSPACE + '/jeu-khazna/app_flutter/lib/net/transport.dart', 'utf8');
const url = src.match(/'SUPABASE_URL', defaultValue: '([^']+)'/)[1];
const key = src.match(/defaultValue: '(eyJ[^']+)'/)[1];
const room = 'khazna-ci-' + Date.now();

const sub = (client) => new Promise((res, rej) => {
  const ch = client.channel(room, { config: { broadcast: { self: false } } });
  const t = setTimeout(() => rej(new Error('subscribe timeout')), 15000);
  ch.subscribe((st) => { if (st === 'SUBSCRIBED') { clearTimeout(t); res(ch); } else if (st !== 'CLOSED') console.log('status', st); });
  return ch;
});

const a = createClient(url, key), b = createClient(url, key);
const chB = b.channel(room, { config: { broadcast: { self: false } } });
const got = new Promise((res, rej) => {
  const t = setTimeout(() => rej(new Error('no message received')), 15000);
  chB.on('broadcast', { event: 'msg' }, ({ payload }) => { clearTimeout(t); res(payload); });
});
await new Promise((res, rej) => chB.subscribe((st) => st === 'SUBSCRIBED' ? res() : (st === 'CHANNEL_ERROR' || st === 'TIMED_OUT') && rej(new Error(st))));
const chA = await sub(a);
await chA.send({ type: 'broadcast', event: 'msg', payload: { kind: 'hello', id: 'ci', name: 'test' } });
const p = await got;
console.log('✓ Realtime OK', JSON.stringify(p));
process.exit(0);
