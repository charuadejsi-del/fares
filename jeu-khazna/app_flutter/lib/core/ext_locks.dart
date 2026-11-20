// الأقفال الموسّعة (23 قفلاً + الخزنة الأخيرة): لكل قفل ما يراه العميل، وملفّ المحلّل، وطريقة الإدخال، والحلّ.
// كل شيء حتمي من البذرة: نفس البذرة تعطي نفس القفل عند اللاعبَين.
import 'game.dart';

/// معرّفات الأقفال الجديدة بترتيب ظهورها في الحملة.
const List<String> kExtRooms = [
  'switches', 'equation', 'clock', 'morse', 'flags', 'dice', 'shapes', 'scale', 'anagram', 'tiles',
  'suspect', 'rings', 'print', 'sync', 'coords', 'melody', 'laser', 'pipes', 'mix', 'circuit',
  'lamps', 'chess', 'sonar',
];

/// قفل الخزنة الأخيرة: رمز يُجمع من أرقام الأقفال السابقة.
const String kVaultCode = 'vaultcode';

bool isExtRoom(String id) => id == kVaultCode || kExtRooms.contains(id);

class ExtInfo {
  final String title;
  final String icon; // رمز تعبيري
  final String how; // شرح قصير يظهر عند أول لقاء
  const ExtInfo(this.title, this.icon, this.how);
}

const Map<String, ExtInfo> kExtInfo = {
  'switches': ExtInfo('لوحة المفاتيح', '🎚', 'العميل يصف لون كل مفتاح ورمزه، والمحلّل يقول أيّها يُشغَّل حسب الجدول.'),
  'equation': ExtInfo('معادلة الرموز', '➗', 'لكل رمز قيمة سرّية في ملفّ المحلّل. احسبا ناتج المعادلة.'),
  'clock': ExtInfo('ساعة البرج', '🕰', 'العميل يقرأ الساعة والرمز في وسطها، والمحلّل يعرف كم تُقدَّم أو تُؤخَّر.'),
  'morse': ExtInfo('شفرة مورس', '📻', 'ومضات قصيرة وطويلة. الجدول عند المحلّل يحوّلها إلى أرقام.'),
  'flags': ExtInfo('أعلام السفارات', '🚩', 'صِف ألوان كل علم واتجاه خطوطه، فيجد المحلّل رقمه.'),
  'dice': ExtInfo('نرد المهرّبين', '🎲', 'لون كل نرد يغيّر قيمته حسب قاعدة في ملفّ المحلّل.'),
  'shapes': ExtInfo('الأشكال الهندسية', '📐', 'عدّ الأضلاع وطريقة التلوين، والقاعدة عند المحلّل.'),
  'scale': ExtInfo('الميزان', '⚖️', 'أوزان الرموز سرّية. اختر الثقل الذي يعادل الكفّة.'),
  'anagram': ExtInfo('الحروف المبعثرة', '🔤', 'الحروف تكوّن كلمة من قائمة المحلّل، ولكل كلمة رمز.'),
  'tiles': ExtInfo('البلاطات', '🧩', 'اضغط البلاطات بالترتيب الذي يحدّده المحلّل من قيمها.'),
  'suspect': ExtInfo('ملف المشتبه', '🔍', 'صِف وجه المشتبه به، والمحلّل يجد رقم ملفّه.'),
  'rings': ExtInfo('الحلقات الدوّارة', '💍', 'أدِر كل حلقة إلى الرمز المطلوب حسب لونها.'),
  'print': ExtInfo('البصمات', '🖐', 'المحلّل يصف بصمة الجاني، والعميل يختارها من بين ست.'),
  'sync': ExtInfo('المفتاحان', '🗝', 'قفل تعاوني: يُدار المفتاحان معاً في اللحظة نفسها (فرق أقلّ من ثانية ونصف).'),
  'coords': ExtInfo('الإحداثيات', '🗺', 'العميل يرى معالم حوله، والمحلّل يجد مكانه في جدول الخريطة.'),
  'melody': ExtInfo('اللحن السرّي', '🎹', 'استمع للّحن، والمحلّل يحوّل كل نغمة حسب الآلة.'),
  'laser': ExtInfo('الليزر والمرايا', '🔦', 'وجّه كل مرآة حسب لونها وحرف الهدف.'),
  'pipes': ExtInfo('الأنابيب', '🚰', 'اتبع الخلايا الآمنة من البداية إلى النهاية؛ الرموز الآمنة عند المحلّل.'),
  'mix': ExtInfo('مزج الألوان', '🧪', 'صِف لون العيّنة، والمحلّل يعطيك وصفة المزج.'),
  'circuit': ExtInfo('الدائرة الكهربائية', '⚡', 'وصّل كل طرف ملوّن بالرمز الصحيح حسب مخطّط المحلّل.'),
  'lamps': ExtInfo('المصابيح التسعة', '💡', 'أطفئ كل المصابيح. أيّ الأزرار تُضغط؟ الجواب في سجلّ المحلّل.'),
  'chess': ExtInfo('رقعة الشطرنج', '♞', 'قطع هذه العملية تتحرّك بطريقة غريبة. أيّ خانة يصلها الحجر؟'),
  'sonar': ExtInfo('السونار', '📡', 'حدّد اتجاه الغوّاصة من الأصداء وتصحيح المحلّل.'),
  kVaultCode: ExtInfo('باب الخزنة', '🔐', 'كل قفل فتحتماه كشف رقماً. رتّبا الأرقام حسب ملفّ المحلّل.'),
};

String roomTitle(String id, Map<String, String> classic) => classic[id] ?? kExtInfo[id]?.title ?? id;

// ───── النماذج ─────
/// عنصر يراه العميل الميداني.
class OpItem {
  final String kind;
  final List<String> glyphs;
  final List<int> nums;
  final String text;
  final int cols;
  const OpItem(this.kind, {this.glyphs = const [], this.nums = const [], this.text = '', this.cols = 0});
}

/// صفحة في ملفّ المحلّل. خلية تبدأ بـ «#c:» تُرسم كمربّع لون (والباقي رقم ARGB).
class ManualPage {
  final List<String> rules;
  final List<String> header;
  final List<List<String>> rows;
  final Set<int> keyRows;
  const ManualPage({this.rules = const [], this.header = const [], this.rows = const [], this.keyRows = const {}});
}

/// طريقة الإدخال عند العميل.
class InputSpec {
  /// digits | choice | seq | toggles | cyclers | grid | gridseq | sync
  final String kind;
  final int len;
  final List<String> labels;
  final List<int> colors;
  final List<List<String>> options;
  final int cols;
  const InputSpec(this.kind, {this.len = 0, this.labels = const [], this.colors = const [], this.options = const [], this.cols = 0});
}

class ExtPuzzle {
  final String id;
  final String serial;
  final List<OpItem> op;
  final ManualPage manual;
  final InputSpec input;
  final String answer;
  final String hint;
  final List<String> bot;

  /// للمفتاحين: الثقب الصحيح عند المحلّل.
  final int exAnswer;

  /// تحقّق مخصّص (المصابيح: أي حلّ صحيح يُقبل).
  final bool Function(String v)? checker;

  const ExtPuzzle({
    required this.id,
    required this.serial,
    required this.op,
    required this.manual,
    required this.input,
    required this.answer,
    required this.hint,
    required this.bot,
    this.exAnswer = -1,
    this.checker,
  });

