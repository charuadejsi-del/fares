// اختبارات منطق اللعبة (نسخة Dart): flutter test
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/game.dart';

import 'vectors.dart';

List<String> _path(Maze m) {
  final prev = <int, List<Object>>{};
  final seen = <int>{m.start};
  final q = <int>[m.start];
  int head = 0;
  while (head < q.length) {
    final c = q[head++];
    if (c == m.exit) break;
    for (final d in kDirNames) {
      final nc = m.neighbor(c, d);
      if (nc != null && seen.add(nc)) {
        prev[nc] = [c, d];
        q.add(nc);
      }
    }
  }
  final path = <String>[];
  for (int c = m.exit; prev.containsKey(c); c = prev[c]![0] as int) {
    path.insert(0, prev[c]![1] as String);
  }
  return path;
}

void main() {
  const t0 = 1000000;

  test('الألغاز مطابقة لنسخة JavaScript (نفس البذرة = نفس الألغاز)', () {
    final vectors = jsonDecode(kJsVectors) as List;
    for (final v in vectors) {
      final p = generatePuzzles(v['seed'] as int);
      expect(p.keypad.manual, v['keypad']['manual']);
      expect(p.keypad.shown, v['keypad']['shown']);
      expect(p.keypad.answer, v['keypad']['answer']);
      expect(p.wires.wires, v['wires']['wires']);
      expect(p.wires.answer, v['wires']['answer']);
      for (int n = 3; n <= 6; n++) {
        final js = v['wires']['rules']['$n'] as List;
        final dart = p.wires.rules[n]!;
        expect(dart.length, js.length);
        for (int i = 0; i < js.length; i++) {
          expect(dart[i].type, js[i][0]);
          expect(dart[i].color ?? -1, js[i][1]);
          expect(dart[i].k, js[i][2]);
        }
      }
      expect(p.cipher.manual, v['cipher']['manual']);
      expect(p.cipher.sym, v['cipher']['sym']);
      expect(p.cipher.cipher, v['cipher']['cipher']);
      expect(p.cipher.answer, v['cipher']['answer']);
      expect(p.maze.start, v['maze']['start']);
      expect(p.maze.exit, v['maze']['exit']);
      final open = v['maze']['open'] as List;
      for (int i = 0; i < open.length; i++) {
        expect(kDirNames.where((d) => p.maze.open[i].contains(d)).toList(), open[i]);
      }
      expect(p.lights.seq, v['lights']['seq']);
      expect(p.lights.maps, v['lights']['maps']);
    }
  });

  test('كل لعبة قابلة للحل حتى النهاية', () {
    for (int seed = 1; seed <= 300; seed++) {
      final p = generatePuzzles(seed);
      var s = startGame(newState(seed), p, t0);
      s = applyAction(s, p, {'type': 'submit', 'value': p.keypad.answer}, t0);
      expect(s.room, 1);
      s = applyAction(s, p, {'type': 'cut', 'idx': p.wires.answer}, t0);
      expect(s.room, 2);
      s = applyAction(s, p, {'type': 'submit', 'value': ' ${p.cipher.answer} '}, t0);
      expect(s.room, 3);
      for (final d in _path(p.maze)) {
        s = applyAction(s, p, {'type': 'move', 'dir': d}, t0);
      }
      expect(s.room, 4, reason: 'seed $seed maze');
      for (int st = 0; st < 3; st++) {
        for (final c in p.lights.expected(st)) {
          s = applyAction(s, p, {'type': 'press', 'color': c}, t0);
        }
      }
      expect(s.phase, 'won');
      expect(s.penalty, 0);
    }
  });

  test('العقوبات وانتهاء الوقت', () {
    final p = generatePuzzles(42);
    var s = startGame(newState(42), p, t0);
    final bad = p.keypad.answer == '0000' ? '1111' : '0000';
    s = applyAction(s, p, {'type': 'submit', 'value': bad}, t0);
    expect(s.room, 0);
    expect(s.penalty, kPenalty);
    expect(s.lastEvent?.type, 'wrong');
    final late = tick(s, t0 + (kDuration - kPenalty) * 1000 + 1);
    expect(late.phase, 'lost');
    expect(identical(applyAction(late, p, {'type': 'submit', 'value': p.keypad.answer}, t0), late), isTrue);
    expect(identical(applyAction(s, p, {'type': 'cut', 'idx': 0}, t0), s), isTrue);
  });

  test('فكّ الشيفرة بالجدول يعطي الكلمة', () {
    for (int seed = 1; seed <= 100; seed++) {
      final c = generatePuzzles(seed).cipher;
      expect(c.cipher.split('').map((l) => c.decode(l, c.sym)).join(), c.answer);
    }
  });

  test('الحالة تُنقل عبر JSON دون خسارة', () {
    final p = generatePuzzles(5);
    var s = startGame(newState(5), p, t0);
    s = applyAction(s, p, {'type': 'submit', 'value': '9999'}, t0);
    final back = GameState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map);
    expect(jsonEncode(back.toJson()), jsonEncode(s.toJson()));
  });
}
