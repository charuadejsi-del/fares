// وضع الخريطة 2D من الأعلى: كل مرحلة مبنى يُخترق غرفة غرفة حتى الخزنة.
// كل شيء محسوب من البذرة (الخريطة، مسارات الحرّاس، الكاميرات) فيرى الهاتفان المبنى نفسه
// دون إرسال الخريطة؛ الحرّاس والكاميرات تتحرّك حسب «وقت المهمّة» المشترك.
import 'dart:math';
import 'dart:ui' show Offset;

/// أنواع البلاطات.
const int kFloor = 0, kWall = 1, kCrate = 2;

/// قياس الغرفة في الشبكة (يشمل جداراً مشتركاً واحداً).
const int kRoomW = 9, kRoomH = 7;

class HRoom {
  /// حدود الأرضية الداخلية (شاملة).
  final int x0, y0, x1, y1;
  final Offset terminal;
  const HRoom(this.x0, this.y0, this.x1, this.y1, this.terminal);
  Offset get center => Offset((x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2);
  bool contains(Offset p) => p.dx >= x0 && p.dx < x1 + 1 && p.dy >= y0 && p.dy < y1 + 1;
}

/// باب بين الغرفة [after] والغرفة [after]+1: يُفتح حين يُحلّ قفل الغرفة [after].
class HDoor {
  final List<Point<int>> cells;
  final int after;
  const HDoor(this.cells, this.after);
}

/// حارس يدور في مسار مغلق داخل غرفة.
class HGuard {
  final List<Offset> path;
  final double speed;
  final int room;
  HGuard(this.path, this.speed, this.room);
  late final double length = () {
    var l = 0.0;
    for (int i = 0; i < path.length; i++) {
      l += (path[(i + 1) % path.length] - path[i]).distance;
    }
    return l;
  }();
}

/// كاميرا مثبّتة في زاوية تمسح بين زاويتين.
class HCam {
  final Offset pos;
  final double a0, a1, period;
  final int room;
  const HCam(this.pos, this.a0, this.a1, this.period, this.room);
}

/// شعاع ليزر: إمّا يومض (يشتعل وينطفئ) في مكانه، وإمّا ثابت الاشتعال يكنس الغرفة ذهاباً وإياباً.
class HLaser {
  final Offset a, b;
  final bool sweep;

  /// الكنس: الشعاع عمودي ويتحرّك أفقياً (true) أو أفقي ويتحرّك عمودياً.
  final bool vertical;
  final double lo, hi, period, phase;
  final int room;
  const HLaser(this.a, this.b, this.period, this.phase, this.room, {this.sweep = false, this.vertical = false, this.lo = 0, this.hi = 0});

  static const double onFrac = .55;

  /// موضع الشعاع عند الوقت [t]، أو null حين يكون مطفأً.
  (Offset, Offset)? at(double t) {
    if (sweep) {
      final v = lo + (hi - lo) * (.5 - .5 * cos(2 * pi * (t + phase) / period));
      return vertical ? (Offset(v, a.dy), Offset(v, b.dy)) : (Offset(a.dx, v), Offset(b.dx, v));
    }
    return ((t + phase) % period) < period * onFrac ? (a, b) : null;
  }

  /// كم ثانية بقيت قبل الاشتعال (للتحذير)، أو null إن كان مشتعلاً.
  double? warmup(double t) {
    if (sweep) return null;
    final ph = (t + phase) % period;
    return ph < period * onFrac ? null : period - ph;
  }

  bool hits(Offset p, double t) {
    final seg = at(t);
    if (seg == null) return false;
    return _segDist(p, seg.$1, seg.$2) < .32;
  }
}

double _segDist(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final l2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (l2 == 0) return (p - a).distance;
  final k = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / l2).clamp(0.0, 1.0);
  return (p - (a + ab * k)).distance;
}

/// خطّة الهروب بعد فتح الخزنة: المدّة الكلّية، ومتى يُغلق كل باب (ثوانٍ من بداية الإنذار).
class EscapePlan {
  final double seconds;
  final List<double> doorClose;
  const EscapePlan(this.seconds, this.doorClose);
}

