// إطارات الأقفال الواقعية:
// - TerminalFrame: القفل داخل شاشة جهاز معدني (براغٍ، زجاج، خطوط مسح) — شاشة العميل.
// - DossierFrame: ملف ورقي سرّي (مشبك، ختم) — شاشة المحلّل.
// - steelGrad: تدرّج فولاذي للأزرار والخانات.
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// تدرّج معدني بارز من لون أساسي (فاتح أعلى، داكن أسفل).
Gradient steelGrad(Color c) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color.lerp(c, Colors.white, .14)!, c, Color.lerp(c, Colors.black, .38)!],
      stops: const [0, .45, 1],
    );

/// ظلّ زرّ بارز.
const List<BoxShadow> kRaised = [
  BoxShadow(color: Color(0xCC000000), offset: Offset(0, 3), blurRadius: 3),
  BoxShadow(color: Color(0x14FFFFFF), offset: Offset(0, -1), blurRadius: 0),
];

/// قاعدة الخانات: معدن داكن.
const Color kSteel = Color(0xFF23272C);

/// القفل داخل شاشة جهاز.
class TerminalFrame extends StatelessWidget {
  final Widget child;
  final String title;
  final bool solvedFlash;
  const TerminalFrame({super.key, required this.child, required this.title, this.solvedFlash = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B6168), Color(0xFF2E3237), Color(0xFF1C1F23), Color(0xFF3A3F45)],
          stops: [0, .35, .7, 1],
        ),
        border: Border.all(color: const Color(0xFF6E757C), width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // شريط الجهاز: مصباح + الاسم
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: solvedFlash ? K.ok : K.neon,
                  boxShadow: [BoxShadow(color: (solvedFlash ? K.ok : K.neon).withAlpha(160), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('TERMINAL · $title',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: K.mono, fontSize: 10.5, color: Color(0xFFB9BEC4), letterSpacing: 1.5)),
              ),
              const Text('▮▮▮', style: TextStyle(fontSize: 8, color: Color(0xFF8E949A), letterSpacing: 2)),
            ]),
          ),
          // الشاشة
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF07090A),
              border: Border.all(color: const Color(0xFF0B0C0E), width: 3),
              boxShadow: const [BoxShadow(color: Color(0xFF000000), blurRadius: 6, spreadRadius: -2)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(children: [
                // توهّج كهرماني خافت من داخل الشاشة
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(radius: 1.2, colors: [Color(0x1AE8A13A), Color(0x00000000)]),
                    ),
                  ),
                ),
                Padding(padding: const EdgeInsets.all(12), child: child),
                // خطوط المسح + انعكاس الزجاج (لا تلتقط اللمس)
                const Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ScanlinePainter()))),
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: const Alignment(.2, .2),
                          colors: [Colors.white.withAlpha(16), Colors.white.withAlpha(0)],
                        ),
                      ),
                    ),
                  ),
                ),
                if (solvedFlash)
                  Positioned.fill(child: IgnorePointer(child: ColoredBox(color: K.ok.withAlpha(60)))),
              ]),
            ),
          ),
        ]),
        // البراغي في الزوايا
        for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
          Positioned.fill(
            child: IgnorePointer(
              child: Align(
                alignment: a,
                child: Transform.translate(
                  offset: Offset(a.x * 3, a.y * 3),
                  child: const _Screw(),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Screw extends StatelessWidget {
  const _Screw();

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Color(0xFFC9CED3), Color(0xFF5B6168)]),
        ),
        child: Center(child: Container(width: 6, height: 1.2, color: const Color(0xFF2E3237))),
      );
}

class _ScanlinePainter extends CustomPainter {
  const _ScanlinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0x0DFFFFFF);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ملف سرّي من ورق مقوّى: لسان علوي، مشبك، ختم «سرّي».
class DossierFrame extends StatelessWidget {
  final Widget child;
  final String title;
  final int seed;
  const DossierFrame({super.key, required this.child, required this.title, this.seed = 0});

  static const manila = Color(0xFFC8B07E), manilaDark = Color(0xFF9C8457), ink = Color(0xFF3A2E1C);

  @override
  Widget build(BuildContext context) {
    final r = Random(seed);
    return Stack(clipBehavior: Clip.none, children: [
      Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD3BC8A), manila, Color(0xFFB59B69)],
            ),
            border: Border.all(color: manilaDark),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 12, offset: Offset(0, 6))],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF101214),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: const Color(0xFF6B5A3A)),
            ),
            padding: const EdgeInsets.all(10),
            child: child,
          ),
        ),
      ),
      // اللسان
      Positioned(
        top: 0,
        right: 18,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          decoration: const BoxDecoration(
            color: manila,
            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
            border: Border(
              top: BorderSide(color: manilaDark),
              left: BorderSide(color: manilaDark),
              right: BorderSide(color: manilaDark),
            ),
          ),
          child: Text('ملفّ سرّي · $title',
              style: const TextStyle(fontFamily: K.mono, color: ink, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .5)),
        ),
      ),
      // الختم
      Positioned(
        top: 22,
        left: 22,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: -.18 + r.nextDouble() * .1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(border: Border.all(color: const Color(0xB3A3262A), width: 2), borderRadius: BorderRadius.circular(3)),
              child: const Text('TOP SECRET',
                  style: TextStyle(fontFamily: K.mono, color: Color(0xB3A3262A), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
          ),
        ),
      ),
      // المشبك
      const Positioned(
        top: 8,
        left: 120,
        child: IgnorePointer(child: Icon(Icons.attach_file, color: Color(0xFFB9BEC4), size: 30)),
      ),
    ]);
  }
}
