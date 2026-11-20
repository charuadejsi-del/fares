// المراحل: 3 خرائط × 20 مرحلة = 60 مرحلة في الحملة، ثم الخريطة الاحترافية بلا نهاية.
// لكل مرحلة هوية: اسم وقصّة، أقفال خاصة بها، مؤثّرات، وطريقة فتح للخزنة الأخيرة.
// لا تتكرّر مرحلتان في الحملة. الأقفال ثابتة عند كل اللاعبين، والألغاز داخلها تتغيّر في كل محاولة.
import 'dart:math';
import 'dart:ui';

import 'ext_locks.dart';
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

// ───── المؤثّرات ─────
class ModInfo {
  final String title;
  final String icon;
  final String desc;
  const ModInfo(this.title, this.icon, this.desc);
}

const Map<String, ModInfo> kModInfo = {
  'blackout': ModInfo('انقطاع الكهرباء', '🌑', 'شاشة العميل تظلم وتومض بين حين وآخر.'),
  'alarm': ModInfo('الإنذار', '🚨', 'كل خطأ يكلّف أكثر من الذي قبله.'),
  'torn': ModInfo('الدليل الممزّق', '📄', 'بعض أسطر ملفّ المحلّل ممحوّة، وترتيبها مبعثر.'),
  'decoy': ModInfo('الملفّات المزيّفة', '🎭', 'عند المحلّل ملفّان لكل قفل جديد؛ الرقم التسلسلي عند العميل يحدّد الصحيح.'),
  'limited': ModInfo('محاولات محدودة', '❤️', 'ثلاثة أخطاء فقط مسموحة في المهمّة كلّها.'),
  'swap': ModInfo('تبادل الأدوار', '🔄', 'في منتصف المهمّة يتبادل العميل والمحلّل دوريهما.'),
  'silent': ModInfo('الصمت التامّ', '🔇', 'الميكروفون مقفل: الرسائل السريعة فقط.'),
};

/// المرحلة التي يظهر فيها كل مؤثّر لأول مرّة.
const Map<String, int> _modIntro = {
  'blackout': 6, 'alarm': 10, 'torn': 15, 'decoy': 19, 'limited': 25, 'swap': 30, 'silent': 35,
};

/// المرحلة التي يظهر فيها كل قفل لأول مرّة.
const Map<String, int> _lockIntro = {
  'switches': 2, 'equation': 3, 'clock': 4, 'morse': 5, 'flags': 7, 'dice': 8, 'shapes': 9,
  'dial': 11, 'scale': 12, 'anagram': 13, 'tiles': 14, 'suspect': 16, 'rings': 17, 'print': 18,
  'laser': 20, 'sync': 22, 'coords': 23, 'melody': 24, 'radio': 26, 'pipes': 27, 'mix': 29,
  'circuit': 31, 'lamps': 33, 'chess': 40, 'sonar': 60,
};

/// أقفال الزعماء: لا تظهر في الحملة إلا عند زعيمها.
const Map<String, int> _bossLock = {'laser': 20, 'chess': 40, 'sonar': 60};

// ───── القصص ─────
const List<List<String>> _names = [
  [
    'رصيف التهريب', 'مخزن الحاويات', 'برج المراقبة', 'سفينة الأشباح', 'مكتب الجمارك',
    'قبو المنارة', 'سوق السمك', 'حوض الإصلاح', 'زورق الليل', 'مستودع الملح',
    'نفق الأرصفة', 'رافعة الحديد', 'غرفة اللاسلكي', 'مقهى البحّارة', 'خزانة القبطان',
    'الحاوية 707', 'مرسى الصيّادين', 'ورشة الشباك', 'بوّابة الميناء', 'عرش القرصان',
  ],
  [
    'جسر الصخور', 'طاحونة الماء', 'كوخ الصيّاد', 'محطّة الضخّ', 'سدّ الوادي',
    'قارب النهر', 'كهف الشلّال', 'قنطرة الرومان', 'مزرعة القصب', 'معمل الطين',
    'منبع العين', 'بيت الحارس', 'مخيّم الرحّالة', 'معصرة الزيتون', 'نفق القناة',
    'جزيرة القصب', 'برج الحمام', 'مخزن الحبوب', 'صخرة الصدى', 'قصر السدّ',
  ],
  [
    'ممرّ الذئاب', 'قرية الحجارة', 'منجم النحاس', 'دير الثلوج', 'كهف الخفافيش',
    'معسكر الجبل', 'مرصد النجوم', 'قلعة الضباب', 'جسر الحبال', 'مغارة الكنز',
    'محطّة التلفريك', 'حصن الأجداد', 'برج الإشارة', 'ملجأ الرعاة', 'نفق القطار',
    'قمّة الريح', 'سجن الصخر', 'مخبأ الأرشيف', 'بوّابة الرياح', 'عرين النسر',
  ],
];

const List<String> _goals = [
  'استعِد الملفّ المسروق قبل أن يُنقل',
  'افتح خزنة المهرّب واجمع الأدلّة',
  'عطّل جهاز الإنذار وأنقذ الرهينة',
  'اعترض الرسالة قبل وصولها إلى الزعيم',
  'استعِد المفتاح الذهبي من الخزنة',
  'اكشف هويّة العميل المزدوج',
  'أوقف الشحنة المشبوهة الليلة',
  'استرجع الخريطة الأصلية',
];

class StageDef {
  final int n;
  final String name;
  final List<String> rooms;
  final String diff;
  final bool boss;
  final int seed;
  final String story;
  final List<String> mods;

  /// القفل الجديد الذي يظهر أول مرّة في هذه المرحلة.
  final String? newLock;