class HeistParams {
  final int guards, cams, crates;
  final double guardSpeed, guardRange, camRange, vision;
  const HeistParams(this.guards, this.cams, this.crates, this.guardSpeed, this.guardRange, this.camRange, this.vision);
}

/// تصاعد الصعوبة عبر المراحل.
HeistParams heistParams(int stage) {
  if (stage <= 5) return const HeistParams(0, 0, 2, 1.3, 3.5, 4.5, 4.2);
  if (stage <= 20) return HeistParams(stage < 12 ? 1 : 2, 1, 3, 1.4, 3.6, 4.5, 3.8);
  if (stage <= 40) return HeistParams(stage < 30 ? 2 : 3, 2, 4, 1.6, 3.8, 5.0, 3.5);
  return HeistParams(stage < 50 ? 3 : 4, 3, 5, 1.9, 4.0, 5.2, 3.0);
}

/// نصف زاوية مخروط الرؤية.
const double kGuardHalf = 0.62, kCamHalf = 0.45;

/// العقوبة عند الاكتشاف (ثوانٍ).
const int kSpotPenalty = 20;

/// مدّة تعطيل الكاميرا (ثوانٍ من وقت المهمّة).
const double kCamHackSeconds = 10;

/// المحلّل يرى الحرّاس مباشرة حتى المرحلة 40؛ بعدها يرى المسارات فقط.
bool analystSeesGuards(int stage) => stage <= 40;

// ───── مفاجآت المطاردة (تتراكم مرحلة بعد مرحلة) ─────
/// وقع الخطى: الحرّاس يواصلون دورتهم أثناء الاختراق ويمكنهم رؤيتك وأنت عند الجهاز.
bool footstepsStage(int n) => n >= 6;

/// الهروب: فتح الخزنة يطلق الإنذار؛ الأبواب تُغلق واحداً بعد الآخر حتى تصل إلى المخرج.
bool escapeStage(int n) => n >= 10;

/// بطاقة الحارس: جهاز غرفة الحارس لا يعمل إلا ببطاقته — تُسرق من خلفه.
bool cardStage(int n) => n >= 12;

/// قطع التيار: المحلّل يطفئ المبنى، الكاميرات تتوقّف والحرّاس بمصابيح قصيرة.
bool powerStage(int n) => n >= 15;

/// الليزر: أشعّة تومض، ومن المرحلة 30 أشعّة تكنس الغرفة.
bool laserStage(int n) => n >= 18;

const double kAgentSpeed = 3.2;
const double kPowerSeconds = 15, kPowerCooldown = 35;

/// كم يقترب العميل من ظهر الحارس ليسرق البطاقة، وكم يبقى خلفه.
const double kPickRange = 1.15, kPickSeconds = .8;

class HeistMap {
  final int w, h;
  final List<int> tiles;
  final List<HRoom> rooms;
  final List<HDoor> doors;
  final List<HGuard> guards;
  final List<HCam> cams;
  final Offset spawn;
  final HeistParams params;
  final List<HLaser> lasers = [];

  /// الحرّاس الذين يحملون بطاقات (رقم الحارس)؛ البطاقة تفتح جهاز غرفته.
  final List<int> cardGuards = [];
  HeistMap(this.w, this.h, this.tiles, this.rooms, this.doors, this.guards, this.cams, this.spawn, this.params);

  int at(int x, int y) => (x < 0 || y < 0 || x >= w || y >= h) ? kWall : tiles[y * w + x];

  /// [shut]: أبواب أُغلقت أثناء الهروب (أرقامها).
  bool doorClosedAt(int x, int y, int solved, [Set<int> shut = const {}]) {
    for (int i = 0; i < doors.length; i++) {
      final d = doors[i];
      if ((d.after >= solved || shut.contains(i)) && d.cells.any((c) => c.x == x && c.y == y)) return true;
    }
    return false;
  }

