// core.js — منطق لعبة «الخزنة» (دوال صافية، مشتركة بين المتصفح والاختبارات)

export const DURATION = 600; // مدة اللعبة بالثواني (10 دقائق)
export const PENALTY = 30;   // عقوبة الخطأ بالثواني
export const BUMP = 10;      // عقوبة الاصطدام بجدار في السرداب

export const ROOMS = ['keypad', 'wires', 'cipher', 'maze', 'lights'];
export const ROOM_NAMES = {
  keypad: 'باب الرموز',
  wires: 'صندوق الأسلاك',
  cipher: 'المخطوط المشفّر',
  maze: 'السرداب المظلم',
  lights: 'قفل الأضواء',
};

export const SYMBOLS = [
  { s: '★', n: 'نجمة' }, { s: '☾', n: 'هلال' }, { s: '◆', n: 'معيّن' },
  { s: '▲', n: 'مثلث' }, { s: '●', n: 'دائرة' }, { s: '■', n: 'مربّع' },
  { s: '✚', n: 'زائد' }, { s: '☀', n: 'شمس' }, { s: '♣', n: 'نفل' },
  { s: '♠', n: 'بستوني' }, { s: '♥', n: 'قلب' }, { s: '✿', n: 'وردة' },
];

export const COLORS = [
  { id: 'red', n: 'أحمر', c: '#e53935' },
  { id: 'blue', n: 'أزرق', c: '#1e88e5' },
  { id: 'yellow', n: 'أصفر', c: '#fdd835' },
  { id: 'green', n: 'أخضر', c: '#43a047' },
  { id: 'white', n: 'أبيض', c: '#f5f5f5' },
  { id: 'black', n: 'أسود', c: '#212121' },
];
export const LIGHTS = COLORS.slice(0, 4);

export const ALPHABET = [...'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'];
const WORDS = ['مفتاح', 'كنز', 'سرداب', 'قنديل', 'ذهب', 'لغز', 'حارس', 'صندوق', 'مخطوط', 'فارس',
  'جبل', 'نجم', 'قمر', 'سيف', 'درع', 'طريق', 'ظلام', 'شمس', 'بحر', 'صخر'];

export const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };
const OPP = { up: 'down', down: 'up', left: 'right', right: 'left' };

// مولّد أرقام عشوائية حتمي (mulberry32): نفس البذرة = نفس الألغاز عند كل اللاعبين
export function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6D2B79F5) >>> 0;
    let t = s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const int = (r, n) => Math.floor(r() * n);
const pick = (r, a) => a[int(r, a.length)];
function shuffle(r, a) {
  a = [...a];
  for (let i = a.length - 1; i > 0; i--) { const j = int(r, i + 1); [a[i], a[j]] = [a[j], a[i]]; }
  return a;
}

export function normalize(v) {
  return String(v ?? '').replace(/\s+/g, '').replace(/[أإآ]/g, 'ا').replace(/ى/g, 'ي').replace(/ة/g, 'ه');
}

// ───── الغرفة 1: باب الرموز ─────
function genKeypad(r) {
  const digits = SYMBOLS.map(() => int(r, 10));
  const shown = shuffle(r, SYMBOLS.map((_, i) => i)).slice(0, 4);
  return { manual: digits, shown, answer: shown.map(i => digits[i]).join('') };
}

// ───── الغرفة 2: صندوق الأسلاك ─────
const count = (w, c) => w.filter(x => x === c).length;
export function evalRule(rule, wires) {
  const n = wires.length;
  switch (rule.type) {
    case 'none': return count(wires, rule.color) === 0 ? rule.k - 1 : -1;
    case 'lastIs': return wires[n - 1] === rule.color ? n - 1 : -1;
    case 'many': return count(wires, rule.color) > 1 ? wires.lastIndexOf(rule.color) : -1;
    case 'one': return count(wires, rule.color) === 1 ? 0 : -1;
    case 'default': return rule.k - 1;
  }
  return -1;
}
export function ruleText(rule) {
  const C = rule.color !== undefined ? COLORS[rule.color].n : '';
  switch (rule.type) {
    case 'none': return `إذا لم يوجد أي سلك ${C} ← اقطع السلك رقم ${rule.k}`;
    case 'lastIs': return `إذا كان آخر سلك ${C} ← اقطع آخر سلك`;
    case 'many': return `إذا وُجد أكثر من سلك ${C} ← اقطع آخر سلك ${C}`;
    case 'one': return `إذا وُجد سلك ${C} واحد فقط ← اقطع أول سلك`;
    case 'default': return `وإلا ← اقطع السلك رقم ${rule.k}`;
  }
  return '';
}
function genWires(r) {
  const rules = {};
  for (let n = 3; n <= 6; n++) {
    const list = [];
    for (let i = 0; i < 3; i++) {
      const type = pick(r, ['none', 'lastIs', 'many', 'one']);
      list.push({ type, color: int(r, COLORS.length), k: 1 + int(r, n) });
    }
    list.push({ type: 'default', k: 1 + int(r, n) });
    rules[n] = list;
  }
  const n = 3 + int(r, 4);
  const wires = Array.from({ length: n }, () => int(r, COLORS.length));
  let answer = -1;
  for (const rule of rules[n]) { answer = evalRule(rule, wires); if (answer >= 0) break; }
  return { rules, wires, answer };
}

// ───── الغرفة 3: المخطوط المشفّر ─────
function genCipher(r) {
  const shifts = SYMBOLS.map(() => 1 + int(r, 9));
  const sym = int(r, SYMBOLS.length);
  const word = pick(r, WORDS);
  const k = shifts[sym];
  const cipher = [...word].map(ch => ALPHABET[(ALPHABET.indexOf(ch) + k) % ALPHABET.length]).join('');
  return { manual: shifts, sym, cipher, answer: word };
}

