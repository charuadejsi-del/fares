// يولّد test/vectors.dart: ألغاز مرجعية من core.js لضمان تطابق نسخة Dart معها.
import { writeFileSync } from 'node:fs';
import * as G from '../core.js';
const seeds = [1, 7, 42, 2024, 99999, 123456789, 1073741823, 2147483000];
const v = seeds.map(seed => {
  const P = G.generate(seed);
  return {
    seed,
    keypad: { manual: P.keypad.manual, shown: P.keypad.shown, answer: P.keypad.answer },
    wires: { wires: P.wires.wires, answer: P.wires.answer,
      rules: Object.fromEntries(Object.entries(P.wires.rules).map(([n, l]) => [n, l.map(r => [r.type, r.color ?? -1, r.k])])) },
    cipher: { manual: P.cipher.manual, sym: P.cipher.sym, cipher: P.cipher.cipher, answer: P.cipher.answer },
    maze: { start: P.maze.start, exit: P.maze.exit, open: P.maze.open.map(o => Object.keys(G.DIRS).filter(d => o[d])) },
    lights: { seq: P.lights.seq, maps: P.lights.maps },
  };
});
writeFileSync(new URL('../app_flutter/test/vectors.dart', import.meta.url),
  `// مولَّد بواسطة jeu-khazna/tools/gen-dart-vectors.mjs — لا تعدّله يدوياً.\nconst String kJsVectors = r'''${JSON.stringify(v)}''';\n`);
console.log('✓ vectors', seeds.length);
