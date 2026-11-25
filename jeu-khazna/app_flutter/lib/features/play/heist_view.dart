// وضع الخريطة 2D: العميل يتحرّك داخل المبنى برؤية محدودة، والمحلّل يرى المخطّط كاملاً.
// الوصول إلى جهاز الغرفة يفتح القفل نفسه (كل الأقفال الثلاثين كما هي).
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/heist.dart';
import '../../core/stages.dart';
import '../../widgets/spy_ui.dart';

/// صور الوضع 2D (تُحمَّل مرّة واحدة؛ الرسم يعود للأشكال البسيطة إلى أن تجهز).
class HeistSprites {
  static final Map<String, ui.Image> _img = {};
  static bool _loading = false;
  static const names = [
    'h_agent', 'h_guard', 'h_camera', 'h_terminal', 'h_crate', 'h_door',
    'h_floor_port', 'h_floor_river', 'h_floor_mountain',
  ];

  static ui.Image? get(String n) => _img[n];

  static Future<void> load() async {
    if (_loading || _img.length == names.length) return;
    _loading = true;
    for (final n in names) {
      try {
        final ext = n.startsWith('h_floor') ? 'jpg' : 'png';
        final data = await rootBundle.load('assets/images/$n.$ext');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _img[n] = (await codec.getNextFrame()).image;
      } catch (_) {}
    }
    _loading = false;
  }

  /// أرضية المنطقة: الميناء 1–20، النهر 21–40، الجبل بعدها.
  static ui.Image? floorFor(int stage) =>
      get(stage <= 20 ? 'h_floor_port' : (stage <= 40 ? 'h_floor_river' : 'h_floor_mountain'));
}

