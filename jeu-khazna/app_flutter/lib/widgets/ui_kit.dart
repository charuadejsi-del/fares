// مكوّنات الواجهة الجديدة: بطاقات زجاجية، أزرار متدرّجة بضغط، شارة الرصيد، شريط سفلي، خزنة متحرّكة.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/auth.dart';
import '../core/services.dart';

/// التبويب المختار في الشريط السفلي (0 الرئيسية، 1 الحملة، 2 المتجر، 3 الملف).
final tabProvider = StateProvider<int>((ref) => 0);

/// يفتح المتجر من أي شاشة.
void openShop(BuildContext context, WidgetRef ref) {
  ref.read(tabProvider.notifier).state = 2;
  context.go('/home');
}

/// تصغير خفيف عند الضغط + اهتزاز + صوت.
class Pressable extends ConsumerStatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final bool sound;
  const Pressable({super.key, required this.child, this.onTap, this.sound = true});

  @override
  ConsumerState<Pressable> createState() => _PressableState();
}

class _PressableState extends ConsumerState<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              if (widget.sound) ref.read(audioProvider).fx(Sfx.click, HapticKind.light, volume: 0.5);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(opacity: enabled ? 1 : 0.45, duration: const Duration(milliseconds: 150), child: widget.child),
      ),
    );
  }
}

/// بطاقة زجاجية بحافة متدرّجة.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  final Gradient? gradient;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.accent, this.radius = 20, this.gradient});

  @override
  Widget build(BuildContext context) {
    final a = accent ?? K.neon;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [a.withAlpha(110), K.border, K.border, a.withAlpha(40)],
          stops: const [0, .35, .7, 1],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(120), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.all(1),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 1),
          gradient: gradient ??
              LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [K.surface2.withAlpha(245), K.surface.withAlpha(245)],
              ),
        ),
        child: child,
      ),
    );
  }
}

/// زر رئيسي متدرّج (أو محدّد).
class GlowButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color color;
  final bool outline;
  final double height;
  final bool busy;
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.color = K.neon,
    this.outline = false,
    this.height = 56,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = outline ? color : K.ink;
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: outline ? null : LinearGradient(colors: [color, Color.lerp(color, Colors.white, .18)!]),
          color: outline ? color.withAlpha(16) : null,
          border: Border.all(color: outline ? color.withAlpha(110) : Colors.transparent),
          boxShadow: outline ? null : [BoxShadow(color: color.withAlpha(90), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: busy
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, color: fg, size: 22), const SizedBox(width: 10)],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ]),
      ),
    );
  }
}

/// شارة صغيرة بأيقونة ونص.
class Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const Pill({super.key, required this.icon, required this.text, this.color = K.neon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      );
}

/// رصيد الوقت + زر الشراء. يظهر في أعلى كل الشاشات.
class BalanceChip extends ConsumerWidget {
  const BalanceChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final m = authService.profile?.balanceMinutes;
        final low = (m ?? 99) < 10;
        final c = low ? K.danger : K.neon;
        return Pressable(
          onTap: () => openShop(context, ref),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 5, 5, 5),
            decoration: BoxDecoration(
              color: c.withAlpha(20),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: c.withAlpha(90)),
              boxShadow: [BoxShadow(color: c.withAlpha(40), blurRadius: 14)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, size: 18, color: c),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(end: (m ?? 0).toDouble()),
                duration: const Duration(milliseconds: 700),
                builder: (context, v, _) => Text(m == null ? '—' : '${v.round()}',
                    style: TextStyle(fontFamily: K.mono, fontSize: 17, color: c, fontWeight: FontWeight.w700)),
              ),
              Text(' د', style: TextStyle(color: c.withAlpha(200), fontSize: 13)),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
                child: const Icon(Icons.add, size: 18, color: K.ink),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// عنوان قسم.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? tag;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.tag, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 10),
        child: Row(children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Text(tag!, style: const TextStyle(fontFamily: K.mono, fontSize: 10, color: K.muted, letterSpacing: 1.4)),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

/// خزنة متحرّكة (حلقات تدور + قرص + توهّج نابض).
class VaultHero extends StatefulWidget {
  final double size;
  final Color color;
  const VaultHero({super.key, this.size = 150, this.color = K.neon});

  @override
  State<VaultHero> createState() => _VaultHeroState();
}

class _VaultHeroState extends State<VaultHero> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) =>
              CustomPaint(size: Size.square(widget.size), painter: _VaultPainter(_t.value, widget.color)),
        ),
      );
}

