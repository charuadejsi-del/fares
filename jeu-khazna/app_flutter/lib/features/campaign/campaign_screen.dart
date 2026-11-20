// خرائط الحملة: 3 خرائط × 20 مرحلة، ثم الخريطة الاحترافية (العاصمة) بلا نهاية.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/services.dart';
import '../../core/stages.dart';
import '../../core/team.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/spy_ui.dart';

bool stageUnlocked(StarSource p, int n) => n <= 1 || p.starsOf(n - 1) > 0;

int currentStage(StarSource p) {
  int n = 1;
  while (n < 100000 && stageUnlocked(p, n + 1)) {
    n++;
  }
  return n;
}

class CampaignScreen extends ConsumerStatefulWidget {
  /// داخل الشريط السفلي (بلا زر رجوع).
  final bool embedded;
  const CampaignScreen({super.key, this.embedded = false});

  @override
  ConsumerState<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends ConsumerState<CampaignScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    _pages = PageController(initialPage: pageOf(currentStage(ref.read(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty)));
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _open(int n) {
    ref.read(audioProvider).fx(Sfx.click, HapticKind.light);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StageSheet(n: n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(teamProgressProvider(null));
    final progress = async.valueOrNull ?? TeamProgress.empty;
    final current = currentStage(progress);
    final pageCount = max(pageOf(current) + 2, kRegions.length + 1);
    final content = Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(children: [
                if (!widget.embedded)
                  IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon))
                else
                  const SizedBox(width: 8),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الحملة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  MonoLabel('SOLO CAMPAIGN // هاتف واحد', size: 10),
                ]),
                const Spacer(),
                if (async.isLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.neon)),
                const SizedBox(width: 10),
                Pill(icon: Icons.star_rounded, text: '${progress.totalStars}', color: K.amber),
                const SizedBox(width: 8),
                const BalanceChip(),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: pageCount,
                itemBuilder: (context, page) => _MapPage(
                  page: page,
                  progress: progress,
                  current: current,
                  pulse: _pulse,
                  onOpen: _open,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Text('اسحب يميناً ويساراً للتنقّل بين الخرائط', style: TextStyle(color: K.muted, fontSize: 12)),
            ),
          ]);
    if (widget.embedded) return content;
    return Scaffold(body: SpyBackground(dim: 0.2, child: SafeArea(child: content)));
  }
}

class _MapPage extends StatelessWidget {
  final int page;
  final StarSource progress;
  final int current;
  final Animation<double> pulse;
  final void Function(int) onOpen;
  const _MapPage(
      {required this.page, required this.progress, required this.current, required this.pulse, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final first = page * kStagesPerMap + 1;
    final pro = first > kCampaignStages;
    final region = pro ? kProRegion : kRegions[page];
    final locked = !stageUnlocked(progress, first);
    final title = pro ? 'الخريطة الاحترافية ${page - kRegions.length + 1}' : 'الخريطة ${page + 1}: ${region.name}';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
        child: Row(children: [
          Icon(pro ? Icons.workspace_premium : Icons.map_outlined, color: region.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: TextStyle(color: region.color, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          MonoLabel('$first–${first + kStagesPerMap - 1}', color: K.muted),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
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
                  child: Image.asset(region.image,
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: K.panelSolid)),
                ),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: pulse,
                    builder: (context, _) => CustomPaint(painter: _RoutePainter(first, progress, pulse.value, region.color)),
                  ),
                ),
                for (int n = first; n < first + kStagesPerMap; n++)
                  Positioned(
                    left: stagePos(n).dx * w - 26,
                    top: stagePos(n).dy * h - 26,
                    child: _Marker(
                      def: stageDef(n),
                      stars: progress.starsOf(n),
                      unlocked: stageUnlocked(progress, n),
                      current: n == current,
                      color: region.color,
                      pulse: pulse,
                      onTap: () => onOpen(n),
                    ),
                  ),
                if (locked)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withAlpha(170),
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.lock, color: K.muted, size: 54),
                        const SizedBox(height: 10),
                        Text(pro ? 'أنهِ المراحل الستّين لفتح الخريطة الاحترافية' : 'أنهِ الخريطة السابقة لفتح هذه الخريطة',
                            textAlign: TextAlign.center, style: const TextStyle(color: K.text, fontSize: 16)),
                      ]),
                    ),
                  ),
              ]),
            ),
          );
        }),
      ),
    ]);
  }
}

class _RoutePainter extends CustomPainter {
  final int first;
  final StarSource progress;
  final double t;
  final Color color;
  _RoutePainter(this.first, this.progress, this.t, this.color);