  bool check(String v) => checker != null ? checker!(v) : v.trim() == answer;
}

// ───── أدوات ─────
int _hash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

int _level(String diff) => switch (diff) { 'recruit' => 0, 'agent' => 1, 'elite' => 2, _ => 3 };

String _sym(int i) => '${kSymbols[i].s} ${kSymbols[i].n}';
String _c(int i) => kColors[i].n;
String _l(int i) => kLights[i].n;
String _swatch(int argb) => '#c:$argb';
String _pad(int v, int n) => v.toString().padLeft(n, '0');
const String _letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';

List<int> _distinct(Rng r, int n, int pool) => r.shuffle([for (int i = 0; i < pool; i++) i]).sublist(0, n);

final Map<String, ExtPuzzle> _cache = {};

/// القفل الموسّع للغرفة الحالية.
ExtPuzzle extFor(GameState s) => extPuzzle(s.roomId, s.seed, s.diff, room: s.room, rooms: s.rooms);

ExtPuzzle extPuzzle(String id, int seed, String diff, {int room = 0, List<String> rooms = const []}) {
  final key = '$id:$seed:$diff:$room:${rooms.join(",")}';
  final hit = _cache[key];
  if (hit != null) return hit;
  if (_cache.length > 300) _cache.clear();
  final r = Rng((seed ^ _hash(id) ^ (room * 7919)) & 0x7fffffff);
  final lv = _level(diff);
  final serial = '${_letters[r.nextInt(_letters.length)]}${1 + r.nextInt(9)}';
  final p = switch (id) {
    'switches' => _switches(r, lv, serial),
    'equation' => _equation(r, lv, serial),
    'clock' => _clock(r, lv, serial),
    'morse' => _morse(r, lv, serial),
    'flags' => _flags(r, lv, serial),
    'dice' => _dice(r, lv, serial),
    'shapes' => _shapes(r, lv, serial),
    'scale' => _scale(r, lv, serial),
    'anagram' => _anagram(r, lv, serial),
    'tiles' => _tiles(r, lv, serial),
    'suspect' => _suspect(r, lv, serial),
    'rings' => _rings(r, lv, serial),
    'print' => _print(r, lv, serial),
    'sync' => _sync(r, lv, serial),
    'coords' => _coords(r, lv, serial),
    'melody' => _melody(r, lv, serial),
    'laser' => _laser(r, lv, serial),
    'pipes' => _pipes(r, lv, serial),
    'mix' => _mix(r, lv, serial),
    'circuit' => _circuit(r, lv, serial),
    'lamps' => _lamps(r, lv, serial),
    'chess' => _chess(r, lv, serial),
    'sonar' => _sonar(r, lv, serial),
    _ => _vault(seed, rooms, room, r, serial),
  };
  _cache[key] = p;
  return p;
}

// ───── 1. لوحة المفاتيح ─────
ExtPuzzle _switches(Rng r, int lv, String serial) {
  final n = 5 + (lv >= 2 ? 2 : lv);
  // لكل لون مجموعة رموز تعني «شغّل»
  final onSets = [for (int c = 0; c < kColors.length; c++) _distinct(r, 4, kSymbols.length).toSet()];
  List<int> colors, glyphs;
  String bits;
  do {
    colors = [for (int i = 0; i < n; i++) r.nextInt(kColors.length)];
    glyphs = [for (int i = 0; i < n; i++) r.nextInt(kSymbols.length)];
    bits = [for (int i = 0; i < n; i++) onSets[colors[i]].contains(glyphs[i]) ? '1' : '0'].join();
  } while (!bits.contains('1') || !bits.contains('0'));
  return ExtPuzzle(
    id: 'switches',
    serial: serial,
    op: [OpItem('switches', nums: [...colors, ...glyphs], cols: n)],
    manual: ManualPage(
      rules: ['المفتاح يُشغَّل إذا كان رمزه ضمن قائمة لونه. وإلا يبقى مطفأً.'],
      header: ['لون المفتاح', 'شغّله إذا كان رمزه'],
      rows: [for (int c = 0; c < kColors.length; c++) [_c(c), onSets[c].map((i) => kSymbols[i].s).join('  ')]],
      keyRows: colors.toSet(),
    ),
    input: InputSpec('toggles', labels: [for (int i = 0; i < n; i++) '${i + 1}']),
    answer: bits,
    hint: 'المفاتيح المشغّلة: ${[for (int i = 0; i < n; i++) if (bits[i] == '1') '${i + 1}'].join('، ')}',
    bot: [
      'صِف لي كل مفتاح: لونه ورمزه… أفتح جدول الألوان.',
      'أراجع القوائم: ${[for (int i = 0; i < n; i++) '${i + 1}=${_c(colors[i])}/${kSymbols[glyphs[i]].s}'].join('، ')}',
      'شغّل المفاتيح: ${[for (int i = 0; i < n; i++) if (bits[i] == '1') '${i + 1}'].join('، ')} واترك الباقي.',
    ],
  );
}

// ───── 2. معادلة الرموز ─────
ExtPuzzle _equation(Rng r, int lv, String serial) {
  final vals = [for (int i = 0; i < kSymbols.length; i++) 1 + r.nextInt(9)];
  final ops = lv == 0 ? ['+', '−'] : ['+', '−', '×'];
  late List<int> s;
  late List<String> o;
  late int res;
  do {
    s = [for (int i = 0; i < 3; i++) r.nextInt(kSymbols.length)];
    o = [ops[r.nextInt(ops.length)], ops[r.nextInt(ops.length)]];
    final a = vals[s[0]], b = vals[s[1]], c = vals[s[2]];
    int ap(int x, String op, int y) => op == '+' ? x + y : (op == '−' ? x - y : x * y);
    // الضرب أولاً
    if (o[1] == '×' && o[0] != '×') {
      res = ap(a, o[0], b * c);
    } else {
      res = ap(ap(a, o[0], b), o[1], c);
    }
  } while (res < 0 || res > 999);
  return ExtPuzzle(
    id: 'equation',
    serial: serial,
    op: [OpItem('equation', glyphs: [kSymbols[s[0]].s, o[0], kSymbols[s[1]].s, o[1], kSymbols[s[2]].s])],
    manual: ManualPage(
      rules: ['عوّض كل رمز بقيمته ثم احسب. الضرب قبل الجمع والطرح.'],
      header: ['الرمز', 'القيمة'],
      rows: [for (int i = 0; i < kSymbols.length; i++) [_sym(i), '${vals[i]}']],
      keyRows: s.toSet(),
    ),
    input: const InputSpec('digits', len: 0),
    answer: '$res',
    hint: 'الناتج من ${'$res'.length} أرقام ويبدأ بـ ${'$res'[0]}',
    bot: [
      'اقرأ لي المعادلة رمزاً رمزاً…',
      '${kSymbols[s[0]].s}=${vals[s[0]]}، ${kSymbols[s[1]].s}=${vals[s[1]]}، ${kSymbols[s[2]].s}=${vals[s[2]]}. أحسب…',
      'الناتج: $res',
    ],
  );
}

