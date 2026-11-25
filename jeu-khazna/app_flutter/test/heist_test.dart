import 'dart:math';
import 'dart:ui' show Offset;

import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/game.dart';
import 'package:khazna/core/heist.dart';

/// هل يمكن الوصول من نقطة البداية إلى كل الأجهزة حين تُفتح الأبواب واحداً واحداً؟
bool reachable(HeistMap m) {
  for (int solved = 0; solved < m.rooms.length; solved++) {
    final start = solved == 0 ? m.spawn : m.checkpoint(solved);
    final goal = m.rooms[solved].terminal;
    final s0 = Point(start.dx.floor(), start.dy.floor());
    final g = Point(goal.dx.floor(), goal.dy.floor());
    final seen = <Point<int>>{s0};
    final q = [s0];
    var ok = false;
    while (q.isNotEmpty) {
      final c = q.removeLast();
      if (c == g) {
        ok = true;
        break;
      }
      for (final o in const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]) {
        final n = Point(c.x + o.x, c.y + o.y);
        if (!m.solid(n.x, n.y, solved) && seen.add(n)) q.add(n);
      }
    }
    if (!ok) return false;
  }
  return true;
}

void main() {
  test('الخريطة نفسها لنفس البذرة', () {
    final a = heistMap(123, 15, 5), b = heistMap(123, 15, 5);
    expect(identical(a, b), true);
    expect(a.rooms.length, 5);
    expect(a.doors.length, 4);
  });

  test('كل الأجهزة قابلة للوصول في 300 خريطة', () {
    for (int seed = 1; seed <= 100; seed++) {
      for (final stage in [1, 12, 33, 55]) {
        final n = 3 + seed % 4;
        final m = heistMap(seed * 7919, stage, n);
        expect(reachable(m), true, reason: 'seed=$seed stage=$stage n=$n');
        expect(m.solid(m.spawn.dx.floor(), m.spawn.dy.floor(), 0), false);
      }
    }
  });

  test('الحرّاس والكاميرات حسب المرحلة، والحارس يبقى داخل غرفته', () {
    expect(heistMap(5, 2, 4).guards, isEmpty);
    final m = heistMap(5, 45, 5);
    expect(m.guards.length, heistParams(45).guards);
    expect(m.cams, isNotEmpty);
    for (final g in m.guards) {
      final room = m.rooms[g.room];
      for (double t = 0; t < 30; t += .7) {
        final (p, _) = guardAt(g, t);
        expect(p.dx >= room.x0 && p.dx <= room.x1 + 1 && p.dy >= room.y0 && p.dy <= room.y1 + 1, true);
      }
    }
  });

  test('الباب المغلق يمنع المرور ويُفتح بعد حلّ القفل', () {
    final m = heistMap(42, 3, 3);
    final d = m.doors.first.cells.first;
    expect(m.solid(d.x, d.y, 0), true);
    expect(m.solid(d.x, d.y, 1), false);
    final p = m.move(m.spawn, const Offset(100, 0), 0);
    expect(m.solid(p.dx.floor(), p.dy.floor(), 0), false);
  });

  test('مخروط الرؤية', () {
    expect(inCone(Offset.zero, 0, const Offset(2, 0), 4, .5), true);
    expect(inCone(Offset.zero, 0, const Offset(-2, 0), 4, .5), false);
    expect(inCone(Offset.zero, 0, const Offset(6, 0), 4, .5), false);
  });

  test('الاكتشاف يُحتسب خطأً ويعطّل الكاميرا مرّة واحدة', () {
    final p = generatePuzzles(3);
    var s = GameState(seed: 3, rooms: const ['switches', 'clock', 'vaultcode'], phase: 'playing', startedAt: 1000, stage: 10, heist: true);
    s = applyAction(s, p, {'type': 'spotted'}, 2000);
    expect(s.spots, 1);
    expect(s.errors, 1);
    expect(s.penalty, kSpotPenalty);
    s = applyAction(s, p, {'type': 'hackcam', 'cam': 0}, 3000);
    expect(s.camOff.containsKey('0'), true);
    final again = applyAction(s, p, {'type': 'hackcam', 'cam': 0}, 4000);
    expect(again.eventId, s.eventId);
    final back = GameState.fromJson(s.toJson());
    expect(back.heist, true);
    expect(back.camOff['0'], s.camOff['0']);
  });
}
