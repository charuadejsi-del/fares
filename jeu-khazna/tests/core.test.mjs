// اختبارات منطق اللعبة: node jeu-khazna/tests/core.test.mjs
import assert from 'node:assert/strict';
import * as G from '../core.js';

let n = 0;
const T0 = 1_000_000;

// حلّ المرحلة بالكامل لكل بذرة: يتأكّد أن كل لغز قابل للحل وأن القواعد متّسقة
function solveMaze(P) {
  const { N, open, start, exit } = P.maze;
  const prev = { [start]: null }, q = [start];
  while (q.length) {
    const c = q.shift();
    if (c === exit) break;
    for (const d of Object.keys(G.DIRS)) {
      if (!open[c][d]) continue;
      const nc = (Math.floor(c / N) + G.DIRS[d][1]) * N + (c % N + G.DIRS[d][0]);
      if (!(nc in prev)) { prev[nc] = [c, d]; q.push(nc); }
    }
  }
  const path = [];
  for (let c = exit; prev[c]; c = prev[c][0]) path.unshift(prev[c][1]);
  return path;
}

for (let seed = 1; seed <= 500; seed++) {
  const P = G.generate(seed);
  // الحتمية
  assert.deepEqual(P, G.generate(seed));
  assert.equal(P.keypad.answer.length, 4);
  assert.ok(P.wires.answer >= 0 && P.wires.answer < P.wires.wires.length, `wires seed ${seed}`);
  assert.ok(P.maze.distance >= 1, `maze seed ${seed}`);
  // فكّ الشيفرة بالرجوع بالإزاحة يعطي الكلمة
  const k = P.cipher.manual[P.cipher.sym];
  const dec = [...P.cipher.cipher].map(ch => G.ALPHABET[(G.ALPHABET.indexOf(ch) - k + 28) % 28]).join('');
  assert.equal(dec, P.cipher.answer);

  let s = G.start(G.newState(seed), P, T0);
  s = G.apply(s, P, { type: 'submit', value: P.keypad.answer }, T0);
  assert.equal(s.room, 1);
  s = G.apply(s, P, { type: 'cut', idx: P.wires.answer }, T0);
  assert.equal(s.room, 2);
  s = G.apply(s, P, { type: 'submit', value: ' ' + P.cipher.answer + ' ' }, T0);
  assert.equal(s.room, 3);
  for (const d of solveMaze(P)) s = G.apply(s, P, { type: 'move', dir: d }, T0);
  assert.equal(s.room, 4, `maze path seed ${seed}`);
  for (let st = 0; st < 3; st++) for (const c of G.lightsExpected(P, st)) s = G.apply(s, P, { type: 'press', color: c }, T0);
  assert.equal(s.phase, 'won');
  assert.equal(s.penalty, 0);
  n++;
}

// العقوبات
{
  const P = G.generate(42);
  let s = G.start(G.newState(42), P, T0);
  const wrong = P.keypad.answer === '0000' ? '1111' : '0000';
  s = G.apply(s, P, { type: 'submit', value: wrong }, T0);
  assert.equal(s.room, 0); assert.equal(s.penalty, G.PENALTY); assert.equal(s.lastEvent.type, 'wrong');
  // انتهاء الوقت
  const late = G.tick(s, T0 + (G.DURATION - G.PENALTY) * 1000 + 1);
  assert.equal(late.phase, 'lost');
  // الأفعال بعد النهاية تُتجاهل
  assert.equal(G.apply(late, P, { type: 'submit', value: P.keypad.answer }, T0), late);
  // فعل غير مناسب للغرفة يُتجاهل
  assert.equal(G.apply(s, P, { type: 'cut', idx: 0 }, T0), s);
  n++;
}

// اصطدام بجدار في السرداب
{
  for (let seed = 1; seed < 100; seed++) {
    const P = G.generate(seed);
    const blocked = Object.keys(G.DIRS).find(d => !P.maze.open[P.maze.start][d]);
    if (!blocked) continue;
    let s = { ...G.start(G.newState(seed), P, T0), room: 3 };
    s = G.apply(s, P, { type: 'move', dir: blocked }, T0);
    assert.equal(s.lastEvent.type, 'bump'); assert.equal(s.penalty, G.BUMP); assert.equal(s.mazePos, P.maze.start);
    n++; break;
  }
}

// خطأ في الأضواء يعيد الإدخال
{
  const P = G.generate(7);
  let s = { ...G.start(G.newState(7), P, T0), room: 4 };
  const good = G.lightsExpected(P, 0)[0];
  s = G.apply(s, P, { type: 'press', color: (good + 1) % 4 }, T0);
  assert.equal(s.lightStage, 0); assert.deepEqual(s.lightInput, []); assert.equal(s.penalty, G.PENALTY);
  n++;
}

console.log(`✓ ${n} اختبار ناجح`);
