import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';
import '../play/play_screen.dart' show fmtTime;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: ref.read(settingsProvider).name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final rate = p.played == 0 ? 0 : (p.won * 100 / p.played).round();
    final toNext = p.nextRankAt - p.stars;
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
              const Spacer(),
              const MonoLabel('AGENT DOSSIER // الملف'),
            ]),
            const SizedBox(height: 10),
            HudPanel(
              label: 'IDENTITY',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _name,
                  maxLength: 20,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: fieldDecoration('الاسم الحركي', icon: Icons.badge_outlined),
                  onChanged: (v) => ref.read(settingsProvider.notifier).setName(v),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.military_tech, color: K.amber, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.rank, style: const TextStyle(color: K.amber, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text(toNext > 0 ? 'باقي $toNext نجمة للرتبة التالية' : 'أعلى رتبة!',
                          style: const TextStyle(color: K.muted, fontSize: 12.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.nextRankAt == 0 ? 1 : (p.stars / p.nextRankAt).clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    color: K.amber,
                    backgroundColor: K.line,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            HudPanel(
              label: 'SERVICE RECORD',
              color: K.agent,
              child: Column(children: [
                _Line(Icons.flag_outlined, 'المهمّات', '${p.played}'),
                _Line(Icons.lock_open, 'الخزائن المفتوحة', '${p.won}'),
                _Line(Icons.percent, 'نسبة النجاح', '$rate%'),
                _Line(Icons.star_rounded, 'النجوم', '${p.stars}'),
                _Line(Icons.flag, 'أعلى مرحلة', '${p.bestStage}'),
                _Line(Icons.monetization_on, 'العملات', '${p.coins}'),
                _Line(Icons.fingerprint, 'معرّف اللاعب', ref.read(progressProvider.notifier).playerId.substring(0, 6)),
                _Line(Icons.timer_outlined, 'أفضل وقت', p.bestTime == 0 ? '—' : fmtTime(p.bestTime.toDouble())),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String k;
  final String v;
  const _Line(this.icon, this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: K.agent, size: 20),
          const SizedBox(width: 10),
          Text(k, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(v, style: const TextStyle(fontFamily: K.mono, fontSize: 18, color: K.text)),
        ]),
      );
}
