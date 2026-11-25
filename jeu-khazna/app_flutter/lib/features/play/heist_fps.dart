// وضع الخريطة 3D: العميل يرى المبنى بعينيه (منظور الشخص الأول).
// الجدران بإلقاء الأشعّة على شبكة الخريطة بدقّة الشاشة، والأرضية والسقف مستويات حقيقية بالمنظور
// (تحويل إسقاطي 4×4)، والحرّاس والأجهزة كائنات تواجه الكاميرا مع اختبار العمق لكل عمود.
// كل الخامات مولّدة بالكود (256×256) — لا صور إضافية.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game.dart';
import '../../core/heist.dart';
import 'heist_view.dart' show HeistSprites;

// ───────── الخامات ─────────
class FpsTextures {
  static final Map<String, ui.Image> _img = {};
  static bool _busy = false;
  static const int n = 256;

  static ui.Image? get(String k) => _img[k];

  static ui.Image? wallFor(int stage) => get(stage <= 20 ? 'wall_port' : (stage <= 40 ? 'wall_river' : 'wall_mountain'));

  static Future<void> load() async {
    if (_busy || _img.isNotEmpty) return;
    _busy = true;
    final square = <String, void Function(Canvas)>{
      'wall_port': _concrete,
      'wall_river': _planks,
      'wall_mountain': _stone,
      'door': _door,
      'crate': _crate,
      'ceil': _ceiling,
      'term_on': (c) => _terminal(c, K.neon),
      'term_done': (c) => _terminal(c, K.ok),
      'term_off': (c) => _terminal(c, const Color(0xFF4A5057)),
      'vault': _vault,
      'exit': _exit,
      'mark': _mark,
      'cam': _camera,
      'card': _card,
    };
    for (final e in square.entries) {
      await _make(e.key, n, n, (c) {
        c.scale(n / 64);
        e.value(c);
      });
    }
    // الحارس: أمام/خلف/جانب × خطوتان (128×256)
    for (final view in const ['front', 'back', 'side']) {
      for (final step in const [0, 1]) {
        await _make('guard_${view}_$step', 128, 256, (c) {
          c.scale(2);
          _guard(c, view, step);
        });
      }
    }
    _busy = false;
  }

  static Future<void> _make(String key, int w, int h, void Function(Canvas) draw) async {
    try {
      final rec = ui.PictureRecorder();
      draw(Canvas(rec));
      _img[key] = await rec.endRecording().toImage(w, h);
    } catch (_) {}
  }

  static final _rnd = Random(7);
  static Paint _p(Color c) => Paint()..color = c;

