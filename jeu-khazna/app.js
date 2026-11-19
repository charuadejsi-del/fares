// app.js — واجهة لعبة «الخزنة»
// المضيف (منشئ الغرفة) هو المرجع: يطبّق الأفعال ويبثّ الحالة. الضيف يرسل أفعاله فقط.
import * as G from './core.js';
import { connect } from './net.js';

const app = document.getElementById('app');
const flashEl = document.getElementById('flash');
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); } catch { /* تخزين غير متاح */ } },
};

const me = { id: Math.random().toString(36).slice(2, 10), name: store.get('khazna-name') || '' };
const ROLE = { op: 'المشغّل', ex: 'الخبير' };
const ROLE_DESC = {
  op: 'أمام الخزنة: ترى الأقفال، لكن بلا دليل',
  ex: 'معك الدليل: تعرف الحلول، لكن لا ترى الأقفال',
};

let net = null, isHost = false, code = '', state = null, P = null, players = {};
let recv = { rem: G.DURATION, at: 0 }, seenKey = '', entry = '', decSym = -1, error = '', lastRenderKey = '';
let helloTimer = null, hostTimer = null, lastBroadcast = 0, playToken = 0;

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = sec => { sec = Math.max(0, Math.ceil(sec)); return `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`; };
const myRole = () => players[me.id]?.role;
const newSeed = () => Math.floor(Math.random() * 2 ** 31);
const online = () => { const c = window.KHAZNA_CONFIG || {}; return !!(c.supabaseUrl && c.supabaseAnonKey); };

// ───────── الاتصال ─────────
async function enter(asHost, roomCode) {
  const input = document.getElementById('name');
  me.name = ((input ? input.value : me.name) || '').trim().slice(0, 20) || 'لاعب';
  store.set('khazna-name', me.name);
  isHost = asHost; code = roomCode; error = '';
  try { net = await connect(code, onMessage); }
  catch (e) { net = null; error = 'تعذّر الاتصال: ' + e.message; render(true); return; }
  if (isHost) {
    state = G.newState(newSeed()); P = G.generate(state.seed);
    players = { [me.id]: { name: me.name, role: 'op' } };
    hostTimer = setInterval(hostLoop, 1000);
    broadcast();
  } else {
    sendHello(); helloTimer = setInterval(sendHello, 1500);
  }
  render(true);
}

function leave() {
  clearInterval(helloTimer); clearInterval(hostTimer);
  helloTimer = hostTimer = null;
  try { net?.close(); } catch { /* تجاهل */ }
  net = null; state = null; P = null; players = {}; isHost = false; code = ''; entry = '';
  render(true);
}

const sendHello = () => net?.send({ kind: 'hello', id: me.id, name: me.name });

function broadcast() {
  if (!isHost || !net) return;
  lastBroadcast = Date.now();
  net.send({ kind: 'state', state, players, rem: G.remaining(state, Date.now()) });
}

function hostLoop() {
  const t = G.tick(state, Date.now());
  if (t !== state) { state = t; broadcast(); render(); return; }
  if (Date.now() - lastBroadcast > 2000) broadcast(); // للمتأخرين ولمزامنة المؤقّت
}

function onMessage(m) {
  if (!m || typeof m !== 'object') return;
  if (isHost) {
    if (m.kind === 'hello' && typeof m.id === 'string') {
      if (!players[m.id]) {
        if (Object.keys(players).length >= 2) return; // الغرفة ممتلئة
        const hostRole = players[me.id].role;
        players[m.id] = { name: String(m.name || 'لاعب').slice(0, 20), role: hostRole === 'op' ? 'ex' : 'op' };
        render();
      }
      broadcast();
    } else if (m.kind === 'action' && players[m.id]) {
      doAction(m.action);
    }
    return;
  }
  if (m.kind !== 'state' || !m.state || !m.players) return;
  if (!m.players[me.id]) {
    if (Object.keys(m.players).length >= 2) { leave(); error = 'الغرفة ممتلئة.'; render(true); }
    return; // ننتظر أن يضيفنا المضيف
  }
  if (helloTimer) { clearInterval(helloTimer); helloTimer = null; }
  if (!P || state?.seed !== m.state.seed) P = G.generate(m.state.seed);
  state = m.state; players = m.players; recv = { rem: m.rem, at: Date.now() };
  render();
}

