// منطق لعبة «الخزنة» — نسخة Dart مطابقة لـ core.js
// نفس البذرة تعطي نفس الألغاز في نسخة الويب والنسخة الأصلية، فيمكن اللعب بينهما.
import 'ext_locks.dart';
import 'stages.dart' show stageMods;

const int kDuration = 600; // ثانية
const int kPenalty = 30;
const int kBump = 10;

/// المؤثّر «محاولات محدودة»: عدد الأخطاء المسموح بها في المهمّة.
const int kLimitedTries = 3;

/// قفل المفتاحين: أقصى فرق بين اللاعبَين.
const int kSyncWindowMs = 1500;

/// الأقفال الخمسة الأساسية (المتوافقة مع نسخة الويب).
const List<String> kRooms = ['keypad', 'wires', 'cipher', 'maze', 'lights'];

/// كل الأقفال المتاحة، منها قفلان خاصّان بالتطبيق.
const List<String> kAllRooms = ['keypad', 'wires', 'cipher', 'maze', 'lights', 'dial', 'radio'];

class Difficulty {
  final String id;
  final String name;
  final int duration;
  final int penalty;
  final int mazeN;
  final int lightStages;
  final int wireMin;
  final int wireMax;
  const Difficulty(this.id, this.name, this.duration, this.penalty, this.mazeN, this.lightStages, this.wireMin, this.wireMax);
}

const Map<String, Difficulty> kDifficulties = {
  'recruit': Difficulty('recruit', 'مجنّد', 720, 20, 5, 2, 3, 4),
  'agent': Difficulty('agent', 'عميل', 600, 30, 5, 3, 3, 6),
  'elite': Difficulty('elite', 'نخبة', 540, 45, 6, 4, 4, 6),
  'master': Difficulty('master', 'أسطورة', 480, 45, 7, 4, 4, 6),
};
Difficulty diffOf(String id) => kDifficulties[id] ?? kDifficulties['agent']!;

const List<String> kWaveNames = ['موجة ناعمة', 'موجة مربّعة', 'موجة منشارية', 'نبضات متقطّعة'];
const int kFreqMin = 80;
const int kFreqMax = 119;
const Map<String, String> kRoomNames = {
  'keypad': 'باب الرموز',
  'wires': 'صندوق الأسلاك',
  'cipher': 'المخطوط المشفّر',
  'maze': 'السرداب المظلم',
  'lights': 'قفل الأضواء',
  'dial': 'قرص الخزنة',
  'radio': 'تردّد الراديو',
};

class Sym {
  final String s;
  final String n;
  const Sym(this.s, this.n);
}

const List<Sym> kSymbols = [
  Sym('★', 'نجمة'), Sym('☾', 'هلال'), Sym('◆', 'معيّن'),
  Sym('▲', 'مثلث'), Sym('●', 'دائرة'), Sym('■', 'مربّع'),
  Sym('✚', 'زائد'), Sym('☀', 'شمس'), Sym('♣', 'نفل'),
  Sym('♠', 'بستوني'), Sym('♥', 'قلب'), Sym('✿', 'وردة'),
];

class GColor {
  final String id;
  final String n;
  final int argb;
  const GColor(this.id, this.n, this.argb);
}

const List<GColor> kColors = [
  GColor('red', 'أحمر', 0xFFE53935),
  GColor('blue', 'أزرق', 0xFF1E88E5),
  GColor('yellow', 'أصفر', 0xFFFDD835),
  GColor('green', 'أخضر', 0xFF43A047),
  GColor('white', 'أبيض', 0xFFF5F5F5),
  GColor('black', 'أسود', 0xFF212121),
];
const List<GColor> kLights = [
  GColor('red', 'أحمر', 0xFFE53935),
  GColor('blue', 'أزرق', 0xFF1E88E5),
  GColor('yellow', 'أصفر', 0xFFFDD835),
  GColor('green', 'أخضر', 0xFF43A047),
];