// ───── 3. ساعة البرج ─────
ExtPuzzle _clock(Rng r, int lv, String serial) {
  final h = 1 + r.nextInt(12), m = r.nextInt(12) * 5;
  final glyphs = _distinct(r, 6, kSymbols.length);
  final offs = [for (int i = 0; i < 6; i++) (r.nextInt(2) == 0 ? -1 : 1) * (5 * (1 + r.nextInt(11)) + 60 * r.nextInt(lv + 1))];
  final pick = r.nextInt(6);
  var total = (h % 12) * 60 + m + offs[pick];
  total = ((total % 720) + 720) % 720;
  var nh = total ~/ 60;
  if (nh == 0) nh = 12;
  final ans = '${_pad(nh, 2)}${_pad(total % 60, 2)}';
  String fmt(int o) => '${o > 0 ? 'قدّم' : 'أخّر'} ${o.abs() ~/ 60 > 0 ? '${o.abs() ~/ 60} س و' : ''}${o.abs() % 60} د';
  return ExtPuzzle(
    id: 'clock',
    serial: serial,
    op: [OpItem('clock', nums: [h, m, glyphs[pick]])],
    manual: ManualPage(
      rules: ['الرمز في وسط الساعة يحدّد التعديل. أدخل الوقت الجديد بأربعة أرقام (ساعة 01–12 ثم الدقائق).'],
      header: ['الرمز في الوسط', 'التعديل'],
      rows: [for (int i = 0; i < 6; i++) [_sym(glyphs[i]), fmt(offs[i])]],
      keyRows: {pick},
    ),
    input: const InputSpec('digits', len: 4),
    answer: ans,
    hint: 'الساعة الجديدة تبدأ بـ ${ans.substring(0, 2)}',
    bot: [
      'كم تشير الساعة؟ وما الرمز في وسطها؟',
      'الرمز ${kSymbols[glyphs[pick]].s}: ${fmt(offs[pick])}. الساعة الآن ${_pad(h, 2)}:${_pad(m, 2)}…',
      'أدخل الوقت: ${ans.substring(0, 2)} ${ans.substring(2)}',
    ],
  );
}

// ───── 4. شفرة مورس ─────
ExtPuzzle _morse(Rng r, int lv, String serial) {
  final all = <String>[
    for (int b = 0; b < 16; b++) [for (int k = 3; k >= 0; k--) (b >> k) & 1 == 1 ? '-' : '.'].join()
  ];
  final pats = r.shuffle(all).sublist(0, 10);
  final n = lv >= 2 ? 5 : 4;
  final digits = [for (int i = 0; i < n; i++) r.nextInt(10)];
  String pretty(String p) => p.replaceAll('.', '•').replaceAll('-', '▬');
  return ExtPuzzle(
    id: 'morse',
    serial: serial,
    op: [OpItem('flash', glyphs: [for (final d in digits) pats[d]])],
    manual: ManualPage(
      rules: ['• ومضة قصيرة، ▬ ومضة طويلة. بين كل رقم وآخر توقّف. جدول هذه العملية خاص بها.'],
      header: ['الرقم', 'النبضات'],
      rows: [for (int d = 0; d < 10; d++) ['$d', pretty(pats[d])]],
      keyRows: digits.toSet(),
    ),
    input: InputSpec('digits', len: n),
    answer: digits.join(),
    hint: 'أوّل رقمين: ${digits.take(2).join()}',
    bot: [
      'عدّ لي الومضات القصيرة والطويلة لكل رقم…',
      'أطابق مع الجدول: ${[for (final d in digits) pretty(pats[d])].join(' | ')}',
      'الرمز: ${digits.join(' ')}',
    ],
  );
}

// ───── 5. أعلام السفارات ─────
ExtPuzzle _flags(Rng r, int lv, String serial) {
  final flags = <List<int>>[]; // [c1,c2,c3,orient]
  final seen = <String>{};
  while (flags.length < 10) {
    final cs = _distinct(r, 3, kColors.length);
    final f = [...cs, r.nextInt(2)];
    if (seen.add(f.join(','))) flags.add(f);
  }
  final n = lv >= 2 ? 4 : 3;
  final shown = [for (int i = 0; i < n; i++) r.nextInt(10)];
  String desc(List<int> f) => '${f[3] == 0 ? 'أفقي' : 'عمودي'}: ${_c(f[0])} / ${_c(f[1])} / ${_c(f[2])}';
  return ExtPuzzle(
    id: 'flags',
    serial: serial,
    op: [OpItem('flags', nums: [for (final i in shown) ...flags[i]])],
    manual: ManualPage(
      rules: ['الألوان من الأعلى إلى الأسفل (الأفقي) أو من اليمين إلى اليسار (العمودي).'],
      header: ['العلم', 'الرقم'],
      rows: [for (int d = 0; d < 10; d++) [desc(flags[d]), '$d']],
      keyRows: shown.toSet(),
    ),
    input: InputSpec('digits', len: n),
    answer: shown.join(),
    hint: 'العلم الأول = ${shown.first}',
    bot: [
      'صِف لي الأعلام بالترتيب: الاتجاه والألوان…',
      'وجدتها: ${[for (final i in shown) desc(flags[i])].join(' ؛ ')}',
      'الرمز: ${shown.join(' ')}',
    ],
  );
}

// ───── 6. نرد المهرّبين ─────
ExtPuzzle _dice(Rng r, int lv, String serial) {
  final rules = <String>[];
  final fns = <int Function(int)>[];
  for (int c = 0; c < 4; c++) {
    final t = r.nextInt(4), k = 1 + r.nextInt(5);
    switch (t) {
      case 0:
        rules.add('أضف $k');
        fns.add((v) => (v + k) % 10);
      case 1:
        rules.add('اضرب في 2 ثم أضف ${k - 1}');
        fns.add((v) => (v * 2 + k - 1) % 10);
      case 2:
        rules.add('اطرحه من 9');
        fns.add((v) => 9 - v);
      default:
        rules.add('كما هو');
        fns.add((v) => v);
    }
  }
  final n = 4;
  final vals = [for (int i = 0; i < n; i++) 1 + r.nextInt(6)];
  final cols = [for (int i = 0; i < n; i++) r.nextInt(4)];
  final digits = [for (int i = 0; i < n; i++) fns[cols[i]](vals[i])];
  return ExtPuzzle(
    id: 'dice',
    serial: serial,
    op: [OpItem('dice', nums: [for (int i = 0; i < n; i++) ...[vals[i], cols[i]]])],
    manual: ManualPage(
      rules: ['لون النرد يحدّد ما تفعله بعدد نقاطه. خذ آخر رقم فقط إن تجاوز الناتج 9.'],
      header: ['لون النرد', 'القاعدة'],
      rows: [for (int c = 0; c < 4; c++) [_l(c), rules[c]]],
      keyRows: cols.toSet(),
    ),
    input: InputSpec('digits', len: n),
    answer: digits.join(),
    hint: 'أوّل رقم: ${digits.first}',
    bot: [
      'كم نقطة على كل نرد وما لونه؟',
      'أطبّق القواعد: ${[for (int i = 0; i < n; i++) '${vals[i]} ${_l(cols[i])}→${digits[i]}'].join('، ')}',
      'الرمز: ${digits.join(' ')}',
    ],
  );
}

// ───── 7. الأشكال الهندسية ─────
const List<String> _shapeNames = ['', '', '', 'مثلث', 'مربّع', 'مخمّس', 'مسدّس', 'مسبّع', 'مثمّن'];