// ───────── الأفعال ─────────
function dispatch(action) {
  if (isHost) doAction(action);
  else net?.send({ kind: 'action', id: me.id, action });
}
function doAction(action) {
  const ns = G.apply(state, P, action, Date.now());
  if (ns !== state) { state = ns; broadcast(); render(); }
}
function hostStart() {
  if (Object.keys(players).length < 2) return;
  state = G.start(state, P, Date.now()); broadcast(); render();
}
function swapRoles() {
  for (const id in players) players[id].role = players[id].role === 'op' ? 'ex' : 'op';
  broadcast(); render();
}
function newGame() {
  state = G.newState(newSeed()); P = G.generate(state.seed); broadcast(); render();
}

// ───────── المؤقّت والتنبيهات ─────────
function remainingNow() {
  if (!state) return G.DURATION;
  if (state.phase !== 'playing') return state.phase === 'lobby' ? G.DURATION : 0;
  return isHost ? G.remaining(state, Date.now()) : Math.max(0, recv.rem - (Date.now() - recv.at) / 1000);
}
setInterval(() => {
  const el = document.getElementById('timer');
  if (!el) return;
  const r = remainingNow();
  el.textContent = fmt(r);
  el.classList.toggle('warn', r < 60);
}, 250);

function flash(kind, msg) {
  flashEl.textContent = msg;
  flashEl.className = 'show ' + kind;
  clearTimeout(flash.t);
  flash.t = setTimeout(() => { flashEl.className = ''; }, 1300);
}
const vibrate = p => { try { navigator.vibrate?.(p); } catch { /* غير مدعوم */ } };

function handleEvent() {
  if (!state?.lastEvent) return;
  const key = state.seed + ':' + state.eventId;
  if (key === seenKey) return;
  seenKey = key;
  const { type, pen } = state.lastEvent;
  if (type === 'wrong') { flash('bad', `❌ خطأ! −${pen} ثانية`); vibrate(250); }
  else if (type === 'bump') { flash('bad', `💥 اصطدمت بجدار! −${pen} ثوانٍ`); vibrate(150); }
  else if (type === 'solved' && state.phase === 'playing') { flash('good', '✅ فُتح القفل!'); vibrate([60, 40, 60]); }
  else if (type === 'stage') flash('good', '✨ المرحلة التالية');
  if (type === 'solved' || type === 'start') { entry = ''; decSym = -1; }
  if (G.ROOMS[state.room] === 'lights' && (type === 'stage' || type === 'solved' || type === 'start')) setTimeout(playLights, 500);
}

function playLights() {
  if (myRole() !== 'op' || state?.phase !== 'playing' || G.ROOMS[state.room] !== 'lights') return;
  const tok = ++playToken;
  const seq = P.lights.seq.slice(0, state.lightStage + 1);
  let i = 0;
  const step = () => {
    const lamp = document.getElementById('lamp');
    if (!lamp || tok !== playToken) return;
    if (i >= seq.length * 2) { lamp.style.background = ''; return; }
    lamp.style.background = i % 2 === 0 ? G.LIGHTS[seq[i / 2]].c : '';
    i++;
    setTimeout(step, i % 2 ? 750 : 300);
  };
  step();
}

// ───────── العرض ─────────
function render(force = false) {
  const key = JSON.stringify([!!net, error, state, players, entry]);
  if (!force && key === lastRenderKey) return;
  lastRenderKey = key;
  // حفظ ما يكتبه اللاعب حتى لا يضيع عند تحديث الشاشة
  const ans = document.getElementById('answer');
  const kept = ans ? { v: ans.value, f: document.activeElement === ans } : null;

  if (!net) app.innerHTML = homeView();
  else if (!state || !players[me.id] || state.phase === 'lobby') app.innerHTML = lobbyView();
  else if (state.phase === 'playing') app.innerHTML = gameView();
  else app.innerHTML = endView();

  const ans2 = document.getElementById('answer');
  if (ans2 && kept) { ans2.value = kept.v; if (kept.f) ans2.focus(); }
  handleEvent();
}

