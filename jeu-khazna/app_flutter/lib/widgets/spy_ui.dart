// عناصر الواجهة المشتركة: خلفية العمليات، لوحات بزوايا، أزرار نيون، نص يُكتب، نص متشوّش.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/services.dart';

/// خلفية: صورة (اختيارية) + تعتيم + شبكة + خطوط مسح متحرّكة.
class SpyBackground extends StatefulWidget {
  final String? image;
  final double dim;
  final Widget child;
  const SpyBackground({super.key, this.image, this.dim = 0.72, required this.child});

  @override
  State<SpyBackground> createState() => _SpyBackgroundState();
}

class _SpyBackgroundState extends State<SpyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: K.bg),
      if (widget.image != null)
        Image.asset(widget.image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              K.bg.withAlpha((widget.dim * 255 * 0.85).round()),
              K.bg.withAlpha((widget.dim * 255).round()),
              K.bg.withAlpha(250),
            ],
          ),
        ),
      ),
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _scan,
          builder: (context, _) => CustomPaint(painter: _GridPainter(_scan.value)),
        ),
      ),
      widget.child,
    ]);
  }
}

class _GridPainter extends CustomPainter {
  final double t;
  _GridPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = K.neon.withAlpha(10)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final lines = Paint()..color = Colors.black.withAlpha(40);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), lines);
    }
    final y = t * (size.height + 160) - 80;
    final band = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, K.neon.withAlpha(18), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, y - 80, size.width, 160));
    canvas.drawRect(Rect.fromLTWH(0, y - 80, size.width, 160), band);
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.t != t;
}

/// لوحة بزوايا مضيئة (طابع شاشات العمليات).
class HudPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final String? label;
  const HudPanel({super.key, required this.child, this.color = K.neon, this.padding = const EdgeInsets.all(16), this.label});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornersPainter(color),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(1),
        padding: padding,
        decoration: BoxDecoration(
          color: K.panel,
          border: Border.all(color: color.withAlpha(45)),
        ),
        child: label == null
            ? child
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(width: 6, height: 6, color: color),
                  const SizedBox(width: 8),
                  Text(label!, style: TextStyle(fontFamily: K.mono, color: color, fontSize: 12, letterSpacing: 2)),
                ]),
                const SizedBox(height: 10),
                child,
              ]),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  final Color color;
  _CornersPainter(this.color);

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const l = 14.0;
    final path = Path()
      ..moveTo(0, l)
      ..lineTo(0, 0)
      ..lineTo(l, 0)
      ..moveTo(s.width - l, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, l)
      ..moveTo(s.width, s.height - l)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width - l, s.height)
      ..moveTo(l, s.height)
      ..lineTo(0, s.height)
      ..lineTo(0, s.height - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant _CornersPainter old) => old.color != color;
}

/// زرّ نيون كبير مع صوت واهتزاز.
class NeonButton extends ConsumerStatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool filled;
  final double height;
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = K.neon,
    this.filled = true,
    this.height = 56,
  });

  @override
  ConsumerState<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends ConsumerState<NeonButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final c = enabled ? widget.color : K.muted;
    final fg = widget.filled ? const Color(0xFF00170D) : c;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.6);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.filled ? c.withAlpha(enabled ? 255 : 60) : c.withAlpha(_down ? 40 : 14),
            border: Border.all(color: c, width: 1.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: enabled ? K.glow(c, _down ? 26 : 14, widget.filled ? 120 : 60) : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[Icon(widget.icon, color: fg, size: 22), const SizedBox(width: 10)],
            Flexible(
              child: Text(widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// نص يظهر حرفاً حرفاً مثل شاشة طرفية.
class TypewriterText extends ConsumerStatefulWidget {
  final String text;
  final TextStyle style;
  final Duration perChar;
  final bool sound;
  final TextAlign align;
  const TypewriterText(this.text,
      {super.key,
      required this.style,
      this.perChar = const Duration(milliseconds: 35),
      this.sound = false,
      this.align = TextAlign.start});

  @override
  ConsumerState<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends ConsumerState<TypewriterText> {
  int _n = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(widget.perChar, (t) {
      if (!mounted) return;
      if (_n >= widget.text.length) {
        t.cancel();
        return;
      }
      setState(() => _n++);
      if (widget.sound && _n % 2 == 0) ref.read(audioProvider).play(Sfx.type, volume: 0.35);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _n >= widget.text.length;
    return Text('${widget.text.substring(0, _n)}${done ? '' : '▌'}', style: widget.style, textAlign: widget.align);
  }
}

/// عنوان نيون يتشوّش لحظياً بين حين وآخر.
class GlitchTitle extends StatefulWidget {
  final String text;
  final double size;
  const GlitchTitle(this.text, {super.key, this.size = 56});

  @override
  State<GlitchTitle> createState() => _GlitchTitleState();
}

class _GlitchTitleState extends State<GlitchTitle> {
  final _r = Random();
  Timer? _t;
  double _dx = 0;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      final glitch = _r.nextDouble() < 0.07;
      setState(() => _dx = glitch ? (_r.nextDouble() * 6 - 3) : 0);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: widget.size, fontWeight: FontWeight.w900, height: 1.1);
    return Stack(alignment: Alignment.center, children: [
      if (_dx != 0)
        Transform.translate(
            offset: Offset(_dx * 2, 0),
            child: Text(widget.text, style: base.copyWith(color: K.danger.withAlpha(160)))),
      if (_dx != 0)
        Transform.translate(
            offset: Offset(-_dx * 2, 0), child: Text(widget.text, style: base.copyWith(color: K.agent.withAlpha(160)))),
      Text(widget.text,
          style: base.copyWith(color: K.neon, shadows: [Shadow(color: K.neon.withAlpha(180), blurRadius: 24)])),
    ]);
  }
}

/// شارة الدور.
class RoleBadge extends StatelessWidget {
  final String? role;
  final bool big;
  const RoleBadge(this.role, {super.key, this.big = false});

  @override
  Widget build(BuildContext context) {
    final c = K.role(role);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 14 : 10, vertical: big ? 7 : 4),
      decoration: BoxDecoration(
        color: c.withAlpha(30),
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(K.roleIcon(role), color: c, size: big ? 20 : 16),
        const SizedBox(width: 6),
        Text(K.roleName(role), style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: big ? 15 : 13)),
      ]),
    );
  }
}

/// سطر صغير بخط أحادي المسافة.
class MonoLabel extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const MonoLabel(this.text, {super.key, this.color = K.neonDim, this.size = 12});

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(fontFamily: K.mono, color: color, fontSize: size, letterSpacing: 2));
}

/// نافذة تأكيد بطابع اللعبة.
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String body, required String confirm, Color color = K.danger}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: HudPanel(
        color: color,
        label: 'CONFIRM',
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: K.muted, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: NeonButton(
                    label: 'إلغاء', filled: false, color: K.muted, height: 48, onTap: () => Navigator.of(ctx).pop(false))),
            const SizedBox(width: 10),
            Expanded(child: NeonButton(label: confirm, color: color, height: 48, onTap: () => Navigator.of(ctx).pop(true))),
          ]),
        ]),
      ),
    ),
  );
  return ok == true;
}