  /// بقع ناعمة (لا مربّعات): تعطي سطحاً واقعياً.
  static void _grain(Canvas c, Color base, int amount, double spread, [double size = 1.2]) {
    for (int i = 0; i < amount; i++) {
      final v = (_rnd.nextDouble() - .5) * spread;
      final col = Color.lerp(base, v > 0 ? Colors.white : Colors.black, v.abs())!;
      c.drawCircle(
        Offset(_rnd.nextDouble() * 64, _rnd.nextDouble() * 64),
        size * (.4 + _rnd.nextDouble()),
        Paint()
          ..color = col.withAlpha(150)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .5),
      );
    }
  }

  static void _shadeEdges(Canvas c) {
    // ظلّ عند السقف والأرض (إحساس بالعمق عند التقاء الجدار)
    c.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x88000000)],
          stops: [0, .18, .8, 1],
        ).createShader(const Rect.fromLTWH(0, 0, 64, 64)),
    );
  }

  static void _concrete(Canvas c) {
    const base = Color(0xFF59626B);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    _grain(c, base, 700, .3);
    for (int i = 0; i < 5; i++) {
      c.drawCircle(Offset(_rnd.nextDouble() * 64, 30 + _rnd.nextDouble() * 34), 4 + _rnd.nextDouble() * 6,
          Paint()
            ..color = const Color(0x22000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    final seam = Paint()..color = const Color(0xFF2C3238);
    c.drawRect(const Rect.fromLTWH(0, 31.4, 64, 1.2), seam);
    c.drawRect(const Rect.fromLTWH(31.4, 0, 1.2, 64), seam);
    c.drawRect(const Rect.fromLTWH(0, 32.6, 64, .5), _p(const Color(0xFF79838C)));
    for (final o in const [Offset(4, 4), Offset(60, 4), Offset(4, 28), Offset(60, 28), Offset(4, 36), Offset(60, 36), Offset(4, 50), Offset(60, 50)]) {
      c.drawCircle(o, 1.3, _p(const Color(0xFF2F353B)));
      c.drawCircle(o - const Offset(.3, .3), .8, _p(const Color(0xFFA2ABB3)));
    }
    for (double x = -8; x < 64; x += 6) {
      c.drawPath(
        Path()
          ..moveTo(x, 64)
          ..lineTo(x + 3, 64)
          ..lineTo(x + 7, 56)
          ..lineTo(x + 4, 56)
          ..close(),
        _p(const Color(0xFFB8901F)),
      );
    }
    c.drawRect(const Rect.fromLTWH(0, 55.5, 64, .8), _p(const Color(0xFF2C3238)));
    _shadeEdges(c);
  }

  static void _planks(Canvas c) {
    for (int i = 0; i < 4; i++) {
      final base = Color.lerp(const Color(0xFF5E4028), const Color(0xFF85603A), _rnd.nextDouble())!;
      c.drawRect(Rect.fromLTWH(0, i * 16.0, 64, 16), _p(base));
      for (int k = 0; k < 6; k++) {
        final y = i * 16.0 + 1.5 + _rnd.nextDouble() * 13;
        final path = Path()..moveTo(0, y);
        for (double x = 0; x <= 64; x += 8) {
          path.lineTo(x, y + sin(x / 9 + k) * .8);
        }
        c.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .35
          ..color = Color.lerp(base, Colors.black, .3)!);
      }
      _grain(c, base, 60, .2, .8);
      c.drawRect(Rect.fromLTWH(0, i * 16.0 + 15.2, 64, .8), _p(const Color(0xFF24170C)));
      c.drawRect(Rect.fromLTWH(0, i * 16.0, 64, .4), _p(Color.lerp(base, Colors.white, .15)!));
      for (final x in const [6.0, 58.0]) {
        c.drawCircle(Offset(x, i * 16.0 + 8), 1, _p(const Color(0xFF1E140A)));
      }
    }
    _shadeEdges(c);
  }

  static void _stone(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(const Color(0xFF2A2D30)));
    for (int row = 0; row < 4; row++) {
      final off = row.isOdd ? -11.0 : 0.0;
      for (int col = 0; col < 4; col++) {
        final base = Color.lerp(const Color(0xFF63676B), const Color(0xFF818488), _rnd.nextDouble())!;
        final r = Rect.fromLTWH(off + col * 22.0 + .8, row * 16.0 + .8, 20.4, 14.4);
        final rr = RRect.fromRectAndRadius(r, const Radius.circular(2.5));
        c.drawRRect(rr, _p(base));
        c.drawRRect(rr, Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withAlpha(40), Colors.black.withAlpha(70)],
          ).createShader(r));
      }
    }
    _grain(c, const Color(0xFF707377), 400, .35);
    _shadeEdges(c);
  }

  static void _door(Canvas c) {
    const base = Color(0xFF66707A);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF4F5862), base, Color(0xFF4F5862)]).createShader(const Rect.fromLTWH(0, 0, 64, 64)));
    _grain(c, base, 250, .2, .8);
    for (double y = 6; y < 64; y += 12) {
      c.drawRect(Rect.fromLTWH(2, y, 60, 2.4), _p(const Color(0xFF3A4249)));
      c.drawRect(Rect.fromLTWH(2, y + 2.4, 60, .6), _p(const Color(0xFF9AA3AB)));
    }
    c.drawRect(const Rect.fromLTWH(0, 0, 2.5, 64), _p(const Color(0xFF262B30)));
    c.drawRect(const Rect.fromLTWH(61.5, 0, 2.5, 64), _p(const Color(0xFF262B30)));
    c.drawRect(const Rect.fromLTWH(31.6, 0, .8, 64), _p(const Color(0xFF262B30)));
    _shadeEdges(c);
  }

  static void _crate(Canvas c) {
    const base = Color(0xFF86633A);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    for (int k = 0; k < 4; k++) {
      c.drawRect(Rect.fromLTWH(0, k * 16.0 + 15.5, 64, .5), _p(const Color(0xFF4A3218)));
    }
    _grain(c, base, 200, .25, .9);
    final dark = Paint()
      ..color = const Color(0xFF4E361C)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    c.drawRect(const Rect.fromLTWH(2.5, 2.5, 59, 59), dark);
    c.drawLine(const Offset(5, 5), const Offset(59, 59), dark);
    c.drawLine(const Offset(59, 5), const Offset(5, 59), dark);
    _shadeEdges(c);
  }

  static void _ceiling(Canvas c) {
    const base = Color(0xFF23272C);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    _grain(c, base, 300, .25);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 1), _p(const Color(0xFF111316)));
    c.drawRect(const Rect.fromLTWH(0, 0, 1, 64), _p(const Color(0xFF111316)));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(22, 28, 20, 8), const Radius.circular(2)), _p(const Color(0xFF3A3F45)));
    c.drawRect(const Rect.fromLTWH(24, 30, 16, 4), _p(const Color(0xFF8F8A6A)));
  }

  static void _terminal(Canvas c, Color screen) {
    c.drawOval(const Rect.fromLTWH(10, 59, 44, 5), _p(const Color(0x66000000)));
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 6, 36, 56), const Radius.circular(4));
    c.drawRRect(body, Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF2A2F35), Color(0xFF4A515A), Color(0xFF2A2F35)]).createShader(body.outerRect));
    c.drawRRect(body.deflate(1.5), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6
      ..color = const Color(0xFF6E767E));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(17.5, 11, 29, 21), const Radius.circular(2)), _p(const Color(0xFF07090A)));
    c.drawRect(const Rect.fromLTWH(19.5, 13, 25, 17), Paint()
      ..shader = RadialGradient(colors: [screen, Color.lerp(screen, Colors.black, .45)!]).createShader(const Rect.fromLTWH(19.5, 13, 25, 17)));
    for (double y = 14; y < 30; y += 2) {
      c.drawRect(Rect.fromLTWH(19.5, y, 25, .5), _p(Colors.black.withAlpha(55)));
    }
    c.drawRect(const Rect.fromLTWH(21, 15, 10, 1), _p(Colors.white.withAlpha(120)));
    c.drawRect(const Rect.fromLTWH(21, 18, 16, 1), _p(Colors.white.withAlpha(90)));
    for (int i = 0; i < 9; i++) {
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(19 + (i % 3) * 9.0, 37 + (i ~/ 3) * 6.5, 7.4, 5), const Radius.circular(1));
      c.drawRRect(r, _p(const Color(0xFF1C2024)));
      c.drawRRect(r.deflate(.5), Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8C949B), Color(0xFF5B636A)])
            .createShader(r.outerRect));
    }
    c.drawCircle(const Offset(44.5, 57.5), 1.6, _p(screen));
    c.drawCircle(const Offset(44.5, 57.5), 3, Paint()
      ..color = screen.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
  }

  static void _vault(Canvas c) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(5, 3, 54, 60), const Radius.circular(3)), Paint()
      ..shader = const LinearGradient(colors: [Color(0xFF2A2E33), Color(0xFF454B52), Color(0xFF2A2E33)]).createShader(const Rect.fromLTWH(5, 3, 54, 60)));
    c.drawCircle(const Offset(32, 33), 23, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFB9C0C6), Color(0xFF5E666D)], center: Alignment(-.3, -.4))
          .createShader(Rect.fromCircle(center: const Offset(32, 33), radius: 23)));
    c.drawCircle(const Offset(32, 33), 18, _p(const Color(0xFF3E444A)));
    final spoke = Paint()
      ..color = const Color(0xFFD5DADF)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      c.drawLine(const Offset(32, 33), Offset(32 + cos(a) * 15, 33 + sin(a) * 15), spoke);
    }
    c.drawCircle(const Offset(32, 33), 5, _p(const Color(0xFFE8A13A)));
    for (final y in const [12.0, 54.0]) {
      c.drawRect(Rect.fromLTWH(8, y - 2, 6, 4), _p(const Color(0xFF8C949B)));
    }
  }

  static void _exit(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()
      ..shader = const RadialGradient(colors: [Color(0xEE3DD68C), Color(0x003DD68C)]).createShader(const Rect.fromLTWH(0, 0, 64, 64)));
    c.drawRect(const Rect.fromLTWH(26, 0, 12, 64), Paint()
      ..shader = const LinearGradient(colors: [Color(0x003DD68C), Color(0xDD9CF5C4), Color(0x003DD68C)]).createShader(const Rect.fromLTWH(26, 0, 12, 64)));
  }

  static void _mark(Canvas c) {
    c.drawRect(const Rect.fromLTWH(28, 0, 8, 64), Paint()
      ..shader = const LinearGradient(colors: [Color(0x00E8A13A), Color(0xCCE8A13A), Color(0x00E8A13A)]).createShader(const Rect.fromLTWH(28, 0, 8, 64)));
    c.drawOval(const Rect.fromLTWH(12, 56, 40, 8), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFE8A13A));
  }

  static void _camera(Canvas c) {
    c.drawRect(const Rect.fromLTWH(28, 0, 8, 22), _p(const Color(0xFF3A4046)));
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(12, 20, 40, 22), const Radius.circular(5));
    c.drawRRect(body, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD8DCDF), Color(0xFF8A9096)])
          .createShader(body.outerRect));
    c.drawCircle(const Offset(32, 31), 8, _p(const Color(0xFF15181B)));
    c.drawCircle(const Offset(32, 31), 4, _p(const Color(0xFF3B5B7A)));
    c.drawCircle(const Offset(45, 25), 2, _p(K.danger));
  }

  static void _card(Canvas c) {
    final r = RRect.fromRectAndRadius(const Rect.fromLTWH(10, 18, 44, 28), const Radius.circular(3));
    c.drawRRect(r.inflate(4), Paint()
      ..color = const Color(0x66E9B949)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    c.drawRRect(r, _p(const Color(0xFFE9B949)));
    c.drawRect(const Rect.fromLTWH(15, 24, 10, 8), _p(const Color(0xFF8A6A1E)));
    c.drawRect(const Rect.fromLTWH(29, 26, 20, 2.5), _p(const Color(0xFF8A6A1E)));
    c.drawRect(const Rect.fromLTWH(29, 32, 14, 2), _p(const Color(0xFF8A6A1E)));
  }

  /// حارس بزيّ كحلي وقبّعة ومصباح يدوي (64×128 قبل التكبير).
  static void _guard(Canvas c, String view, int step) {
    const uni = Color(0xFF1F2B44), uniL = Color(0xFF34466B), skin = Color(0xFFC79A78), boot = Color(0xFF111316);
    final side = view == 'side';
    c.drawOval(const Rect.fromLTWH(14, 122, 36, 6), _p(const Color(0x66000000)));
    final swing = step == 0 ? 3.0 : -3.0;
    if (side) {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(27 + swing, 80, 9, 40), const Radius.circular(3)), _p(uni));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(27 - swing, 80, 9, 40), const Radius.circular(3)), _p(uniL));
      c.drawRect(Rect.fromLTWH(26 + swing, 116, 14, 6), _p(boot));
      c.drawRect(Rect.fromLTWH(26 - swing, 116, 14, 6), _p(boot));
    } else {
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(21, 80 - (step == 0 ? 2 : 0), 10, 40), const Radius.circular(3)), _p(uni));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(33, 80 - (step == 1 ? 2 : 0), 10, 40), const Radius.circular(3)), _p(uni));
      c.drawRect(const Rect.fromLTWH(20, 116, 12, 6), _p(boot));
      c.drawRect(const Rect.fromLTWH(32, 116, 12, 6), _p(boot));
    }
    final torso = RRect.fromRectAndRadius(Rect.fromLTWH(side ? 22 : 16, 40, side ? 20 : 32, 44), const Radius.circular(6));
    c.drawRRect(torso, Paint()..shader = const LinearGradient(colors: [uni, uniL, uni]).createShader(torso.outerRect));
    c.drawRect(Rect.fromLTWH(torso.left, 74, torso.width, 4), _p(const Color(0xFF0E1218)));
    if (view == 'front') {
      c.drawRect(const Rect.fromLTWH(36, 48, 6, 5), _p(const Color(0xFFE8A13A)));
      c.drawLine(const Offset(32, 42), const Offset(32, 74), Paint()
        ..strokeWidth = .8
        ..color = const Color(0xFF0E1218));
    }
    if (side) {
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(30, 44, 8, 30), const Radius.circular(3)), _p(uniL));
      c.drawRect(const Rect.fromLTWH(36, 66, 14, 5), _p(const Color(0xFF2A2F35)));
      c.drawCircle(const Offset(51, 68.5), 3.5, Paint()
        ..color = const Color(0xFFFFF4C2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    } else {
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(9, 44, 8, 32), const Radius.circular(3)), _p(uni));
      c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(47, 44, 8, 32), const Radius.circular(3)), _p(uni));
      if (view == 'front') {
        c.drawCircle(const Offset(51, 78), 4, Paint()
          ..color = const Color(0xFFFFF4C2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      }
    }
    c.drawRect(Rect.fromLTWH(side ? 28 : 27, 34, 10, 7), _p(Color.lerp(skin, Colors.black, .2)!));
    c.drawOval(Rect.fromLTWH(side ? 23 : 22, 14, 20, 22), _p(view == 'back' ? const Color(0xFF2A1E16) : skin));
    if (view == 'front') {
      c.drawCircle(const Offset(28.5, 25), 1.2, _p(const Color(0xFF1A1A1A)));
      c.drawCircle(const Offset(35.5, 25), 1.2, _p(const Color(0xFF1A1A1A)));
      c.drawRect(const Rect.fromLTWH(29.5, 30, 5, .9), _p(const Color(0xFF7A4E3A)));
    } else if (side) {
      c.drawCircle(const Offset(39, 25), 1.1, _p(const Color(0xFF1A1A1A)));
    }
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(side ? 21 : 20, 10, 24, 9), const Radius.circular(4)), _p(const Color(0xFF151C2C)));
    c.drawRect(Rect.fromLTWH(side ? 30 : 18, 17, side ? 18 : 28, 3), _p(const Color(0xFF0D1220)));
  }
}