// ───── الغرفة 4: السرداب المظلم ─────
function bfs(open, N, start) {
  const dist = Array(N * N).fill(-1); dist[start] = 0;
  const q = [start];
  while (q.length) {
    const c = q.shift(), x = c % N, y = Math.floor(c / N);
    for (const d of Object.keys(DIRS)) {
      if (!open[c][d]) continue;
      const nc = (y + DIRS[d][1]) * N + (x + DIRS[d][0]);
      if (dist[nc] < 0) { dist[nc] = dist[c] + 1; q.push(nc); }
    }
  }
  return dist;
}
function genMaze(r, N = 5) {
  const open = Array.from({ length: N * N }, () => ({}));
  const seen = new Set([0]);
  const stack = [[0, 0]];
  while (stack.length) {
    const [x, y] = stack[stack.length - 1];
    const opts = shuffle(r, Object.keys(DIRS)).filter(d => {
      const nx = x + DIRS[d][0], ny = y + DIRS[d][1];
      return nx >= 0 && ny >= 0 && nx < N && ny < N && !seen.has(ny * N + nx);
    });
    if (!opts.length) { stack.pop(); continue; }
    const d = opts[0], nx = x + DIRS[d][0], ny = y + DIRS[d][1];
    open[y * N + x][d] = true; open[ny * N + nx][OPP[d]] = true;
    seen.add(ny * N + nx); stack.push([nx, ny]);
  }
  const start = int(r, N * N);
  const dist = bfs(open, N, start);
  let exit = start;
  dist.forEach((d, i) => { if (d > dist[exit]) exit = i; });
  return { N, open, start, exit, distance: dist[exit] };
}

// ───── الغرفة 5: قفل الأضواء ─────
function genLights(r) {
  const seq = Array.from({ length: 3 }, () => int(r, LIGHTS.length));
  const maps = [0, 1, 2].map(() => shuffle(r, [0, 1, 2, 3]));
  return { seq, maps };
}
export function lightsExpected(P, stage) {
  return P.lights.seq.slice(0, stage + 1).map(c => P.lights.maps[stage][c]);
}

export function generate(seed) {
  const r = rng(seed);
  return { keypad: genKeypad(r), wires: genWires(r), cipher: genCipher(r), maze: genMaze(r), lights: genLights(r) };
}

// ───── الحالة والقواعد ─────
export function newState(seed) {
  return { seed, phase: 'lobby', room: 0, startedAt: 0, penalty: 0, mazePos: null,
    lightStage: 0, lightInput: [], cut: [], lastEvent: null, eventId: 0, finishedIn: 0 };
}
export function start(state, P, now) {
  return { ...newState(state.seed), phase: 'playing', startedAt: now, mazePos: P.maze.start, eventId: state.eventId + 1,
    lastEvent: { type: 'start', room: ROOMS[0] } };
}
export function remaining(state, now) {
  if (!state.startedAt) return DURATION;
  return Math.max(0, DURATION - (now - state.startedAt) / 1000 - state.penalty);
}
export function tick(state, now) {
  if (state.phase === 'playing' && remaining(state, now) <= 0) return { ...state, phase: 'lost' };
  return state;
}

export function apply(state, P, action, now) {
  if (state.phase !== 'playing' || !action) return state;
  const room = ROOMS[state.room];
  const s = { ...state };
  const ev = (type, extra = {}) => { s.eventId = state.eventId + 1; s.lastEvent = { type, room, ...extra }; };
  const advance = () => {
    s.room = state.room + 1;
    if (s.room >= ROOMS.length) { s.phase = 'won'; s.finishedIn = Math.round(DURATION - remaining(s, now)); }
    ev('solved');
  };
  const wrong = (pen = PENALTY, type = 'wrong') => { s.penalty = state.penalty + pen; ev(type, { pen }); };

  switch (room) {
    case 'keypad':
      if (action.type !== 'submit') return state;
      String(action.value ?? '').trim() === P.keypad.answer ? advance() : wrong();
      break;
    case 'cipher':
      if (action.type !== 'submit') return state;
      normalize(action.value) === P.cipher.answer ? advance() : wrong();
      break;
    case 'wires':
      if (action.type !== 'cut' || !Number.isInteger(action.idx) || state.cut.includes(action.idx)) return state;
      if (action.idx < 0 || action.idx >= P.wires.wires.length) return state;
      s.cut = [...state.cut, action.idx];
      action.idx === P.wires.answer ? advance() : wrong();
      break;
    case 'maze': {
      if (action.type !== 'move' || !DIRS[action.dir]) return state;
      const { N, open, exit } = P.maze, pos = state.mazePos;
      if (!open[pos][action.dir]) { wrong(BUMP, 'bump'); break; }
      const np = (Math.floor(pos / N) + DIRS[action.dir][1]) * N + (pos % N + DIRS[action.dir][0]);
      s.mazePos = np;
      np === exit ? advance() : ev('moved');
      break;
    }
    case 'lights': {
      if (action.type !== 'press' || !Number.isInteger(action.color)) return state;
      const st = state.lightStage, expected = lightsExpected(P, st);
      const input = [...state.lightInput, action.color];
      if (input[input.length - 1] !== expected[input.length - 1]) { s.lightInput = []; wrong(); break; }
      if (input.length < expected.length) { s.lightInput = input; ev('press'); break; }
      s.lightInput = [];
      if (st === 2) advance(); else { s.lightStage = st + 1; ev('stage'); }
      break;
    }
  }
  return tick(s, now);
}