final List<String> kAlphabet = 'ابتثجحخدذرزسشصضطظعغفقكلمنهوي'.split('');
const List<String> _words = [
  'مفتاح', 'كنز', 'سرداب', 'قنديل', 'ذهب', 'لغز', 'حارس', 'صندوق', 'مخطوط', 'فارس',
  'جبل', 'نجم', 'قمر', 'سيف', 'درع', 'طريق', 'ظلام', 'شمس', 'بحر', 'صخر',
];

const List<String> kDirNames = ['up', 'down', 'left', 'right'];
const Map<String, List<int>> kDirs = {
  'up': [0, -1],
  'down': [0, 1],
  'left': [-1, 0],
  'right': [1, 0],
};
const Map<String, String> _opp = {'up': 'down', 'down': 'up', 'left': 'right', 'right': 'left'};

// ───── مولّد عشوائي حتمي (mulberry32)، مطابق بتّاً بتّاً لنسخة JavaScript ─────
const int _m32 = 0xFFFFFFFF;
int _imul(int a, int b) => ((a & _m32) * (b & _m32)) & _m32;

class Rng {
  int _s;
  Rng(int seed) : _s = seed & _m32;

  double next() {
    _s = (_s + 0x6D2B79F5) & _m32;
    int t = _s;
    t = _imul(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + _imul(t ^ (t >>> 7), t | 61)) & _m32)) & _m32;
    return ((t ^ (t >>> 14)) & _m32) / 4294967296.0;
  }

  int nextInt(int n) => (next() * n).floor();

  List<T> shuffle<T>(List<T> a) {
    final b = List<T>.of(a);
    for (int i = b.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = b[i];
      b[i] = b[j];
      b[j] = tmp;
    }
    return b;
  }
}

String normalizeAnswer(String v) => v
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه');

// ───── الألغاز ─────
class Keypad {
  final List<int> manual; // رقم لكل رمز
  final List<int> shown; // 4 رموز
  final String answer;
  Keypad(this.manual, this.shown, this.answer);
}

class WireRule {
  final String type; // none | lastIs | many | one | default
  final int? color;
  final int k;
  WireRule(this.type, this.color, this.k);

  int eval(List<int> wires) {
    final n = wires.length;
    int count(int c) => wires.where((x) => x == c).length;
    switch (type) {
      case 'none':
        return count(color!) == 0 ? k - 1 : -1;
      case 'lastIs':
        return wires[n - 1] == color ? n - 1 : -1;
      case 'many':
        return count(color!) > 1 ? wires.lastIndexOf(color!) : -1;
      case 'one':
        return count(color!) == 1 ? 0 : -1;
      case 'default':
        return k - 1;
    }
    return -1;
  }

  String get text {
    final c = color == null ? '' : kColors[color!].n;
    switch (type) {
      case 'none':
        return 'إذا لم يوجد أي سلك $c ← اقطع السلك رقم $k';
      case 'lastIs':
        return 'إذا كان آخر سلك $c ← اقطع آخر سلك';
      case 'many':
        return 'إذا وُجد أكثر من سلك $c ← اقطع آخر سلك $c';
      case 'one':
        return 'إذا وُجد سلك $c واحد فقط ← اقطع أول سلك';
      default:
        return 'وإلا ← اقطع السلك رقم $k';
    }
  }
}

class Wires {
  final Map<int, List<WireRule>> rules;
  final List<int> wires;
  final int answer;
  Wires(this.rules, this.wires, this.answer);
}

class Cipher {
  final List<int> manual; // إزاحة لكل رمز
  final int sym;
  final String cipher;
  final String answer;
  Cipher(this.manual, this.sym, this.cipher, this.answer);

  String decode(String letter, int symbol) {
    final i = kAlphabet.indexOf(letter);
    if (i < 0) return letter;
    final k = manual[symbol];
    return kAlphabet[(i - k + kAlphabet.length) % kAlphabet.length];
  }
}

class Maze {
  final int n;
  final List<Set<String>> open;
  final int start;
  final int exit;
  final int distance;
  Maze(this.n, this.open, this.start, this.exit, this.distance);