// ───────── الرسّام ─────────
class _Sprite {
  final Offset pos;
  final ui.Image img;
  final double height; // نسبة من ارتفاع الجدار
  final double lift; // ارتفاع القاعدة عن الأرض
  final bool glow;
  final bool flip;
  const _Sprite(this.pos, this.img, this.height, {this.lift = 0, this.glow = false, this.flip = false});
}

class FpsPainter extends CustomPainter {
  final HeistMap map;
  final GameState Function() state;
  final double Function() time;
  final Offset Function() agent;
  final double Function() facing;
  final double Function() alert;
  final Offset? Function() mark;
  final double vision;

  FpsPainter({
    required this.map,
    required Listenable repaint,
    required this.state,
    required this.time,
    required this.agent,
    required this.facing,
    required this.alert,
    required this.mark,
    required this.vision,
  }) : super(repaint: repaint);

  static const double fov = .66; // نصف عرض مستوى الكاميرا (≈ 66°)

  late final Map<int, int> _doorAt = {
    for (int i = 0; i < map.doors.length; i++)
      for (final c in map.doors[i].cells) c.y * map.w + c.x: i,
  };

  Float64List _z = Float64List(0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = state();
    final t = time();
    final pos = agent();
    final ang = facing();
    final escaping = s.escape > 0;
    final shut = escaping ? map.shutAfter(t - s.escape) : const <int>{};
    final solved = escaping ? map.rooms.length : s.room;
    final power = s.power > t;
    final w = size.width, h = size.height;
    final horizon = h / 2;
    final fogDist = (power ? min(vision, 1.9) : vision) * 1.9;
    final dirX = cos(ang), dirY = sin(ang);
    final planeX = -dirY * fov, planeY = dirX * fov;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final pulse = .5 + .5 * sin(nowMs / 260);

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF050607));

    // ── الأرضية والسقف بالمنظور الحقيقي
    _plane(canvas, size, pos, dirX, dirY, floor: true, img: HeistSprites.floorFor(s.stage), fogDist: fogDist, extra: (c) {
      // مصابيح الحرّاس ومخاريط الكاميرات على الأرض (تحجبها الجدران تلقائياً)
      final gRange = map.guardRange(power: power, alarm: escaping);
      for (final g in map.guards) {
        final (gp, ga) = guardAt(g, t);
        _floorCone(c, gp, ga, kGuardHalf, gRange, power ? const Color(0xFFFFF1B8) : const Color(0xFFFFE6A0));
      }
      if (!power) {
        for (int i = 0; i < map.cams.length; i++) {
          if ((s.camOff['$i'] ?? -1) > t) continue;
          final cam = map.cams[i];
          _floorCone(c, cam.pos, camAngle(cam, t), kCamHalf, map.params.camRange, const Color(0xFFE5484D));
        }
      }
      final mk = mark();
      if (mk != null) {
        final ph = (nowMs / 900) % 1;
        c.drawCircle(mk, .25 + ph * .6, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .06
          ..color = K.neon.withAlpha(((1 - ph) * 230).round()));
      }
      if (escaping) c.drawCircle(map.spawn, .55 + .1 * pulse, Paint()..color = K.ok.withAlpha(120));
    });
    _plane(canvas, size, pos, dirX, dirY, floor: false, img: FpsTextures.get('ceil'), fogDist: fogDist);

    // ── الجدران: عمود لكل بكسل تقريباً
    final cols = min(560, max(120, w.round()));
    final colW = w / cols;
    if (_z.length != cols) _z = Float64List(cols);
    final wallImg = FpsTextures.wallFor(s.stage);
    final doorImg = FpsTextures.get('door');
    final crateImg = FpsTextures.get('crate');
    final texN = FpsTextures.n.toDouble();
    final light = Paint()..filterQuality = FilterQuality.medium;

    for (int x = 0; x < cols; x++) {
      final camX = 2 * (x + .5) / cols - 1;
      final rx = dirX + planeX * camX, ry = dirY + planeY * camX;
      var mx = pos.dx.floor(), my = pos.dy.floor();
      final ddx = rx == 0 ? 1e30 : (1 / rx).abs(), ddy = ry == 0 ? 1e30 : (1 / ry).abs();
      final stepX = rx < 0 ? -1 : 1, stepY = ry < 0 ? -1 : 1;
      var sdx = rx < 0 ? (pos.dx - mx) * ddx : (mx + 1 - pos.dx) * ddx;
      var sdy = ry < 0 ? (pos.dy - my) * ddy : (my + 1 - pos.dy) * ddy;
      var side = 0, kind = -1, door = -1;
      for (int i = 0; i < 90; i++) {
        if (sdx < sdy) {
          sdx += ddx;
          mx += stepX;
          side = 0;
        } else {
          sdy += ddy;
          my += stepY;
          side = 1;
        }
        final tile = map.at(mx, my);
        if (tile == kWall) {
          kind = 0;
          break;
        }
        if (tile == kCrate) {
          kind = 1;
          break;
        }
        final di = _doorAt[my * map.w + mx];
        if (di != null && (map.doors[di].after >= solved || shut.contains(di))) {
          kind = 2;
          door = di;
          break;
        }
      }
      final dist = max(.05, side == 0 ? sdx - ddx : sdy - ddy);
      _z[x] = kind < 0 ? 1e9 : dist;
      if (kind < 0) continue;

      final lineH = h / dist;
      final top = horizon - lineH / 2;
      var wallX = side == 0 ? pos.dy + dist * ry : pos.dx + dist * rx;
      wallX -= wallX.floor();
      final img = kind == 0 ? wallImg : (kind == 1 ? crateImg : doorImg);
      // الإضاءة: الضباب بالمسافة + بقعة المصباح في الوسط + الوجه الجانبي أغمق
      final fog = (dist / fogDist).clamp(0.0, 1.0);
      final spot = 1 - camX.abs() * .35;
      final dark = (1 - (1 - pow(fog, 1.3)) * spot) * 235 + (side == 1 ? 28 : 0);
      final dst = Rect.fromLTWH(x * colW, top, colW + .5, lineH);
      if (img != null) {
        final tx = (wallX * texN).clamp(0.0, texN - 1);
        light.colorFilter = ColorFilter.mode(Color.fromARGB(dark.clamp(0, 248).round(), 0, 0, 0), BlendMode.srcATop);
        canvas.drawImageRect(img, Rect.fromLTWH(tx, 0, 1, texN), dst, light);
      } else {
        canvas.drawRect(dst, Paint()..color = Color.lerp(const Color(0xFF4A5057), Colors.black, dark.clamp(0, 248) / 255)!);
      }
      if (kind == 2) {
        final closedNow = shut.contains(door);
        final next = map.doors[door].after == solved && !closedNow;
        final col = next ? K.neon : K.danger;
        final glow = ((1 - fog) * 230).round().clamp(50, 230);
        canvas.drawRect(Rect.fromLTWH(dst.left, top + lineH * .47, dst.width, lineH * .05), Paint()..color = col.withAlpha(glow));
        if (closedNow && ((wallX * 6).floor()).isEven) {
          canvas.drawRect(Rect.fromLTWH(dst.left, top, dst.width, lineH), Paint()..color = K.danger.withAlpha((glow * .3).round()));
        }
      }
    }

    // ── الكائنات
    final sprites = <_Sprite>[];
    for (int i = 0; i < map.rooms.length; i++) {
      final vault = i == map.rooms.length - 1;
      final img = vault ? FpsTextures.get('vault') : FpsTextures.get(i < solved ? 'term_done' : (i == solved ? 'term_on' : 'term_off'));
      if (img != null) sprites.add(_Sprite(map.rooms[i].terminal, img, vault ? .9 : .78, glow: i == solved));
    }
    final camImg = FpsTextures.get('cam');
    if (camImg != null) {
      for (final cam in map.cams) {
        sprites.add(_Sprite(cam.pos, camImg, .22, lift: .72));
      }
    }
    final step = (nowMs ~/ 260) % 2;
    for (int gi = 0; gi < map.guards.length; gi++) {
      final g = map.guards[gi];
      final (gp, ga) = guardAt(g, t);
      // أيّ وجه نراه؟ الزاوية بين اتجاه الحارس واتجاهنا إليه
      var rel = atan2(pos.dy - gp.dy, pos.dx - gp.dx) - ga;
      while (rel > pi) {
        rel -= 2 * pi;
      }
      while (rel < -pi) {
        rel += 2 * pi;
      }
      final view = rel.abs() < pi / 4 ? 'front' : (rel.abs() > 3 * pi / 4 ? 'back' : 'side');
      final img = FpsTextures.get('guard_${view}_$step');
      if (img != null) sprites.add(_Sprite(gp, img, .92, flip: view == 'side' && rel < 0));
      if (map.cardGuards.contains(gi) && !s.cards.contains(g.room)) {
        final card = FpsTextures.get('card');
        if (card != null) sprites.add(_Sprite(gp, card, .2, lift: .95 + .03 * pulse, glow: true));
      }
    }
    final mk = mark();
    final markImg = FpsTextures.get('mark'), exitImg = FpsTextures.get('exit');
    if (mk != null && markImg != null) sprites.add(_Sprite(mk, markImg, 1.1, glow: true));
    if (escaping && exitImg != null) sprites.add(_Sprite(map.spawn, exitImg, 1, glow: true));
    sprites.sort((a, b) => (b.pos - pos).distanceSquared.compareTo((a.pos - pos).distanceSquared));

    final invDet = 1 / (planeX * dirY - dirX * planeY);
    (double, double) project(Offset p) {
      final r = p - pos;
      return (invDet * (dirY * r.dx - dirX * r.dy), invDet * (-planeY * r.dx + planeX * r.dy));
    }

    final sp = Paint()..filterQuality = FilterQuality.medium;
    for (final o in sprites) {
      final (tX, depth) = project(o.pos);
      if (depth < .15) continue;
      final screenCol = (cols / 2) * (1 + tX / depth);
      final full = h / depth;
      final sh = full * o.height;
      final sw = sh * o.img.width / o.img.height;
      final bottom = horizon + full * (.5 - o.lift);
      final half = sw / colW / 2;
      final c0 = (screenCol - half).floor(), c1 = (screenCol + half).ceil();
      final fog = (depth / fogDist).clamp(0.0, 1.0);
      final dark = (o.glow ? pow(fog, 1.3) * 120 : pow(fog, 1.3) * 235).round();
      sp.colorFilter = ColorFilter.mode(Color.fromARGB(dark.clamp(0, 245).toInt(), 0, 0, 0), BlendMode.srcATop);
      final iw = o.img.width.toDouble(), ih = o.img.height.toDouble();
      for (int x = max(0, c0); x < min(cols, c1); x++) {
        if (depth >= _z[x]) continue;
        var u = ((x + .5 - (screenCol - half)) / (half * 2)).clamp(0.0, .999);
        if (o.flip) u = .999 - u;
        canvas.drawImageRect(o.img, Rect.fromLTWH(u * iw, 0, 1, ih), Rect.fromLTWH(x * colW, bottom - sh, colW + .5, sh), sp);
      }
    }

    // ── الليزر: شعاع على ارتفاع الخصر، مقطّع لاختبار العمق
    for (final l in map.lasers) {
      final seg = l.at(t);
      final warm = l.warmup(t);
      if (seg == null && (warm == null || warm > .9)) continue;
      final a = seg?.$1 ?? l.a, b = seg?.$2 ?? l.b;
      const z = .42;
      final paint = Paint()
        ..strokeCap = StrokeCap.round
        ..color = seg != null ? const Color(0xFFFF4040) : const Color(0x88FF4040);
      const nSeg = 40;
      for (int k = 0; k < nSeg; k++) {
        if (seg == null && k.isOdd) continue; // تحذير متقطّع قبل الاشتعال
        final p0 = Offset.lerp(a, b, k / nSeg)!, p1 = Offset.lerp(a, b, (k + 1) / nSeg)!;
        final (x0, d0) = project(p0);
        final (x1, d1) = project(p1);
        if (d0 < .15 || d1 < .15) continue;
        final sx0 = (w / 2) * (1 + x0 / d0), sx1 = (w / 2) * (1 + x1 / d1);
        final col = ((sx0 + sx1) / 2 / colW).floor();
        if (col < 0 || col >= cols || (d0 + d1) / 2 >= _z[col]) continue;
        final sy0 = horizon + h * (.5 - z) / d0, sy1 = horizon + h * (.5 - z) / d1;
        final width = max(1.2, h * .012 / ((d0 + d1) / 2));
        paint.strokeWidth = width;
        if (seg != null) {
          canvas.drawLine(Offset(sx0, sy0), Offset(sx1, sy1), Paint()
            ..strokeWidth = width * 5
            ..color = const Color(0x44FF2020)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
        }
        canvas.drawLine(Offset(sx0, sy0), Offset(sx1, sy1), paint);
      }
    }

    // ── علامة الهدف
    final goal = escaping ? map.spawn : (solved < map.rooms.length ? map.rooms[solved].terminal : null);
    if (goal != null) {
      final (tX, depth) = project(goal);
      final col = escaping ? K.ok : K.neon;
      if (depth > .2 && (tX / depth).abs() < 1.05) {
        final sx = (w / 2) * (1 + tX / depth);
        final y = horizon - h / depth * .32 - 22;
        final dm = Path()
          ..moveTo(sx, y - 9)
          ..lineTo(sx + 7, y)
          ..lineTo(sx, y + 9)
          ..lineTo(sx - 7, y)
          ..close();
        canvas.drawPath(dm, Paint()..color = col.withAlpha((150 + 100 * pulse).round()));
        _label(canvas, Offset(sx, y + 20), '${(goal - pos).distance.round()}m', col, 12);
      } else {
        var diff = atan2(goal.dy - pos.dy, goal.dx - pos.dx) - ang;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        final right = diff > 0;
        final x = right ? w - 26 : 26.0;
        canvas.drawPath(
          Path()
            ..moveTo(x + (right ? 12 : -12), horizon)
            ..lineTo(x, horizon - 12)
            ..lineTo(x, horizon + 12)
            ..close(),
          Paint()..color = col.withAlpha((120 + 120 * pulse).round()),
        );
      }
    }

    // ── المؤثّرات على الشاشة
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(radius: .95, colors: [Color(0x00000000), Color(0x99000000)], stops: [.6, 1])
            .createShader(Offset.zero & size),
    );
    final al = alert();
    if (al > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(radius: .8, colors: [const Color(0x00000000), K.danger.withAlpha((90 + 240 * al).clamp(0, 200).round())], stops: const [.5, 1])
              .createShader(Offset.zero & size),
      );
    }
    if (escaping) {
      final k = .5 + .5 * sin(nowMs / 180);
      canvas.drawRect(Offset.zero & size, Paint()..color = K.danger.withAlpha((12 + 40 * k).round()));
    }
    if (power) canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0x33061030));
    canvas.drawCircle(Offset(w / 2, horizon), 2, Paint()..color = Colors.white.withAlpha(90));
  }

  /// مستوى أفقي (أرضية أو سقف) بالمنظور الحقيقي: مصفوفة إسقاط تحوّل إحداثيات العالم إلى الشاشة.
  void _plane(Canvas canvas, Size size, Offset pos, double dirX, double dirY,
      {required bool floor, required ui.Image? img, required double fogDist, void Function(Canvas)? extra}) {
    final w = size.width, h = size.height, horizon = h / 2;
    final k = w / (2 * fov);
    final cd = -(dirX * pos.dx + dirY * pos.dy);
    final cl = -(-dirY * pos.dx + dirX * pos.dy);
    final yk = floor ? h / 2 : -h / 2;
    // صفوف المصفوفة: sx·d، sy·d، z، d — مخزّنة بالأعمدة
    final m = Float64List.fromList([
      (w / 2) * dirX - k * dirY, horizon * dirX, 0, dirX, //
      (w / 2) * dirY + k * dirX, horizon * dirY, 0, dirY, //
      0, 0, 1, 0, //
      (w / 2) * cd + k * cl, horizon * cd + yk, 0, cd, //
    ]);
    // شبه منحرف أمام الكاميرا فقط (العمق موجب دائماً)
    const near = .06;
    final far = fogDist * 2.2;
    final right = Offset(-dirY, dirX), fwd = Offset(dirX, dirY);
    Offset at(double d, double l) => pos + fwd * d + right * l;
    const spread = fov * 1.6;
    final p0 = at(near, -near * spread), p1 = at(near, near * spread), p2 = at(far, far * spread), p3 = at(far, -far * spread);
    final quad = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    canvas.save();
    canvas.clipRect(floor ? Rect.fromLTWH(0, horizon, w, h - horizon) : Rect.fromLTWH(0, 0, w, horizon));
    canvas.transform(m);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (img != null) {
      final sc = (floor ? 3 : 2) / img.width;
      paint.shader = ImageShader(img, TileMode.repeated, TileMode.repeated, (Matrix4.identity()..scale(sc, sc)).storage);
    } else {
      paint.color = floor ? const Color(0xFF1E2226) : const Color(0xFF15181B);
    }
    canvas.drawPath(quad, paint);
    canvas.drawPath(quad, Paint()..color = const Color(0x55000000));
    extra?.call(canvas);
    canvas.restore();
    // الضباب: كلّما اقترب الخطّ من الأفق كان أبعد وأظلم
    double yAt(double d) => horizon + (floor ? 1 : -1) * (h / 2) / d;
    final rect = floor ? Rect.fromLTWH(0, horizon, w, h - horizon) : Rect.fromLTWH(0, 0, w, horizon);
    double stop(double y) => ((y - rect.top) / rect.height).clamp(0.0, 1.0);
    final sF = stop(yAt(fogDist)), sH = stop(yAt(fogDist / 2)), sQ = stop(yAt(fogDist / 4.5));
    final stops = floor ? [0.0, sF, max(sF, sH), max(sH, sQ), 1.0] : [0.0, sQ, max(sQ, sH), max(sH, sF), 1.0];
    final colors = floor
        ? const [Color(0xFF050607), Color(0xF5050607), Color(0x99050607), Color(0x22050607), Color(0x00050607)]
        : const [Color(0x00050607), Color(0x33050607), Color(0xAA050607), Color(0xF5050607), Color(0xFF050607)];
    canvas.drawRect(rect, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors, stops: stops).createShader(rect));
  }

  /// مخروط ضوء على الأرض (بإحداثيات العالم داخل تحويل الأرضية).
  void _floorCone(Canvas c, Offset p, double angle, double half, double range, Color col) {
    final rect = Rect.fromCircle(center: p, radius: range);
    c.drawPath(
      Path()
        ..moveTo(p.dx, p.dy)
        ..arcTo(rect, angle - half, half * 2, false)
        ..close(),
      Paint()..shader = RadialGradient(colors: [col.withAlpha(120), col.withAlpha(0)]).createShader(rect),
    );
  }

  void _label(Canvas canvas, Offset at, String text, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, fontFamily: K.mono)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FpsPainter old) => old.map != map || old.vision != vision;
}