  /// صلب للحركة: جدار أو صندوق أو باب مغلق.
  bool solid(int x, int y, int solved, [Set<int> shut = const {}]) => at(x, y) != kFloor || doorClosedAt(x, y, solved, shut);

  /// رقم الغرفة التي فيها النقطة (‎-1 = في باب أو جدار).
  int roomOf(Offset p) {
    for (int i = 0; i < rooms.length; i++) {
      if (rooms[i].contains(p)) return i;
    }
    return -1;
  }

  Offset doorCenter(int i) {
    final d = doors[i];
    var c = Offset.zero;
    for (final q in d.cells) {
      c += Offset(q.x + .5, q.y + .5);
    }
    return c / d.cells.length.toDouble();
  }

  /// غرف الأجهزة المقفلة بالبطاقة.
  Set<int> get cardRooms => {for (final g in cardGuards) guards[g].room};

  /// الأبواب المغلقة بعد [since] ثانية من بداية الإنذار.
  Set<int> shutAfter(double since) => {
        for (int i = 0; i < doors.length; i++)
          if (since >= escape.doorClose[i]) i,
      };

  late final EscapePlan escape = () {
    // مسافة المشي الحقيقية (بحث عرضي) من الخزنة إلى كل باب وإلى المخرج
    final all = doors.length + 1;
    final dist = List<int>.filled(w * h, -1);
    final v = rooms.last.terminal;
    final q = <int>[v.dy.floor() * w + v.dx.floor()];
    dist[q.first] = 0;
    for (int k = 0; k < q.length; k++) {
      final c = q[k], cx = c % w, cy = c ~/ w;
      for (final o in const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]) {
        final x = cx + o.x, y = cy + o.y;
        if (solid(x, y, all)) continue;
        final i = y * w + x;
        if (dist[i] < 0) {
          dist[i] = dist[c] + 1;
          q.add(i);
        }
      }
    }
    double secs(int tiles) => tiles / kAgentSpeed;
    final close = [
      for (final d in doors)
        () {
          final m = d.cells.map((c) => dist[c.y * w + c.x]).where((x) => x >= 0).fold<int>(0, max);
          return secs(m) * 1.5 + 3.5;
        }(),
    ];
    final exit = dist[spawn.dy.floor() * w + spawn.dx.floor()];
    return EscapePlan(secs(max(0, exit)) * 1.5 + 6, close);
  }();

  /// نقطة الحفظ: مدخل الغرفة الحالية (أو نقطة البداية).
  Offset checkpoint(int solved) {
    if (solved <= 0 || solved > doors.length) return spawn;
    final d = doors[solved - 1];
    final r = rooms[solved];
    // الخلية الداخلية المجاورة للباب داخل الغرفة الجديدة
    for (final c in d.cells) {
      for (final o in const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]) {
        final p = Offset(c.x + o.x + .5, c.y + o.y + .5);
        if (r.contains(p) && at(c.x + o.x, c.y + o.y) == kFloor) return p;
      }
    }
    return r.center;
  }

  /// يتحرّك من [from] بمقدار [delta] مع منع اختراق الجدران (دائرة نصف قطرها [radius]).
  Offset move(Offset from, Offset delta, int solved, {double radius = .3, Set<int> shut = const {}}) {
    bool blocked(double x, double y) {
      for (final dx in [-radius, radius]) {
        for (final dy in [-radius, radius]) {
          if (solid((x + dx).floor(), (y + dy).floor(), solved, shut)) return true;
        }
      }
      return false;
    }

    var x = from.dx, y = from.dy;
    if (!blocked(x + delta.dx, y)) x += delta.dx;
    if (!blocked(x, y + delta.dy)) y += delta.dy;
    return Offset(x, y);
  }

  /// خطّ رؤية: الجدران والصناديق والأبواب المغلقة تحجب.
  bool lineOfSight(Offset a, Offset b, int solved, [Set<int> shut = const {}]) {
    final d = b - a;
    final n = max(1, (d.distance / .2).ceil());
    for (int i = 1; i < n; i++) {
      final p = a + d * (i / n);
      if (solid(p.dx.floor(), p.dy.floor(), solved, shut)) return false;
    }
    return true;
  }

  /// هل يُرى العميل الآن؟ [camOff]: الكاميرات المعطّلة (رقم ← حتى أيّ وقت).
  /// [power]: التيار مقطوع (لا كاميرات، مصابيح الحرّاس أقصر). [alarm]: الإنذار يعمل (الحرّاس أيقظ).
  bool seen(Offset p, double t, int solved, Map<String, double> camOff,
      {bool power = false, bool alarm = false, Set<int> shut = const {}}) {
    final range = guardRange(power: power, alarm: alarm);
    for (final g in guards) {
      final (gp, ga) = guardAt(g, t);
      if (inCone(gp, ga, p, range, kGuardHalf) && lineOfSight(gp, p, solved, shut)) return true;
    }
    if (power) return false;
    for (int i = 0; i < cams.length; i++) {
      if ((camOff['$i'] ?? -1) > t) continue;
      final c = cams[i];
      if (inCone(c.pos, camAngle(c, t), p, params.camRange, kCamHalf) && lineOfSight(c.pos, p, solved)) return true;
    }
    return false;
  }

  double guardRange({bool power = false, bool alarm = false}) =>
      params.guardRange * (power ? .55 : 1) * (alarm ? 1.25 : 1);

  /// هل يلمس العميل شعاعاً مشتعلاً؟
  bool laserHit(Offset p, double t) => lasers.any((l) => l.hits(p, t));

  /// العميل خلف الحارس وقريب منه (خارج مخروط رؤيته).
  bool behind(int g, Offset p, double t) {
    final (gp, ga) = guardAt(guards[g], t);
    final d = p - gp;
    if (d.distance > kPickRange) return false;
    var diff = atan2(d.dy, d.dx) - ga;
    while (diff > pi) {
      diff -= 2 * pi;
    }
    while (diff < -pi) {
      diff += 2 * pi;
    }
    return diff.abs() > pi / 2;
  }

  /// أقرب حارس إلى [p] (للتحذير بوقع الخطى).
  double nearestGuard(Offset p, double t) {
    var best = double.infinity;
    for (final g in guards) {
      best = min(best, (guardAt(g, t).$1 - p).distance);
    }
    return best;
  }
}

