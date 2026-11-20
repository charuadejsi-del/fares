// مكوّنات الواجهة الجديدة: بطاقات زجاجية، أزرار متدرّجة بضغط، شارة الرصيد، شريط سفلي، خزنة متحرّكة.

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

/// بطاقة V3: سطح مطفأ بحدّ رفيع وزوايا شبه مستقيمة (accent يلوّن الحدّ فقط).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  final Gradient? gradient;
  const GlassCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.accent, this.radius = K.radius, this.gradient});

  @override
  Widget build(BuildContext context) {
    final r = radius > 12 ? K.radius : radius;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(r),
        color: gradient == null ? K.surface : null,
        gradient: gradient,
        border: Border.all(color: accent == null ? K.border : accent!.withAlpha(110)),
      ),
      child: child,
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
    final fg = outline ? K.text : (color == K.neon || color == K.amber ? K.ink : Colors.white);
    return Pressable(
      onTap: busy ? null : onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(K.radius),
          color: outline ? Colors.transparent : color,
          border: Border.all(color: outline ? K.borderStrong : Colors.transparent),
        ),
        child: busy
            ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, color: outline ? color : fg, size: 20), const SizedBox(width: 10)],
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w800)),
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
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withAlpha(110)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
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
            padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 5, 5),
            decoration: BoxDecoration(
              color: K.surface,
              borderRadius: BorderRadius.circular(K.radius),
              border: Border.all(color: low ? K.danger.withAlpha(140) : K.borderStrong),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, size: 17, color: low ? K.danger : K.text2),
              const SizedBox(width: 6),
              TweenAnimationBuilder<double>(
                tween: Tween(end: (m ?? 0).toDouble()),
                duration: const Duration(milliseconds: 700),
                builder: (context, v, _) => Text(m == null ? '—' : '${v.round()}',
                    style: TextStyle(fontFamily: K.mono, fontSize: 17, color: low ? K.danger : K.text, fontWeight: FontWeight.w700)),
              ),
              const Text(' د', style: TextStyle(color: K.muted, fontSize: 12)),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: c),
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
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: K.text2)),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Text(tag!, style: const TextStyle(fontFamily: K.mono, fontSize: 10, color: K.muted, letterSpacing: 1.4)),
          ],
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

/// صورة باب الخزنة الحقيقية (بدل الرسم الكرتوني) مع إضاءة خافتة تتنفّس ببطء.
class VaultHero extends StatefulWidget {
  final double size;
  final Color color;
  final bool open;
  const VaultHero({super.key, this.size = 150, this.color = K.neon, this.open = false});

  @override
  State<VaultHero> createState() => _VaultHeroState();
}

class _VaultHeroState extends State<VaultHero> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(K.radius),
          child: Stack(fit: StackFit.expand, children: [
            ColorFiltered(
              colorFilter: widget.open
                  ? const ColorFilter.matrix([1.15, .1, 0, 0, 10, .05, .95, 0, 0, 4, 0, 0, .55, 0, 0, 0, 0, 0, 1, 0])
                  : const ColorFilter.matrix([.45, .45, .1, 0, 0, .4, .5, .1, 0, 0, .4, .45, .15, 0, 0, 0, 0, 0, 1, 0]),
              child: Image.asset('assets/images/vault.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: K.surface)),
            ),
            AnimatedBuilder(
              animation: _t,
              builder: (context, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(colors: [
                    (widget.open ? K.neon : Colors.white).withAlpha((widget.open ? 70 : 14) + (18 * _t.value).round()),
                    Colors.transparent,
                  ], radius: .7),
                ),
              ),
            ),
          ]),
        ),
      );
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
        color: K.bg,
        border: Border(top: BorderSide(color: K.border)),
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
        duration: const Duration(milliseconds: 200),
        width: active ? 22 : 0,
        height: 2,
        color: K.neon,
      ),
      const SizedBox(height: 7),
      Icon(icon, color: c, size: 22),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: c, fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600)),
    ]);
  }
}

/// أحرف الاسم الأولى في مربّع فولاذي.
/// العربية: حرفان متّصلان (الألف وحدها كانت تُقرأ كأنها «i»).
class Avatar extends StatelessWidget {
  final String name;
  final double size;
  const Avatar(this.name, {super.key, this.size = 44});

  static String initials(String name) {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final chars = n.characters.toList();
    final first = chars.first;
    final arabic = RegExp(r'[\u0600-\u06FF]').hasMatch(first);
    if (arabic) return chars.where((c) => c.trim().isNotEmpty).take(2).join();
    return first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final t = initials(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(K.radius),
        color: K.surface2,
        border: Border.all(color: K.borderStrong),
      ),
      child: Text(t,
          maxLines: 1,
          style: TextStyle(color: K.steel, fontWeight: FontWeight.w800, fontSize: size * (t.characters.length > 1 ? .34 : .42))),
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
          borderRadius: BorderRadius.circular(K.radius), side: BorderSide(color: error ? K.danger.withAlpha(140) : K.borderStrong)),
      content: Row(children: [
        Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: error ? K.danger : K.ok),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontFamily: K.font, color: K.text, fontWeight: FontWeight.w700))),
      ]),
    ));
}
