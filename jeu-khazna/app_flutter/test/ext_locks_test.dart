import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/ext_locks.dart';
import 'package:khazna/core/game.dart';

void main() {
  test('كل قفل موسّع له حلّ صالح ومدخل متّسق', () {
    for (final diff in ['recruit', 'agent', 'elite', 'master']) {
      for (int seed = 1; seed < 60; seed++) {
        for (final id in [...kExtRooms, kVaultCode]) {
          final rooms = ['keypad', 'switches', 'morse', id];
          final x = extPuzzle(id, seed * 7919 + 3, diff, room: 3, rooms: rooms);
          final why = '$id seed=$seed diff=$diff';
          expect(x.check(x.answer), isTrue, reason: why);
          expect(x.bot, isNotEmpty, reason: why);
          expect(x.hint, isNotEmpty, reason: why);
          final inp = x.input;
          switch (inp.kind) {
            case 'digits':
              expect(RegExp(r'^\d+$').hasMatch(x.answer), isTrue, reason: why);
              if (inp.len > 0) expect(x.answer.length, inp.len, reason: why);
              if (inp.len == 0) expect(x.answer.length, lessThanOrEqualTo(4), reason: why);
            case 'choice':
              expect(int.parse(x.answer), inInclusiveRange(0, inp.labels.length - 1), reason: why);
            case 'toggles':
              expect(x.answer.length, inp.labels.length, reason: why);
            case 'cyclers':
              final parts = x.answer.split(',').map(int.parse).toList();
              expect(parts.length, inp.options.length, reason: why);
              for (int i = 0; i < parts.length; i++) {
                expect(parts[i], inInclusiveRange(0, inp.options[i].length - 1), reason: why);
              }
            case 'seq':
              expect(x.answer.split(',').length, inp.len, reason: why);
            case 'grid':
              expect(int.parse(x.answer), inInclusiveRange(0, inp.labels.length - 1), reason: why);
            case 'gridseq':
              final parts = x.answer.split(',').map(int.parse).toList();
              expect(parts.length, inp.len, reason: why);
              expect(parts.first, inp.colors[0], reason: why);
              expect(parts.last, inp.colors[1], reason: why);
            case 'sync':
              expect(x.exAnswer, inInclusiveRange(0, inp.labels.length - 1), reason: why);
            default:
              fail('unknown input ${inp.kind}');
          }
          for (final row in x.manual.rows) {
            if (x.manual.header.isNotEmpty) expect(row.length, x.manual.header.length, reason: why);
          }
          // جواب خاطئ واضح يُرفض
          expect(x.check('${x.answer}9'), isFalse, reason: why);
        }
      }
    }
  });

  test('المفتاحان ورمز الخزنة عبر منطق اللعبة', () {
    final rooms = ['switches', 'sync', kVaultCode];
    var s = GameState(seed: 42, rooms: rooms, phase: 'playing', startedAt: 1000);
    final p = generatePuzzles(42);
    final sw = extFor(s);
    s = applyAction(s, p, {'type': 'ext', 'value': sw.answer}, 2000);
    expect(s.room, 1);
    final sy = extFor(s);
    s = applyAction(s, p, {'type': 'sync', 'role': 'op', 'idx': int.parse(sy.answer)}, 3000);
    expect(s.room, 1);
    s = applyAction(s, p, {'type': 'sync', 'role': 'ex', 'idx': sy.exAnswer}, 3800);
    expect(s.room, 2);
    final v = extFor(s);
    expect(v.answer.length, 2);
    expect(v.answer.split('').toSet(), {for (final i in [0, 1]) '${vaultDigit(42, i)}'});
    s = applyAction(s, p, {'type': 'ext', 'value': v.answer}, 5000);
    expect(s.phase, 'won');
  });
}
