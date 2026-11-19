// net.js — قناة الاتصال بين اللاعبين
// • أونلاين: Supabase Realtime (إذا مُلئ config.js)
// • تجربة محلية: BroadcastChannel (تبويبان في نفس المتصفح)

export async function connect(room, onMessage) {
  const cfg = window.KHAZNA_CONFIG || {};
  const name = 'khazna-' + room;

  if (cfg.supabaseUrl && cfg.supabaseAnonKey) {
    const { createClient } = await import('https://esm.sh/@supabase/supabase-js@2');
    const client = createClient(cfg.supabaseUrl, cfg.supabaseAnonKey);
    const ch = client.channel(name, { config: { broadcast: { self: false } } });
    ch.on('broadcast', { event: 'msg' }, ({ payload }) => onMessage(payload));
    await new Promise((resolve, reject) => {
      ch.subscribe(status => {
        if (status === 'SUBSCRIBED') resolve();
        else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') reject(new Error(status));
      });
    });
    return {
      mode: 'online',
      send: msg => ch.send({ type: 'broadcast', event: 'msg', payload: msg }),
      close: () => client.removeChannel(ch),
    };
  }

  const bc = new BroadcastChannel(name);
  bc.onmessage = e => onMessage(e.data);
  return { mode: 'local', send: msg => bc.postMessage(msg), close: () => bc.close() };
}