ExtPuzzle _shapes(Rng r, int lv, String serial) {
  final fill = r.nextInt(4), hollow = r.nextInt(4);
  final n = 4;
  final sides = [for (int i = 0; i < n; i++) 3 + r.nextInt(6)];
  final filled = [for (int i = 0; i < n; i++) r.nextInt(2)];
  final digits = [for (int i = 0; i < n; i++) (sides[i] + (filled[i] == 1 ? fill : -hollow) + 10) % 10];
  return ExtPuzzle(
    id: 'shapes',
    serial: serial,
    op: [OpItem('shapes', nums: [for (int i = 0; i < n; i++) ...[sides[i], filled[i]]])],
    manual: ManualPage(
      rules: [
        'عدد الأضلاع هو الأساس.',
        'الشكل المملوء: أضف $fill.',
        'الشكل المفرّغ: اطرح $hollow.',
        'إن صار الناتج أكبر من 9 خذ آحاده، وإن صار سالباً أضف 10.',
      ],
      header: ['الشكل', 'الأضلاع'],
      rows: [for (int k = 3; k <= 8; k++) [_shapeNames[k], '$k']],
    ),
    input: InputSpec('digits', len: n),
    answer: digits.join(),
    hint: 'آخر رقم: ${digits.last}',
    bot: [
      'صِف لي الأشكال: كم ضلعاً، ومملوءة أم مفرّغة؟',
      'المملوء +$fill، المفرّغ −$hollow… ${[for (int i = 0; i < n; i++) '${_shapeNames[sides[i]]}→${digits[i]}'].join('، ')}',
      'الرمز: ${digits.join(' ')}',
    ],
  );
}

// ───── 8. الميزان ─────
ExtPuzzle _scale(Rng r, int lv, String serial) {
  final syms = _distinct(r, 6, kSymbols.length);
  final w = [for (int i = 0; i < 6; i++) 1 + r.nextInt(9)];
  final k = 3 + (lv >= 2 ? 1 : 0);
  final left = [for (int i = 0; i < k; i++) r.nextInt(6)];
  final sum = left.fold<int>(0, (a, i) => a + w[i]);
  final opts = <int>{sum};
  while (opts.length < 4) {
    final d = sum + (r.nextInt(2) == 0 ? -1 : 1) * (1 + r.nextInt(6));
    if (d > 0) opts.add(d);
  }
  final list = r.shuffle(opts.toList());
  return ExtPuzzle(
    id: 'scale',
    serial: serial,
    op: [OpItem('scale', glyphs: [for (final i in left) kSymbols[syms[i]].s])],
    manual: ManualPage(
      rules: ['اجمع أوزان الرموز في الكفّة. على العميل أن يضع الثقل المساوي تماماً.'],
      header: ['الرمز', 'الوزن (كغ)'],
      rows: [for (int i = 0; i < 6; i++) [_sym(syms[i]), '${w[i]}']],
      keyRows: left.toSet(),
    ),
    input: InputSpec('choice', labels: [for (final v in list) '$v كغ']),
    answer: '${list.indexOf(sum)}',
    hint: 'الكفّة تزن $sum كغ',
    bot: [
      'ما الرموز الموضوعة في الكفّة؟',
      'أجمع: ${[for (final i in left) w[i]].join(' + ')}',
      'ضع ثقل $sum كغ.',
    ],
  );
}

// ───── 9. الحروف المبعثرة ─────
const List<String> _anaWords = [
  'مفتاح', 'سرداب', 'قنديل', 'حارس', 'صندوق', 'مخطوط', 'فارس', 'طريق', 'ظلام', 'خريطة',
  'جاسوس', 'عميل', 'رسالة', 'شفرة', 'قلعة', 'سفينة', 'ميناء', 'مخبأ', 'كتيبة', 'بوصلة',
];

ExtPuzzle _anagram(Rng r, int lv, String serial) {
  final words = r.shuffle(_anaWords).sublist(0, 10);
  final codes = r.shuffle([for (int i = 100; i < 1000; i += 37) i]).sublist(0, 10);
  final t = r.nextInt(10);
  final letters = r.shuffle(words[t].split(''));
  return ExtPuzzle(
    id: 'anagram',
    serial: serial,
    op: [OpItem('tiles', glyphs: letters)],
    manual: ManualPage(
      rules: ['رتّب الحروف لتكوّن كلمة من القائمة، ثم أعطِ العميل رمزها.'],
      header: ['الكلمة', 'الرمز'],
      rows: [for (int i = 0; i < 10; i++) [words[i], '${codes[i]}']],
      keyRows: {t},
    ),
    input: const InputSpec('digits', len: 3),
    answer: '${codes[t]}',
    hint: 'الكلمة تبدأ بـ «${words[t][0]}»',
    bot: [
      'ما الحروف المبعثرة أمامك؟',
      'هذه الحروف تكوّن «${words[t]}».',
      'رمزها: ${codes[t]}',
    ],
  );
}

// ───── 10. البلاطات ─────
ExtPuzzle _tiles(Rng r, int lv, String serial) {
  final n = lv >= 2 ? 6 : 5;
  final syms = _distinct(r, n + 2, kSymbols.length);
  final vals = r.shuffle([for (int i = 1; i <= 20; i++) i]).sublist(0, n + 2);
  final shown = r.shuffle([for (int i = 0; i < n; i++) i]);
  final asc = r.nextInt(2) == 0;
  final order = [for (int i = 0; i < n; i++) i]..sort((a, b) => asc ? vals[shown[a]] - vals[shown[b]] : vals[shown[b]] - vals[shown[a]]);
  return ExtPuzzle(
    id: 'tiles',
    serial: serial,
    op: const [],
    manual: ManualPage(
      rules: ['اضغط البلاطات ${asc ? 'من الأصغر قيمة إلى الأكبر' : 'من الأكبر قيمة إلى الأصغر'}.'],
      header: ['الرمز', 'القيمة'],
      rows: [for (int i = 0; i < n + 2; i++) [_sym(syms[i]), '${vals[i]}']],
      keyRows: shown.toSet(),
    ),
    input: InputSpec('seq', len: n, labels: [for (final i in shown) kSymbols[syms[i]].s], cols: 3),
    answer: order.join(','),
    hint: 'ابدأ بـ ${kSymbols[syms[shown[order.first]]].s}',
    bot: [
      'ما الرموز على البلاطات؟',
      'القيم: ${[for (final i in shown) '${kSymbols[syms[i]].s}=${vals[i]}'].join('، ')}',
      'اضغط بالترتيب: ${[for (final o in order) kSymbols[syms[shown[o]]].s].join(' ← ')}',
    ],
  );
}

// ───── 11. ملف المشتبه ─────
const List<String> _hats = ['بلا قبّعة', 'قبّعة رياضية', 'برنيطة'];

