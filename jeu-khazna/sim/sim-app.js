// sim-app.js — محاكي «الخزنة»: الشاشتان (المشغّل والخبير) على نفس الجهاز، بلا اتصال.
// يُدمج مع core.js في ملف واحد بواسطة tools/build-sim.mjs
/* global DURATION, PENALTY, BUMP, ROOMS, ROOM_NAMES, SYMBOLS, COLORS, LIGHTS, ALPHABET,
   generate, newState, start, apply, tick, remaining, ruleText, lightsExpected */

const app = document.getElementById('app');
const flashEl = document.getElementById('flash');
let state = null, P = null, entry = '', seenKey = '', playToken = 0, view = 'op', armedCut = -1;

const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = sec => { sec = Math.max(0, Math.ceil(sec)); return `${String(Math.floor(sec / 60)).padStart(2, '0')}:${String(sec % 60).padStart(2, '0')}`; };

function newGame() {
  const seed = Math.floor(Math.random() * 2 ** 31);
  P = generate(seed);
  state = start(newState(seed), P, Date.now());
  entry = ''; armedCut = -1;
  render();
}
function dispatch(action) {
  const ns = apply(state, P, action, Date.now());
  if (ns !== state) { state = ns; render(); }
}

setInterval(() => {
  if (!state) return;
  const t = tick(state, Date.now());
  if (t !== state) { state = t; render(); return; }
  const el = document.getElementById('timer');
  if (el && state.phase === 'playing') {
    const r = remaining(state, Date.now());
    el.textContent = fmt(r);
    el.classList.toggle('warn', r < 60);
  }
}, 250);

function flash(kind, msg) {
  flashEl.textContent = msg;
  flashEl.className = 'show ' + kind;
  clearTimeout(flash.t);
  flash.t = setTimeout(() => { flashEl.className = ''; }, 1300);
}

function handleEvent() {
  if (!state?.lastEvent) return;
  const key = state.seed + ':' + state.eventId;
  if (key === seenKey) return;
  seenKey = key;
  const { type, pen } = state.lastEvent;
  if (type === 'wrong') flash('bad', `❌ خطأ! −${pen} ثانية`);
  else if (type === 'bump') flash('bad', `💥 اصطدمت بجدار! −${pen} ثوانٍ`);
  else if (type === 'solved' && state.phase === 'playing') flash('good', '✅ فُتح القفل!');
  else if (type === 'stage') flash('good', '✨ المرحلة التالية');
  if (type === 'solved' || type === 'start') { entry = ''; armedCut = -1; }
  if (ROOMS[state.room] === 'lights' && (type === 'stage' || type === 'solved' || type === 'start')) setTimeout(playLights, 500);
}

function playLights() {
  if (state?.phase !== 'playing' || ROOMS[state.room] !== 'lights') return;
  const tok = ++playToken;
  const seq = P.lights.seq.slice(0, state.lightStage + 1);
  let i = 0;
  const step = () => {
    const lamp = document.getElementById('lamp');
    if (!lamp || tok !== playToken) return;
    if (i >= seq.length * 2) { lamp.style.background = ''; return; }
    lamp.style.background = i % 2 === 0 ? LIGHTS[seq[i / 2]].c : '';
    i++;
    setTimeout(step, i % 2 ? 750 : 300);
  };
  step();
}

// ───────── العرض ─────────
function render() {
  const ans = document.getElementById('answer');
  const kept = ans ? { v: ans.value, f: document.activeElement === ans } : null;
  if (!state) app.innerHTML = homeView();
  else if (state.phase === 'playing') app.innerHTML = gameView();
  else app.innerHTML = endView();
  const ans2 = document.getElementById('answer');
  if (ans2 && kept) { ans2.value = kept.v; if (kept.f) ans2.focus(); }
  app.dataset.view = view;
  handleEvent();
}

function homeView() {
  return `
  <section class="card hero">
    <div class="logo">🔐</div>
    <h1>الخزنة</h1>
    <p class="sub">محاكي التجربة: شاشة المشغّل وشاشة الخبير على نفس الجهاز</p>
    <button class="primary big" data-act="new">ابدأ التجربة</button>
  </section>
  <section class="card how">
    <h2>كيف تُلعب؟</h2>
    <p><b>المشغّل</b>: أمام الخزنة، يرى الأقفال لكن بلا دليل.</p>
    <p><b>الخبير</b>: معه الدليل، يعرف الحلول لكن لا يرى الأقفال.</p>
    <p>في اللعبة الحقيقية، كل لاعب يرى شاشته فقط ويتكلّمان لحلّ الألغاز. هنا تستطيع التنقّل بين الشاشتين لتجرّب الألغاز بنفسك، أو تعطي الهاتف لصديق مع كل دور.</p>
    <p>افتح 5 أقفال قبل أن تنتهي 10 دقائق. كل خطأ يكلّف ${PENALTY} ثانية.</p>
  </section>`;
}