function homeView() {
  return `
  <section class="card hero">
    <div class="logo">🔐</div>
    <h1>الخزنة</h1>
    <p class="sub">ألغاز جماعية: لا أحد يستطيع حلّها وحده</p>
    <label class="field">اسمك<input id="name" maxlength="20" autocomplete="nickname" value="${esc(me.name)}" placeholder="مثلاً: فارس"></label>
    <button class="primary big" data-act="create">إنشاء غرفة</button>
    <form class="row" data-form="join">
      <input id="code" inputmode="numeric" pattern="[0-9]{4}" maxlength="4" placeholder="رمز الغرفة (4 أرقام)" dir="ltr">
      <button>دخول</button>
    </form>
    ${error ? `<p class="error">${esc(error)}</p>` : ''}
    <p class="hint">${online()
      ? '🌐 وضع أونلاين: العب مع صديقك من هاتف آخر.'
      : '🧪 وضع التجربة المحلية: افتح اللعبة في تبويبين من نفس المتصفح (للعب بين هاتفين اضبط config.js).'}</p>
  </section>
  <section class="card how">
    <h2>كيف تُلعب؟</h2>
    <p><b>${ROLE.op}</b>: ${ROLE_DESC.op}.</p>
    <p><b>${ROLE.ex}</b>: ${ROLE_DESC.ex}.</p>
    <p>تكلّما معاً (مكالمة أو في نفس الغرفة) وافتحا 5 أقفال قبل أن تنتهي 10 دقائق. كل خطأ يكلّفكما ${G.PENALTY} ثانية.</p>
  </section>`;
}

function lobbyView() {
  const list = Object.entries(players);
  const ready = list.length >= 2;
  return `
  <section class="card">
    <p class="muted">رمز الغرفة</p>
    <div class="room-code" dir="ltr">${esc(code)}</div>
    <p class="muted small">أرسل هذا الرمز لصديقك</p>
    <ul class="players">
      ${list.length && players[me.id] ? list.map(([id, p]) => `
        <li><span class="role ${p.role}">${ROLE[p.role]}</span> ${esc(p.name)} ${id === me.id ? '<em>(أنت)</em>' : ''}
          <small>${ROLE_DESC[p.role]}</small></li>`).join('') : '<li class="muted">جاري الاتصال بالمضيف…</li>'}
      ${list.length === 1 ? '<li class="muted">في انتظار اللاعب الثاني…</li>' : ''}
    </ul>
    ${isHost ? `
      <button data-act="swap" class="ghost">🔄 تبديل الأدوار</button>
      <button data-act="start" class="primary big" ${ready ? '' : 'disabled'}>ابدأ اللعبة</button>`
    : `<p class="muted">المضيف هو من يبدأ اللعبة.</p>`}
    <button data-act="leave" class="link">خروج</button>
  </section>`;
}

function gameView() {
  const room = G.ROOMS[state.room], role = myRole();
  const dots = G.ROOMS.map((r, i) => `<i class="${i < state.room ? 'done' : i === state.room ? 'now' : ''}" title="${G.ROOM_NAMES[r]}"></i>`).join('');
  const views = {
    keypad: [keypadOp, keypadEx], wires: [wiresOp, wiresEx], cipher: [cipherOp, cipherEx],
    maze: [mazeOp, mazeEx], lights: [lightsOp, lightsEx],
  };
  const body = views[room][role === 'op' ? 0 : 1]();
  return `
  <header class="hud">
    <span class="role ${role}">${ROLE[role]}</span>
    <div class="dots">${dots}</div>
    <span id="timer" class="timer" dir="ltr">${fmt(remainingNow())}</span>
  </header>
  <section class="card puzzle">
    <h2>${state.room + 1}. ${G.ROOM_NAMES[room]}</h2>
    ${body}
  </section>`;
}

// الغرفة 1
function keypadOp() {
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✔'];
  return `
  <p class="lead">صِف هذه الرموز للخبير بالترتيب (من اليسار إلى اليمين)، ثم أدخل الرمز الذي يعطيك إياه.</p>
  <div class="symbols" dir="ltr">${P.keypad.shown.map(i => `<span>${G.SYMBOLS[i].s}</span>`).join('')}</div>
  <div class="display" dir="ltr">${esc(entry.padEnd(4, '·'))}</div>
  <div class="pad" dir="ltr">${keys.map(k => `<button data-act="key" data-k="${k}" class="${k === '✔' ? 'primary' : ''}">${k}</button>`).join('')}</div>`;
}
function keypadEx() {
  return `
  <p class="lead">المشغّل سيصف لك 4 رموز. أعطه الرقم المقابل لكل رمز، بنفس الترتيب.</p>
  <div class="manual-grid">${G.SYMBOLS.map((sy, i) => `<div><b>${sy.s}</b><small>${sy.n}</small><em>${P.keypad.manual[i]}</em></div>`).join('')}</div>`;
}

