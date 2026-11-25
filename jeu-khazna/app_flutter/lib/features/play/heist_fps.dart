// وضع الخريطة 3D: العميل يرى المبنى بعينيه (منظور الشخص الأول) بتقنية «إلقاء الأشعّة» على شبكة الخريطة نفسها.
// المحلّل يبقى على المخطّط من الأعلى. كل شيء يُرسم بالكود: الجدران والأبواب والصناديق والأجهزة.
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/game.dart';
import '../../core/heist.dart';

/// خامات 3D مولّدة بالكود مرّة واحدة (64×64).
class FpsTextures {
  static final Map<String, ui.Image> _img = {};
  static bool _busy = false;
  static const int n = 64;

  static ui.Image? get(String k) => _img[k];

  /// خامة جدار المنطقة: الميناء خرسانة، النهر خشب، الجبل حجر.
  static ui.Image? wallFor(int stage) => get(stage <= 20 ? 'wall_port' : (stage <= 40 ? 'wall_river' : 'wall_mountain'));

  static Future<void> load() async {
    if (_busy || _img.isNotEmpty) return;
    _busy = true;
    final makers = <String, void Function(Canvas)>{
      'wall_port': _concrete,
      'wall_river': _planks,
      'wall_mountain': _stone,
      'door': _door,
      'crate': _crate,
      'term_on': (c) => _terminal(c, K.neon),
      'term_done': (c) => _terminal(c, K.ok),
      'term_off': (c) => _terminal(c, const Color(0xFF4A5057)),
      'vault': _vault,
      'exit': _exit,
    };
    for (final e in makers.entries) {
      try {
        final rec = ui.PictureRecorder();
        e.value(Canvas(rec));
        _img[e.key] = await rec.endRecording().toImage(n, n);
      } catch (_) {}
    }
    _busy = false;
  }

  static final _rnd = Random(7);
  static Paint _p(Color c) => Paint()..color = c;

  static void _noise(Canvas c, Color base, int amount, double spread) {
    for (int i = 0; i < amount; i++) {
      final v = (_rnd.nextDouble() - .5) * spread;
      final col = Color.lerp(base, v > 0 ? Colors.white : Colors.black, v.abs())!;
      c.drawRect(Rect.fromLTWH(_rnd.nextInt(n).toDouble(), _rnd.nextInt(n).toDouble(), 1 + _rnd.nextInt(2).toDouble(), 1), _p(col));
    }
  }

  static void _concrete(Canvas c) {
    const base = Color(0xFF4B535C);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    _noise(c, base, 900, .35);
    // ألواح بفواصل وبراغي
    final seam = _p(const Color(0xFF2C3238));
    c.drawRect(const Rect.fromLTWH(0, 31, 64, 2), seam);
    c.drawRect(const Rect.fromLTWH(31, 0, 2, 64), seam);
    for (final o in const [Offset(5, 5), Offset(58, 5), Offset(5, 26), Offset(58, 26), Offset(5, 38), Offset(58, 38), Offset(5, 58), Offset(58, 58)]) {
      c.drawCircle(o, 1.6, _p(const Color(0xFF8A939C)));
    }
    // خطّ تحذير سفلي
    for (int x = 0; x < 64; x += 8) {
      c.drawRect(Rect.fromLTWH(x.toDouble(), 58, 4, 6), _p(const Color(0xFF8C6D1F)));
    }
  }

  static void _planks(Canvas c) {
    for (int i = 0; i < 4; i++) {
      final base = Color.lerp(const Color(0xFF5A3E26), const Color(0xFF7A5634), _rnd.nextDouble())!;
      c.drawRect(Rect.fromLTWH(0, i * 16.0, 64, 16), _p(base));
      _noise(c, base, 120, .3);
      for (int k = 0; k < 3; k++) {
        final y = i * 16.0 + 3 + _rnd.nextInt(10);
        c.drawRect(Rect.fromLTWH(0, y, 64, 1), _p(Color.lerp(base, Colors.black, .22)!));
      }
      c.drawRect(Rect.fromLTWH(0, i * 16.0 + 15, 64, 1), _p(const Color(0xFF2A1C10)));
      c.drawCircle(Offset(6, i * 16.0 + 8), 1.3, _p(const Color(0xFF2A1C10)));
      c.drawCircle(Offset(58, i * 16.0 + 8), 1.3, _p(const Color(0xFF2A1C10)));
    }
  }

