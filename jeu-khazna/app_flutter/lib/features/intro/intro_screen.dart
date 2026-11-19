// مقدّمة سينمائية: باب الخزنة يظهر، خطّ ماسح يمرّ عليه، ثم «تمّ الاتصال بالقاعدة».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3400));
  Timer? _done;
  bool _left = false;

  @override
  void initState() {
    super.initState();
    _a.forward();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) ref.read(audioProvider).play(Sfx.vault, volume: 0.7);
    });
    _done = Timer(const Duration(milliseconds: 3900), _go);
  }

  void _go() {
    if (_left || !mounted) return;
    _left = true;
    context.go('/home');
  }

  @override
  void dispose() {
    _done?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _go,
        child: SpyBackground(
          dim: 0.4,
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _a,
              builder: (context, _) {
                final t = _a.value;
                final appear = Curves.easeOutCubic.transform((t / 0.35).clamp(0.0, 1.0).toDouble());
                final scan = ((t - 0.25) / 0.4).clamp(0.0, 1.0).toDouble();
                final unlocked = t > 0.55;
                return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const MonoLabel('SECURE CHANNEL // HQ-07', size: 12),
                  const SizedBox(height: 26),
                  Opacity(
                    opacity: appear,
                    child: Transform.scale(
                      scale: 0.82 + 0.18 * appear,
                      child: SizedBox(
                        width: 270,
                        height: 270,
                        child: Stack(fit: StackFit.expand, children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: K.glow(unlocked ? K.neon : K.neonDim, unlocked ? 60 : 30, unlocked ? 140 : 70),
                            ),
                          ),
                          ClipOval(
                            child: Transform.rotate(
                              angle: unlocked ? (t - 0.55) * 1.2 : 0,
                              child: Image.asset('assets/images/vault.jpg',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.lock, size: 120, color: K.neon)),
                            ),
                          ),
                          if (scan > 0 && scan < 1)
                            Align(
                              alignment: Alignment(0, -1 + 2 * scan),
                              child: Container(height: 3, decoration: BoxDecoration(color: K.neon, boxShadow: K.glow(K.neon, 20, 220))),
                            ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 34),
                  Opacity(opacity: appear, child: const GlitchTitle('الخزنة', size: 54)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 26,
                    child: t > 0.35
                        ? TypewriterText(unlocked ? 'تمّ الاتصال بالقاعدة ✓' : 'جارٍ فكّ التشفير…',
                            key: ValueKey(unlocked),
                            style: const TextStyle(fontFamily: K.mono, color: K.neon, fontSize: 15),
                            sound: true)
                        : const SizedBox(),
                  ),
                  const SizedBox(height: 40),
                  const MonoLabel('اضغط للتخطّي', color: K.muted, size: 11),
                ]);
              },
            ),
          ),
        ),
      ),
    );
  }
}