class _VaultPainter extends CustomPainter {
  final double t;
  final Color c;
  _VaultPainter(this.t, this.c);

  @override
  void paint(Canvas canvas, Size s) {
    final o = s.center(Offset.zero);
    final r = s.width / 2;
    final pulse = 0.5 + 0.5 * sin(t * pi * 6);
    canvas.drawCircle(o, r * .95, Paint()..shader = RadialGradient(colors: [c.withAlpha((40 + 30 * pulse).round()), Colors.transparent]).createShader(Rect.fromCircle(center: o, radius: r)));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    // حلقة خارجية متقطّعة
    ring
      ..strokeWidth = 2
      ..color = c.withAlpha(120);
    for (int i = 0; i < 36; i++) {
      final a = t * 2 * pi + i * 2 * pi / 36;
      canvas.drawArc(Rect.fromCircle(center: o, radius: r * .92), a, .09, false, ring);
    }
    // حلقة وسطى عكسية
    ring
      ..strokeWidth = 5
      ..color = c.withAlpha(200);
    for (int i = 0; i < 3; i++) {
      canvas.drawArc(Rect.fromCircle(center: o, radius: r * .74), -t * 4 * pi + i * 2 * pi / 3, 1.3, false, ring);
    }
    // جسم القرص
    canvas.drawCircle(o, r * .58, Paint()..color = const Color(0xFF0A1414));
    canvas.drawCircle(o, r * .58, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = c.withAlpha(160));
    // تدريجات القرص
    final tick = Paint()
      ..color = c.withAlpha(170)
      ..strokeWidth = 2;
    for (int i = 0; i < 24; i++) {
      final a = t * 2 * pi * 2 + i * 2 * pi / 24;
      final l = i % 6 == 0 ? .12 : .06;
      canvas.drawLine(o + Offset(cos(a), sin(a)) * r * .52, o + Offset(cos(a), sin(a)) * r * (.52 - l), tick);
    }
    // مقبض
    final h = Paint()
      ..color = c
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final ha = t * 2 * pi * 2;
    for (int i = 0; i < 3; i++) {
      final a = ha + i * 2 * pi / 3;
      canvas.drawLine(o, o + Offset(cos(a), sin(a)) * r * .3, h);
    }
    canvas.drawCircle(o, r * .1, Paint()..color = c);
    canvas.drawCircle(o, r * .1 + 6 * pulse, Paint()
      ..style = PaintingStyle.stroke
      ..color = c.withAlpha((120 * (1 - pulse)).round()));
  }

  @override
  bool shouldRepaint(covariant _VaultPainter old) => old.t != t || old.c != c;
}

/// الشريط السفلي للتطبيق.
class AppNavBar extends ConsumerWidget {
  const AppNavBar({super.key});

  static const items = [
    (Icons.radar, 'المقرّ'),
    (Icons.map_outlined, 'الحملة'),
    (Icons.storefront_outlined, 'المتجر'),
    (Icons.badge_outlined, 'ملفّي'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF2070D0E),
        border: const Border(top: BorderSide(color: K.border)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(160), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: Pressable(
                  onTap: () => ref.read(tabProvider.notifier).state = i,
                  child: _NavItem(icon: items[i].$1, label: items[i].$2, active: tab == i),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _NavItem({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final c = active ? K.neon : K.muted;
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(horizontal: active ? 18 : 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? K.neon.withAlpha(28) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active ? [BoxShadow(color: K.neon.withAlpha(50), blurRadius: 14)] : null,
        ),
        child: Icon(icon, color: c, size: 24),
      ),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: c, fontSize: 11.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
    ]);
  }
}

/// حرف أوّل الاسم في مربّع متدرّج.
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});

  static const _hues = [Color(0xFF00FFA3), Color(0xFF22C7FF), Color(0xFFFFB547), Color(0xFF9D8CFF), Color(0xFFFF7AB6), Color(0xFF7DFF5A)];

  @override
  Widget build(BuildContext context) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final c = _hues[h % _hues.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: LinearGradient(colors: [c, c.withAlpha(150)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        boxShadow: [BoxShadow(color: c.withAlpha(80), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
          style: TextStyle(color: K.ink, fontWeight: FontWeight.w900, fontSize: size * .42)),
    );
  }
}

/// إشعار عائم موحّد.
void showToast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: K.surface2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14), side: BorderSide(color: (error ? K.danger : K.neon).withAlpha(120))),
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? K.danger : K.neon),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontFamily: K.font, color: K.text, fontWeight: FontWeight.w700))),
      ]),
    ));
}
