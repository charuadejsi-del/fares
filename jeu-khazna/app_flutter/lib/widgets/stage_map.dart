// خريطة المراحل داخل الغرفة: كل الخرائط ظاهرة، والمقفل عليه 🔒 حتى يفوز الفريق بما قبله.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme.dart';
import '../core/services.dart';
import '../core/stages.dart';
import '../core/team.dart';
import 'spy_ui.dart';
import 'ui_kit.dart';

Future<int?> showStageMap(BuildContext context, {required TeamProgress progress, required int selected, required bool canPick}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StageMapSheet(progress: progress, selected: selected, canPick: canPick),
  );
}

class _StageMapSheet extends StatefulWidget {
  final TeamProgress progress;
  final int selected;
  final bool canPick;
  const _StageMapSheet({required this.progress, required this.selected, required this.canPick});

  @override
  State<_StageMapSheet> createState() => _StageMapSheetState();
}

class _StageMapSheetState extends State<_StageMapSheet> with SingleTickerProviderStateMixin {
  late final int _pages = max(kRegions.length + 1, pageOf(widget.progress.current) + 1);
  late final TabController _tabs =
      TabController(length: _pages, vsync: this, initialIndex: min(pageOf(widget.progress.current), _pages - 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Region _region(int page) => page < kRegions.length ? kRegions[page] : kProRegion;

  @override
  Widget build(BuildContext context) {
    final p = widget.progress;
    return Container(
      height: MediaQuery.of(context).size.height * .86,
      decoration: const BoxDecoration(
        color: Color(0xFF0A1112),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: K.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: K.borderStrong, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
            child: Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('خريطة الفريق', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                MonoLabel('TEAM PROGRESS // تقدّمكما معاً', size: 10),
              ]),
              const Spacer(),
              Pill(icon: Icons.flag, text: '${p.top}', color: K.neon),
              const SizedBox(width: 6),
              Pill(icon: Icons.star_rounded, text: '${p.totalStars}', color: K.amber),
            ]),
          ),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: K.border,
            indicatorColor: K.neon,
            labelColor: K.text,
            unselectedLabelColor: K.muted,
            labelStyle: const TextStyle(fontFamily: K.font, fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              for (int i = 0; i < _pages; i++)
                Tab(
                  child: Row(children: [
                    Icon(i < kRegions.length ? Icons.map_outlined : Icons.workspace_premium, size: 16, color: _region(i).color),
                    const SizedBox(width: 6),
                    Text(i < kRegions.length ? _region(i).name : 'احترافية ${i - kRegions.length + 1}'),
                  ]),
                ),
            ],
          ),
          if (widget.canPick)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Pressable(
                onTap: () => Navigator.of(context).pop(0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.selected == 0 ? K.neon : K.border),
                    color: K.surface,
                  ),
                  child: const Row(children: [
                    Icon(Icons.bolt, color: K.agent),
                    SizedBox(width: 10),
                    Expanded(child: Text('مهمّة كلاسيكية سريعة (خارج الخريطة)', style: TextStyle(fontWeight: FontWeight.w700))),
                    Icon(Icons.chevron_left, color: K.muted),
                  ]),
                ),
              ),
            ),
          Expanded(
            child: TabBarView(controller: _tabs, children: [
              for (int page = 0; page < _pages; page++)
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .92),
                  itemCount: kStagesPerMap,
                  itemBuilder: (context, i) {
                    final n = page * kStagesPerMap + i + 1;
                    return _StageNode(
                      n: n,
                      stars: p.starsOf(n),
                      unlocked: p.unlocked(n),
                      current: n == p.current,
                      selected: n == widget.selected,
                      onTap: widget.canPick && p.unlocked(n) ? () => Navigator.of(context).pop(n) : null,
                    );
                  },
                ),
            ]),
          ),
          if (!widget.canPick)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('قائد الفريق هو من يختار المرحلة', style: TextStyle(color: K.muted)),
            ),
        ]),
      ),
    );
  }
}

class _StageNode extends StatelessWidget {
  final int n;
  final int stars;
  final bool unlocked;
  final bool current;
  final bool selected;
  final VoidCallback? onTap;
  const _StageNode({required this.n, required this.stars, required this.unlocked, required this.current, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    final def = stageDef(n);
    final c = !unlocked ? K.muted : def.region.color;
    final done = stars > 0;
    return Pressable(
      onTap: onTap,
      sound: unlocked,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: unlocked ? c.withAlpha(done ? 26 : 14) : K.surface,
          border: Border.all(color: selected ? K.text : (current ? c : (unlocked ? c.withAlpha(90) : K.border)), width: selected || current ? 2 : 1),
          boxShadow: current ? [BoxShadow(color: c.withAlpha(90), blurRadius: 16)] : null,
        ),
        child: Stack(children: [
          if (def.boss)
            const Positioned(top: 5, left: 6, child: Icon(Icons.local_fire_department, size: 14, color: K.danger)),
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              unlocked
                  ? Text('$n', style: TextStyle(fontFamily: K.mono, fontSize: 22, color: c, height: 1))
                  : const Icon(Icons.lock_rounded, color: K.muted, size: 22),
              const SizedBox(height: 6),
              if (unlocked)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  for (int i = 0; i < 3; i++) Icon(Icons.star_rounded, size: 12, color: i < stars ? K.amber : K.border),
                ])
              else
                Text('$n', style: const TextStyle(fontFamily: K.mono, fontSize: 11, color: K.muted)),
            ]),
          ),
          if (current)
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Text('التالية', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: c, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    );
  }
}

/// شريط «فُتحت مرحلة جديدة» بقفل يُفتح + صوت.
class UnlockBanner extends ConsumerStatefulWidget {
  final int stage;
  const UnlockBanner({super.key, required this.stage});

  @override
  ConsumerState<UnlockBanner> createState() => _UnlockBannerState();
}

class _UnlockBannerState extends ConsumerState<UnlockBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _a.forward();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) ref.read(audioProvider).fx(Sfx.light, HapticKind.medium);
      });
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = stageDef(widget.stage);
    final c = def.region.color;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = Curves.easeOutBack.transform(_a.value.clamp(0.0, 1.0));
        final open = _a.value > .45;
        return Opacity(
          opacity: _a.value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: .85 + .15 * t,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: c.withAlpha(24),
                border: Border.all(color: c.withAlpha(150)),
                boxShadow: [BoxShadow(color: c.withAlpha((90 * _a.value).round()), blurRadius: 26)],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Transform.rotate(
                  angle: open ? -.35 : 0,
                  child: Icon(open ? Icons.lock_open_rounded : Icons.lock_rounded, color: c, size: 30),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('فُتحت المرحلة ${widget.stage}', style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(def.name, style: const TextStyle(color: K.text2, fontSize: 13)),
                ]),
              ]),
            ),
          ),
        );
      },
    );
  }
}