/// موقع الحارس واتجاهه عند الوقت [t].
(Offset, double) guardAt(HGuard g, double t) {
  if (g.path.length < 2 || g.length <= 0) return (g.path.first, 0);
  var d = (t * g.speed) % g.length;
  for (int i = 0; i < g.path.length; i++) {
    final a = g.path[i], b = g.path[(i + 1) % g.path.length];
    final seg = (b - a).distance;
    if (d <= seg) {
      final dir = b - a;
      return (a + dir * (seg == 0 ? 0 : d / seg), atan2(dir.dy, dir.dx));
    }
    d -= seg;
  }
  return (g.path.first, 0);
}

double camAngle(HCam c, double t) => c.a0 + (c.a1 - c.a0) * (.5 - .5 * cos(2 * pi * t / c.period));

bool inCone(Offset from, double angle, Offset p, double range, double half) {
  final d = p - from;
  final dist = d.distance;
  if (dist > range || dist < .05) return dist < .05;
  var diff = atan2(d.dy, d.dx) - angle;
  while (diff > pi) {
    diff -= 2 * pi;
  }
  while (diff < -pi) {
    diff += 2 * pi;
  }
  return diff.abs() <= half;
}

final Map<String, HeistMap> _cache = {};

/// الخريطة لهذه البذرة/المرحلة/عدد الأقفال.
HeistMap heistMap(int seed, int stage, int locks) =>
    _cache.putIfAbsent('$seed:$stage:$locks', () {
      if (_cache.length > 8) _cache.clear();
      return _generate(seed, stage, locks);
    });