ExtPuzzle _suspect(Rng r, int lv, String serial) {
  final people = <List<int>>[]; // hair, glasses, hat, scar, eyes
  final seen = <String>{};
  while (people.length < 8) {
    final p = [r.nextInt(kColors.length), r.nextInt(2), r.nextInt(3), r.nextInt(2), r.nextInt(4)];
    if (seen.add(p.join(','))) people.add(p);
  }
  final codes = r.shuffle([for (int i = 10; i < 100; i += 7) i]).sublist(0, 8);
  final t = r.nextInt(8);
  final p = people[t];
  return ExtPuzzle(
    id: 'suspect',
    serial: serial,
    op: [OpItem('face', nums: p)],
    manual: ManualPage(
      rules: ['طابق كل الملامح. ملف واحد فقط يطابق تماماً.'],
      header: ['الملف', 'الشعر', 'نظّارة', 'القبّعة', 'ندبة', 'العيون'],
      rows: [
        for (int i = 0; i < 8; i++)
          [
            '${codes[i]}',
            _c(people[i][0]),
            people[i][1] == 1 ? 'نعم' : 'لا',
            _hats[people[i][2]],
            people[i][3] == 1 ? 'نعم' : 'لا',
            _l(people[i][4]),
          ]
      ],
      keyRows: {t},
    ),
    input: const InputSpec('digits', len: 2),
    answer: '${codes[t]}',
    hint: 'رقم الملف يبدأ بـ ${'${codes[t]}'[0]}',
    bot: [
      'صِف لي الوجه: الشعر، النظّارة، القبّعة، الندبة، العيون…',
      'شعر ${_c(p[0])}، ${_hats[p[2]]}، عيون ${_l(p[4])}… أبحث في الملفّات.',
      'إنه الملف رقم ${codes[t]}',
    ],
  );
}

// ───── 12. الحلقات الدوّارة ─────
ExtPuzzle _rings(Rng r, int lv, String serial) {
  final n = lv >= 2 ? 4 : 3;
  final ringSyms = _distinct(r, 6, kSymbols.length);
  final target = [for (int c = 0; c < kColors.length; c++) r.nextInt(6)];
  final colors = _distinct(r, n, kColors.length);
  final options = [for (int i = 0; i < n; i++) r.shuffle([for (final s in ringSyms) kSymbols[s].s])];
  final ans = [for (int i = 0; i < n; i++) options[i].indexOf(kSymbols[ringSyms[target[colors[i]]]].s)];
  return ExtPuzzle(
    id: 'rings',
    serial: serial,
    op: const [],
    manual: ManualPage(
      rules: ['أدِر كل حلقة حتى يظهر الرمز المقابل للونها.'],
      header: ['لون الحلقة', 'الرمز المطلوب'],
      rows: [for (int c = 0; c < kColors.length; c++) [_c(c), _sym(ringSyms[target[c]])]],
      keyRows: colors.toSet(),
    ),
    input: InputSpec('cyclers', options: options, colors: [for (final c in colors) kColors[c].argb]),
    answer: ans.join(','),
    hint: 'الحلقة الأولى: ${options[0][ans[0]]}',
    bot: [
      'ما ألوان الحلقات بالترتيب؟',
      'حسب الجدول: ${[for (final c in colors) '${_c(c)}→${kSymbols[ringSyms[target[c]]].s}'].join('، ')}',
      'أدِرها إلى: ${[for (int i = 0; i < n; i++) options[i][ans[i]]].join(' ، ')}',
    ],
  );
}

// ───── 13. البصمات ─────
const List<String> _printTypes = ['حلقيّة', 'دوّامية', 'قوسيّة'];

ExtPuzzle _print(Rng r, int lv, String serial) {
  final prints = <List<int>>[]; // type, marks(1..3), markColor
  final seen = <String>{};
  while (prints.length < 6) {
    final p = [r.nextInt(3), 1 + r.nextInt(3), r.nextInt(4)];
    if (seen.add(p.join(','))) prints.add(p);
  }
  final t = r.nextInt(6);
  final p = prints[t];
  return ExtPuzzle(
    id: 'print',
    serial: serial,
    op: [OpItem('prints', nums: [for (final x in prints) ...x])],
    manual: ManualPage(
      rules: [
        'بصمة الجاني في هذه العملية:',
        '• النمط: ${_printTypes[p[0]]}',
        '• عدد العلامات: ${p[1]}',
        '• لون العلامات: ${_l(p[2])}',
        'صِفها للعميل ليختارها من بين البصمات الست.',
      ],
    ),
    input: const InputSpec('choice', labels: ['1', '2', '3', '4', '5', '6']),
    answer: '$t',
    hint: 'البصمة رقم ${t + 1}',
    bot: [
      'سأصف لك بصمة الجاني، انتبه…',
      'نمط ${_printTypes[p[0]]}، فيها ${p[1]} علامة باللون ${_l(p[2])}.',
      'اختر البصمة رقم ${t + 1}.',
    ],
  );
}

// ───── 14. المفتاحان ─────
ExtPuzzle _sync(Rng r, int lv, String serial) {
  final opCols = _distinct(r, 3, 4);
  final exSyms = _distinct(r, 3, kSymbols.length);
  final indicators = _distinct(r, 4, kSymbols.length);
  // لكل مؤشّر: أي ثقب عند العميل وأي ثقب عند المحلّل
  final map = [for (int i = 0; i < 4; i++) [r.nextInt(3), r.nextInt(3)]];
  final ind = r.nextInt(4);
  final opIdx = map[ind][0], exIdx = map[ind][1];
  return ExtPuzzle(
    id: 'sync',
    serial: serial,
    op: [OpItem('indicator', glyphs: [kSymbols[indicators[ind]].s])],
    manual: ManualPage(
      rules: [
        'العميل يرى رمزاً على الباب. ابحث عنه: سيعرف أيّ ثقب يُدير، وأنت تُدير ثقبك.',
        'عُدّا معاً «3، 2، 1» وأديرا المفتاحين في اللحظة نفسها.',
      ],
      header: ['رمز الباب', 'ثقب العميل', 'ثقبك'],
      rows: [for (int i = 0; i < 4; i++) [_sym(indicators[i]), _l(opCols[map[i][0]]), _sym(exSyms[map[i][1]])]],
      keyRows: {ind},
    ),
    input: InputSpec('sync', labels: [for (final s in exSyms) kSymbols[s].s], colors: [for (final c in opCols) kLights[c].argb]),
    answer: '$opIdx',
    exAnswer: exIdx,
    hint: 'ثقب العميل ${_l(opCols[opIdx])}، وثقب المحلّل ${kSymbols[exSyms[exIdx]].s}',
    bot: [
      'ما الرمز المرسوم على الباب؟',
      'رمز ${kSymbols[indicators[ind]].s}: أنت تدير الثقب ${_l(opCols[opIdx])} وأنا أدير ثقبي.',
      'جاهز؟ أدِر الثقب ${_l(opCols[opIdx])} الآن، سأديره معك!',
    ],
  );
}

// ───── 15. الإحداثيات ─────
const List<String> _marks = ['🏛', '⛲', '🌳', '🗼', '⛪', '🏭', '🌉', '🗿', '🕌', '🏰'];

ExtPuzzle _coords(Rng r, int lv, String serial) {
  final rowsN = 8;
  final cells = _distinct(r, rowsN, 25);
  final triples = <List<int>>[];
  final seen = <String>{};
  while (triples.length < rowsN) {
    final t = _distinct(r, 3, _marks.length)..sort();
    if (seen.add(t.join(','))) triples.add(t);
  }
  final t = r.nextInt(rowsN);
  String coord(int c) => '${'ABCDE'[c % 5]}${c ~/ 5 + 1}';
  return ExtPuzzle(
    id: 'coords',
    serial: serial,
    op: [OpItem('landmarks', glyphs: r.shuffle([for (final i in triples[t]) _marks[i]]))],
    manual: ManualPage(
      rules: ['ابحث عن الإحداثية التي تُرى منها المعالم الثلاثة نفسها (الترتيب لا يهمّ).'],
      header: ['الإحداثية', 'المعالم المرئية'],
      rows: [for (int i = 0; i < rowsN; i++) [coord(cells[i]), triples[i].map((k) => _marks[k]).join('  ')]],
      keyRows: {t},
    ),
    input: InputSpec('grid', cols: 5, labels: [for (int c = 0; c < 25; c++) coord(c)]),
    answer: '${cells[t]}',
    hint: 'العمود ${'ABCDE'[cells[t] % 5]}',
    bot: [
      'ما المعالم التي تراها حولك؟',
      'المعالم ${triples[t].map((k) => _marks[k]).join(' ')}… أبحث في الخريطة.',
      'أنت في الخانة ${coord(cells[t])}.',
    ],
  );
}