// الغرفة 2
function wiresOp() {
  return `
  <p class="lead">صِف للخبير عدد الأسلاك وألوانها من الأعلى إلى الأسفل، ثم اقطع السلك الذي يحدّده.</p>
  <div class="wires">${P.wires.wires.map((c, i) => {
    const cut = state.cut.includes(i);
    return `<div class="wire ${cut ? 'cut' : ''}"><span class="num">${i + 1}</span>
      <span class="bar" style="--c:${G.COLORS[c].c}"></span>
      <button data-act="cut" data-i="${i}" ${cut ? 'disabled' : ''}>${cut ? 'مقطوع' : '✂️ اقطع'}</button></div>`;
  }).join('')}</div>`;
}
function wiresEx() {
  return `
  <p class="lead">اسأل المشغّل عن عدد الأسلاك وألوانها. السلك رقم 1 هو الأعلى. طبّق <b>أوّل</b> قاعدة صحيحة فقط.</p>
  ${[3, 4, 5, 6].map(n => `<div class="rules"><h3>إذا كان هناك ${n} أسلاك</h3>
    <ol>${P.wires.rules[n].map(r => `<li>${G.ruleText(r)}</li>`).join('')}</ol></div>`).join('')}`;
}

// الغرفة 3
function cipherOp() {
  return `
  <p class="lead">صِف الرمز للخبير، ثم اقرأ له الحروف المشفّرة واحداً واحداً من اليمين إلى اليسار. هو يقول لك الحرف الأصلي لكل واحد.</p>
  <div class="big-symbol">${G.SYMBOLS[P.cipher.sym].s}</div>
  <div class="cipher">${[...P.cipher.cipher].map(c => `<span>${c}</span>`).join('')}</div>
  <form class="row" data-form="cipher">
    <input id="answer" autocomplete="off" placeholder="الكلمة بعد فكّ الشيفرة">
    <button class="primary">تحقّق</button>
  </form>`;
}
function cipherEx() {
  const k = decSym >= 0 ? P.cipher.manual[decSym] : 0;
  return `
  <p class="lead">1) اسأل المشغّل عن الرمز، واضغط عليه هنا. 2) سيظهر لك جدول الفكّ. 3) المشغّل يقرأ لك الحروف، وأنت تقول له الحرف الأصلي لكل واحد.</p>
  <div class="manual-grid pick">${G.SYMBOLS.map((sy, i) => `<button data-act="decsym" data-i="${i}" class="${decSym === i ? 'on' : ''}"><b>${sy.s}</b><small>${sy.n}</small></button>`).join('')}</div>
  ${decSym < 0 ? '<p class="muted">اختر الرمز لترى جدول الفكّ.</p>' : `
  <h3>جدول الفكّ للرمز ${G.SYMBOLS[decSym].s} (${G.SYMBOLS[decSym].n})</h3>
  <p class="muted small">ابحث عن الحرف الذي يقرؤه المشغّل في الأعلى، والحرف الأصلي هو الذي تحته.</p>
  <div class="decoder">${G.ALPHABET.map((ch, i) => `<span><b>${ch}</b><i>↓</i><em>${G.ALPHABET[(i - k + G.ALPHABET.length) % G.ALPHABET.length]}</em></span>`).join('')}</div>`}`;
}

// الغرفة 4
function mazeOp() {
  return `
  <p class="lead">أنت في ظلام دامس 🔦. الخبير يرى الخريطة ومكانك. اتبع توجيهاته. كل اصطدام بجدار يكلّف ${G.BUMP} ثوانٍ.</p>
  <div class="arrows" dir="ltr">
    <button data-act="move" data-d="up" class="up">▲<small>فوق</small></button>
    <button data-act="move" data-d="left" class="left">◀<small>يسار</small></button>
    <button data-act="move" data-d="right" class="right">▶<small>يمين</small></button>
    <button data-act="move" data-d="down" class="down">▼<small>تحت</small></button>
  </div>`;
}
function mazeEx() {
  const { N, open, exit } = P.maze;
  const cells = open.map((o, i) => {
    const cls = [o.up ? '' : 'wt', o.down ? '' : 'wb', o.left ? '' : 'wl', o.right ? '' : 'wr'].join(' ');
    return `<div class="${cls}">${i === state.mazePos ? '🔦' : i === exit ? '🚪' : ''}</div>`;
  }).join('');
  return `
  <p class="lead">وجّه المشغّل (🔦) إلى الباب (🚪). الاتجاهات كما تظهر على شاشتك: فوق، تحت، يمين، يسار.</p>
  <div class="maze" dir="ltr" style="--n:${N}">${cells}</div>`;
}

