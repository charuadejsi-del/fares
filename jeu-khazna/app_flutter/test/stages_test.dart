import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/game.dart';
import 'package:khazna/core/stages.dart';

void main() {
  test('المراحل: 3 خرائط × 20 ثم الاحترافية', () {
    for (int n = 1; n <= 200; n++) {
      final d = stageDef(n);
      expect(d.rooms.length, inInclusiveRange(3, 7), reason: 'stage $n');
      expect(d.rooms.toSet().length, d.rooms.length);
      for (final r in d.rooms) {
        expect(kAllRooms.contains(r), isTrue);
      }
      if (n < 11) expect(d.rooms.contains('dial'), isFalse);
      if (n < 26) expect(d.rooms.contains('radio'), isFalse);
      final pos = stagePos(n);
      expect(pos.dx, inInclusiveRange(0.1, 0.9));
      expect(pos.dy, inInclusiveRange(0.05, 0.95));
    }
    expect(stageDef(11).rooms.contains('dial'), isTrue);
    expect(stageDef(26).rooms.contains('radio'), isTrue);
    expect(stageDef(20).boss, isTrue);
    expect(stageDef(60).region.name, 'الجبل');
    expect(stageDef(61).pro, isTrue);
    expect(stageDef(120).milestone, isTrue);
    expect(stageDef(5).diff, 'recruit');
    expect(stageDef(30).diff, 'agent');
    expect(stageDef(50).diff, 'elite');
    expect(stageDef(70).diff, 'master');
  });
}