// ───────── التوليد ─────────
HeistMap _generate(int seed, int stage, int n) {
  n = max(1, n);
  final r = Random(seed ^ 0x5EED1234);
  final p = heistParams(stage);
  final cols = n > 9 ? 4 : 3;
  final rows = (n / cols).ceil() + 1;
  final slots = _slotPath(r, cols, rows, n);
  final w = cols * kRoomW + 1, h = rows * kRoomH + 1;
  final tiles = List<int>.filled(w * h, kWall);
  void set(int x, int y, int v) => tiles[y * w + x] = v;

  // الغرف
  final bounds = <List<int>>[];
  for (final s in slots) {
    final x0 = s.x * kRoomW + 1, y0 = s.y * kRoomH + 1;
    final x1 = x0 + kRoomW - 2, y1 = y0 + kRoomH - 2;
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        set(x, y, kFloor);
      }
    }
    bounds.add([x0, y0, x1, y1]);
  }

  // الأبواب: فتحة بخليّتين في الجدار المشترك
  final doors = <HDoor>[];
  for (int i = 0; i + 1 < slots.length; i++) {
    final a = slots[i], b = slots[i + 1];
    final cells = <Point<int>>[];
    if (a.y == b.y) {
      final x = max(a.x, b.x) * kRoomW;
      final yMid = a.y * kRoomH + kRoomH ~/ 2;
      cells.addAll([Point(x, yMid - 1), Point(x, yMid)]);
    } else {
      final y = max(a.y, b.y) * kRoomH;
      final xMid = a.x * kRoomW + kRoomW ~/ 2;
      cells.addAll([Point(xMid - 1, y), Point(xMid, y)]);
    }
    for (final c in cells) {
      set(c.x, c.y, kFloor);
    }
    doors.add(HDoor(cells, i));
  }

  bool nearDoor(int x, int y) => doors.any((d) => d.cells.any((c) => (c.x - x).abs() + (c.y - y).abs() <= 2));

  // نقطة البداية: أبعد زاوية عن باب الخروج في الغرفة الأولى
  final b0 = bounds.first;
  final spawnCandidates = [
    Offset(b0[0] + 1.5, b0[1] + 1.5), Offset(b0[2] - .5, b0[1] + 1.5),
    Offset(b0[0] + 1.5, b0[3] - .5), Offset(b0[2] - .5, b0[3] - .5),
  ];
  Offset spawn = spawnCandidates.first;
  if (doors.isNotEmpty) {
    final dc = doors.first.cells.first;
    final door = Offset(dc.x + .5, dc.y + .5);
    spawnCandidates.sort((a, b) => (b - door).distance.compareTo((a - door).distance));
    spawn = spawnCandidates.first;
  }

  // الحرّاس: في الغرف 1..n-1 (ليس غرفة البداية)
  final reserved = <int>{};
  void reserve(Offset o) => reserved.add(o.dy.floor() * w + o.dx.floor());
  final guards = <HGuard>[];
  if (n > 1 && p.guards > 0) {
    final pool = [for (int i = 1; i < n; i++) i]..shuffle(r);
    for (int k = 0; k < p.guards; k++) {
      final ri = pool[k % pool.length];
      final b = bounds[ri];
      final path = r.nextBool()
          // حلقة مستطيلة داخلية
          ? [
              Offset(b[0] + 1.5, b[1] + 1.5), Offset(b[2] - .5, b[1] + 1.5),
              Offset(b[2] - .5, b[3] - .5), Offset(b[0] + 1.5, b[3] - .5),
            ]
          // ذهاب وإياب في صفّ عشوائي
          : () {
              final y = b[1] + 1 + r.nextInt(max(1, b[3] - b[1] - 1)) + .5;
              return [Offset(b[0] + .5, y), Offset(b[2] + .5, y)];
            }();
      // انطلاقات مختلفة لحارسين في نفس الغرفة: ابدأ المسار من نقطة أخرى
      final shift = guards.where((g) => g.room == ri).length;
      final rot = [...path.sublist(shift % path.length), ...path.sublist(0, shift % path.length)];
      guards.add(HGuard(rot, p.guardSpeed * (0.85 + r.nextDouble() * .3), ri));
      for (int i = 0; i < rot.length; i++) {
        final a = rot[i], c = rot[(i + 1) % rot.length];
        final steps = ((c - a).distance / .5).ceil();
        for (int s = 0; s <= steps; s++) {
          reserve(a + (c - a) * (steps == 0 ? 0 : s / steps));
        }
      }
    }
  }

  // الكاميرات: في زاوية غرفة، تمسح 90° نحو الداخل
  final cams = <HCam>[];
  if (n > 1 && p.cams > 0) {
    final pool = [for (int i = 1; i < n; i++) i]..shuffle(r);
    for (int k = 0; k < p.cams && k < pool.length; k++) {
      final b = bounds[pool[k]];
      final corner = r.nextInt(4);
      final pos = [
        Offset(b[0] + .3, b[1] + .3), Offset(b[2] + .7, b[1] + .3),
        Offset(b[2] + .7, b[3] + .7), Offset(b[0] + .3, b[3] + .7),
      ][corner];
      final base = [0.0, pi / 2, pi, -pi / 2][corner];
      cams.add(HCam(pos, base, base + pi / 2, 5 + r.nextDouble() * 3, pool[k]));
    }
  }

  // الأجهزة (موقع القفل في كل غرفة): خلية ملاصقة لجدار، بعيدة عن الأبواب ومسارات الحرّاس
  final rooms = <HRoom>[];
  for (int i = 0; i < bounds.length; i++) {
    final b = bounds[i];
    final cand = <Point<int>>[];
    for (int y = b[1]; y <= b[3]; y++) {
      for (int x = b[0]; x <= b[2]; x++) {
        final edge = x == b[0] || x == b[2] || y == b[1] || y == b[3];
        if (!edge || nearDoor(x, y) || reserved.contains(y * w + x)) continue;
        if (i == 0 && (Offset(x + .5, y + .5) - spawn).distance < 3) continue;
        cand.add(Point(x, y));
      }
    }
    final t = cand.isEmpty ? Point(b[0] + (b[2] - b[0]) ~/ 2, b[1] + (b[3] - b[1]) ~/ 2) : cand[r.nextInt(cand.length)];
    reserve(Offset(t.x + .5, t.y + .5));
    rooms.add(HRoom(b[0], b[1], b[2], b[3], Offset(t.x + .5, t.y + .5)));
  }
  reserve(spawn);

  // الصناديق: مخابئ تحجب الرؤية، مع ضمان بقاء الطريق مفتوحاً
  final map = HeistMap(w, h, tiles, rooms, doors, guards, cams, spawn, p);
  for (int i = 0; i < bounds.length; i++) {
    final b = bounds[i];
    for (int k = 0; k < p.crates; k++) {
      final x = b[0] + 1 + r.nextInt(max(1, b[2] - b[0] - 1));
      final y = b[1] + 1 + r.nextInt(max(1, b[3] - b[1] - 1));
      if (reserved.contains(y * w + x) || nearDoor(x, y) || tiles[y * w + x] != kFloor) continue;
      set(x, y, kCrate);
      if (!_connected(map)) set(x, y, kFloor);
    }
  }

  // بطاقات الحرّاس: حارس واحد، ومن المرحلة 35 حارسان في غرفتين مختلفتين
  final rc = Random(seed ^ 0xCA4D);
  if (cardStage(stage) && guards.isNotEmpty) {
    final order = [for (int i = 0; i < guards.length; i++) i]..shuffle(rc);
    final want = stage >= 35 ? 2 : 1;
    for (final g in order) {
      if (map.cardGuards.length >= want) break;
      if (map.cardGuards.any((o) => guards[o].room == guards[g].room)) continue;
      map.cardGuards.add(g);
    }
  }

  // الليزر: في غرف لا فيها جهاز على صفّ الشعاع، ولا في غرفة البداية
  final rl = Random(seed ^ 0x1A5E);
  if (laserStage(stage) && n > 1) {
    final count = stage >= 40 ? 3 : (stage >= 30 ? 2 : 1);
    final pool = [for (int i = 1; i < n; i++) i]..shuffle(rl);
    for (int k = 0; k < count && k < pool.length; k++) {
      final ri = pool[k];
      final b = bounds[ri];
      final term = rooms[ri].terminal;
      final tx = term.dx.floor(), ty = term.dy.floor();
      final period = 2.6 + rl.nextDouble() * 1.6;
      final phase = rl.nextDouble() * period;
      final sweep = stage >= 30 && k == 0;
      if (sweep) {
        // الجهاز على جدار جانبي ← شعاع عمودي يكنس بين الجدارين دون أن يصله
        final vertical = tx == b[0] || tx == b[2];
        map.lasers.add(vertical
            ? HLaser(Offset(0, b[1].toDouble()), Offset(0, b[3] + 1.0), period * 2.2, phase, ri,
                sweep: true, vertical: true, lo: b[0] + 1.5, hi: b[2] - .5)
            : HLaser(Offset(b[0].toDouble(), 0), Offset(b[2] + 1.0, 0), period * 2.2, phase, ri,
                sweep: true, lo: b[1] + 1.5, hi: b[3] - .5));
        continue;
      }
      final rows = [for (int y = b[1] + 1; y < b[3]; y++) if (y != ty) y];
      if (rows.isEmpty) continue;
      final y = rows[rl.nextInt(rows.length)] + .5;
      map.lasers.add(HLaser(Offset(b[0].toDouble(), y), Offset(b[2] + 1.0, y), period, phase, ri));
    }
  }
  return map;
}