  int? neighbor(int pos, String dir) {
    if (!open[pos].contains(dir)) return null;
    final d = kDirs[dir]!;
    return (pos ~/ n + d[1]) * n + (pos % n + d[0]);
  }
}

class Lights {
  final List<int> seq;
  final List<List<int>> maps;
  Lights(this.seq, this.maps);
  List<int> expected(int stage) => [for (final c in seq.sublist(0, stage + 1)) maps[stage][c]];
}

/// قرص الخزنة: 3 رموز، ولكل رمز رقم مختلف حسب موضعه (الأول/الثاني/الثالث).
class DialLock {
  final List<List<int>> manual; // [رمز][موضع] = 0..39
  final List<int> shown;
  DialLock(this.manual, this.shown);
  List<int> get answer => [for (int i = 0; i < shown.length; i++) manual[shown[i]][i]];
}

/// تردّد الراديو: شكل الموجة × لون المؤشّر ← التردّد.
class RadioLock {
  final List<List<int>> manual; // [موجة][لون] = kFreqMin..kFreqMax
  final int wave;
  final int color;
  RadioLock(this.manual, this.wave, this.color);
  int get answer => manual[wave][color];
}

class Puzzles {
  final Keypad keypad;
  final Wires wires;
  final Cipher cipher;
  final Maze maze;
  final Lights lights;
  final DialLock dial;
  final RadioLock radio;
  Puzzles(this.keypad, this.wires, this.cipher, this.maze, this.lights, this.dial, this.radio);
}

Keypad _genKeypad(Rng r) {
  final digits = [for (int i = 0; i < kSymbols.length; i++) r.nextInt(10)];
  final shown = r.shuffle([for (int i = 0; i < kSymbols.length; i++) i]).sublist(0, 4);
  return Keypad(digits, shown, shown.map((i) => digits[i]).join());
}

Wires _genWires(Rng r, Difficulty d) {
  const types = ['none', 'lastIs', 'many', 'one'];
  final rules = <int, List<WireRule>>{};
  for (int n = 3; n <= 6; n++) {
    final list = <WireRule>[];
    for (int i = 0; i < 3; i++) {
      final type = types[r.nextInt(types.length)];
      final color = r.nextInt(kColors.length);
      final k = 1 + r.nextInt(n);
      list.add(WireRule(type, color, k));
    }
    list.add(WireRule('default', null, 1 + r.nextInt(n)));
    rules[n] = list;
  }
  final n = d.wireMin + r.nextInt(d.wireMax - d.wireMin + 1);
  final wires = [for (int i = 0; i < n; i++) r.nextInt(kColors.length)];
  int answer = -1;
  for (final rule in rules[n]!) {
    answer = rule.eval(wires);
    if (answer >= 0) break;
  }
  return Wires(rules, wires, answer);
}

Cipher _genCipher(Rng r) {
  final shifts = [for (int i = 0; i < kSymbols.length; i++) 1 + r.nextInt(9)];
  final sym = r.nextInt(kSymbols.length);
  final word = _words[r.nextInt(_words.length)];
  final k = shifts[sym];
  final enc = word.split('').map((ch) => kAlphabet[(kAlphabet.indexOf(ch) + k) % kAlphabet.length]).join();
  return Cipher(shifts, sym, enc, word);
}

List<int> _bfs(List<Set<String>> open, int n, int start) {
  final dist = List<int>.filled(n * n, -1);
  dist[start] = 0;
  final q = <int>[start];
  int head = 0;
  while (head < q.length) {
    final c = q[head++];
    final x = c % n, y = c ~/ n;
    for (final d in kDirNames) {
      if (!open[c].contains(d)) continue;
      final nc = (y + kDirs[d]![1]) * n + (x + kDirs[d]![0]);
      if (dist[nc] < 0) {
        dist[nc] = dist[c] + 1;
        q.add(nc);
      }
    }
  }
  return dist;
}