function gameView() {
  const room = ROOMS[state.room];
  const dots = ROOMS.map((r, i) => `<i class="${i < state.room ? 'done' : i === state.room ? 'now' : ''}" title="${ROOM_NAMES[r]}"></i>`).join('');
  const views = {
    keypad: [keypadOp, keypadEx], wires: [wiresOp, wiresEx], cipher: [cipherOp, cipherEx],
    maze: [mazeOp, mazeEx], lights: [lightsOp, lightsEx],
  };
  const [op, ex] = views[room];
  return `
  <header class="hud">
    <span class="sim-badge">محاكي</span>
    <div class="dots">${dots}</div>
    <span id="timer" class="timer" dir="ltr">${fmt(remaining(state, Date.now()))}</span>
  </header>
  <nav class="tabs" role="tablist">
    <button data-act="view" data-v="op" class="${view === 'op' ? 'on' : ''}" role="tab" aria-selected="${view === 'op'}">🎮 شاشة المشغّل</button>
    <button data-act="view" data-v="ex" class="${view === 'ex' ? 'on' : ''}" role="tab" aria-selected="${view === 'ex'}">📖 شاشة الخبير</button>
  </nav>
  <div class="split">
    <section class="card puzzle panel op">
      <div class="panel-title"><span class="role op">المشغّل</span> ${state.room + 1}. ${ROOM_NAMES[room]}</div>
      ${op()}
    </section>
    <section class="card puzzle panel ex">
      <div class="panel-title"><span class="role ex">الخبير</span> ${state.room + 1}. ${ROOM_NAMES[room]}</div>
      ${ex()}
    </section>
  </div>
  <button data-act="quit" class="link">إنهاء التجربة</button>`;
}

// الغرفة 1
function keypadOp() {
  const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✔'];
  return `
  <p class="lead">صِف هذه الرموز للخبير بالترتيب (من اليسار إلى اليمين)، ثم أدخل الرمز الذي يعطيك إياه.</p>
  <div class="symbols" dir="ltr">${P.keypad.shown.map(i => `<span>${SYMBOLS[i].s}</span>`).join('')}</div>
  <div class="display" dir="ltr">${esc(entry.padEnd(4, '·'))}</div>
  <div class="pad" dir="ltr">${keys.map(k => `<button data-act="key" data-k="${k}" class="${k === '✔' ? 'primary' : ''}">${k}</button>`).join('')}</div>`;
}
function keypadEx() {
  return `
  <p class="lead">المشغّل سيصف لك 4 رموز. أعطه الرقم المقابل لكل رمز، بنفس الترتيب.</p>
  <div class="manual-grid">${SYMBOLS.map((sy, i) => `<div><b>${sy.s}</b><small>${sy.n}</small><em>${P.keypad.manual[i]}</em></div>`).join('')}</div>`;
}

// الغرفة 2
function wiresOp() {
  return `
  <p class="lead">صِف للخبير عدد الأسلاك وألوانها من الأعلى إلى الأسفل، ثم اقطع السلك الذي يحدّده (اضغط مرتين للتأكيد).</p>
  <div class="wires">${P.wires.wires.map((c, i) => {
    const cut = state.cut.includes(i), armed = armedCut === i;
    return `<div class="wire ${cut ? 'cut' : ''}"><span class="num">${i + 1}</span>
      <span class="bar" style="--c:${COLORS[c].c}"></span>
      <button data-act="cut" data-i="${i}" class="${armed ? 'armed' : ''}" ${cut ? 'disabled' : ''}>${cut ? 'مقطوع' : armed ? 'متأكد؟' : '✂️ اقطع'}</button></div>`;
  }).join('')}</div>`;
}
function wiresEx() {
  return `
  <p class="lead">اسأل المشغّل عن عدد الأسلاك وألوانها. السلك رقم 1 هو الأعلى. طبّق <b>أوّل</b> قاعدة صحيحة فقط.</p>
  ${[3, 4, 5, 6].map(n => `<div class="rules"><h3>إذا كان هناك ${n} أسلاك</h3>
    <ol>${P.wires.rules[n].map(r => `<li>${ruleText(r)}</li>`).join('')}</ol></div>`).join('')}`;
}