// ───── 16. اللحن السرّي ─────
const List<String> _instruments = ['🎻 كمان', '🎺 بوق', '🥁 طبل', '🎹 بيانو'];

ExtPuzzle _melody(Rng r, int lv, String serial) {
  final maps = [for (int i = 0; i < 4; i++) r.shuffle([0, 1, 2, 3])];
  final inst = r.nextInt(4);
  final n = 4 + (lv >= 2 ? 2 : lv);
  final notes = [for (int i = 0; i < n; i++) r.nextInt(4)];
  final ans = [for (final x in notes) maps[inst][x]];
  return ExtPuzzle(
    id: 'melody',
    serial: serial,
    op: [OpItem('notes', nums: notes, text: _instruments[inst])],
    manual: ManualPage(
      rules: ['الآلة تحدّد التحويل: كل نغمة تُعزف بلون آخر. أعِد اللحن بالألوان المحوّلة وبالترتيب نفسه.'],
      header: ['الآلة', for (int c = 0; c < 4; c++) 'إذا سمع ${_l(c)}'],
      rows: [for (int i = 0; i < 4; i++) [_instruments[i], for (int c = 0; c < 4; c++) _l(maps[i][c])]],
      keyRows: {inst},
    ),
    input: InputSpec('seq', len: n, colors: [for (int c = 0; c < 4; c++) kLights[c].argb], labels: [for (int c = 0; c < 4; c++) _l(c)]),
    answer: ans.join(','),
    hint: 'أوّل نغمتين: ${ans.take(2).map(_l).join('، ')}',
    bot: [
      'ما الآلة؟ وما ترتيب ألوان اللحن؟',
      '${_instruments[inst]}: ${[for (final x in notes) '${_l(x)}→${_l(maps[inst][x])}'].join('، ')}',
      'اعزف: ${ans.map(_l).join(' ← ')}',
    ],
  );
}

// ───── 17. الليزر والمرايا ─────
const List<String> _arrows = ['↗', '↘', '↙', '↖'];

ExtPuzzle _laser(Rng r, int lv, String serial) {
  final n = lv >= 2 ? 4 : 3;
  final base = [for (int c = 0; c < kColors.length; c++) r.nextInt(4)];
  final colors = _distinct(r, n, kColors.length);
  final letter = r.nextInt(4);
  final shift = [0, 1, 2, 3][letter];
  final ans = [for (final c in colors) (base[c] + shift) % 4];
  return ExtPuzzle(
    id: 'laser',
    serial: serial,
    op: [OpItem('target', text: 'ABCD'[letter])],
    manual: ManualPage(
      rules: [
        'الاتجاه الأساسي لكل مرآة حسب لونها.',
        'حرف الهدف يدير كل المرايا: A بلا تدوير، B ربع دورة، C نصف دورة، D ثلاثة أرباع (باتجاه ↗ ↘ ↙ ↖).',
      ],
      header: ['لون المرآة', 'الاتجاه الأساسي'],
      rows: [for (int c = 0; c < kColors.length; c++) [_c(c), _arrows[base[c]]]],
      keyRows: colors.toSet(),
    ),
    input: InputSpec('cyclers', options: [for (int i = 0; i < n; i++) _arrows], colors: [for (final c in colors) kColors[c].argb]),
    answer: ans.join(','),
    hint: 'المرآة الأولى: ${_arrows[ans[0]]}',
    bot: [
      'ما حرف الهدف وألوان المرايا؟',
      'الهدف ${'ABCD'[letter]}: أدير كل اتجاه $shift خطوة…',
      'وجّه المرايا: ${ans.map((a) => _arrows[a]).join(' ، ')}',
    ],
  );
}

// ───── 18. الأنابيب ─────
ExtPuzzle _pipes(Rng r, int lv, String serial) {
  final n = lv >= 2 ? 5 : 4;
  final safeSets = [for (int c = 0; c < kColors.length; c++) _distinct(r, 4, kSymbols.length)];
  final frame = r.nextInt(kColors.length);
  final safe = safeSets[frame];
  final unsafe = [for (int i = 0; i < kSymbols.length; i++) if (!safe.contains(i)) i];
  List<int> path = [];
  for (int attempt = 0; attempt < 200; attempt++) {
    final start = r.nextInt(n * n);
    final p = [start];
    final target = n + 2 + r.nextInt(n);
    var ok = true;
    while (p.length < target) {
      final cur = p.last;
      final cands = <int>[];
      for (final d in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final x = cur % n + d[0], y = cur ~/ n + d[1];
        if (x < 0 || y < 0 || x >= n || y >= n) continue;
        final nc = y * n + x;
        if (p.contains(nc)) continue;
        // لا تلامس خلايا سابقة غير المتتالية (مسار وحيد)
        var touches = false;
        for (final e in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          final xx = x + e[0], yy = y + e[1];
          if (xx < 0 || yy < 0 || xx >= n || yy >= n) continue;
          final q = yy * n + xx;
          if (q != cur && p.contains(q)) touches = true;
        }
        if (!touches) cands.add(nc);
      }
      if (cands.isEmpty) {
        ok = false;
        break;
      }
      p.add(cands[r.nextInt(cands.length)]);
    }
    if (ok) {
      path = p;
      break;
    }
  }
  if (path.isEmpty) path = [for (int i = 0; i < n; i++) i];
  final cells = [
    for (int c = 0; c < n * n; c++)
      path.contains(c) ? kSymbols[safe[r.nextInt(4)]].s : kSymbols[unsafe[r.nextInt(unsafe.length)]].s
  ];
  return ExtPuzzle(
    id: 'pipes',
    serial: serial,
    op: [OpItem('frame', nums: [kColors[frame].argb], text: _c(frame))],
    manual: ManualPage(
      rules: [
        'لون الإطار يحدّد الرموز الآمنة. الماء يمرّ فقط عبر الخلايا الآمنة المتجاورة (بلا قُطري).',
        'على العميل أن يضغط الخلايا من «▶» حتى «■» بالترتيب.',
      ],
      header: ['لون الإطار', 'الرموز الآمنة'],
      rows: [for (int c = 0; c < kColors.length; c++) [_c(c), safeSets[c].map((i) => kSymbols[i].s).join('  ')]],
      keyRows: {frame},
    ),
    input: InputSpec('gridseq', cols: n, len: path.length, labels: cells, colors: [path.first, path.last]),
    answer: path.join(','),
    hint: 'المسار من ${path.length} خلايا',
    bot: [
      'ما لون إطار الأنابيب؟',
      'الإطار ${_c(frame)}: الآمن ${safe.map((i) => kSymbols[i].s).join(' ')}. اتبع هذه الرموز فقط.',
      'ابدأ من ▶ واتبع الرموز الآمنة المتجاورة حتى ■ (${path.length} خلايا).',
    ],
  );
}

