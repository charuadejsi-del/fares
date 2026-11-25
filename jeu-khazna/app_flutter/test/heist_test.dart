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

  test('الهروب ممكن دائماً: كل باب يُغلق بعد أن يصله العميل بهامش', () {
    for (int seed = 1; seed <= 80; seed++) {
      for (final stage in [10, 25, 45]) {
        final m = heistMap(seed * 104729, stage, 3 + seed % 5);
        final plan = m.escape;
        expect(plan.doorClose.length, m.doors.length);
        for (int k = 0; k < m.doors.length; k++) {
          // أقصر مسافة مستقيمة من الخزنة إلى الباب (حدّ أدنى للمشي)
          final straight = (m.doorCenter(k) - m.rooms.last.terminal).distance / kAgentSpeed;
          expect(plan.doorClose[k] > straight + 3, true, reason: 'seed=$seed stage=$stage door=$k');
        }
        expect(plan.seconds > plan.doorClose.fold<double>(0, max), true);
      }
    }
  });

  test('الليزر لا يصيب أيّ جهاز أبداً، والبطاقات في غرف الحرّاس', () {
    for (int seed = 1; seed <= 80; seed++) {
      for (final stage in [18, 33, 50]) {
        final m = heistMap(seed * 15485863, stage, 4 + seed % 4);
        expect(m.lasers.isNotEmpty, true);
        for (final l in m.lasers) {
          expect(l.room > 0, true);
          for (double t = 0; t < 20; t += .25) {
            for (final r in m.rooms) {
              expect(l.hits(r.terminal, t), false, reason: 'seed=$seed stage=$stage');
            }
          }
        }
        if (m.guards.isNotEmpty) expect(m.cardGuards, isNotEmpty);
        for (final g in m.cardGuards) {
          expect(m.cardRooms.contains(m.guards[g].room), true);
        }
      }
    }
    expect(heistMap(9, 9, 4).lasers, isEmpty);
    expect(heistMap(9, 9, 4).cardGuards, isEmpty);
  });

  test('الليزر الوامض ينطفئ ويشتعل', () {
    final m = heistMap(77, 20, 5);
    final l = m.lasers.firstWhere((l) => !l.sweep);
    final on = [for (double t = 0; t < 10; t += .1) l.at(t) != null];
    expect(on.contains(true) && on.contains(false), true);
  });

  test('السرقة من الخلف فقط', () {
    final m = heistMap(31, 20, 5);
    final g = m.guards.first;
    final (gp, ga) = guardAt(g, 3);
    final back = gp - Offset(cos(ga), sin(ga)) * .8;
    final front = gp + Offset(cos(ga), sin(ga)) * .8;
    expect(m.behind(0, back, 3), true);
    expect(m.behind(0, front, 3), false);
  });

  test('فتح الخزنة يطلق الهروب، ثم المخرج = فوز، والحبس = خسارة', () {
    final p = generatePuzzles(5);
    final base = GameState(seed: 5, rooms: const ['keypad'], phase: 'playing', startedAt: 1000, stage: 12, heist: true);
    var s = applyAction(base, p, {'type': 'submit', 'value': p.keypad.answer}, 5000);
    expect(s.phase, 'playing');
    expect(s.escape > 0, true);
    expect(s.lastEvent?.type, 'escape');
    // لا أقفال أثناء الهروب
    expect(applyAction(s, p, {'type': 'submit', 'value': p.keypad.answer}, 6000).eventId, s.eventId);
    final won = applyAction(s, p, {'type': 'escaped'}, 9000);
    expect(won.phase, 'won');
    expect(applyAction(s, p, {'type': 'caught'}, 9000).phase, 'lost');
    expect(GameState.fromJson(s.toJson()).escape, s.escape);
    // قبل المرحلة 10: الخزنة تنهي المهمّة مباشرة
    final early = GameState(seed: 5, rooms: const ['keypad'], phase: 'playing', startedAt: 1000, stage: 9, heist: true);
    expect(applyAction(early, p, {'type': 'submit', 'value': p.keypad.answer}, 5000).phase, 'won');
  });

  test('البطاقة وقطع التيار', () {
    final p = generatePuzzles(6);
    var s = GameState(seed: 6, rooms: const ['keypad', 'wires'], phase: 'playing', startedAt: 1000, stage: 16, heist: true);
    s = applyAction(s, p, {'type': 'card', 'room': 1}, 2000);
    expect(s.cards, [1]);
    expect(applyAction(s, p, {'type': 'card', 'room': 1}, 2500).eventId, s.eventId);
    s = applyAction(s, p, {'type': 'power'}, 3000);
    expect(s.power > 0, true);
    // إعادة القطع قبل انتهاء فترة الانتظار مرفوضة
    expect(applyAction(s, p, {'type': 'power'}, 10000).power, s.power);
    final later = applyAction(s, p, {'type': 'power'}, 3000 + ((kPowerSeconds + kPowerCooldown + 1) * 1000).round());
    expect(later.power > s.power, true);
    final back = GameState.fromJson(later.toJson());
    expect(back.cards, [1]);
    expect(back.power, later.power);
    // قبل المرحلة 15 لا قطع للتيار
    final early = GameState(seed: 6, rooms: const ['keypad'], phase: 'playing', startedAt: 1000, stage: 13, heist: true);
    expect(applyAction(early, p, {'type': 'power'}, 3000).power, 0);
  });

  test('نقطة العودة بعد الاكتشاف آمنة (لا يُكشف العميل فور عودته)', () {
    var unsafe = 0, total = 0;
    for (int seed = 1; seed <= 60; seed++) {
      for (final stage in [14, 26, 48]) {
        final m = heistMap(seed * 6151, stage, 4 + seed % 3);
        for (int solved = 1; solved < m.rooms.length; solved++) {
          for (double t = 0; t < 30; t += 3.7) {
            total++;
            final p = m.safeCheckpoint(solved, t, const {});
            if (m.seen(p, t, solved, const {}) || m.seen(p, t + 1, solved, const {})) unsafe++;
          }
        }
      }
    }
    expect(unsafe / total < .02, true, reason: '$unsafe / $total');
  });

  test('العميل المنحني عند الجهاز لا تراه الكاميرا ولا الحارس البعيد', () {
    final m = heistMap(31, 20, 5);
    final g = m.guards.first;
    final (gp, ga) = guardAt(g, 3);
    final far = gp + Offset(cos(ga), sin(ga)) * 3.0;
    if (m.lineOfSight(gp, far, 99)) {
      expect(m.seen(far, 3, 99, const {}), true);
      expect(m.seen(far, 3, 99, const {}, crouch: true), false);
    }
  });
}
