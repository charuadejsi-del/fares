import 'package:flutter_test/flutter_test.dart';
import 'package:khazna/core/ext_locks.dart';
import 'package:khazna/core/game.dart';
import 'package:khazna/core/stages.dart';

void main() {
  test('المراحل: 60 مرحلة فريدة ثم الاحترافية', () {
    final sigs = <String>{};
    final seenLocks = <String>{};
    for (int n = 1; n <= 200; n++) {
      final d = stageDef(n);
      expect(d.rooms.length, inInclusiveRange(3, 7), reason: 'stage $n');
      expect(d.rooms.toSet().length, d.rooms.length, reason: 'stage $n ${d.rooms}');
      for (final r in d.rooms) {
        expect(kAllRooms.contains(r) || isExtRoom(r), isTrue, reason: r);
      }
      if (n <= kCampaignStages) {
        expect(sigs.add('${d.rooms.join(',')}|${d.mods.join(',')}'), isTrue, reason: 'duplicate stage $n');
        if (d.newLock != null) expect(d.rooms.contains(d.newLock), isTrue, reason: 'stage $n new ${d.newLock}');
        if (d.newMod != null) expect(d.mods.contains(d.newMod), isTrue);
        seenLocks.addAll(d.rooms);
        expect(d.story, isNotEmpty);
      }
      if (n < 11) expect(d.rooms.contains('dial'), isFalse);
      if (n < 26) expect(d.rooms.contains('radio'), isFalse);
      if (n <= kCampaignStages && n != 20) expect(d.rooms.contains('laser'), isFalse, reason: 'boss lock at $n');
      if (n <= kCampaignStages && n != 40) expect(d.rooms.contains('chess'), isFalse);
      if (n <= kCampaignStages && n != 60) expect(d.rooms.contains('sonar'), isFalse);
      final pos = stagePos(n);
      expect(pos.dx, inInclusiveRange(0.1, 0.9));
      expect(pos.dy, inInclusiveRange(0.05, 0.95));
    }
    // كل الأقفال الثلاثين تظهر في الحملة
    for (final r in [...kAllRooms, ...kExtRooms]) {
      expect(seenLocks.contains(r), isTrue, reason: 'never used: $r');
    }
    expect(stageDef(11).rooms.contains('dial'), isTrue);
    expect(stageDef(26).rooms.contains('radio'), isTrue);
    expect(stageDef(20).boss, isTrue);
    expect(stageDef(20).finale, kVaultCode);
    expect(stageDef(60).region.name, 'الجبل');
    expect(stageDef(61).pro, isTrue);
    expect(stageDef(120).milestone, isTrue);
    expect(stageDef(5).diff, 'recruit');
    expect(stageDef(30).diff, 'agent');
    expect(stageDef(50).diff, 'elite');
    expect(stageDef(70).diff, 'master');
    expect(stageMods(0), isEmpty);
  });
}
