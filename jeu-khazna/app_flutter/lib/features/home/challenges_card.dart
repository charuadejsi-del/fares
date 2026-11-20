// تحديات اليوم: 3 مهام تتجدّد كل يوم (توقيت الجزائر)، وكل تحدٍّ مكتمل يعطي دقائق.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/services.dart';
import '../../core/social.dart';
import '../../widgets/ui_kit.dart';

class ChallengesCard extends ConsumerStatefulWidget {
  const ChallengesCard({super.key});

  @override
  ConsumerState<ChallengesCard> createState() => _ChallengesCardState();
}

class _ChallengesCardState extends ConsumerState<ChallengesCard> {
  String? _claiming;

  Future<void> _claim(Challenge c) async {
    setState(() => _claiming = c.code);
    try {
      final bal = await SocialService.claim(c.code);
      authService.setBalance(bal);
      ref.read(audioProvider).fx(Sfx.vault, HapticKind.heavy);
      if (mounted) showToast(context, '🎉 +${c.rewardMinutes} دقائق');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _claiming = null);
      ref.invalidate(challengesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(challengesProvider).valueOrNull;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final done = list.where((c) => c.claimed).length;
    return GlassCard(
      accent: K.violet,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.task_alt_rounded, color: K.violet),
          const SizedBox(width: 8),
          const Expanded(child: Text('تحديات اليوم', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          Text('$done/${list.length}', style: const TextStyle(fontFamily: K.mono, color: K.violet)),
        ]),
        const SizedBox(height: 10),
        for (final c in list)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              Text(c.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: c.claimed ? TextDecoration.lineThrough : null,
                        color: c.claimed ? K.muted : K.text,
                      )),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (c.progress / c.target).clamp(0.0, 1.0).toDouble(),
                      minHeight: 5,
                      color: c.claimed ? K.muted : K.violet,
                      backgroundColor: K.border,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              if (c.claimed)
                const Icon(Icons.check_circle, color: K.neon, size: 22)
              else if (c.ready)
                SizedBox(
                  width: 92,
                  child: GlowButton(
                    label: '+${c.rewardMinutes} د',
                    icon: Icons.redeem,
                    height: 36,
                    color: K.violet,
                    busy: _claiming == c.code,
                    onTap: _claiming == null ? () => _claim(c) : null,
                  ),
                )
              else
                Text('${c.progress}/${c.target}', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
            ]),
          ),
      ]),
    );
  }
}
