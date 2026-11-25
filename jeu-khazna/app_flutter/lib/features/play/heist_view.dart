// وضع الخريطة 2D: العميل يتحرّك داخل المبنى برؤية محدودة، والمحلّل يرى المخطّط كاملاً.
// الوصول إلى جهاز الغرفة يفتح القفل نفسه (كل الأقفال الثلاثين كما هي).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/heist.dart';
import '../../core/stages.dart';
import '../../widgets/spy_ui.dart';

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
    if ((c.myRole ?? 'op') == 'op') return _AgentView(c: c, map: map, lockView: lockView, onExit: onExit);
    return LayoutBuilder(
      builder: (context, box) => Column(children: [
        SizedBox(height: box.maxHeight * .42, child: _AnalystMap(c: c, map: map)),
        Expanded(child: lockView),
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
  late final Ticker _ticker = createTicker(_tick)..start();
  final _frame = ValueNotifier<int>(0);
  late Offset _pos;
  Offset _stick = Offset.zero;
  double _facing = 0;
  double _seenFor = 0;
  int _invulnUntil = 0;
  int _spots = 0, _room = 0;
  bool _hacking = false;
  bool _help = true;
  Duration _last = Duration.zero;

  GameController get c => widget.c;

  @override
  void initState() {
    super.initState();
    final s = c.state!;
    _spots = s.spots;
    _room = s.room;
    // بعد تبادل الأدوار: نبدأ من آخر موقع للشريك
    _pos = c.partnerX != null && s.room > 0 ? Offset(c.partnerX!, c.partnerY!) : widget.map.checkpoint(s.room);
    if (s.room > 0 || s.spots > 0) _help = false;
  }

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
    final solved = s.room;

    // اكتُشف العميل → العودة إلى نقطة الحفظ
    if (s.spots != _spots) {
      _spots = s.spots;
      _pos = widget.map.checkpoint(solved);
      _invulnUntil = DateTime.now().millisecondsSinceEpoch + 2500;
      _seenFor = 0;
    }
    // فُتح القفل → العودة إلى الخريطة والباب التالي مفتوح
    if (s.room != _room) {
      _room = s.room;
      if (_hacking) setState(() => _hacking = false);
    }

    if (!_hacking && !s.paused) {
      var v = _stick.distance > .1 ? _stick : _keys();
      if (v.distance > 1) v = v / v.distance;
      if (v.distance > .05) {
        _facing = atan2(v.dy, v.dx);
        _pos = widget.map.move(_pos, v * 3.2 * dt, solved);
        if (_help) setState(() => _help = false);
      }
      // الكشف: نصف ثانية متواصلة تحت الرؤية
      final t = c.heistTime;
      if (DateTime.now().millisecondsSinceEpoch > _invulnUntil && widget.map.seen(_pos, t, solved, s.camOff)) {
        _seenFor += dt;
        if (_seenFor >= .5) {
          _seenFor = 0;
          _invulnUntil = DateTime.now().millisecondsSinceEpoch + 2500;
          c.dispatch({'type': 'spotted'});
        }
      } else {
        _seenFor = max(0, _seenFor - dt * 2);
      }
      c.sendPos(_pos.dx, _pos.dy);
    }
    _frame.value++;
  }

  bool get _atTerminal {
    final s = c.state!;
    if (s.room >= widget.map.rooms.length) return false;
    return (_pos - widget.map.rooms[s.room].terminal).distance < 1.3;
  }

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final p = widget.map.params;
    final blackout = stageMods(s.stage).contains('blackout') && !s.lit;
    final vision = blackout ? 2.2 : p.vision;
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
      ValueListenableBuilder<int>(
        valueListenable: _frame,
        builder: (context, _, __) => !_hacking && _atTerminal
            ? Positioned(
                bottom: 36,
                right: 20,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _hacking = true),
                  icon: Icon(_isVault(s) ? Icons.lock_open : Icons.terminal, size: 20),
                  label: Text(_isVault(s) ? 'افتح الخزنة' : 'اخترق الجهاز', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: K.neon,
                    foregroundColor: K.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                  ),
                ),
              )
            : const SizedBox.shrink(),
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
            Positioned.fill(child: ColoredBox(color: K.bg, child: widget.lockView)),
            Positioned(
              left: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: 'heist-map',
                backgroundColor: K.surface2,
                foregroundColor: K.text,
                tooltip: 'العودة إلى الخريطة',
                onPressed: () => setState(() => _hacking = false),
                child: const Icon(Icons.map_outlined),
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
  const _Banner({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xE6121518),
          borderRadius: BorderRadius.circular(K.radius),
          border: Border.all(color: K.neon.withAlpha(120)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 13, height: 1.55)),
      );
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
  late final Ticker _ticker = createTicker((_) => _frame.value++)..start();
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
  }) : super(repaint: repaint);

  static const _floor = Color(0xFF16191C), _floor2 = Color(0xFF1A1D21), _wall = Color(0xFF353A40), _wallTop = Color(0xFF4A5057);
  static const _crate = Color(0xFF4B3D2A), _guard = Color(0xFFC9CED3), _cone = Color(0xFFE5484D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = state();
    final t = time();
    final solved = s.room;
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
          canvas.drawRect(r, (x + y).isEven ? pFloor : pFloor2);
          if (v == kCrate) {
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
    for (final d in map.doors) {
      final open = d.after < solved;
      for (final c in d.cells) {
        final r = Rect.fromLTWH(origin.dx + c.x * scale, origin.dy + c.y * scale, scale, scale);
        if (open) {
          canvas.drawRect(r, Paint()..color = K.ok.withAlpha(40));
        } else {
          canvas.drawRect(r.deflate(scale * .15), Paint()..color = (d.after == solved ? K.neon : K.danger).withAlpha(200));
        }
      }
    }

    // الأجهزة
    for (int i = 0; i < map.rooms.length; i++) {
      final c = sc(map.rooms[i].terminal);
      final vault = i == map.rooms.length - 1;
      final col = i < solved ? K.ok : (i == solved ? K.neon : const Color(0xFF5B6168));
      if (i == solved) canvas.drawCircle(c, scale * (.6 + .25 * pulse), Paint()..color = K.neon.withAlpha(40));
      if (vault) {
        canvas.drawCircle(c, scale * .38, Paint()..color = const Color(0xFF2E3237));
        canvas.drawCircle(c, scale * .38, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scale * .08
          ..color = col);
        canvas.drawCircle(c, scale * .1, Paint()..color = col);
      } else {
        final r = Rect.fromCenter(center: c, width: scale * .62, height: scale * .5);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(scale * .06)), Paint()..color = const Color(0xFF22262B));
        canvas.drawRect(r.deflate(scale * .09), Paint()..color = col.withAlpha(i == solved ? 230 : 140));
      }
    }

    // الكاميرات
    for (int i = 0; i < map.cams.length; i++) {
      final cam = map.cams[i];
      final off = (s.camOff['$i'] ?? -1) > t;
      final p = sc(cam.pos);
      final ang = camAngle(cam, t);
      if (!off) _cone(canvas, p, ang, kCamHalf, map.params.camRange * scale, const Color(0xFFFFC94D));
      canvas.drawRect(Rect.fromCenter(center: p, width: scale * .34, height: scale * .34), Paint()..color = off ? const Color(0xFF3A3F45) : const Color(0xFFB9BEC4));
      canvas.drawCircle(p, scale * .08, Paint()..color = off ? K.muted : K.danger);
      if (off) {
        final sec = ((s.camOff['$i'] ?? 0) - t).ceil();
        _label(canvas, p + Offset(0, -scale * .55), '$sec', K.ok, scale * .32);
      }
    }

    // الحرّاس (أو مساراتهم فقط عند المحلّل في المراحل المتقدّمة)
    for (final g in map.guards) {
      if (!showGuards) {
        final path = Path()..moveTo(sc(g.path.first).dx, sc(g.path.first).dy);
        for (final q in g.path.skip(1)) {
          path.lineTo(sc(q).dx, sc(q).dy);
        }
        path.close();
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1, scale * .07)
          ..color = _cone.withAlpha(120));
        continue;
      }
      final (gp, ga) = guardAt(g, t);
      final p = sc(gp);
      _cone(canvas, p, ga, kGuardHalf, map.params.guardRange * scale, _cone);
      canvas.drawCircle(p, scale * .32, Paint()..color = const Color(0xFF2B3A55));
      canvas.drawCircle(p, scale * .32, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .06
        ..color = _guard);
      canvas.drawCircle(p + Offset(cos(ga), sin(ga)) * scale * .2, scale * .08, Paint()..color = _guard);
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
      canvas.drawCircle(p, scale * .3, Paint()..color = K.agent);
      canvas.drawCircle(p, scale * .3, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale * .06
        ..color = const Color(0xFFE6E8EA));
      if (agentMode) canvas.drawCircle(p + Offset(cos(f), sin(f)) * scale * .18, scale * .08, Paint()..color = const Color(0xFF0A0C0E));
      // تحذير «!» عندما يراه أحد
      final al = alert();
      if (al > 0) _label(canvas, p + Offset(0, -scale * .75), '!', K.danger, scale * (.45 + al));
    }

    // الظلام حول العميل
    if (agentMode && a != null) {
      final p = sc(a);
      canvas.saveLayer(Offset.zero & size, Paint());
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xF2050607));
      canvas.drawCircle(
        p,
        vision * scale,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = RadialGradient(colors: const [Colors.black, Colors.black, Color(0x00000000)], stops: const [0, .7, 1])
              .createShader(Rect.fromCircle(center: p, radius: vision * scale)),
      );
      canvas.restore();
      // الجهاز المطلوب يبقى ظاهراً كمنارة خافتة حتى خارج الرؤية
      if (solved < map.rooms.length) {
        final tp = sc(map.rooms[solved].terminal);
        canvas.drawCircle(tp, scale * (.18 + .08 * pulse), Paint()..color = K.neon.withAlpha(150));
      }
    }
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