String _clock(double sec) {
  final s = sec.ceil().clamp(0, 99999);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// يختار شاشة العميل أو المحلّل. [lockView] = شاشة القفل الحالية (تُفتح عند الجهاز).
class HeistPlay extends StatelessWidget {
  final GameController c;
  final Widget lockView;
  final VoidCallback onExit;
  const HeistPlay({super.key, required this.c, required this.lockView, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final map = heistMap(s.seed, s.stage, s.rooms.length);
    HeistSprites.load();
    if ((c.myRole ?? 'op') == 'op') return _AgentView(c: c, map: map, lockView: lockView, onExit: onExit);
    return LayoutBuilder(
      builder: (context, box) => Column(children: [
        SizedBox(height: box.maxHeight * .42, child: _AnalystMap(c: c, map: map)),
        Expanded(child: s.escape > 0 ? _EscapePanel(c: c, map: map) : lockView),
      ]),
    );
  }
}

// ───────── العميل ─────────
class _AgentView extends StatefulWidget {
  final GameController c;
  final HeistMap map;
  final Widget lockView;
  final VoidCallback onExit;
  const _AgentView({required this.c, required this.map, required this.lockView, required this.onExit});

  @override
  State<_AgentView> createState() => _AgentViewState();
}

class _AgentViewState extends State<_AgentView> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  late Offset _pos;
  Offset _stick = Offset.zero;
  double _facing = 0;
  double _seenFor = 0;
  int _invulnUntil = 0;
  int _spots = 0, _room = 0;
  bool _hacking = false;
  bool _help = true;
  String? _intro;
  Duration _last = Duration.zero;

  // مفاجآت المطاردة
  double _pick = 0; // تقدّم سرقة البطاقة (0..kPickSeconds)
  final Set<int> _picked = {};
  bool _endSent = false;
  int _shutCount = 0;
  double _nearGuard = double.infinity;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    final s = c.state!;
    _spots = s.spots;
    _room = s.room;
    // بعد تبادل الأدوار: نبدأ من آخر موقع للشريك
    _pos = c.partnerX != null && s.room > 0 ? Offset(c.partnerX!, c.partnerY!) : widget.map.checkpoint(s.room);
    if (s.room > 0 || s.spots > 0) _help = false;
    _intro = _introFor(s.stage);
    if (_intro != null) {
      Future.delayed(const Duration(seconds: 9), () {
        if (mounted) setState(() => _intro = null);
      });
    }
  }

  /// تعريف المفاجأة الجديدة في مرحلتها الأولى.
  static String? _introFor(int n) => switch (n) {
        6 => '🔊 جديد: الحرّاس لا يتوقّفون وأنت تخترق. راقب تحذير الخطى واهرب قبل أن يراك.',
        10 => '🚨 جديد: فتح الخزنة يطلق الإنذار! عُد إلى نقطة البداية قبل أن تُغلق الأبواب خلفك.',
        12 => '🪪 جديد: جهاز غرفة الحارس الذهبي يحتاج بطاقته. تسلّل خلفه وابقَ قريباً لتسرقها.',
        15 => '⚡ جديد: شريكك يستطيع قطع التيار: الكاميرات تتوقّف والحرّاس يرون أقلّ… وأنت أيضاً.',
        18 => '🔴 جديد: أشعّة ليزر تومض. لا تعبرها وهي مشتعلة — شريكك يعدّ لك التوقيت.',
        30 => '🔴 جديد: شعاع ليزر يكنس الغرفة ذهاباً وإياباً. اعبر خلفه.',
        35 => '🪪 حارسان يحملان بطاقتين هذه المرّة.',
        _ => null,
      };

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Offset _keys() {
    final k = HardwareKeyboard.instance.logicalKeysPressed;
    var x = 0.0, y = 0.0;
    if (k.contains(LogicalKeyboardKey.arrowLeft) || k.contains(LogicalKeyboardKey.keyA) || k.contains(LogicalKeyboardKey.keyQ)) x -= 1;
    if (k.contains(LogicalKeyboardKey.arrowRight) || k.contains(LogicalKeyboardKey.keyD)) x += 1;
    if (k.contains(LogicalKeyboardKey.arrowUp) || k.contains(LogicalKeyboardKey.keyW) || k.contains(LogicalKeyboardKey.keyZ)) y -= 1;
    if (k.contains(LogicalKeyboardKey.arrowDown) || k.contains(LogicalKeyboardKey.keyS)) y += 1;
    final v = Offset(x, y);
    return v.distance > 1 ? v / v.distance : v;
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = now;
    final s = c.state;
    if (s == null || s.phase != 'playing') return;
    final map = widget.map;
    final solved = s.room;
    final t = c.heistTime;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final escaping = s.escape > 0;
    final since = escaping ? t - s.escape : 0.0;
    final power = s.power > t;

    // الأبواب التي أُغلقت (الباب الذي يقف فيه العميل يبقى له حتى يخرج منه)
    final shut = escaping ? (map.shutAfter(since)..removeWhere((i) => (map.doorCenter(i) - _pos).distance < 1.4)) : <int>{};
    if (escaping && map.shutAfter(since).length != _shutCount) {
      _shutCount = map.shutAfter(since).length;
      HapticFeedback.heavyImpact();
    }

    // اكتُشف العميل → العودة إلى نقطة الحفظ (أثناء الهروب: لا عودة، فقط العقوبة)
    if (s.spots != _spots) {
      _spots = s.spots;
      if (!escaping) _pos = map.checkpoint(solved);
      _invulnUntil = nowMs + 2500;
      _seenFor = 0;
      _pick = 0;
      if (_hacking) setState(() => _hacking = false);
    }
    // فُتح القفل → العودة إلى الخريطة والباب التالي مفتوح
    if (s.room != _room || (escaping && _hacking)) {
      _room = s.room;
      if (_hacking) setState(() => _hacking = false);
    }

    if (s.paused) {
      _frame.value++;
      return;
    }

    if (!_hacking) {
      var v = _stick.distance > .1 ? _stick : _keys();
      if (v.distance > 1) v = v / v.distance;
      if (v.distance > .05) {
        _facing = atan2(v.dy, v.dx);
        _pos = map.move(_pos, v * kAgentSpeed * dt, solved, shut: shut);
        if (_help) setState(() => _help = false);
      }
    }

    // الكشف: نصف ثانية تحت الرؤية، والليزر فوراً. من المرحلة 6 يستمرّ حتى أثناء الاختراق.
    final watch = !_hacking || footstepsStage(s.stage);
    if (watch && nowMs > _invulnUntil) {
      if (map.laserHit(_pos, t)) {
        _spot();
      } else if (map.seen(_pos, t, solved, s.camOff, power: power, alarm: escaping, shut: shut)) {
        _seenFor += dt;
        if (_seenFor >= .5) _spot();
      } else {
        _seenFor = max(0, _seenFor - dt * 2);
      }
    }
    _nearGuard = map.guards.isEmpty ? double.infinity : map.nearestGuard(_pos, t);

    // سرقة البطاقة: البقاء خلف الحارس kPickSeconds
    if (cardStage(s.stage) && !_hacking && !escaping) {
      int? target;
      for (final g in map.cardGuards) {
        final r = map.guards[g].room;
        if (s.cards.contains(r) || _picked.contains(r)) continue;
        if (map.behind(g, _pos, t)) target = r;
      }
      if (target != null) {
        _pick += dt;
        if (_pick >= kPickSeconds) {
          _pick = 0;
          _picked.add(target);
          HapticFeedback.mediumImpact();
          c.dispatch({'type': 'card', 'room': target});
        }
      } else {
        _pick = max(0, _pick - dt * 1.5);
      }
    }

    // الهروب: المخرج، أو انتهاء الوقت، أو الحبس خلف باب مغلق
    if (escaping && !_endSent) {
      final r = map.roomOf(_pos);
      if ((_pos - map.spawn).distance < 1.1) {
        _endSent = true;
        c.dispatch({'type': 'escaped'});
      } else if (since > map.escape.seconds || (r >= 0 && shut.any((k) => k < r))) {
        _endSent = true;
        c.dispatch({'type': 'caught'});
      }
    }

    c.sendPos(_pos.dx, _pos.dy);
    _frame.value++;
  }

  void _spot() {
    _seenFor = 0;
    _invulnUntil = DateTime.now().millisecondsSinceEpoch + 2500;
    c.dispatch({'type': 'spotted'});
  }

  /// الجهاز يحتاج بطاقة لم تُسرق بعد.
  bool get _needsCard {
    final s = c.state!;
    return cardStage(s.stage) && widget.map.cardRooms.contains(s.room) && !s.cards.contains(s.room);
  }

  bool get _atTerminal {
    final s = c.state!;
    if (s.escape > 0 || s.room >= widget.map.rooms.length) return false;
    return (_pos - widget.map.rooms[s.room].terminal).distance < 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final p = widget.map.params;
    final blackout = stageMods(s.stage).contains('blackout') && !s.lit;
    final vision = blackout ? 2.2 : p.vision;
    final footsteps = footstepsStage(s.stage) && widget.map.guards.isNotEmpty;
    return Stack(children: [
      Positioned.fill(
        child: ClipRect(
          child: CustomPaint(
            painter: HeistPainter(
              map: widget.map,
              repaint: _frame,
              state: () => c.state!,
              time: () => c.heistTime,
              agent: () => _pos,
              facing: () => _facing,
              mark: () => c.markX == null || DateTime.now().millisecondsSinceEpoch - c.markAt > 5000 ? null : Offset(c.markX!, c.markY!),
              alert: () => _seenFor,
              agentMode: true,
              vision: vision,
              showGuards: true,
              pick: () => _pick,
            ),
          ),
        ),
      ),
      // الشريط العلوي
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: _Hud(c: c, onExit: widget.onExit, frame: _frame),
      ),
      if (_intro != null && !_help)
        Positioned(
          top: 64,
          left: 16,
          right: 16,
          child: GestureDetector(onTap: () => setState(() => _intro = null), child: _Banner(text: _intro!, color: K.amber)),
        ),
      if (_help)
        Positioned(
          top: 64,
          left: 16,
          right: 16,
          child: _Banner(
            text: 'تحرّك بالعصا (أو الأسهم). رؤيتك محدودة: شريكك يرى المخطّط والحرّاس. '
                'اذهب إلى الجهاز المضيء واخترقه. إن رآك حارس أو كاميرا تعود إلى نقطة الحفظ.',
          ),
        ),
      // زرّ الاختراق عند الجهاز
      Positioned(
        bottom: 36,
        right: 20,
        child: ValueListenableBuilder<int>(
          valueListenable: _frame,
          builder: (context, _, __) => !_hacking && _atTerminal && _needsCard
              ? FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.badge_outlined, size: 20),
                  label: const Text('🔒 يحتاج بطاقة الحارس الذهبي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: const Color(0xE6121518),
                    disabledForegroundColor: K.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    side: const BorderSide(color: K.amber),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                  ),
                )
              : !_hacking && _atTerminal
              ? FilledButton.icon(
                  onPressed: () => setState(() => _hacking = true),
                  icon: Icon(_isVault(s) ? Icons.lock_open : Icons.terminal, size: 20),
                  label: Text(_isVault(s) ? 'افتح الخزنة' : 'اخترق الجهاز', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: K.neon,
                    foregroundColor: K.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
      // عصا التحكّم
      if (!_hacking)
        Positioned(
          left: 22,
          bottom: 26,
          child: _Joystick(onChanged: (v) => _stick = v),
        ),
      // شاشة القفل فوق الخريطة
      if (_hacking)
        Positioned.fill(
          child: Stack(children: [
            // أرضية الغرفة خلف الجهاز + اقتراب الكاميرا (زووم) عند بدء الاختراق
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: K.bg,
                  image: DecorationImage(
                    image: AssetImage(s.stage <= 20
                        ? 'assets/images/h_floor_port.jpg'
                        : (s.stage <= 40 ? 'assets/images/h_floor_river.jpg' : 'assets/images/h_floor_mountain.jpg')),
                    repeat: ImageRepeat.repeat,
                    scale: 2,
                    colorFilter: const ColorFilter.mode(Color(0xB30A0C0E), BlendMode.darken),
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(radius: .95, colors: [Color(0x000A0C0E), Color(0xE60A0C0E)]),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                key: ValueKey('hack-${s.room}'),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) => Opacity(
                  opacity: v,
                  child: Transform.scale(scale: .78 + .22 * v, child: child),
                ),
                child: widget.lockView,
              ),
            ),
            if (footsteps)
              Positioned(
                top: 8,
                left: 60,
                right: 60,
                child: IgnorePointer(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (context, _, __) => _Footsteps(distance: _nearGuard, seenFor: _seenFor),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: ValueListenableBuilder<int>(
                valueListenable: _frame,
                builder: (context, _, __) {
                  final danger = footsteps && _nearGuard < 3.2;
                  return FloatingActionButton.extended(
                    heroTag: 'heist-map',
                    backgroundColor: danger ? K.danger : K.surface2,
                    foregroundColor: danger ? Colors.white : K.text,
                    onPressed: () => setState(() => _hacking = false),
                    icon: Icon(danger ? Icons.directions_run : Icons.map_outlined),
                    label: Text(danger ? 'اختبئ!' : 'الخريطة', style: const TextStyle(fontWeight: FontWeight.w800)),
                  );
                },
              ),
            ),
          ]),
        ),
    ]);
  }

  bool _isVault(GameState s) => s.room == s.rooms.length - 1;
}

