// الترتيب العالمي: أعلى مرحلة ثم العملات.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  late Future<List<LeaderEntry>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final notifier = ref.read(progressProvider.notifier);
    final p = ref.read(progressProvider);
    final name = ref.read(settingsProvider).name;
    final lb = ref.read(leaderboardProvider);
    _future = lb
        .submit(id: notifier.playerId, name: name.isEmpty ? 'عميل' : name, bestStage: p.bestStage, coins: p.coins)
        .then((_) => lb.top());
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(progressProvider.notifier).playerId;
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const MonoLabel('GLOBAL RANKING // الترتيب'),
                const Spacer(),
                IconButton(
                    onPressed: () => setState(_load), icon: const Icon(Icons.refresh, color: K.neon)),
              ]),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: HudPanel(
                label: 'CONTESTS // المسابقات',
                color: K.amber,
                padding: EdgeInsets.all(12),
                child: Text(
                  'المسابقات والجوائز يعلن عنها فريق «الخزنة». الترتيب هنا حسب أعلى مرحلة ثم العملات، '
                  'ويُتحقَّق من الفائزين قبل تسليم أي جائزة.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: FutureBuilder<List<LeaderEntry>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator(color: K.neon));
                  }
                  if (snap.hasError) {
                    return const Center(
                        child: Text('تعذّر تحميل الترتيب. تحقّق من الإنترنت.', style: TextStyle(color: K.muted)));
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Center(child: Text('لا أحد في الترتيب بعد. كن الأوّل!', style: TextStyle(color: K.muted)));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final e = list[i];
                      final me = e.id == myId;
                      final medal = i == 0 ? K.amber : (i == 1 ? const Color(0xFFC0C8C4) : (i == 2 ? const Color(0xFFCD7F32) : K.muted));
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: me ? K.neon.withAlpha(25) : K.panel,
                          border: Border.all(color: me ? K.neon : K.line),
                        ),
                        child: Row(children: [
                          SizedBox(
                            width: 34,
                            child: i < 3
                                ? Icon(Icons.emoji_events, color: medal)
                                : MonoLabel('${i + 1}', color: K.muted, size: 15),
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e.name}${me ? ' (أنت)' : ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                              MonoLabel('ID ${e.id.substring(0, 6)}', color: K.muted, size: 10),
                            ]),
                          ),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('مرحلة ${e.bestStage}', style: const TextStyle(color: K.neon, fontWeight: FontWeight.w800)),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.monetization_on, size: 14, color: K.amber),
                              const SizedBox(width: 3),
                              Text('${e.coins}', style: const TextStyle(fontFamily: K.mono, color: K.amber)),
                            ]),
                          ]),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