  @override
  void paint(Canvas canvas, Size s) {
    for (int n = first; n < first + kStagesPerMap - 1; n++) {
      final a = Offset(stagePos(n).dx * s.width, stagePos(n).dy * s.height);
      final b = Offset(stagePos(n + 1).dx * s.width, stagePos(n + 1).dy * s.height);
      final done = progress.starsOf(n) > 0;
      final paint = Paint()
        ..color = done ? color.withAlpha(220) : Colors.white.withAlpha(45)
        ..strokeWidth = done ? 3 : 2;
      final d = b - a;
      final len = d.distance;
      if (len == 0) continue;
      final dir = d / len;
      const dash = 7.0, gap = 6.0;
      double x = done ? (t * (dash + gap)) % (dash + gap) : 0;
      while (x < len) {
        canvas.drawLine(a + dir * x, a + dir * min(x + dash, len), paint);
        x += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoutePainter old) => true;
}

class _Marker extends StatelessWidget {
  final StageDef def;
  final int stars;
  final bool unlocked;
  final bool current;
  final Color color;
  final Animation<double> pulse;
  final VoidCallback onTap;
  const _Marker(
      {required this.def,
      required this.stars,
      required this.unlocked,
      required this.current,
      required this.color,
      required this.pulse,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = !unlocked ? K.muted : (stars > 0 ? K.amber : color);
    final size = def.boss || def.milestone ? 44.0 : 34.0;
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: SizedBox(
        width: 52,
        height: 64,
        child: Column(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(alignment: Alignment.center, children: [
              if (current)
                AnimatedBuilder(
                  animation: pulse,
                  builder: (context, _) => Container(
                    width: 26 + 26 * pulse.value,
                    height: 26 + 26 * pulse.value,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withAlpha(((1 - pulse.value) * 255).round()), width: 2)),
                  ),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: def.boss ? BoxShape.rectangle : BoxShape.circle,
                  color: K.bg.withAlpha(235),
                  border: Border.all(color: c, width: def.boss ? 3 : 2.2),
                  boxShadow: unlocked ? K.glow(c, 12, 140) : null,
                ),
                child: Center(
                  child: !unlocked
                      ? const Icon(Icons.lock, size: 15, color: K.muted)
                      : def.milestone
                          ? const Icon(Icons.emoji_events, size: 22, color: K.amber)
                          : def.boss
                              ? Icon(Icons.dangerous, size: 22, color: c)
                              : Text('${def.n}', style: TextStyle(fontFamily: K.mono, color: c, fontSize: 14)),
                ),
              ),
            ]),
          ),
          if (unlocked && stars > 0)
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (int i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 11, color: i < stars ? K.amber : K.muted),
            ]),
        ]),
      ),
    );
  }
}

/// تفاصيل المرحلة مع اختيار طريقة اللعب.
class StageSheet extends ConsumerWidget {
  final int n;
  const StageSheet({super.key, required this.n});

  void _play(BuildContext context, WidgetRef ref, {required bool table}) {
    final d = stageDef(n);
    final name = ref.read(settingsProvider).name;
    final c = GameController.local(
      meName: name.isEmpty ? 'عميل' : name,
      rooms: d.rooms,
      diff: d.diff,
      table: table,
      missionId: n,
    );
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push('/play', extra: c);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = stageDef(n);
    final d = diffOf(def.diff);
    final stars = (ref.watch(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty).starsOf(n);
    final color = def.region.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SafeArea(
        top: false,
        child: HudPanel(
          color: color,
          label: def.milestone ? 'CONTEST STAGE $n' : (def.boss ? 'BOSS // STAGE $n' : 'STAGE $n'),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(def.name, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color))),
              for (int i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, color: i < stars ? K.amber : K.line),
            ]),
            if (def.milestone) ...[
              const SizedBox(height: 6),
              const Text('🏆 مرحلة مسابقة: تظهر في الترتيب العالمي.',
                  style: TextStyle(color: K.amber, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in def.rooms)
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
              Text(d.name, style: const TextStyle(color: K.amber, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Icon(Icons.timer_outlined, color: K.danger, size: 18),
              const SizedBox(width: 4),
              Text('${d.duration ~/ 60} د', style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 16),
            NeonButton(label: 'هاتف واحد', icon: Icons.smartphone, onTap: () => _play(context, ref, table: false)),
            const SizedBox(height: 10),
            NeonButton(
              label: 'وضع الطاولة (لاعبان معاً)',
              icon: Icons.table_restaurant_outlined,
              filled: false,
              color: K.agent,
              onTap: () => _play(context, ref, table: true),
            ),
            const SizedBox(height: 8),
            const Text('للعب أونلاين: أنشئ غرفة واختر هذه المرحلة من غرفة الانتظار.',
                textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}