  /// المؤثّر الجديد الذي يظهر أول مرّة في هذه المرحلة.
  final String? newMod;

  const StageDef(this.n, this.name, this.rooms, this.diff, this.boss, this.seed,
      {this.story = '', this.mods = const [], this.newLock, this.newMod});

  bool get pro => n > kCampaignStages;

  /// مراحل المسابقة في الخريطة الاحترافية: كل 20 مرحلة (80، 100، 120…).
  bool get milestone => pro && n % kStagesPerMap == 0;

  Region get region => pro ? kProRegion : kRegions[(n - 1) ~/ kStagesPerMap];

  /// طريقة فتح الخزنة الأخيرة (آخر قفل).
  String get finale => rooms.last;

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

/// مؤثّرات المرحلة (0 = مهمّة حرّة بلا مؤثّرات).
List<String> stageMods(int n) => n <= 0 ? const [] : stageDef(n).mods;

List<StageDef>? _campaign;

StageDef stageDef(int n) {
  if (n <= kCampaignStages) {
    _campaign ??= _buildCampaign();
    return _campaign![(n.clamp(1, kCampaignStages)) - 1];
  }
  return _buildStage(n, 0);
}

List<StageDef> _buildCampaign() {
  final out = <StageDef>[];
  final seen = <String>{};
  for (int n = 1; n <= kCampaignStages; n++) {
    var d = _buildStage(n, 0);
    for (int k = 1; k < 60 && !seen.add(_sig(d)); k++) {
      d = _buildStage(n, k);
    }
    out.add(d);
  }
  return out;
}

String _sig(StageDef d) => '${([...d.rooms.sublist(0, d.rooms.length - 1)]..sort()).join(',')}|${d.finale}|${([...d.mods]..sort()).join(',')}';

StageDef _buildStage(int n, int variant) {
  final seed = 7919 * n + 104729;
  final r = Rng(seed + variant * 15485863);
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

  // الأقفال المتاحة حتى هذه المرحلة
  final available = <String>[
    ...kRooms,
    for (final e in _lockIntro.entries)
      if (pro || (e.value <= n && (!_bossLock.containsKey(e.key) || _bossLock[e.key] == n))) e.key,
  ];
  final String? newLock = pro ? null : _firstKey(_lockIntro, n);

  // العدد: يتصاعد داخل كل منطقة
  final count = boss ? 7 : (pro ? 5 + local % 3 : min(6, 3 + local ~/ 4 + (n > 20 ? 1 : 0)));

  // الخزنة الأخيرة
  final finales = <String>[
    if (n >= 4) kVaultCode,
    if (pro || n >= 11) 'dial',
    if (pro || n >= 17) 'rings',
    if (pro || n >= 22) 'sync',
    if (pro || n >= 33) 'lamps',
  ];
  final String finale;
  if (boss) {
    finale = kVaultCode;
  } else if (finales.isEmpty) {
    finale = '';
  } else {
    finale = finales[r.nextInt(finales.length)];
  }

  final rooms = <String>[];
  if (newLock != null && newLock != finale) rooms.add(newLock);
  if (boss && !pro) {
    for (final e in _bossLock.entries) {
      if (e.value == n && !rooms.contains(e.key)) rooms.add(e.key);
    }
  }
  // نفضّل الأقفال الحديثة (آخر ما ظهر) مع خليط من القديمة
  final recent = [for (final e in _lockIntro.entries) if (e.value <= n && e.value > n - 10 && available.contains(e.key)) e.key];
  final pool = r.shuffle(available);
  final ordered = [...r.shuffle(recent), ...pool];
  final need = (finale.isEmpty ? count : count - 1);
  for (final x in ordered) {
    if (rooms.length >= need) break;
    if (x == finale || rooms.contains(x)) continue;
    rooms.add(x);
  }
  final body = r.shuffle(rooms);
  // القفل الجديد أوّلاً حتى يتعلّمه اللاعبون مع شرحه
  if (newLock != null && body.contains(newLock)) {
    body
      ..remove(newLock)
      ..insert(0, newLock);
  }
  final finalRooms = [...body, if (finale.isNotEmpty) finale];

  // المؤثّرات
  final modsAvail = [for (final e in _modIntro.entries) if (pro || e.value <= n) e.key];
  final String? newMod = pro ? null : _firstKey(_modIntro, n);
  final modCount = modsAvail.isEmpty ? 0 : (boss ? 2 : (pro ? 1 + local % 2 : (local % 3 == 0 ? 0 : 1)));
  final mods = <String>[if (newMod != null) newMod];
  final modTarget = max(modCount, mods.length);
  for (final m in r.shuffle(modsAvail)) {
    if (mods.length >= modTarget) break;
    if (!mods.contains(m)) mods.add(m);
  }

  final region = pro ? kProRegion : kRegions[(n - 1) ~/ kStagesPerMap];
  final place = pro ? 'العاصمة — الملفّ ${n - kCampaignStages}' : _names[(n - 1) ~/ kStagesPerMap][local];
  final name = boss ? 'الزعيم: $place' : place;
  final goal = _goals[(seed + variant) % _goals.length];
  final story = boss
      ? 'مواجهة ${region.name}: الزعيم يحرس خزنته الكبرى. $goal.'
      : '${region.name} — $place: $goal.';
  return StageDef(n, name, finalRooms, diff, boss, seed, story: story, mods: mods, newLock: newLock, newMod: newMod);
}

String? _firstKey(Map<String, int> m, int n) {
  for (final e in m.entries) {
    if (e.value == n) return e.key;
  }
  return null;
}