/// مسار من n خانة متجاورة في شبكة cols×rows (بحث عميق مع تراجع؛ وإلا مسار أفعواني).
List<Point<int>> _slotPath(Random r, int cols, int rows, int n) {
  for (int attempt = 0; attempt < 40; attempt++) {
    final path = <Point<int>>[Point(r.nextInt(cols), rows - 1)];
    final used = {path.first};
    bool dfs() {
      if (path.length == n) return true;
      final c = path.last;
      final nb = [Point(c.x + 1, c.y), Point(c.x - 1, c.y), Point(c.x, c.y + 1), Point(c.x, c.y - 1)]
          .where((q) => q.x >= 0 && q.y >= 0 && q.x < cols && q.y < rows && !used.contains(q))
          .toList()
        ..shuffle(r);
      for (final q in nb) {
        path.add(q);
        used.add(q);
        if (dfs()) return true;
        path.removeLast();
        used.remove(q);
      }
      return false;
    }

    if (dfs()) return path;
  }
  return [for (int i = 0; i < n; i++) Point((i ~/ rows).isEven ? i % cols : cols - 1 - i % cols, rows - 1 - i ~/ cols)];
}

/// كل الأجهزة والأبواب قابلة للوصول عند فتح كل الأبواب.
bool _connected(HeistMap m) {
  final all = m.doors.length + 1;
  final start = Point(m.spawn.dx.floor(), m.spawn.dy.floor());
  final seen = <int>{start.y * m.w + start.x};
  final q = <Point<int>>[start];
  while (q.isNotEmpty) {
    final c = q.removeLast();
    for (final o in const [Point(1, 0), Point(-1, 0), Point(0, 1), Point(0, -1)]) {
      final x = c.x + o.x, y = c.y + o.y;
      if (m.solid(x, y, all)) continue;
      if (seen.add(y * m.w + x)) q.add(Point(x, y));
    }
  }
  for (final room in m.rooms) {
    final t = room.terminal;
    if (!seen.contains(t.dy.floor() * m.w + t.dx.floor())) return false;
  }
  for (final d in m.doors) {
    for (final c in d.cells) {
      if (!seen.contains(c.y * m.w + c.x)) return false;
    }
  }
  return true;
}