  static void _stone(Canvas c) {
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(const Color(0xFF26292C)));
    for (int row = 0; row < 4; row++) {
      final off = row.isOdd ? -10.0 : 0.0;
      for (int col = 0; col < 3; col++) {
        final base = Color.lerp(const Color(0xFF5E6266), const Color(0xFF7A7D80), _rnd.nextDouble())!;
        final r = Rect.fromLTWH(off + col * 26.0 + 1, row * 16.0 + 1, 24, 14);
        c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)), _p(base));
        c.drawRect(Rect.fromLTWH(r.left + 2, r.top + 1, r.width - 4, 2), _p(Color.lerp(base, Colors.white, .15)!));
      }
    }
    _noise(c, const Color(0xFF6A6D70), 500, .4);
  }

  static void _door(Canvas c) {
    const base = Color(0xFF5B636B);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    _noise(c, base, 400, .25);
    for (int y = 6; y < 64; y += 12) {
      c.drawRect(Rect.fromLTWH(0, y.toDouble(), 64, 3), _p(const Color(0xFF3A4046)));
      c.drawRect(Rect.fromLTWH(0, y + 3.0, 64, 1), _p(const Color(0xFF7E878F)));
    }
    c.drawRect(const Rect.fromLTWH(0, 0, 3, 64), _p(const Color(0xFF2A2F34)));
    c.drawRect(const Rect.fromLTWH(61, 0, 3, 64), _p(const Color(0xFF2A2F34)));
  }

  static void _crate(Canvas c) {
    const base = Color(0xFF7B5A34);
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), _p(base));
    _noise(c, base, 300, .3);
    final dark = Paint()
      ..color = const Color(0xFF4A3218)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    c.drawRect(const Rect.fromLTWH(3, 3, 58, 58), dark);
    c.drawLine(const Offset(6, 6), const Offset(58, 58), dark);
    c.drawLine(const Offset(58, 6), const Offset(6, 58), dark);
  }

  static void _terminal(Canvas c, Color screen) {
    // خزانة معدنية واقفة بشاشة مضيئة (خلفية شفّافة)
    final body = RRect.fromRectAndRadius(const Rect.fromLTWH(14, 6, 36, 58), const Radius.circular(4));
    c.drawRRect(body, _p(const Color(0xFF2A2F35)));
    c.drawRRect(body.deflate(2), _p(const Color(0xFF3A4048)));
    c.drawRect(const Rect.fromLTWH(18, 12, 28, 20), _p(const Color(0xFF0B0E10)));
    c.drawRect(const Rect.fromLTWH(20, 14, 24, 16), _p(screen.withAlpha(200)));
    for (double y = 15; y < 30; y += 3) {
      c.drawRect(Rect.fromLTWH(20, y, 24, 1), _p(Colors.black.withAlpha(60)));
    }
    for (int i = 0; i < 6; i++) {
      c.drawRect(Rect.fromLTWH(19 + (i % 3) * 9.0, 38 + (i ~/ 3) * 7.0, 7, 5), _p(const Color(0xFF6B737B)));
    }
    c.drawCircle(const Offset(44, 56), 2, _p(screen));
  }

  static void _vault(Canvas c) {
    c.drawRect(const Rect.fromLTWH(6, 4, 52, 60), _p(const Color(0xFF30353B)));
    c.drawCircle(const Offset(32, 34), 22, _p(const Color(0xFF7E878F)));
    c.drawCircle(const Offset(32, 34), 18, _p(const Color(0xFF4A5057)));
    final spoke = Paint()
      ..color = const Color(0xFFB9C0C6)
      ..strokeWidth = 3;
    for (int i = 0; i < 6; i++) {
      final a = i * pi / 3;
      c.drawLine(const Offset(32, 34), Offset(32 + cos(a) * 15, 34 + sin(a) * 15), spoke);
    }
    c.drawCircle(const Offset(32, 34), 5, _p(const Color(0xFFE8A13A)));
  }

  static void _exit(Canvas c) {
    final g = Paint()
      ..shader = const RadialGradient(colors: [Color(0xEE3DD68C), Color(0x003DD68C)]).createShader(const Rect.fromLTWH(0, 0, 64, 64));
    c.drawRect(const Rect.fromLTWH(0, 0, 64, 64), g);
    c.drawRect(const Rect.fromLTWH(24, 4, 16, 60), _p(const Color(0xCC3DD68C)));
  }
}

/// كائن مسطّح يواجه الكاميرا دائماً (جهاز، خزنة، مخرج...).
class _Sprite {
  final Offset pos;
  final ui.Image img;
  final double height; // نسبة من ارتفاع الجدار
  final bool glow;
  const _Sprite(this.pos, this.img, this.height, {this.glow = false});
}

/// رسّام المنظور الأول.
class FpsPainter extends CustomPainter {
  final HeistMap map;
  final GameState Function() state;
  final double Function() time;
  final Offset Function() agent;
  final double Function() facing;
  final double Function() alert;
  final double vision;