// ───── 19. مزج الألوان ─────
const List<int> _bases = [0xFFE53935, 0xFFFDD835, 0xFF1E88E5]; // أحمر، أصفر، أزرق

int _mixColor(List<int> k) {
  final tot = k.fold<int>(0, (a, b) => a + b);
  double rr = 0, gg = 0, bb = 0;
  for (int i = 0; i < 3; i++) {
    final c = _bases[i];
    rr += ((c >> 16) & 0xFF) * k[i];
    gg += ((c >> 8) & 0xFF) * k[i];
    bb += (c & 0xFF) * k[i];
  }
  return 0xFF000000 | ((rr / tot).round() << 16) | ((gg / tot).round() << 8) | (bb / tot).round();
}

ExtPuzzle _mix(Rng r, int lv, String serial) {
  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
  final all = <List<int>>[];
  for (int a = 0; a <= 3; a++) {
    for (int b = 0; b <= 3; b++) {
      for (int c = 0; c <= 3; c++) {
        if (a + b + c == 0) continue;
        if (gcd(gcd(a, b), c) != 1) continue;
        if ([a, b, c].where((x) => x > 0).length < 2) continue;
        all.add([a, b, c]);
      }
    }
  }
  final recipes = r.shuffle(all).sublist(0, 8);
  final t = r.nextInt(8);
  return ExtPuzzle(
    id: 'mix',
    serial: serial,
    op: [OpItem('sample', nums: [_mixColor(recipes[t])])],
    manual: ManualPage(
      rules: ['العميل يصف لون العيّنة. جد اللون الأقرب وأعطه عدد القطرات من كل أنبوب: أحمر، أصفر، أزرق.'],
      header: ['اللون', 'أحمر', 'أصفر', 'أزرق'],
      rows: [for (final k in recipes) [_swatch(_mixColor(k)), '${k[0]}', '${k[1]}', '${k[2]}']],
      keyRows: {t},
    ),
    input: InputSpec('cyclers',
        options: [for (int i = 0; i < 3; i++) ['0', '1', '2', '3']], colors: _bases, labels: const ['أحمر', 'أصفر', 'أزرق']),
    answer: recipes[t].join(','),
    hint: 'قطرات الأحمر: ${recipes[t][0]}',
    bot: [
      'صِف لي لون العيّنة بدقّة…',
      'أقرب لون في الجدول وجدته.',
      'الوصفة: أحمر ${recipes[t][0]}، أصفر ${recipes[t][1]}، أزرق ${recipes[t][2]}',
    ],
  );
}

// ───── 20. الدائرة الكهربائية ─────
ExtPuzzle _circuit(Rng r, int lv, String serial) {
  final n = 4;
  final glyphOf = [for (int c = 0; c < kColors.length; c++) r.nextInt(kSymbols.length)];
  // نضمن أن ألوان الأطراف الأربعة لها رموز مختلفة
  late List<int> colors;
  do {
    colors = _distinct(r, n, kColors.length);
  } while ({for (final c in colors) glyphOf[c]}.length < n);
  final right = r.shuffle([for (final c in colors) kSymbols[glyphOf[c]].s]);
  final volt = 1 + r.nextInt(3);
  var ans = [for (final c in colors) right.indexOf(kSymbols[glyphOf[c]].s)];
  if (volt == 3) ans = [ans[1], ans[0], ans[2], ans[3]];
  return ExtPuzzle(
    id: 'circuit',
    serial: serial,
    op: [OpItem('volt', text: '$volt')],
    manual: ManualPage(
      rules: [
        'كل طرف ملوّن يُوصل بالرمز المقابل للونه.',
        'إذا كان الجهد 3 فولت: بدّل وصلتَي الطرفين الأوّل والثاني.',
      ],
      header: ['لون الطرف', 'يوصل بـ'],
      rows: [for (int c = 0; c < kColors.length; c++) [_c(c), _sym(glyphOf[c])]],
      keyRows: colors.toSet(),
    ),
    input: InputSpec('cyclers', options: [for (int i = 0; i < n; i++) right], colors: [for (final c in colors) kColors[c].argb]),
    answer: ans.join(','),
    hint: 'الطرف الأول يوصل بـ ${right[ans[0]]}',
    bot: [
      'ما الجهد؟ وما ألوان الأطراف؟',
      'الجهد $volt فولت${volt == 3 ? '، سأبدّل الأوّلَين' : ''}.',
      'الوصلات: ${[for (final a in ans) right[a]].join(' ، ')}',
    ],
  );
}

// ───── 21. المصابيح التسعة ─────
const Map<String, List<List<int>>> _lampRules = {
  'plus': [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]],
  'cross': [[0, 0], [1, 1], [-1, -1], [1, -1], [-1, 1]],
  'row': [[0, 0], [1, 0], [-1, 0]],
  'col': [[0, 0], [0, 1], [0, -1]],
};
const Map<String, String> _lampRuleText = {
  'plus': 'الضغطة تقلب المصباح وجيرانه الأربعة (أعلى، أسفل، يمين، يسار).',
  'cross': 'الضغطة تقلب المصباح وجيرانه القُطريين الأربعة.',
  'row': 'الضغطة تقلب المصباح وجاريه في الصفّ نفسه.',
  'col': 'الضغطة تقلب المصباح وجاريه في العمود نفسه.',
};

List<int> _applyLamps(List<int> lamps, List<int> presses, String rule) {
  final out = [...lamps];
  for (final p in presses) {
    final x = p % 3, y = p ~/ 3;
    for (final d in _lampRules[rule]!) {
      final xx = x + d[0], yy = y + d[1];
      if (xx < 0 || yy < 0 || xx > 2 || yy > 2) continue;
      out[yy * 3 + xx] ^= 1;
    }
  }
  return out;
}

ExtPuzzle _lamps(Rng r, int lv, String serial) {
  final rule = _lampRules.keys.toList()[r.nextInt(4)];
  final k = 2 + (lv >= 2 ? 1 : 0);
  late List<int> presses, lamps;
  do {
    presses = _distinct(r, k, 9);
    lamps = _applyLamps(List.filled(9, 0), presses, rule);
  } while (!lamps.contains(1));
  final serials = <String>{serial};
  while (serials.length < 6) {
    serials.add('${_letters[r.nextInt(_letters.length)]}${1 + r.nextInt(9)}');
  }
  final list = r.shuffle(serials.toList());
  final fake = {for (final s in list) s: s == serial ? presses : _distinct(r, k, 9)};
  String cells(List<int> ps) => (ps.toList()..sort()).map((i) => '${i + 1}').join('، ');
  final bits = [for (int i = 0; i < 9; i++) presses.contains(i) ? '1' : '0'].join();
  return ExtPuzzle(
    id: 'lamps',
    serial: serial,
    op: [OpItem('lamps', nums: lamps, text: serial)],
    manual: ManualPage(
      rules: [_lampRuleText[rule]!, 'الخلايا مرقّمة 1–9 من اليمين إلى اليسار ومن الأعلى إلى الأسفل. السجلّ يعطي الحلّ حسب الرقم التسلسلي للّوحة.'],
      header: ['الرقم التسلسلي', 'اضغط الخلايا'],
      rows: [for (final s in list) [s, cells(fake[s]!)]],
      keyRows: {list.indexOf(serial)},
    ),
    input: InputSpec('toggles', cols: 3, labels: [for (int i = 0; i < 9; i++) '${i + 1}']),
    answer: bits,
    checker: (v) {
      if (v.length != 9) return false;
      final ps = [for (int i = 0; i < 9; i++) if (v[i] == '1') i];
      return !_applyLamps(lamps, ps, rule).contains(1);
    },
    hint: 'اضغط الخلايا: ${cells(presses)}',
    bot: [
      'ما الرقم التسلسلي للّوحة؟',
      'الرقم $serial… وجدته في السجلّ.',
      'اضغط الخلايا: ${cells(presses)}',
    ],
  );
}