Maze _genMaze(Rng r, [int n = 5]) {
  final open = [for (int i = 0; i < n * n; i++) <String>{}];
  final seen = <int>{0};
  final stack = <List<int>>[
    [0, 0]
  ];
  while (stack.isNotEmpty) {
    final x = stack.last[0], y = stack.last[1];
    final opts = r.shuffle(kDirNames).where((d) {
      final nx = x + kDirs[d]![0], ny = y + kDirs[d]![1];
      return nx >= 0 && ny >= 0 && nx < n && ny < n && !seen.contains(ny * n + nx);
    }).toList();
    if (opts.isEmpty) {
      stack.removeLast();
      continue;
    }
    final d = opts.first;
    final nx = x + kDirs[d]![0], ny = y + kDirs[d]![1];
    open[y * n + x].add(d);
    open[ny * n + nx].add(_opp[d]!);
    seen.add(ny * n + nx);
    stack.add([nx, ny]);
  }
  final start = r.nextInt(n * n);
  final dist = _bfs(open, n, start);
  int exit = start;
  for (int i = 0; i < dist.length; i++) {
    if (dist[i] > dist[exit]) exit = i;
  }
  return Maze(n, open, start, exit, dist[exit]);
}

Lights _genLights(Rng r, int stages) {
  final seq = [for (int i = 0; i < stages; i++) r.nextInt(kLights.length)];
  final maps = [for (int i = 0; i < stages; i++) r.shuffle([0, 1, 2, 3])];
  return Lights(seq, maps);
}

DialLock _genDial(Rng r) {
  final manual = [
    for (int i = 0; i < kSymbols.length; i++) [for (int j = 0; j < 3; j++) r.nextInt(40)]
  ];
  final shown = r.shuffle([for (int i = 0; i < kSymbols.length; i++) i]).sublist(0, 3);
  return DialLock(manual, shown);
}

RadioLock _genRadio(Rng r) {
  final manual = [
    for (int w = 0; w < kWaveNames.length; w++)
      [for (int c = 0; c < kLights.length; c++) kFreqMin + r.nextInt(kFreqMax - kFreqMin + 1)]
  ];
  return RadioLock(manual, r.nextInt(kWaveNames.length), r.nextInt(kLights.length));
}

/// ترتيب استدعاءات المولّد ثابت: الأقفال الجديدة بعد القديمة، فتبقى الألغاز الافتراضية مطابقة لنسخة الويب.
Puzzles generatePuzzles(int seed, [String diff = 'agent']) {
  final d = diffOf(diff);
  final r = Rng(seed);
  final keypad = _genKeypad(r);
  final wires = _genWires(r, d);
  final cipher = _genCipher(r);
  final maze = _genMaze(r, d.mazeN);
  final lights = _genLights(r, d.lightStages);
  return Puzzles(keypad, wires, cipher, maze, lights, _genDial(r), _genRadio(r));
}

// ───── الحالة ─────
class GameEvent {
  final String type; // start | solved | wrong | bump | moved | press | stage
  final String room;
  final int? pen;
  const GameEvent(this.type, this.room, [this.pen]);

  Map<String, dynamic> toJson() => {'type': type, 'room': room, if (pen != null) 'pen': pen};
  static GameEvent? fromJson(dynamic j) {
    if (j is! Map) return null;
    return GameEvent('${j['type']}', '${j['room']}', (j['pen'] as num?)?.toInt());
  }
}

class GameState {
  final int seed;
  final List<String> rooms;
  final String diff;
  final int dialStep;
  final int stage; // رقم المرحلة في الحملة (0 = مهمّة حرّة)
  final String phase; // lobby | playing | won | lost
  final int room;
  final int startedAt; // ms
  final int penalty;
  final int? mazePos;
  final int lightStage;
  final List<int> lightInput;
  final List<int> cut;
  final GameEvent? lastEvent;
  final int eventId;
  final int finishedIn;

  /// مدّة المرحلة بالثواني من لوحة المدير (0 = مدّة مستوى الصعوبة).
  final int duration;

  /// توقّف مؤقّت: وقت بداية التوقّف (0 = غير متوقّف) وسببه: peer | balance.
  final int pausedAt;
  final String pauseReason;

