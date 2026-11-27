import 'package:flutter/material.dart';

import '../core/nesting/nesting_engine.dart';

/// Aperçu du film : chaque image est un rectangle coloré à sa place.
class NestPreview extends StatelessWidget {
  final NestResult result;
  final Map<String, Color> colors;
  final Map<String, String> labels;

  const NestPreview(
      {super.key,
      required this.result,
      required this.colors,
      required this.labels});

  @override
  Widget build(BuildContext context) {
    if (result.placements.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final scale = c.maxWidth / result.filmWidthCm;
      final h = (result.lengthCm * scale).clamp(40.0, 2000.0);
      return Directionality(
        // le film se lit de gauche à droite comme dans Photoshop
        textDirection: TextDirection.ltr,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade400)),
          child: CustomPaint(
            size: Size(c.maxWidth, h),
            painter: _FilmPainter(result, scale, colors, labels),
          ),
        ),
      );
    });
  }
}

class _FilmPainter extends CustomPainter {
  final NestResult r;
  final double scale;
  final Map<String, Color> colors;
  final Map<String, String> labels;
  _FilmPainter(this.r, this.scale, this.colors, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black54;
    for (final p in r.placements) {
      final rect = Rect.fromLTWH(
          p.x * scale, p.y * scale, p.width * scale, p.height * scale);
      canvas.drawRect(
          rect, Paint()..color = (colors[p.itemId] ?? Colors.teal).withValues(alpha: .55));
      canvas.drawRect(rect, border);
      if (rect.width > 22 && rect.height > 14) {
        final tp = TextPainter(
          text: TextSpan(
              text: labels[p.itemId] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: rect.width);
        tp.paint(canvas,
            rect.center - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FilmPainter old) => old.r != r;
}
