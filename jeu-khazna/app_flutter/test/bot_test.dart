import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/bot.dart';
import 'package:khazna/core/game.dart';

void main() {
  test('العميل الآلي يعطي الجواب الصحيح لكل قفل', () {
    for (var seed = 1; seed < 40; seed++) {
      final p = generatePuzzles(seed);
      const all = ['keypad', 'wires', 'cipher', 'maze', 'lights', 'dial', 'radio'];
      for (var i = 0; i < all.length; i++) {
        final s = GameState(seed: seed, phase: 'playing', rooms: all, room: i);
        final lines = botScript(s, p);
        expect(lines, isNotEmpty);
        final last = lines.last;
        switch (s.roomId) {
          case 'keypad':
            expect(last.replaceAll(' ', ''), contains(p.keypad.answer));
          case 'wires':
            expect(last, contains('${p.wires.answer + 1}'));
          case 'cipher':
            expect(last, contains(p.cipher.answer));
          case 'radio':
            expect(last, contains('${p.radio.answer}'));
          case 'dial':
            expect(last, contains('${p.dial.answer[0]}'));
        }
        expect(botKey(s), isNotEmpty);
      }
    }
  });

  test('ردود الرسائل السريعة', () {
    final script = ['أ', 'ب', 'الجواب'];
    expect(botReply('code', script, 1), 'الجواب');
    expect(botReply('repeat', script, 2), 'ب');
    expect(botReply('unknown', script, 0), isNull);
  });
}
