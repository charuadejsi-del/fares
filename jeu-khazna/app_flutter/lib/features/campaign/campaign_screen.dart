// خريطة الحملة: 9 مهمّات تُفتح واحدة بعد الأخرى.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';
import 'missions.dart';

class CampaignScreen extends ConsumerStatefulWidget {
  const CampaignScreen({super.key});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _open(Mission m) {
    ref.read(audioProvider).fx(Sfx.click, HapticKind.light);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => MissionSheet(mission: m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final current = kMissions.lastWhere((m) => progress.unlocked(m.id), orElse: () => kMissions.first).id;
    return Scaffold(
      body: SpyBackground(
        dim: 0.2,
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const MonoLabel('CAMPAIGN // الحملة'),
                const Spacer(),
                const Icon(Icons.star_rounded, color: K.amber, size: 20),
                const SizedBox(width: 4),
                Text('${progress.campaignStars}/${kMissions.length * 3}',
                    style: const TextStyle(fontFamily: K.mono, color: K.amber, fontSize: 16)),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, box) {
                // نحافظ على نسبة الخريطة (768×1376) داخل المساحة المتاحة
                const ratio = 768 / 1376;
                var w = box.maxWidth, h = box.maxWidth / ratio;
                if (h > box.maxHeight) {
                  h = box.maxHeight;
                  w = h * ratio;
                }
                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(
                        child: Image.asset('assets/images/map.jpg',
                            fit: BoxFit.fill, errorBuilder: (_, __, ___) => const ColoredBox(color: K.panelSolid)),
                      ),
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, _) => CustomPaint(painter: _RoutePainter(progress, _pulse.value)),
                        ),
                      ),
                      for (final m in kMissions)
                        Positioned(
                          left: m.pos.dx * w - 30,
                          top: m.pos.dy * h - 30,
                          child: _Marker(
                            mission: m,
                            stars: progress.starsOf(m.id),
                            unlocked: progress.unlocked(m.id),
                            current: m.id == current,
                            pulse: _pulse,
                            onTap: () => _open(m),
                          ),
                        ),
                    ]),
                  ),
                );
              }),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final Progress progress;
  final double t;
  _RoutePainter(this.progress, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    for (int i = 0; i < kMissions.length - 1; i++) {
      final a = Offset(kMissions[i].pos.dx * s.width, kMissions[i].pos.dy * s.height);
      final b = Offset(kMissions[i + 1].pos.dx * s.width, kMissions[i + 1].pos.dy * s.height);
      final done = progress.starsOf(kMissions[i].id) > 0;
      final paint = Paint()
        ..color = done ? K.amber.withAlpha(200) : K.text.withAlpha(50)
        ..strokeWidth = done ? 3 : 2;
      // خطّ متقطّع متحرّك
      final d = b - a;
      final len = d.distance;
      final dir = d / len;
      const dash = 8.0, gap = 7.0;
      double x = done ? (t * (dash + gap)) % (dash + gap) : 0;
      while (x < len) {
        final p1 = a + dir * x;
        final p2 = a + dir * min(x + dash, len);
        canvas.drawLine(p1, p2, paint);
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => true;
}

class _Marker extends StatelessWidget {
  final Mission mission;
  final int stars;
  final bool unlocked;
  final bool current;
  final Animation<double> pulse;
  final VoidCallback onTap;
  const _Marker(
      {required this.mission,
      required this.stars,
      required this.unlocked,
      required this.current,
      required this.pulse,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = !unlocked ? K.muted : (stars > 0 ? K.amber : K.neon);
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: SizedBox(
        width: 60,
        height: 74,
        child: Column(children: [
          SizedBox(
            width: 60,
            height: 60,
            child: Stack(alignment: Alignment.center, children: [
              if (current)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Container(
                    width: 30 + 30 * pulse.value,
                    height: 30 + 30 * pulse.value,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: K.neon.withAlpha(((1 - pulse.value) * 255).round()), width: 2)),
                  ),
                ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: K.bg.withAlpha(230),
                  border: Border.all(color: color, width: 2.5),
                  boxShadow: unlocked ? K.glow(color, 14, 140) : null,
                ),
                child: Center(
                  child: unlocked
                      ? Text('${mission.id}', style: TextStyle(fontFamily: K.mono, color: color, fontSize: 18))
                      : const Icon(Icons.lock, size: 18, color: K.muted),
                ),
              ),
            ]),
          ),
          if (unlocked)
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 13, color: i < stars ? K.amber : K.muted),
            ]),
        ]),
      ),
    );
  }
}

/// ورقة تفاصيل المهمّة مع اختيار طريقة اللعب.
class MissionSheet extends ConsumerWidget {
  final Mission mission;
  const MissionSheet({super.key, required this.mission});

  void _play(BuildContext context, WidgetRef ref, {required bool table}) {
    final name = ref.read(settingsProvider).name;
    final c = GameController.local(
      meName: name.isEmpty ? 'عميل' : name,
      rooms: mission.rooms,
      diff: mission.diff,
      table: table,
      missionId: mission.id,
    );
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/play', extra: c);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = diffOf(mission.diff);
    final stars = ref.watch(progressProvider).starsOf(mission.id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SafeArea(
        top: false,
        child: HudPanel(
          label: 'MISSION 0${mission.id}',
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Text(mission.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: K.neon)),
              ),
              for (int i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i < stars ? K.amber : K.line),
            ]),
            const SizedBox(height: 8),
            Text(mission.story, style: const TextStyle(fontSize: 15, height: 1.6)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in mission.rooms)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: K.line), color: K.cell),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(K.roomIcons[r], size: 16, color: K.neonDim),
                    const SizedBox(width: 6),
                    Text(K.roomNames[r] ?? r, style: const TextStyle(fontSize: 13)),
                  ]),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.shield_outlined, color: K.amber, size: 18),
              const SizedBox(width: 6),
              Text('الصعوبة: ${d.name}', style: const TextStyle(color: K.amber, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: K.danger, size: 18),
              const SizedBox(width: 6),
              Text('${d.duration ~/ 60} د · خطأ −${d.penalty} ث',
                  style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            NeonButton(label: 'هاتف واحد (تبديل الأدوار)', icon: Icons.smartphone, onTap: () => _play(context, ref, table: false)),
            const SizedBox(height: 10),
            NeonButton(
              label: 'وضع الطاولة (لاعبان معاً)',
              icon: Icons.table_restaurant_outlined,
              filled: false,
              color: K.agent,
              onTap: () => _play(context, ref, table: true),
            ),
          ]),
        ),
      ),
    );
  }
}