// الغرفة 3
function cipherOp() {
  return `
  <p class="lead">صِف الرمز للخبير، واقرأ له الحروف المشفّرة واحداً واحداً. هو يعرف كيف تُفكّ.</p>
  <div class="big-symbol">${SYMBOLS[P.cipher.sym].s}</div>
  <div class="cipher">${[...P.cipher.cipher].map(c => `<span>${c}</span>`).join('')}</div>
  <form class="row" data-form="cipher">
    <input id="answer" autocomplete="off" placeholder="الكلمة بعد فكّ الشيفرة">
    <button class="primary">تحقّق</button>
  </form>`;
}
function cipherEx() {
  return `
  <p class="lead">1) اعرف الإزاحة من الرمز. 2) ارجع بكل حرف إلى الخلف في الأبجدية بعدد الإزاحة (قبل «ا» تأتي «ي»).<br>
  <small>مثال: الإزاحة 2 ← الحرف «ث» يصبح «ب».</small></p>
  <div class="manual-grid">${SYMBOLS.map((sy, i) => `<div><b>${sy.s}</b><small>${sy.n}</small><em>${P.cipher.manual[i]}</em></div>`).join('')}</div>
  <h3>الأبجدية</h3>
  <div class="alphabet">${ALPHABET.map((ch, i) => `<span><b>${ch}</b><small>${i + 1}</small></span>`).join('')}</div>`;
}

// الغرفة 4
function mazeOp() {
  return `
  <p class="lead">أنت في ظلام دامس 🔦. الخبير يرى الخريطة ومكانك. اتبع توجيهاته. كل اصطدام بجدار يكلّف ${BUMP} ثوانٍ.</p>
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
  const expected = lightsExpected(P, state.lightStage);
  return `
  <p class="lead">المرحلة ${state.lightStage + 1} من 3. شاهد الأضواء وصِفها للخبير، ثم اضغط الأزرار التي يحدّدها بالترتيب.</p>
  <div id="lamp" class="lamp"></div>
  <button data-act="replay" class="ghost">🔁 أعد عرض الأضواء</button>
  <div class="progress">${expected.map((_, i) => `<i class="${i < state.lightInput.length ? 'on' : ''}"></i>`).join('')}</div>
  <div class="lights">${LIGHTS.map((l, i) => `<button data-act="press" data-c="${i}" style="--c:${l.c}">${l.n}</button>`).join('')}</div>`;
}
function lightsEx() {
  return `
  <p class="lead">المشغّل يرى أضواء تومض. حوّل كل ضوء حسب جدول المرحلة الحالية. في المرحلة 2 يومض ضوءان وفي المرحلة 3 ثلاثة: يضغط المشغّل على الكل بالترتيب.</p>
  ${[0, 1, 2].map(st => `<div class="rules ${st === state.lightStage ? 'current' : ''}">
    <h3>المرحلة ${st + 1}${st === state.lightStage ? ' ← الآن' : ''}</h3>
    <ul>${LIGHTS.map((l, c) => { const t = LIGHTS[P.lights.maps[st][c]];
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
      : `وصلت إلى: <b>${ROOM_NAMES[ROOMS[Math.min(state.room, ROOMS.length - 1)]]}</b>`}</p>
    <button data-act="new" class="primary big">لعبة جديدة (ألغاز مختلفة)</button>
  </section>`;
}

// ───────── الأحداث ─────────
app.addEventListener('click', e => {
  const b = e.target.closest('[data-act]');
  if (!b || b.disabled) return;
  switch (b.dataset.act) {
    case 'new': newGame(); break;
    case 'quit': state = null; render(); break;
    case 'view': view = b.dataset.v; render(); break;
    case 'key': {
      const k = b.dataset.k;
      if (k === '⌫') entry = entry.slice(0, -1);
      else if (k === '✔') { if (entry.length === 4) { const v = entry; entry = ''; dispatch({ type: 'submit', value: v }); } }
      else if (entry.length < 4) entry += k;
      render();
      break;
    }
    case 'cut': {
      const i = Number(b.dataset.i);
      if (armedCut === i) { armedCut = -1; dispatch({ type: 'cut', idx: i }); render(); }
      else { armedCut = i; render(); }
      break;
    }
    case 'move': dispatch({ type: 'move', dir: b.dataset.d }); break;
    case 'press': dispatch({ type: 'press', color: Number(b.dataset.c) }); break;
    case 'replay': playLights(); break;
  }
});

app.addEventListener('submit', e => {
  e.preventDefault();
  if (e.target.dataset.form === 'cipher') {
    const input = document.getElementById('answer');
    if (input.value.trim()) { const v = input.value; input.value = ''; dispatch({ type: 'submit', value: v }); }
  }
});

render();
