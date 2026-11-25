import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/game.dart';
import 'package:khazna/core/heist.dart';
import 'package:khazna/features/play/heist_fps.dart';

void paintAll(HeistMap m, GameState s) {
  final frame = ValueNotifier(0);
  for (int i = 0; i < m.rooms.length; i++) {
    for (double a = 0; a < 2 * pi; a += .7) {
      final p = FpsPainter(
        map: m,
        repaint: frame,
        state: () => s,
        time: () => 12,
        agent: () => i == 0 ? m.spawn : m.checkpoint(i),
        facing: () => a,
        alert: () => .3,
        vision: 3.8,
      );
      final rec = ui.PictureRecorder();
      p.paint(Canvas(rec), const Size(420, 260));
      rec.endRecording();
    }
  }
}

void main() {
  testWidgets('رسم 3D لا ينهار: بلا خامات ثم بالخامات، في الحالات العادية والهروب', (tester) async {
    final m = heistMap(4242, 18, 5);
    final s = GameState(seed: 4242, rooms: const ['keypad', 'wires', 'cipher', 'maze', 'vaultcode'], phase: 'playing', stage: 18, heist: true, room: 2);
    paintAll(m, s);
    await tester.runAsync(FpsTextures.load);
    expect(FpsTextures.wallFor(18), isNotNull);
    expect(FpsTextures.get('term_on'), isNotNull);
    paintAll(m, s);
    paintAll(m, s.copyWith(escape: 3, power: 20, room: 4));
    paintAll(heistMap(99, 50, 7), GameState(seed: 99, rooms: List.filled(7, 'keypad'), phase: 'playing', stage: 50, heist: true));
  });
}