// ───── 22. رقعة الشطرنج ─────
const List<String> _pieces = ['♞', '♝', '♜', '♛'];
const List<String> _pieceNames = ['الحصان', 'الفيل', 'الرخّ', 'الوزير'];

ExtPuzzle _chess(Rng r, int lv, String serial) {
  final vecs = <List<int>>[];
  final seen = <String>{};
  while (vecs.length < 4) {
    final a = r.nextInt(4), b = r.nextInt(4);
    if (a + b == 0 || !seen.add('$a,$b')) continue;
    vecs.add([a, b]);
  }
  final piece = r.nextInt(4);
  late int pos, good;
  late List<int> marks;
  for (int attempt = 0; attempt < 300; attempt++) {
    pos = r.nextInt(25);
    final px = pos % 5, py = pos ~/ 5;
    bool reach(int c) {
      final dx = (c % 5 - px).abs(), dy = (c ~/ 5 - py).abs();
      return dx == vecs[piece][0] && dy == vecs[piece][1];
    }
    final rs = [for (int c = 0; c < 25; c++) if (c != pos && reach(c)) c];
    final nrs = [for (int c = 0; c < 25; c++) if (c != pos && !reach(c)) c];
    if (rs.isEmpty) continue;
    good = rs[r.nextInt(rs.length)];
    marks = r.shuffle([good, ...r.shuffle(nrs).sublist(0, 3)]);
    break;
  }
  String mv(List<int> v) => '${v[0]} أفقياً و${v[1]} عمودياً';
  return ExtPuzzle(
    id: 'chess',
    serial: serial,
    op: [OpItem('board', nums: [pos, piece, ...marks])],
    manual: ManualPage(
      rules: ['في هذه العملية لكل قطعة حركة واحدة خاصة (بأي اتجاه). أيّ خانة مرقّمة تصلها القطعة بحركة واحدة؟'],
      header: ['القطعة', 'حركتها'],
      rows: [for (int i = 0; i < 4; i++) ['${_pieces[i]} ${_pieceNames[i]}', mv(vecs[i])]],
      keyRows: {piece},
    ),
    input: const InputSpec('choice', labels: ['1', '2', '3', '4']),
    answer: '${marks.indexOf(good)}',
    hint: 'الخانة رقم ${marks.indexOf(good) + 1}',
    bot: [
      'ما القطعة وأين هي؟ وأين الخانات المرقّمة؟',
      '${_pieceNames[piece]} يتحرّك ${mv(vecs[piece])}…',
      'الخانة رقم ${marks.indexOf(good) + 1}',
    ],
  );
}

// ───── 23. السونار ─────
const List<String> _subs = ['🐋 حوت', '🛥 زورق', '🚢 مدمّرة', '🔱 غوّاصة'];

ExtPuzzle _sonar(Rng r, int lv, String serial) {
  final echoes = <List<int>>[];
  final cols = _distinct(r, 4, 4);
  for (int i = 0; i < 4; i++) {
    echoes.add([cols[i], r.nextInt(72) * 5, 1 + r.nextInt(9)]);
  }
  final targetColor = [for (int i = 0; i < 4; i++) r.nextInt(4)];
  final corr = [for (int i = 0; i < 4; i++) (r.nextInt(2) == 0 ? -1 : 1) * (10 + r.nextInt(7) * 5)];
  final sub = r.nextInt(4);
  final echo = echoes.firstWhere((e) => e[0] == targetColor[sub]);
  final bearing = ((echo[1] + corr[sub]) % 360 + 360) % 360;
  return ExtPuzzle(
    id: 'sonar',
    serial: serial,
    op: [OpItem('sonar', nums: [for (final e in echoes) ...e], text: _subs[sub])],
    manual: ManualPage(
      rules: ['نوع الهدف يحدّد لون صداه والتصحيح. أضف التصحيح إلى زاوية ذلك الصدى (0–359) وأعطِ النتيجة بثلاثة أرقام.'],
      header: ['الهدف', 'لون الصدى', 'التصحيح'],
      rows: [for (int i = 0; i < 4; i++) [_subs[i], _l(targetColor[i]), '${corr[i] > 0 ? '+' : ''}${corr[i]}°']],
      keyRows: {sub},
    ),
    input: const InputSpec('digits', len: 3),
    answer: _pad(bearing, 3),
    hint: 'الاتجاه بين ${(bearing ~/ 10) * 10} و ${(bearing ~/ 10) * 10 + 9}',
    bot: [
      'ما نوع الهدف؟ وما زوايا الأصداء وألوانها؟',
      '${_subs[sub]}: الصدى ${_l(targetColor[sub])} عند ${echo[1]}°، التصحيح ${corr[sub]}°.',
      'الاتجاه: ${_pad(bearing, 3)}',
    ],
  );
}

// ───── الخزنة الأخيرة ─────
/// الرقم الذي يكشفه القفل رقم i عند فتحه.
int vaultDigit(int seed, int i) => Rng((seed * 31 + i * 977 + 13) & 0x7fffffff).nextInt(10);

ExtPuzzle _vault(int seed, List<String> rooms, int room, Rng r, String serial) {
  final prev = [for (int i = 0; i < room && i < rooms.length; i++) i];
  final count = prev.length.clamp(1, 6).toInt();
  final used = prev.length > 6 ? prev.sublist(prev.length - 6) : (prev.isEmpty ? [0] : prev);
  final order = r.shuffle(used);
  String name(int i) => i < rooms.length ? (kExtInfo[rooms[i]]?.title ?? _classicTitle(rooms[i])) : '?';
  final ans = order.map((i) => vaultDigit(seed, i)).join();
  return ExtPuzzle(
    id: kVaultCode,
    serial: serial,
    op: [OpItem('evidence', glyphs: [for (final i in used) name(i)], nums: [for (final i in used) vaultDigit(seed, i)])],
    manual: ManualPage(
      rules: ['كل قفل فتحتماه كشف رقماً عند العميل. أمْلِ عليه ترتيب الأقفال؛ يكتب أرقامها بهذا الترتيب.'],
      header: ['الترتيب', 'القفل'],
      rows: [for (int k = 0; k < order.length; k++) ['${k + 1}', name(order[k])]],
    ),
    input: InputSpec('digits', len: count),
    answer: ans,
    hint: 'أوّل رقم: ${ans[0]}',
    bot: [
      'اقرأ لي الأرقام التي كشفتها الأقفال…',
      'الترتيب حسب الملفّ: ${order.map(name).join(' ← ')}',
      'الرمز: ${ans.split('').join(' ')}',
    ],
  );
}

String _classicTitle(String id) => const {
      'keypad': 'لوحة الدخول',
      'wires': 'صندوق الإنذار',
      'cipher': 'الرسالة المعترَضة',
      'maze': 'أنفاق التهوية',
      'lights': 'جهاز الإشارات',
      'dial': 'قرص الخزنة',
      'radio': 'تردّد الراديو',
    }[id] ??
    id;