  /// التلميحات المشتراة وآخر تلميح (يظهر للّاعبَين).
  final int hints;
  final String hint;

  /// عدد الأخطاء في المهمّة (للإنذار والمحاولات المحدودة).
  final int errors;

  /// قفل المفتاحين: لحظة إدارة كل لاعب لمفتاحه (0 = لم يُدِر).
  final int syncOp;
  final int syncEx;

  const GameState({
    required this.seed,
    this.rooms = kRooms,
    this.diff = 'agent',
    this.dialStep = 0,
    this.stage = 0,
    this.phase = 'lobby',
    this.room = 0,
    this.startedAt = 0,
    this.penalty = 0,
    this.mazePos,
    this.lightStage = 0,
    this.lightInput = const [],
    this.cut = const [],
    this.lastEvent,
    this.eventId = 0,
    this.finishedIn = 0,
    this.duration = 0,
    this.pausedAt = 0,
    this.pauseReason = '',
    this.hints = 0,
    this.hint = '',
    this.errors = 0,
    this.syncOp = 0,
    this.syncEx = 0,
  });

  bool get paused => pausedAt > 0;
  int get effectiveDuration => duration > 0 ? duration : difficulty.duration;

  String get roomId => rooms[room.clamp(0, rooms.length - 1)];
  Difficulty get difficulty => diffOf(diff);

  GameState copyWith({
    String? phase,
    int? room,
    int? startedAt,
    int? penalty,
    int? mazePos,
    int? lightStage,
    List<int>? lightInput,
    List<int>? cut,
    GameEvent? lastEvent,
    int? eventId,
    int? finishedIn,
    int? dialStep,
    int? pausedAt,
    String? pauseReason,
    int? hints,
    String? hint,
    int? errors,
    int? syncOp,
    int? syncEx,
  }) =>
      GameState(
        seed: seed,
        rooms: rooms,
        diff: diff,
        stage: stage,
        dialStep: dialStep ?? this.dialStep,
        phase: phase ?? this.phase,
        room: room ?? this.room,
        startedAt: startedAt ?? this.startedAt,
        penalty: penalty ?? this.penalty,
        mazePos: mazePos ?? this.mazePos,
        lightStage: lightStage ?? this.lightStage,
        lightInput: lightInput ?? this.lightInput,
        cut: cut ?? this.cut,
        lastEvent: lastEvent ?? this.lastEvent,
        eventId: eventId ?? this.eventId,
        finishedIn: finishedIn ?? this.finishedIn,
        duration: duration,
        pausedAt: pausedAt ?? this.pausedAt,
        pauseReason: pauseReason ?? this.pauseReason,
        hints: hints ?? this.hints,
        hint: hint ?? this.hint,
        errors: errors ?? this.errors,
        syncOp: syncOp ?? this.syncOp,
        syncEx: syncEx ?? this.syncEx,
      );

  /// نسخة بمدّة مختلفة (تأتي من الخادم عند بداية الجلسة).
  GameState withDuration(int seconds) => GameState(
        seed: seed, rooms: rooms, diff: diff, dialStep: dialStep, stage: stage, phase: phase, room: room,
        startedAt: startedAt, penalty: penalty, mazePos: mazePos, lightStage: lightStage, lightInput: lightInput,
        cut: cut, lastEvent: lastEvent, eventId: eventId, finishedIn: finishedIn, duration: seconds,
        pausedAt: pausedAt, pauseReason: pauseReason, hints: hints, hint: hint,
        errors: errors, syncOp: syncOp, syncEx: syncEx,
      );