  FpsPainter({
    required this.map,
    required Listenable repaint,
    required this.state,
    required this.time,
    required this.agent,
    required this.facing,
    required this.alert,
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
    // الضباب: مدى الرؤية في 3D أوسع قليلاً من الدائرة في 2D، ويضيق في الظلام
    final fogDist = (power ? min(vision, 1.9) : vision) * 1.8;

    // السقف والأرضية
    final tint = s.stage <= 20 ? const Color(0xFF1E2A33) : (s.stage <= 40 ? const Color(0xFF2B2318) : const Color(0xFF26282B));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizon),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14171B), Color(0xFF050607)])
          .createShader(Rect.fromLTWH(0, 0, w, horizon)),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, w, h - horizon),
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF050607), tint])
          .createShader(Rect.fromLTWH(0, horizon, w, h - horizon)),
    );

    // الأعمدة
    final cols = min(260, max(80, (w / 3).round()));
    final colW = w / cols;
    if (_z.length != cols) _z = Float64List(cols);
    final dirX = cos(ang), dirY = sin(ang);
    final planeX = -dirY * fov, planeY = dirX * fov;
    final wallImg = FpsTextures.wallFor(s.stage);
    final doorImg = FpsTextures.get('door');
    final crateImg = FpsTextures.get('crate');
    final texN = FpsTextures.n.toDouble();

    for (int x = 0; x < cols; x++) {
      final camX = 2 * (x + .5) / cols - 1;
      final rx = dirX + planeX * camX, ry = dirY + planeY * camX;
      var mx = pos.dx.floor(), my = pos.dy.floor();
      final ddx = rx == 0 ? 1e30 : (1 / rx).abs(), ddy = ry == 0 ? 1e30 : (1 / ry).abs();
      final stepX = rx < 0 ? -1 : 1, stepY = ry < 0 ? -1 : 1;
      var sdx = rx < 0 ? (pos.dx - mx) * ddx : (mx + 1 - pos.dx) * ddx;
      var sdy = ry < 0 ? (pos.dy - my) * ddy : (my + 1 - pos.dy) * ddy;
      var side = 0;
      var kind = -1; // 0 جدار · 1 صندوق · 2 باب
      var door = -1;
      for (int i = 0; i < 80; i++) {
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
      final fog = (dist / fogDist).clamp(0.0, 1.0);
      final shade = (pow(fog, 1.25) * 245 + (side == 1 ? 35 : 0)).clamp(0, 250).round();
      final dst = Rect.fromLTWH(x * colW, top, colW + .6, lineH);
      if (img != null) {
        final tx = (wallX * texN).clamp(0, texN - 1).floorToDouble();
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(tx, 0, 1, texN),
          dst,
          Paint()
            ..filterQuality = FilterQuality.none
            ..colorFilter = ColorFilter.mode(Color.fromARGB(shade, 0, 0, 0), BlendMode.srcATop),
        );
      } else {
        canvas.drawRect(dst, Paint()..color = Color.lerp(const Color(0xFF4A5057), Colors.black, shade / 255)!);
      }
      // لون حالة الباب: التالي (أخضر مضيء)، مقفل (أحمر)، أُغلق أثناء الهروب (أحمر مخطّط)
      if (kind == 2) {
        final closedNow = shut.contains(door);
        final next = map.doors[door].after == solved && !closedNow;
        final col = next ? K.neon : K.danger;
        final glow = ((1 - fog) * 200).round().clamp(40, 200);
        canvas.drawRect(Rect.fromLTWH(dst.left, top + lineH * .46, dst.width, lineH * .06), Paint()..color = col.withAlpha(glow));
        if (closedNow && ((wallX * 6).floor()).isEven) {
          canvas.drawRect(Rect.fromLTWH(dst.left, top, dst.width, lineH), Paint()..color = K.danger.withAlpha((glow * .35).round()));
        }
      }
    }

    // الكائنات: الأجهزة والخزنة والمخرج
    final sprites = <_Sprite>[];
    for (int i = 0; i < map.rooms.length; i++) {
      final vault = i == map.rooms.length - 1;
      final img = vault
          ? FpsTextures.get('vault')
          : FpsTextures.get(i < solved ? 'term_done' : (i == solved ? 'term_on' : 'term_off'));
      if (img != null) sprites.add(_Sprite(map.rooms[i].terminal, img, vault ? .9 : .75, glow: i == solved));
    }
    if (escaping && FpsTextures.get('exit') != null) sprites.add(_Sprite(map.spawn, FpsTextures.get('exit')!, 1, glow: true));
    sprites.sort((a, b) => (b.pos - pos).distanceSquared.compareTo((a.pos - pos).distanceSquared));
    final invDet = 1 / (planeX * dirY - dirX * planeY);
    for (final sp in sprites) {
      final rel = sp.pos - pos;
      final tX = invDet * (dirY * rel.dx - dirX * rel.dy);
      final depth = invDet * (-planeY * rel.dx + planeX * rel.dy);
      if (depth < .15) continue;
      final screenX = (cols / 2) * (1 + tX / depth);
      final fullH = h / depth;
      final sh = fullH * sp.height;
      final sw = sh; // الصور مربّعة
      final bottom = horizon + fullH / 2;
      final c0 = (screenX - sw / colW / 2).floor(), c1 = (screenX + sw / colW / 2).ceil();
      final fog = (depth / fogDist).clamp(0.0, 1.0);
      final shade = sp.glow ? (pow(fog, 1.25) * 140).round() : (pow(fog, 1.25) * 245).round();
      final paint = Paint()
        ..filterQuality = FilterQuality.none
        ..colorFilter = ColorFilter.mode(Color.fromARGB(shade.clamp(0, 250).toInt(), 0, 0, 0), BlendMode.srcATop);
      final texN2 = sp.img.width.toDouble();
      for (int x = max(0, c0); x < min(cols, c1); x++) {
        if (depth >= _z[x]) continue;
        final u = ((x - (screenX - sw / colW / 2)) / (sw / colW)).clamp(0.0, .999);
        canvas.drawImageRect(
          sp.img,
          Rect.fromLTWH((u * texN2).floorToDouble(), 0, 1, sp.img.height.toDouble()),
          Rect.fromLTWH(x * colW, bottom - sh, colW + .6, sh),
          paint,
        );
      }
    }

    // علامة الهدف (فوق الجهاز التالي أو المخرج) حتى لو كان بعيداً في الظلام
    final goal = escaping ? map.spawn : (solved < map.rooms.length ? map.rooms[solved].terminal : null);
    if (goal != null) {
      final rel = goal - pos;
      final depth = invDet * (-planeY * rel.dx + planeX * rel.dy);
      final tX = invDet * (dirY * rel.dx - dirX * rel.dy);
      final pulse = .5 + .5 * sin(DateTime.now().millisecondsSinceEpoch / 260);
      final col = escaping ? K.ok : K.neon;
      if (depth > .2 && (tX / depth).abs() < 1.1) {
        final sx = (w / 2) * (1 + tX / depth);
        final y = horizon - h / depth * .5 - 18;
        final dm = Path()
          ..moveTo(sx, y - 9)
          ..lineTo(sx + 7, y)
          ..lineTo(sx, y + 9)
          ..lineTo(sx - 7, y)
          ..close();
        canvas.drawPath(dm, Paint()..color = col.withAlpha((150 + 100 * pulse).round()));
        _label(canvas, Offset(sx, y + 20), '${rel.distance.round()}m', col, 12);
      } else {
        // خارج مجال الرؤية: سهم على حافّة الشاشة باتجاه الهدف
        var diff = atan2(rel.dy, rel.dx) - ang;
        while (diff > pi) {
          diff -= 2 * pi;
        }
        while (diff < -pi) {
          diff += 2 * pi;
        }
        final right = diff > 0;
        final x = right ? w - 26 : 26.0;
        final p = Path()
          ..moveTo(x + (right ? 12 : -12), horizon)
          ..lineTo(x, horizon - 12)
          ..lineTo(x, horizon + 12)
          ..close();
        canvas.drawPath(p, Paint()..color = col.withAlpha((120 + 120 * pulse).round()));
      }
    }

    // إطار المصباح: ظلام على الحوافّ
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(radius: .9, colors: [Color(0x00000000), Color(0xB0000000)], stops: [.55, 1])
            .createShader(Offset.zero & size),
    );
    // تحذير: يراك أحد
    final al = alert();
    if (al > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(radius: .8, colors: [const Color(0x00000000), K.danger.withAlpha((90 + 240 * al).clamp(0, 200).round())], stops: const [.5, 1])
              .createShader(Offset.zero & size),
      );
    }
    // الإنذار أثناء الهروب
    if (escaping) {
      final k = .5 + .5 * sin(DateTime.now().millisecondsSinceEpoch / 180);
      canvas.drawRect(Offset.zero & size, Paint()..color = K.danger.withAlpha((15 + 45 * k).round()));
    }
    // علامة التصويب
    final cross = Paint()
      ..color = Colors.white.withAlpha(110)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w / 2 - 6, horizon), Offset(w / 2 + 6, horizon), cross);
    canvas.drawLine(Offset(w / 2, horizon - 6), Offset(w / 2, horizon + 6), cross);
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