class _Hud extends StatelessWidget {
  final GameController c;
  final VoidCallback onExit;
  final ValueNotifier<int> frame;
  const _Hud({required this.c, required this.onExit, required this.frame});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xEE0A0C0E), Color(0x000A0C0E)]),
      ),
      child: Row(children: [
        IconButton(onPressed: onExit, icon: const Icon(Icons.close, color: K.text2), tooltip: 'انسحاب'),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            MonoLabel('FIELD AGENT · ROOM ${min(s.room + 1, s.rooms.length)}/${s.rooms.length} · ERR ${s.errors}', size: 10.5),
            Text(s.stage > 0 ? stageDef(s.stage).name : 'المهمّة', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ValueListenableBuilder<int>(valueListenable: frame, builder: (context, _, __) => _StatusChips(c: c)),
          ]),
        ),
        ValueListenableBuilder<int>(
          valueListenable: frame,
          builder: (context, _, __) {
            final r = c.remaining;
            return Text(_clock(r),
                style: TextStyle(fontFamily: K.mono, fontSize: 24, color: r < 30 ? K.danger : K.neon, fontWeight: FontWeight.w700));
          },
        ),
      ]),
    );
  }
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, this.color = K.neon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6121518),
          borderRadius: BorderRadius.circular(K.radius),
          border: Border.all(color: color.withAlpha(140)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.55)),
      );
}

/// شارات الحالة: الإنذار والتيار والبطاقات (تتحدّث كل إطار).
class _StatusChips extends StatelessWidget {
  final GameController c;
  const _StatusChips({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state;
    if (s == null) return const SizedBox.shrink();
    final map = heistMap(s.seed, s.stage, s.rooms.length);
    final t = c.heistTime;
    final chips = <Widget>[];
    if (s.escape > 0) {
      final left = map.escape.seconds - (t - s.escape);
      chips.add(_chip('🚨 المخرج ${_clock(left)}', K.danger, blink: true));
    }
    if (s.power > t) chips.add(_chip('⚡ ظلام ${(s.power - t).ceil()} ث', const Color(0xFF7FA7FF)));
    final cards = map.cardRooms;
    if (cardStage(s.stage) && cards.isNotEmpty && s.escape <= 0) {
      final got = cards.where(s.cards.contains).length;
      chips.add(_chip('🪪 $got/${cards.length}', got == cards.length ? K.ok : K.amber));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 3), child: Wrap(spacing: 6, children: chips));
  }