  Map<String, dynamic> toJson() => {
        'seed': seed,
        'rooms': rooms,
        'diff': diff,
        'dialStep': dialStep,
        'stage': stage,
        'phase': phase,
        'room': room,
        'startedAt': startedAt,
        'penalty': penalty,
        'mazePos': mazePos,
        'lightStage': lightStage,
        'lightInput': lightInput,
        'cut': cut,
        'lastEvent': lastEvent?.toJson(),
        'eventId': eventId,
        'finishedIn': finishedIn,
        if (duration > 0) 'duration': duration,
        if (pausedAt > 0) 'pausedAt': pausedAt,
        if (pauseReason.isNotEmpty) 'pauseReason': pauseReason,
        if (hints > 0) 'hints': hints,
        if (hint.isNotEmpty) 'hint': hint,
        if (errors > 0) 'errors': errors,
        if (syncOp > 0) 'syncOp': syncOp,
        if (syncEx > 0) 'syncEx': syncEx,
      };

  static int _i(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
  static List<int> _l(dynamic v) => v is List ? [for (final x in v) _i(x)] : <int>[];

  static GameState fromJson(Map j) => GameState(
        seed: _i(j['seed']),
        rooms: j['rooms'] is List && (j['rooms'] as List).isNotEmpty
            ? [for (final r in j['rooms'] as List) '$r']
            : kRooms,
        diff: '${j['diff'] ?? 'agent'}',
        dialStep: _i(j['dialStep']),
        stage: _i(j['stage']),
        phase: '${j['phase'] ?? 'lobby'}',
        room: _i(j['room']),
        startedAt: _i(j['startedAt']),
        penalty: _i(j['penalty']),
        mazePos: j['mazePos'] is num ? (j['mazePos'] as num).toInt() : null,
        lightStage: _i(j['lightStage']),
        lightInput: _l(j['lightInput']),
        cut: _l(j['cut']),
        lastEvent: GameEvent.fromJson(j['lastEvent']),
        eventId: _i(j['eventId']),
        finishedIn: _i(j['finishedIn']),
        duration: _i(j['duration']),
        pausedAt: _i(j['pausedAt']),
        pauseReason: '${j['pauseReason'] ?? ''}',
        hints: _i(j['hints']),
        hint: '${j['hint'] ?? ''}',
        errors: _i(j['errors']),
        syncOp: _i(j['syncOp']),
        syncEx: _i(j['syncEx']),
      );
}

GameState newState(int seed, {List<String> rooms = kRooms, String diff = 'agent', int stage = 0, int duration = 0}) =>
    GameState(seed: seed, rooms: rooms, diff: diff, stage: stage, duration: duration);

GameState startGame(GameState s, Puzzles p, int now) => GameState(
      seed: s.seed,
      rooms: s.rooms,
      diff: s.diff,
      stage: s.stage,
      duration: s.duration,
      phase: 'playing',
      startedAt: now,
      mazePos: p.maze.start,
      eventId: s.eventId + 1,
      lastEvent: GameEvent('start', s.rooms.first),
    );

double remainingSeconds(GameState s, int now) {
  final duration = s.effectiveDuration;
  if (s.startedAt == 0) return duration.toDouble();
  final t = s.pausedAt > 0 ? s.pausedAt : now;
  final r = duration - (t - s.startedAt) / 1000 - s.penalty;
  return r < 0 ? 0 : r;
}

GameState tick(GameState s, int now) {
  if (s.phase == 'playing' && !s.paused && remainingSeconds(s, now) <= 0) return s.copyWith(phase: 'lost');
  return s;
}

/// يوقف المؤقّت (انقطاع شريك أو نفاد الرصيد). يُستأنف من نفس النقطة.
GameState pauseGame(GameState s, int now, String reason) {
  if (s.phase != 'playing') return s;
  if (s.paused) return s.pauseReason == reason ? s : s.copyWith(pauseReason: reason);
  return s.copyWith(pausedAt: now, pauseReason: reason, eventId: s.eventId + 1, lastEvent: GameEvent('pause', s.roomId));
}

GameState resumeGame(GameState s, int now) {
  if (!s.paused) return s;
  return s.copyWith(
    startedAt: s.startedAt + (now - s.pausedAt),
    pausedAt: 0,
    pauseReason: '',
    eventId: s.eventId + 1,
    lastEvent: GameEvent('resume', s.roomId),
  );
}

/// تلميح مدفوع للقفل الحالي: يكشف جزءاً من الحلّ.
String hintFor(GameState s, Puzzles p) {
  if (isExtRoom(s.roomId)) return extFor(s).hint;
  switch (s.roomId) {
    case 'keypad':
      final a = p.keypad.answer;
      return 'أوّل رقمين من الرمز: ${a.substring(0, 2)}';
    case 'wires':
      return 'السلك الصحيح لونه ${kColors[p.wires.wires[p.wires.answer]].n}';
    case 'cipher':
      final a = p.cipher.answer;
      return 'الكلمة من ${a.length} حروف وتبدأ بـ «${a.substring(0, 1)}»';
    case 'maze':
      final dir = nextMazeStep(p.maze, s.mazePos ?? p.maze.start);
      const names = {'up': 'للأعلى ⬆', 'down': 'للأسفل ⬇', 'left': 'لليسار ⬅', 'right': 'لليمين ➡'};
      return dir == null ? 'أنت عند المخرج' : 'الخطوة الصحيحة التالية: ${names[dir]}';
    case 'lights':
      final exp = p.lights.expected(s.lightStage);
      final i = s.lightInput.length.clamp(0, exp.length - 1);
      return 'الضغطة التالية: ${kLights[exp[i]].n}';
    case 'dial':
      final ans = p.dial.answer;
      final step = s.dialStep.clamp(0, ans.length - 1);
      return 'الرقم ${step + 1} في القرص هو ${ans[step]}';
    case 'radio':
      final a = p.radio.answer;
      final lo = (a - 2 - (a % 3)).clamp(kFreqMin, kFreqMax);
      return 'التردّد بين $lo و ${(lo + 4).clamp(kFreqMin, kFreqMax)}';
  }
  return '';
}

String? nextMazeStep(Maze m, int from) {
  if (from == m.exit) return null;
  final prev = <int, (int, String)>{};
  final q = <int>[from];
  final seen = <int>{from};
  while (q.isNotEmpty) {
    final c = q.removeAt(0);
    if (c == m.exit) break;
    for (final d in kDirNames) {
      final n = m.neighbor(c, d);
      if (n != null && seen.add(n)) {
        prev[n] = (c, d);
        q.add(n);
      }
    }
  }
  var cur = m.exit;
  String? step;
  while (prev.containsKey(cur)) {
    final (back, d) = prev[cur]!;
    step = d;
    if (back == from) return step;
    cur = back;
  }
  return step;
}

/// يطبّق تلميحاً مدفوعاً (بعد موافقة الخادم).
GameState applyHint(GameState s, Puzzles p) {
  if (s.phase != 'playing') return s;
  return s.copyWith(hints: s.hints + 1, hint: hintFor(s, p), eventId: s.eventId + 1, lastEvent: GameEvent('hint', s.roomId));
}

/// يطبّق فعل اللاعب. يعيد نفس الكائن إذا لم يتغيّر شيء.
GameState applyAction(GameState s, Puzzles p, Map<String, dynamic> a, int now) {
  if (s.phase != 'playing' || s.paused) return s;
  final room = s.roomId;
  final type = a['type'];

  GameState ev(GameState x, String t, [int? pen]) =>
      x.copyWith(eventId: s.eventId + 1, lastEvent: GameEvent(t, room, pen));
  GameState advance(GameState x) {
    final next = s.room + 1;
    if (next >= s.rooms.length) {
      final y = x.copyWith(room: next, phase: 'won');
      return ev(y.copyWith(finishedIn: (s.effectiveDuration - remainingSeconds(y, now)).round(), hint: ''), 'solved');
    }
    return ev(x.copyWith(room: next, hint: ''), 'solved');
  }

  final mods = stageMods(s.stage);
  GameState wrong(GameState x, [int? pen, String t = 'wrong']) {
    var p0 = pen ?? s.difficulty.penalty;
    // الإنذار: كل خطأ أغلى من الذي قبله
    if (mods.contains('alarm') && t == 'wrong') p0 = (p0 * (1 + s.errors * 0.5)).round();
    final errs = s.errors + 1;
    var y = x.copyWith(penalty: s.penalty + p0, errors: errs);
    // محاولات محدودة: الخطأ الرابع يُفشل المهمّة
    if (mods.contains('limited') && t == 'wrong' && errs > kLimitedTries) y = y.copyWith(phase: 'lost');
    return ev(y, t, p0);
  }

  GameState out = s;
  switch (room) {
    case 'keypad': {
      if (type != 'submit') return s;
      out = '${a['value'] ?? ''}'.trim() == p.keypad.answer ? advance(s) : wrong(s);
      break;
    }
    case 'cipher': {
      if (type != 'submit') return s;
      out = normalizeAnswer('${a['value'] ?? ''}') == p.cipher.answer ? advance(s) : wrong(s);
      break;
    }
    case 'wires': {
      final idx = a['idx'];
      if (type != 'cut' || idx is! int || s.cut.contains(idx)) return s;
      if (idx < 0 || idx >= p.wires.wires.length) return s;
      final withCut = s.copyWith(cut: [...s.cut, idx]);
      out = idx == p.wires.answer ? advance(withCut) : wrong(withCut);
      break;
    }
    case 'maze': {
      final dir = a['dir'];
      if (type != 'move' || dir is! String || !kDirs.containsKey(dir)) return s;
      final np = p.maze.neighbor(s.mazePos ?? p.maze.start, dir);
      if (np == null) {
        out = wrong(s, kBump, 'bump');
      } else {
        final moved = s.copyWith(mazePos: np);
        out = np == p.maze.exit ? advance(moved) : ev(moved, 'moved');
      }
      break;
    }
    case 'lights': {
      final c = a['color'];
      if (type != 'press' || c is! int) return s;
      final st = s.lightStage;
      final expected = p.lights.expected(st);
      final input = [...s.lightInput, c];
      if (input.last != expected[input.length - 1]) {
        out = wrong(s.copyWith(lightInput: const []));
      } else if (input.length < expected.length) {
        out = ev(s.copyWith(lightInput: input), 'press');
      } else if (st == p.lights.seq.length - 1) {
        out = advance(s.copyWith(lightInput: const []));
      } else {
        out = ev(s.copyWith(lightInput: const [], lightStage: st + 1), 'stage');
      }
      break;
    }
    case 'dial': {
      final v = a['value'];
      if (type != 'dial' || v is! int) return s;
      final step = s.dialStep;
      final ans = p.dial.answer;
      if (v != ans[step]) {
        out = wrong(s.copyWith(dialStep: 0));
      } else if (step == ans.length - 1) {
        out = advance(s.copyWith(dialStep: 0));
      } else {
        out = ev(s.copyWith(dialStep: step + 1), 'press');
      }
      break;
    }
    case 'radio': {
      final v = a['value'];
      if (type != 'tune' || v is! int) return s;
      out = v == p.radio.answer ? advance(s) : wrong(s);
      break;
    }
    default: {
      if (!isExtRoom(room)) return s;
      final x = extFor(s);
      if (type == 'ext') {
        final v = '${a['value'] ?? ''}';
        if (v.isEmpty) return s;
        out = x.check(v) ? advance(s) : wrong(s);
      } else if (type == 'sync' && room == 'sync') {
        final role = a['role'], idx = a['idx'];
        if (idx is! int || (role != 'op' && role != 'ex')) return s;
        final ok = role == 'op' ? idx == int.parse(x.answer) : idx == x.exAnswer;
        if (!ok) {
          out = wrong(s.copyWith(syncOp: 0, syncEx: 0));
          break;
        }
        final other = role == 'op' ? s.syncEx : s.syncOp;
        if (other > 0 && (now - other).abs() <= kSyncWindowMs) {
          out = advance(s.copyWith(syncOp: 0, syncEx: 0));
        } else {
          out = ev(role == 'op' ? s.copyWith(syncOp: now, syncEx: 0) : s.copyWith(syncEx: now, syncOp: 0), 'press');
        }
      } else {
        return s;
      }
    }
  }
  return tick(out, now);
}