// الغرفة 5
function lightsOp() {
  const expected = G.lightsExpected(P, state.lightStage);
  return `
  <p class="lead">المرحلة ${state.lightStage + 1} من 3. شاهد الأضواء وصِفها للخبير، ثم اضغط الأزرار التي يحدّدها بالترتيب.</p>
  <div id="lamp" class="lamp"></div>
  <button data-act="replay" class="ghost">🔁 أعد عرض الأضواء</button>
  <div class="progress">${expected.map((_, i) => `<i class="${i < state.lightInput.length ? 'on' : ''}"></i>`).join('')}</div>
  <div class="lights">${G.LIGHTS.map((l, i) => `<button data-act="press" data-c="${i}" style="--c:${l.c}">${l.n}</button>`).join('')}</div>`;
}
function lightsEx() {
  return `
  <p class="lead">المشغّل يرى أضواء تومض. حوّل كل ضوء حسب جدول المرحلة الحالية. في المرحلة 2 يومض ضوءان وفي المرحلة 3 ثلاثة: يضغط المشغّل على الكل بالترتيب.</p>
  ${[0, 1, 2].map(st => `<div class="rules ${st === state.lightStage ? 'current' : ''}">
    <h3>المرحلة ${st + 1}${st === state.lightStage ? ' ← الآن' : ''}</h3>
    <ul>${G.LIGHTS.map((l, c) => { const t = G.LIGHTS[P.lights.maps[st][c]];
      return `<li><span class="dot" style="--c:${l.c}"></span>إذا ومض ${l.n} ← اضغط <b style="color:${t.c}">${t.n}</b></li>`; }).join('')}</ul>
  </div>`).join('')}`;
}

function endView() {
  const won = state.phase === 'won';
  return `
  <section class="card hero end ${won ? 'won' : 'lost'}">
    <div class="logo">${won ? '🎉' : '⏰'}</div>
    <h1>${won ? 'فُتحت الخزنة!' : 'انتهى الوقت…'}</h1>
    <p class="sub">${won
      ? `في <b dir="ltr">${fmt(state.finishedIn)}</b>، منها <b>${Math.round(state.penalty)}</b> ثانية عقوبات.`
      : `وصلتما إلى: <b>${G.ROOM_NAMES[G.ROOMS[Math.min(state.room, G.ROOMS.length - 1)]]}</b>`}</p>
    ${isHost ? '<button data-act="again" class="primary big">لعبة جديدة</button>' : '<p class="muted">المضيف يستطيع بدء لعبة جديدة.</p>'}
    <button data-act="leave" class="link">خروج</button>
  </section>`;
}

// ───────── الأحداث ─────────
app.addEventListener('click', e => {
  const b = e.target.closest('[data-act]');
  if (!b || b.disabled) return;
  switch (b.dataset.act) {
    case 'create': enter(true, String(1000 + Math.floor(Math.random() * 9000))); break;
    case 'start': hostStart(); break;
    case 'swap': swapRoles(); break;
    case 'again': newGame(); break;
    case 'leave': leave(); break;
    case 'key': {
      const k = b.dataset.k;
      if (k === '⌫') entry = entry.slice(0, -1);
      else if (k === '✔') { if (entry.length === 4) { dispatch({ type: 'submit', value: entry }); entry = ''; } }
      else if (entry.length < 4) entry += k;
      render();
      break;
    }
    case 'cut': {
      const i = Number(b.dataset.i);
      if (confirm(`قطع السلك رقم ${i + 1}؟`)) dispatch({ type: 'cut', idx: i });
      break;
    }
    case 'move': dispatch({ type: 'move', dir: b.dataset.d }); break;
    case 'press': dispatch({ type: 'press', color: Number(b.dataset.c) }); break;
    case 'replay': playLights(); break;
    case 'decsym': decSym = Number(b.dataset.i); render(true); break;
  }
});

app.addEventListener('submit', e => {
  e.preventDefault();
  const form = e.target.dataset.form;
  if (form === 'join') {
    const c = (document.getElementById('code').value || '').trim();
    if (!/^\d{4}$/.test(c)) { error = 'أدخل رمزاً من 4 أرقام.'; render(true); return; }
    enter(false, c);
  } else if (form === 'cipher') {
    const input = document.getElementById('answer');
    if (input.value.trim()) { dispatch({ type: 'submit', value: input.value }); input.value = ''; }
  }
});

render(true);