  static Widget _chip(String text, Color color, {bool blink = false}) {
    final on = !blink || (DateTime.now().millisecondsSinceEpoch ~/ 400).isEven;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(on ? 60 : 25),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(on ? 220 : 90)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800, fontFamily: K.mono)),
    );
  }
}

/// تحذير وقع الخطى أثناء الاختراق: يشتدّ كلّما اقترب أقرب حارس.
class _Footsteps extends StatelessWidget {
  final double distance;
  final double seenFor;
  const _Footsteps({required this.distance, required this.seenFor});

  @override
  Widget build(BuildContext context) {
    if (distance > 6.5 && seenFor <= 0) return const SizedBox.shrink();
    final k = (1 - (distance - 1) / 5.5).clamp(0.0, 1.0);
    final seen = seenFor > 0;
    final color = seen ? K.danger : Color.lerp(K.amber, K.danger, k)!;
    final text = seen ? '👁 يراك الآن!' : (distance < 3.2 ? '🔊 حارس خلفك تماماً!' : '🔊 خطى تقترب…');
    final bars = (1 + k * 4).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xE6121518),
        borderRadius: BorderRadius.circular(K.radius),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: color.withAlpha((60 + 120 * k).round()), blurRadius: 14)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(width: 10),
        for (int i = 0; i < 5; i++)
          Container(
            width: 5,
            height: 6.0 + i * 3,
            margin: const EdgeInsets.only(left: 2),
            color: i < bars ? color : const Color(0xFF2A2F35),
          ),
      ]),
    );
  }
}

/// لوحة المحلّل أثناء الهروب: العدّ التنازلي ومتى يُغلق كل باب.
class _EscapePanel extends StatefulWidget {
  final GameController c;
  final HeistMap map;
  const _EscapePanel({required this.c, required this.map});

  @override
  State<_EscapePanel> createState() => _EscapePanelState();
}

class _EscapePanelState extends State<_EscapePanel> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.c.state!;
    final plan = widget.map.escape;
    final since = widget.c.heistTime - s.escape;
    final left = plan.seconds - since;
    final blink = (DateTime.now().millisecondsSinceEpoch ~/ 350).isEven;
    // الأبواب بترتيب الإغلاق (من الخزنة نحو المخرج)
    final order = [for (int i = 0; i < plan.doorClose.length; i++) i]..sort((a, b) => plan.doorClose[a].compareTo(plan.doorClose[b]));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: [K.danger.withAlpha(blink ? 70 : 40), const Color(0xFF0A0C0E)], radius: 1.1),
      ),
      child: Column(children: [
        Text('🚨 الإنذار يعمل', style: TextStyle(color: K.danger, fontSize: 22, fontWeight: FontWeight.w900, shadows: [Shadow(color: K.danger.withAlpha(blink ? 200 : 60), blurRadius: 18)])),
        const SizedBox(height: 4),
        const Text('وجّه شريكك إلى نقطة البداية (EXIT) قبل أن تُغلق الأبواب', textAlign: TextAlign.center, style: TextStyle(color: K.text2, fontSize: 13)),
        const SizedBox(height: 10),
        Text(_clock(left), style: TextStyle(fontFamily: K.mono, fontSize: 54, fontWeight: FontWeight.w800, color: left < 10 ? K.danger : K.text)),
        const SizedBox(height: 8),
        Expanded(
          child: ListView(children: [
            for (final i in order)
              () {
                final rem = plan.doorClose[i] - since;
                final closed = rem <= 0;
                final soon = !closed && rem < 4;
                final col = closed ? K.danger : (soon ? K.amber : K.ok);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Icon(closed ? Icons.lock : Icons.sensor_door_outlined, color: col, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('باب الغرفة ${i + 1} ↔ ${i + 2}', style: TextStyle(color: col, fontWeight: FontWeight.w700))),
                    Text(closed ? 'مغلق' : '${rem.ceil()} ث', style: TextStyle(color: col, fontFamily: K.mono, fontWeight: FontWeight.w800)),
                  ]),
                );
              }(),
          ]),
        ),
      ]),
    );
  }
}

/// عصا تحكّم بسيطة: تُرجع متّجهاً طوله ≤ 1.
class _Joystick extends StatefulWidget {
  final ValueChanged<Offset> onChanged;
  const _Joystick({required this.onChanged});

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  static const double r = 58;
  Offset _knob = Offset.zero;

  void _set(Offset local) {
    var v = local - const Offset(r, r);
    if (v.distance > r) v = v / v.distance * r;
    setState(() => _knob = v);
    widget.onChanged(v / r);
  }

  void _end() {
    setState(() => _knob = Offset.zero);
    widget.onChanged(Offset.zero);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onPanStart: (d) => _set(d.localPosition),
        onPanUpdate: (d) => _set(d.localPosition),
        onPanEnd: (_) => _end(),
        onPanCancel: _end,
        child: Container(
          width: r * 2,
          height: r * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0x66121518),
            border: Border.all(color: K.borderStrong, width: 1.5),
          ),
          child: Center(
            child: Transform.translate(
              offset: _knob,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.surface2,
                  border: Border.all(color: K.neon.withAlpha(160), width: 2),
                ),
              ),
            ),
          ),
        ),
      );
}

// ───────── المحلّل ─────────
class _AnalystMap extends StatefulWidget {
  final GameController c;
  final HeistMap map;
  const _AnalystMap({required this.c, required this.map});

  @override
  State<_AnalystMap> createState() => _AnalystMapState();
}

