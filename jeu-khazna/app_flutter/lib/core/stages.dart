// المراحل: 3 خرائط × 20 مرحلة = 60 مرحلة في الحملة، ثم الخريطة الاحترافية بلا نهاية.
// أقفال كل مرحلة ثابتة عند كل اللاعبين، أما الألغاز داخلها فتتغيّر في كل محاولة.
import 'dart:math';
import 'dart:ui';

import 'game.dart';

const int kStagesPerMap = 20;
const int kCampaignStages = 60;

class Region {
  final String name;
  final String image;
  final Color color;
  const Region(this.name, this.image, this.color);
}

const List<Region> kRegions = [
  Region('الميناء', 'assets/images/map.jpg', Color(0xFF00FF9C)),
  Region('النهر', 'assets/images/map2.jpg', Color(0xFF00E5FF)),
  Region('الجبل', 'assets/images/map3.jpg', Color(0xFFFFB020)),
];
const Region kProRegion = Region('العاصمة', 'assets/images/map4.jpg', Color(0xFFFF3B4E));

class StageDef {
  final int n;
  final String name;
  final List<String> rooms;
  final String diff;
  final bool boss;
  final int seed;
  const StageDef(this.n, this.name, this.rooms, this.diff, this.boss, this.seed);

  bool get pro => n > kCampaignStages;

  /// مراحل المسابقة في الخريطة الاحترافية: كل 20 مرحلة (80، 100، 120…).
  bool get milestone => pro && n % kStagesPerMap == 0;

  Region get region => pro ? kProRegion : kRegions[(n - 1) ~/ kStagesPerMap];

  /// مكافأة العملات عند النجاح.
  int coinsFor(int stars) => pro ? 20 + (n - kCampaignStages) ~/ 2 + stars * 10 : stars * 5;
}

/// رقم الصفحة (الخريطة) التي تقع فيها المرحلة، بدءاً من 0.
int pageOf(int n) => (n - 1) ~/ kStagesPerMap;

/// موضع المرحلة على صورة الخريطة (نسبي 0..1): مسار متعرّج من الأسفل إلى الأعلى.
Offset stagePos(int n) {
  final local = (n - 1) % kStagesPerMap;
  final y = 0.94 - local * (0.86 / (kStagesPerMap - 1));
  final x = 0.5 + 0.30 * sin(local * 1.15 + pageOf(n) * 0.7);
  return Offset(x, y);
}

StageDef stageDef(int n) {
  final seed = 7919 * n + 104729;
  final local = (n - 1) % kStagesPerMap;
  final boss = local == kStagesPerMap - 1;
  final pro = n > kCampaignStages;
  final diff = pro
      ? 'master'
      : n <= 20
          ? 'recruit'
          : n <= 40
              ? 'agent'
              : 'elite';
  final available = <String>[
    ...kRooms,
    if (pro || n >= 11) 'dial',
    if (pro || n >= 26) 'radio',
  ];
  final int count;
  if (boss) {
    count = available.length;
  } else if (pro) {
    count = min(available.length, 5 + local % 3);
  } else {
    count = min(available.length, 3 + local ~/ 5);
  }
  var rooms = Rng(seed).shuffle(available).sublist(0, count);
  // المرحلة التي يظهر فيها قفل جديد لأول مرة يجب أن تحتويه
  if (n == 11 && !rooms.contains('dial')) rooms = ['dial', ...rooms.sublist(1)];
  if (n == 26 && !rooms.contains('radio')) rooms = ['radio', ...rooms.sublist(1)];
  final region = pro ? kProRegion : kRegions[(n - 1) ~/ kStagesPerMap];
  final name = pro
      ? (boss ? 'زعيم العاصمة $n' : 'العاصمة $n')
      : (boss ? 'زعيم ${region.name}' : '${region.name} ${local + 1}');
  return StageDef(n, name, rooms, diff, boss, seed);
}
