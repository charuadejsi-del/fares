// الترتيب العالمي للفرق: أعلى مرحلة ثم مجموع النجوم (من الخادم).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/team.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';

final leaderboardRowsProvider = FutureProvider.autoDispose<List<LeaderRow>>((ref) => TeamService.leaderboard());

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(leaderboardRowsProvider);
    final me = authService.profile?.nickname;
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الترتيب العالمي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  MonoLabel('TOP TEAMS // أقوى الفرق', size: 10),
                ]),
                const Spacer(),
                IconButton(onPressed: () => ref.invalidate(leaderboardRowsProvider), icon: const Icon(Icons.refresh, color: K.muted)),
              ]),
            ),
            Expanded(
              child: rows.when(
                loading: () => const Center(child: CircularProgressIndicator(color: K.neon)),
                error: (e, _) => Center(
                  child: TextButton(
                    onPressed: () => ref.invalidate(leaderboardRowsProvider),
                    child: const Text('تعذّر التحميل — إعادة المحاولة', style: TextStyle(color: K.danger)),
                  ),
                ),
                data: (list) => list.isEmpty
                    ? const Center(child: Text('لا توجد فرق بعد — كن الأوّل!', style: TextStyle(color: K.muted)))
                    : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
                        if (list.isNotEmpty) _Podium(list.take(3).toList()),
                        const SizedBox(height: 16),
                        for (int i = 3; i < list.length; i++)
                          _Row(rank: i + 1, row: list[i], mine: me != null && (list[i].nameA == me || list[i].nameB == me)),
                        const SizedBox(height: 10),
                        const Text('الترتيب حسب أعلى مرحلة ثم مجموع النجوم. لا جوائز مالية.',
                            textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
                      ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderRow> top;
  const _Podium(this.top);

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFFFFC94D), Color(0xFFC9D6DF), Color(0xFFE29A5C)];
    Widget place(int i, double h) {
      if (i >= top.length) return const Expanded(child: SizedBox());
      final r = top[i];
      return Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(i == 0 ? Icons.emoji_events : Icons.military_tech, color: colors[i], size: i == 0 ? 40 : 30),
          const SizedBox(height: 6),
          Text(r.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 6),
          Container(
            height: h,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors[i].withAlpha(90), colors[i].withAlpha(15)]),
              border: Border.all(color: colors[i].withAlpha(120)),
            ),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${i + 1}', style: TextStyle(fontFamily: K.mono, fontSize: 26, color: colors[i])),
              Text('مرحلة ${r.bestStage}', style: const TextStyle(fontSize: 11.5, color: K.text2)),
            ]),
          ),
        ]),
      );
    }

    return SizedBox(
      height: 220,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        place(1, 90),
        const SizedBox(width: 8),
        place(0, 120),
        const SizedBox(width: 8),
        place(2, 70),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderRow row;
  final bool mine;
  const _Row({required this.rank, required this.row, required this.mine});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassCard(
          accent: mine ? K.neon : K.border,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            SizedBox(width: 34, child: Text('$rank', style: const TextStyle(fontFamily: K.mono, color: K.muted, fontSize: 16))),
            Avatar(row.nameA, size: 34),
            const SizedBox(width: 10),
            Expanded(child: Text(row.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
            Pill(icon: Icons.flag, text: '${row.bestStage}', color: K.neon),
            const SizedBox(width: 6),
            Pill(icon: Icons.star_rounded, text: '${row.stars}', color: K.amber),
          ]),
        ),
      );
}