class _AnalystMapState extends State<_AnalystMap> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) => _frame.value++)..start();
  }
  final _frame = ValueNotifier<int>(0);
  Offset _ax = Offset.zero, _target = Offset.zero;
  bool _hasAgent = false;

  GameController get c => widget.c;

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// موقع العميل منعّماً بين التحديثات.
  Offset? _agent() {
    if (c.partnerX == null) return null;
    _target = Offset(c.partnerX!, c.partnerY!);
    if (!_hasAgent) {
      _ax = _target;
      _hasAgent = true;
    }
    _ax = Offset.lerp(_ax, _target, .25)!;
    return _ax;
  }

  void _tap(Offset local, Size size) {
    final m = widget.map;
    final scale = min(size.width / m.w, size.height / m.h);
    final ox = (size.width - m.w * scale) / 2, oy = (size.height - m.h * scale) / 2;
    final p = Offset((local.dx - ox) / scale, (local.dy - oy) / scale);
    final s = c.state!;
    for (int i = 0; i < m.cams.length; i++) {
      if ((m.cams[i].pos - p).distance < 1.1) {
        if (s.camOff.containsKey('$i')) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عُطّلت هذه الكاميرا من قبل')));
        } else {
          c.dispatch({'type': 'hackcam', 'cam': i});
        }
        return;
      }
    }
    c.sendMark(p.dx, p.dy);
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: K.border))),
      child: Stack(children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              onTapUp: (d) => _tap(d.localPosition, box.biggest),
              child: CustomPaint(
                painter: HeistPainter(
                  map: widget.map,
                  repaint: _frame,
                  state: () => c.state!,
                  time: () => c.heistTime,
                  agent: _agent,
                  facing: () => 0,
                  mark: () => c.markX == null || DateTime.now().millisecondsSinceEpoch - c.markAt > 5000 ? null : Offset(c.markX!, c.markY!),
                  alert: () => 0,
                  agentMode: false,
                  vision: 0,
                  showGuards: analystSeesGuards(s.stage),
                  pick: () => 0,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 10,
          child: MonoLabel(analystSeesGuards(s.stage) ? 'BLUEPRINT · LIVE' : 'BLUEPRINT · ROUTES ONLY', color: K.neon, size: 10),
        ),
        const Positioned(
          bottom: 6,
          left: 10,
          right: 10,
          child: Text('المس الخريطة لتضع إشارة لشريكك · المس كاميرا لتعطيلها 10 ث',
              textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11)),
        ),
        Positioned(
          top: 4,
          left: 8,
          child: ValueListenableBuilder<int>(valueListenable: _frame, builder: (context, _, __) => _StatusChips(c: c)),
        ),
        if (powerStage(s.stage) && s.escape <= 0)
          Positioned(
            right: 8,
            bottom: 24,
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, _, __) {
                final s = c.state!;
                final t = c.heistTime;
                final on = s.power > t;
                final wait = s.power > 0 ? (s.power + kPowerCooldown - t) : 0.0;
                final ready = wait <= 0;
                return FilledButton.icon(
                  onPressed: ready ? () => c.dispatch({'type': 'power'}) : null,
                  icon: const Icon(Icons.power_off, size: 18),
                  label: Text(on ? 'ظلام ${(s.power - t).ceil()}' : (ready ? 'اقطع التيار' : '${wait.ceil()} ث'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontFamily: K.mono)),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2B4A8F),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF1C222A),
                    disabledForegroundColor: on ? const Color(0xFF7FA7FF) : K.muted,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ───────── الرسم ─────────
class HeistPainter extends CustomPainter {
  final HeistMap map;
  final GameState Function() state;
  final double Function() time;
  final Offset? Function() agent;
  final double Function() facing;
  final Offset? Function() mark;
  final double Function() alert;
  final bool agentMode;
  final double vision;
  final bool showGuards;
  final double Function() pick;

  HeistPainter({
    required this.map,
    required Listenable repaint,
    required this.state,
    required this.time,
    required this.agent,
    required this.facing,
    required this.mark,
    required this.alert,
    required this.agentMode,
    required this.vision,
    required this.showGuards,
    required this.pick,
  }) : super(repaint: repaint);

  static const _floor = Color(0xFF16191C), _floor2 = Color(0xFF1A1D21), _wall = Color(0xFF353A40), _wallTop = Color(0xFF4A5057);
  static const _crate = Color(0xFF4B3D2A), _guard = Color(0xFFC9CED3), _coneRed = Color(0xFFE5484D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = state();
    final t = time();
    final escaping = s.escape > 0;
    final since = escaping ? t - s.escape : 0.0;
    final shut = escaping ? map.shutAfter(since) : const <int>{};
    final power = s.power > t;
    // أثناء الهروب تُعدّ الخزنة محلولة
    final solved = escaping ? map.rooms.length : s.room;
    final a = agent();
    final pulse = .5 + .5 * sin(DateTime.now().millisecondsSinceEpoch / 260);

    // التحويل: العميل = كاميرا تتبعه؛ المحلّل = الخريطة كلها
    late double scale;
    late Offset origin;
    if (agentMode) {
      scale = 42;
      final c = a ?? map.spawn;
      origin = Offset(size.width / 2 - c.dx * scale, size.height / 2 - c.dy * scale);
    } else {
      scale = min(size.width / map.w, size.height / map.h);
      origin = Offset((size.width - map.w * scale) / 2, (size.height - map.h * scale) / 2);
    }
    Offset sc(Offset p) => origin + p * scale;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0C0E));

    // البلاطات المرئية فقط
    final x0 = max(0, (-origin.dx / scale).floor() - 1), y0 = max(0, (-origin.dy / scale).floor() - 1);
    final x1 = min(map.w - 1, ((size.width - origin.dx) / scale).ceil() + 1);
    final y1 = min(map.h - 1, ((size.height - origin.dy) / scale).ceil() + 1);
    final pFloor = Paint()..color = _floor, pFloor2 = Paint()..color = _floor2;
    final floorImg = HeistSprites.floorFor(s.stage);
    Paint? pTex;
    if (floorImg != null) {
      // كل صورة أرضية تغطّي 3×3 خلايا وتتكرّر
      final k = 3 * scale / floorImg.width;
      final m = Matrix4.identity()
        ..translate(origin.dx, origin.dy)
        ..scale(k, k);
      pTex = Paint()
        ..filterQuality = FilterQuality.low
        ..shader = ImageShader(floorImg, TileMode.repeated, TileMode.repeated, m.storage);
    }
    final crateImg = HeistSprites.get('h_crate');
    final pWall = Paint()..color = _wall, pWallTop = Paint()..color = _wallTop;
    final pCrate = Paint()..color = _crate;
    final pCrateLine = Paint()
      ..color = const Color(0xFF6B5638)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1, scale * .06);
    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final r = Rect.fromLTWH(origin.dx + x * scale, origin.dy + y * scale, scale + .5, scale + .5);
        final v = map.at(x, y);
        if (v == kWall) {
          // جدار خارج المبنى بالكامل: لا نرسمه
          final inner = [map.at(x + 1, y), map.at(x - 1, y), map.at(x, y + 1), map.at(x, y - 1)].any((n) => n != kWall);
          if (!inner) continue;
          canvas.drawRect(r, pWall);
          canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * .22), pWallTop);
        } else {
          canvas.drawRect(r, pTex ?? ((x + y).isEven ? pFloor : pFloor2));
          if (v == kCrate && crateImg != null) {
            _sprite(canvas, crateImg, r.center, scale * .96, 0);
          } else if (v == kCrate) {
            final cr = r.deflate(scale * .08);
            canvas.drawRect(cr, pCrate);
            canvas.drawRect(cr, pCrateLine);
            canvas.drawLine(cr.topLeft, cr.bottomRight, pCrateLine);
            canvas.drawLine(cr.topRight, cr.bottomLeft, pCrateLine);
          }
        }
      }
    }

    // الأبواب
    final doorImg = HeistSprites.get('h_door');
    for (int di = 0; di < map.doors.length; di++) {
      final d = map.doors[di];
      if (escaping) {
        _escapeDoor(canvas, d, origin, scale, shut.contains(di), map.escape.doorClose[di] - since, pulse);
        continue;
      }
      final open = d.after < solved;
      for (final c in d.cells) {
        final r = Rect.fromLTWH(origin.dx + c.x * scale, origin.dy + c.y * scale, scale, scale);
        if (open) {
          canvas.drawRect(r, Paint()..color = K.ok.withAlpha(40));
        } else if (doorImg == null) {
          canvas.drawRect(r.deflate(scale * .15), Paint()..color = (d.after == solved ? K.neon : K.danger).withAlpha(200));
        }
      }
      // باب فولاذي يغطّي الخليّتين
      if (!open && doorImg != null && d.cells.length == 2) {
        final a0 = d.cells.first, a1 = d.cells.last;
        final c = Offset((a0.x + a1.x) / 2 + .5, (a0.y + a1.y) / 2 + .5);
        final vertical = a0.x == a1.x;
        _sprite(canvas, doorImg, sc(c), scale * 2, vertical ? pi / 2 : 0);
        final edge = Rect.fromCenter(center: sc(c), width: scale * (vertical ? 1 : 2), height: scale * (vertical ? 2 : 1));
        canvas.drawRect(edge.deflate(scale * .04), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, scale * .06)
          ..color = (d.after == solved ? K.neon : K.danger).withAlpha(200));
      }
    }

    // الأجهزة
    for (int i = 0; i < map.rooms.length; i++) {
      final c = sc(map.rooms[i].terminal);
      final vault = i == map.rooms.length - 1;
      final col = i < solved ? K.ok : (i == solved ? K.neon : const Color(0xFF5B6168));
      if (i == solved) canvas.drawCircle(c, scale * (.6 + .25 * pulse), Paint()..color = K.neon.withAlpha(40));
      final cardLocked = i >= solved && map.cardRooms.contains(i) && !s.cards.contains(i);
      if (vault) {
        canvas.drawCircle(c, scale * .38, Paint()..color = const Color(0xFF2E3237));
        canvas.drawCircle(c, scale * .38, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * .08
          ..color = col);
        canvas.drawCircle(c, scale * .1, Paint()..color = col);
      } else if (HeistSprites.get('h_terminal') != null) {
        canvas.drawCircle(c, scale * .5, Paint()..color = col.withAlpha(i == solved ? 70 : 35));
        _sprite(canvas, HeistSprites.get('h_terminal')!, c, scale * .85, 0, i > solved ? .55 : 1);
        if (i < solved) canvas.drawCircle(c + Offset(scale * .3, -scale * .3), scale * .12, Paint()..color = K.ok);
        if (cardLocked) _card(canvas, c + Offset(scale * .32, -scale * .34), scale * .5, false);
      } else {
        final r = Rect.fromCenter(center: c, width: scale * .62, height: scale * .5);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(scale * .06)), Paint()..color = const Color(0xFF22262B));
        canvas.drawRect(r.deflate(scale * .09), Paint()..color = col.withAlpha(i == solved ? 230 : 140));
      }
    }

    // الكاميرات
    for (int i = 0; i < map.cams.length; i++) {
      final cam = map.cams[i];
      final off = power || (s.camOff['$i'] ?? -1) > t;
      final p = sc(cam.pos);
      final ang = camAngle(cam, t);
      if (!off) _cone(canvas, p, ang, kCamHalf, map.params.camRange * scale, const Color(0xFFFFC94D));
      final camImg = HeistSprites.get('h_camera');
      if (camImg != null) {
        // صورة الكاميرا تنظر إلى الأسفل أصلاً
        _sprite(canvas, camImg, p, scale * .55, ang - pi / 2, off ? .45 : 1);
      } else {
        canvas.drawRect(Rect.fromCenter(center: p, width: scale * .34, height: scale * .34), Paint()..color = off ? const Color(0xFF3A3F45) : const Color(0xFFB9BEC4));
        canvas.drawCircle(p, scale * .08, Paint()..color = off ? K.muted : K.danger);
      }
      if (off && !power) {
        final sec = ((s.camOff['$i'] ?? 0) - t).ceil();
        _label(canvas, p + Offset(0, -scale * .55), '$sec', K.ok, scale * .32);
      }
    }

    // الحرّاس (أو مساراتهم فقط عند المحلّل في المراحل المتقدّمة)
    final gRange = map.guardRange(power: power, alarm: escaping);
    for (int gi = 0; gi < map.guards.length; gi++) {
      final g = map.guards[gi];
      final carries = map.cardGuards.contains(gi) && !s.cards.contains(g.room);
      if (!showGuards) {
        final path = Path()..moveTo(sc(g.path.first).dx, sc(g.path.first).dy);
        for (final q in g.path.skip(1)) {
          path.lineTo(sc(q).dx, sc(q).dy);
        }
        path.close();
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, scale * .07)
          ..color = _coneRed.withAlpha(120));
        continue;
      }
      final (gp, ga) = guardAt(g, t);
      final p = sc(gp);
      _cone(canvas, p, ga, kGuardHalf, gRange * scale, power ? const Color(0xFFFFF1B8) : _coneRed);
      if (carries) {
        // هالة ذهبية خلف الحارس: منطقة السرقة
        final back = ga + pi;
        canvas.drawPath(
          Path()
            ..moveTo(p.dx, p.dy)
            ..arcTo(Rect.fromCircle(center: p, radius: kPickRange * scale), back - pi / 2, pi, false)
            ..close(),
          Paint()..color = K.amber.withAlpha((25 + 35 * pulse).round()),
        );
      }
      final gImg = HeistSprites.get('h_guard');
      if (gImg != null) {
        canvas.drawCircle(p + Offset(scale * .05, scale * .08), scale * .36, Paint()..color = Colors.black.withAlpha(90));
        _sprite(canvas, gImg, p, scale * .95, ga + pi / 2);
        if (carries) _card(canvas, p + Offset(0, -scale * .62), scale * .5, true);
        continue;
      }
      if (carries) _card(canvas, p + Offset(0, -scale * .62), scale * .5, true);
      canvas.drawCircle(p, scale * .32, Paint()..color = const Color(0xFF2B3A55));
      canvas.drawCircle(p, scale * .32, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .06
        ..color = _guard);
      canvas.drawCircle(p + Offset(cos(ga), sin(ga)) * scale * .2, scale * .08, Paint()..color = _guard);
    }

    // الليزر
    for (final l in map.lasers) {
      _laser(canvas, l, t, sc, scale);
    }

    // المخرج أثناء الهروب
    if (escaping) {
      final p = sc(map.spawn);
      for (final k in [0.0, .33, .66]) {
        final ph = ((DateTime.now().millisecondsSinceEpoch / 1100) + k) % 1;
        canvas.drawCircle(p, scale * (.4 + ph * 1.4), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * .08
          ..color = K.ok.withAlpha(((1 - ph) * 220).round()));
      }
      canvas.drawCircle(p, scale * .42, Paint()..color = K.ok.withAlpha(200));
      _label(canvas, p, 'EXIT', const Color(0xFF07130C), scale * .26);
    }

    // إشارة المحلّل
    final mk = mark();
    if (mk != null) {
      final p = sc(mk);
      for (final k in [0.0, .5]) {
        final ph = ((DateTime.now().millisecondsSinceEpoch / 900) + k) % 1;
        canvas.drawCircle(p, scale * (.3 + ph * .9), Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * .07
          ..color = K.neon.withAlpha(((1 - ph) * 230).round()));
      }
      canvas.drawCircle(p, scale * .14, Paint()..color = K.neon);
    }

    // العميل
    if (a != null) {
      final p = sc(a);
      final f = facing();
      canvas.drawCircle(p + Offset(scale * .05, scale * .08), scale * .3, Paint()..color = Colors.black.withAlpha(110));
      final aImg = HeistSprites.get('h_agent');
      if (aImg != null) {
        // حلقة زرقاء خفيفة تميّز العميل، ثم الصورة باتجاه الحركة
        canvas.drawCircle(p, scale * .44, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, scale * .05)
          ..color = K.agent.withAlpha(160));
        _sprite(canvas, aImg, p, scale * .95, f + pi / 2);
      } else {
      canvas.drawCircle(p, scale * .3, Paint()..color = K.agent);
      canvas.drawCircle(p, scale * .3, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .06
        ..color = const Color(0xFFE6E8EA));
      if (agentMode) canvas.drawCircle(p + Offset(cos(f), sin(f)) * scale * .18, scale * .08, Paint()..color = const Color(0xFF0A0C0E));
      }
      // تقدّم سرقة البطاقة
      final pk = pick();
      if (pk > 0) {
        canvas.drawArc(Rect.fromCircle(center: p, radius: scale * .58), -pi / 2, 2 * pi * (pk / kPickSeconds).clamp(0.0, 1.0), false, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * .1
          ..strokeCap = StrokeCap.round
          ..color = K.amber);
      }
      // تحذير «!» عندما يراه أحد
      final al = alert();
      if (al > 0) _label(canvas, p + Offset(0, -scale * .75), '!', K.danger, scale * (.45 + al));
    }

    // الظلام حول العميل (أضيق حين يُقطع التيار)
    if (agentMode && a != null) {
      final p = sc(a);
      final vr = power ? min(vision, 1.9) : vision;
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xF2050607));
      canvas.drawCircle(
        p,
        vr * scale,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = RadialGradient(colors: const [Colors.black, Colors.black, Color(0x00000000)], stops: const [0, .7, 1])
              .createShader(Rect.fromCircle(center: p, radius: vr * scale)),
      );
      canvas.restore();
      // الهدف يبقى ظاهراً كمنارة خافتة حتى خارج الرؤية
      if (escaping) {
        canvas.drawCircle(sc(map.spawn), scale * (.22 + .1 * pulse), Paint()..color = K.ok.withAlpha(190));
      } else if (solved < map.rooms.length) {
        final tp = sc(map.rooms[solved].terminal);
        canvas.drawCircle(tp, scale * (.18 + .08 * pulse), Paint()..color = K.neon.withAlpha(150));
      }
      // الليزر يُرى عبر الظلام (وهجه أحمر)
      for (final l in map.lasers) {
        final seg = l.at(t);
        if (seg != null) {
          canvas.drawLine(sc(seg.$1), sc(seg.$2), Paint()
            ..strokeWidth = scale * .05
            ..color = const Color(0xFFFF3B3B).withAlpha(140));
        }
      }
    }

    // انقطاع التيار: زرقة باهتة على خريطة المحلّل
    if (power && !agentMode) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x66060A1A));
    }
    // الإنذار: نبض أحمر على الحوافّ
    if (escaping) {
      final k = (.5 + .5 * sin(DateTime.now().millisecondsSinceEpoch / 180));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: .85,
            colors: [const Color(0x00000000), K.danger.withAlpha((40 + 80 * k).round())],
            stops: const [.55, 1],
          ).createShader(Offset.zero & size),
      );
    }
  }

  /// باب أثناء الهروب: مفتوح (أخضر)، يوشك أن يُغلق (يومض)، مغلق (مصراع أحمر مخطّط).
  void _escapeDoor(Canvas canvas, HDoor d, Offset origin, double scale, bool closed, double left, double pulse) {
    final rects = [for (final c in d.cells) Rect.fromLTWH(origin.dx + c.x * scale, origin.dy + c.y * scale, scale, scale)];
    final all = rects.reduce((a, b) => a.expandToInclude(b));
    if (closed) {
      canvas.drawRect(all, Paint()..color = const Color(0xFF3A1416));
      final stripe = Paint()
        ..color = K.danger
        ..strokeWidth = max(1, scale * .1);
      canvas.save();
      canvas.clipRect(all);
      for (double x = all.left - all.height; x < all.right; x += scale * .45) {
        canvas.drawLine(Offset(x, all.bottom), Offset(x + all.height, all.top), stripe);
      }
      canvas.restore();
      canvas.drawRect(all, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1, scale * .08)
        ..color = K.danger);
      return;
    }
    final soon = left < 4;
    canvas.drawRect(all, Paint()..color = (soon ? K.amber : K.ok).withAlpha(soon ? (60 + 120 * pulse).round() : 45));
    if (left < 9) _label(canvas, all.center, '${left.ceil()}', soon ? K.amber : K.ok, scale * .5);
  }

  void _laser(Canvas canvas, HLaser l, double t, Offset Function(Offset) sc, double scale) {
    final seg = l.at(t);
    // الباعثان على الجدارين
    final ends = seg ?? (l.a, l.b);
    for (final e in [ends.$1, ends.$2]) {
      canvas.drawCircle(sc(e), scale * .12, Paint()..color = const Color(0xFF55595E));
      canvas.drawCircle(sc(e), scale * .06, Paint()..color = seg != null ? const Color(0xFFFF3B3B) : const Color(0xFF6B2224));
    }
    if (seg == null) {
      // تحذير قبل الاشتعال: خطّ متقطّع خافت
      final w = l.warmup(t);
      if (w != null && w < .9) {
        final a = sc(l.a), b = sc(l.b);
        final n = max(2, ((b - a).distance / (scale * .35)).floor());
        final paint = Paint()
          ..strokeWidth = scale * .04
          ..color = const Color(0xFFFF3B3B).withAlpha((80 + 120 * (1 - w / .9)).round());
        for (int i = 0; i < n; i += 2) {
          canvas.drawLine(Offset.lerp(a, b, i / n)!, Offset.lerp(a, b, (i + 1) / n)!, paint);
        }
      }
      return;
    }
    final a = sc(seg.$1), b = sc(seg.$2);
    canvas.drawLine(a, b, Paint()
      ..strokeWidth = scale * .32
      ..color = const Color(0x55FF2020)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, scale * .18));
    canvas.drawLine(a, b, Paint()
      ..strokeWidth = scale * .08
      ..color = const Color(0xFFFF4545));
    canvas.drawLine(a, b, Paint()
      ..strokeWidth = scale * .025
      ..color = const Color(0xFFFFD6D6));
  }

  /// بطاقة دخول ذهبية صغيرة (فوق الحارس، أو قفل على الجهاز).
  void _card(Canvas canvas, Offset c, double w, bool glow) {
    final r = RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: w, height: w * .66), Radius.circular(w * .1));
    if (glow) canvas.drawRRect(r.inflate(w * .12), Paint()..color = K.amber.withAlpha(70));
    canvas.drawRRect(r, Paint()..color = const Color(0xFFE9B949));
    canvas.drawRect(Rect.fromLTWH(r.left + w * .12, r.top + w * .16, w * .22, w * .18), Paint()..color = const Color(0xFF8A6A1E));
    canvas.drawLine(Offset(r.left + w * .45, r.top + w * .22), Offset(r.right - w * .1, r.top + w * .22), Paint()
      ..strokeWidth = w * .06
      ..color = const Color(0xFF8A6A1E));
  }

  /// يرسم صورة مدوّرة حول [center] بعرض [size] (الصورة تنظر إلى الأعلى أصلاً).
  void _sprite(Canvas canvas, ui.Image img, Offset center, double size, double rotation, [double opacity = 1]) {
    final ratio = img.height / img.width;
    final w = size, h = size * ratio;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset.zero, width: w, height: h),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.restore();
  }

  void _cone(Canvas canvas, Offset p, double angle, double half, double range, Color c) {
    final rect = Rect.fromCircle(center: p, radius: range);
    final path = Path()
      ..moveTo(p.dx, p.dy)
      ..arcTo(rect, angle - half, half * 2, false)
      ..close();
    canvas.drawPath(path, Paint()
      ..shader = RadialGradient(colors: [c.withAlpha(90), c.withAlpha(20)]).createShader(rect));
  }

  void _label(Canvas canvas, Offset at, String text, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900, fontFamily: K.mono)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant HeistPainter old) => old.map != map || old.vision != vision || old.showGuards != showGuards;
}
