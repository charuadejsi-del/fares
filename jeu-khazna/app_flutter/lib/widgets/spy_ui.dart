// عناصر الواجهة المشتركة: خلفية العمليات، لوحات بزوايا، أزرار نيون، نص يُكتب، نص متشوّش.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/services.dart';

/// خلفية V3: صورة حقيقية (اختيارية) باهتة الألوان + تعتيم متدرّج. بلا شبكة ولا مسح متحرّك.
class SpyBackground extends StatelessWidget {
  final String? image;
  final double dim;
  final Widget child;
  const SpyBackground({super.key, this.image, this.dim = 0.72, required this.child});

  static const _desat = ColorFilter.matrix([.5, .4, .1, 0, 0, .4, .5, .1, 0, 0, .4, .4, .2, 0, 0, 0, 0, 0, 1, 0]);

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: K.bg),
      if (image != null)
        ColorFiltered(
          colorFilter: _desat,
          child: Image.asset(image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
        ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              K.bg.withAlpha((dim * 255 * 0.85).round()),
              K.bg.withAlpha((dim * 255).round()),
              K.bg.withAlpha(250),
            ],
          ),
        ),
      ),
      child,
    ]);
  }
}

/// لوحة V3: سطح مطفأ بحدّ رفيع وعنوان صغير بخط أحادي (بدل الزوايا المضيئة).
class HudPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final String? label;
  const HudPanel({super.key, required this.child, this.color = K.neon, this.padding = const EdgeInsets.all(16), this.label});

  @override
  Widget build(BuildContext context) {
    final accent = color != K.neon && color != K.muted;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: K.surface,
        borderRadius: BorderRadius.circular(K.radius),
        border: Border.all(color: accent ? color.withAlpha(110) : K.border),
      ),
      child: label == null
          ? child
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(label!, style: TextStyle(fontFamily: K.mono, color: accent ? color : K.muted, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 10),
              child,
            ]),
    );
  }
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
    final c = enabled ? widget.color : K.borderStrong;
    final fg = !enabled
        ? K.muted
        : widget.filled
            ? (c == K.neon || c == K.amber ? K.ink : Colors.white)
            : (c == K.muted ? K.text2 : K.text);
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
            color: widget.filled ? (enabled ? c : K.surface2) : (_down ? K.surface2 : Colors.transparent),
            border: Border.all(color: widget.filled ? Colors.transparent : (c == K.neon || c == K.muted ? K.borderStrong : c.withAlpha(150))),
            borderRadius: BorderRadius.circular(K.radius),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (widget.icon != null) ...[Icon(widget.icon, color: widget.filled ? fg : c, size: 20), const SizedBox(width: 10)],
            Flexible(
              child: Text(widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
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
      final glitch = _r.nextDouble() < 0.015;
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
          style: base.copyWith(color: K.text, letterSpacing: -.5)),
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
        color: Colors.transparent,
        border: Border.all(color: c.withAlpha(150)),
        borderRadius: BorderRadius.circular(4),
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
  const MonoLabel(this.text, {super.key, this.color = K.muted, this.size = 11});

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
