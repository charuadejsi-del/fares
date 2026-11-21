// ملخّص الجلسة عند الخروج من الغرفة: المهمّات، الانتصارات، النجوم، أفضل وقت، الخبرة.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../app/theme.dart';
import 'spy_ui.dart';

String _t(int sec) => '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

Future<void> showSessionSummary(
  BuildContext context, {
  required int games,
  required int wins,
  required int stars,
  required int xp,
  required int? best,
  required List<int> stages,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: K.bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: K.borderStrong)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const MonoLabel('DEBRIEF · ملخّص الجلسة', color: K.neon, size: 11),
          const SizedBox(height: 6),
          Text(wins > 0 ? 'عمل ممتاز الليلة.' : 'جلسة تدريب.', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Row(children: [
            _Stat(label: 'مهمّات', value: '$games'),
            _Stat(label: 'انتصارات', value: '$wins'),
            _Stat(label: 'نجوم', value: '$stars ★', color: K.neon),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _Stat(label: 'أفضل وقت', value: best == null ? '—' : _t(best)),
            _Stat(label: 'الخبرة', value: '+$xp XP', color: K.ok),
          ]),
          if (stages.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
                stages.length == 1
                    ? 'المرحلة المكتملة: ${stages.first}'
                    : 'المراحل المكتملة: ${stages.first} ← ${stages.last} (${stages.length})',
                style: const TextStyle(color: K.text2, fontSize: 13)),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Share.share(
                  'جلستي في «الخزنة»: $wins انتصارات، $stars نجمة${best == null ? '' : '، أفضل وقت ${_t(best)}'}'
                  '${stages.isEmpty ? '' : '، وصلنا إلى المرحلة ${stages.last}'}. هل تستطيعون أفضل؟ #الخزنة',
                ),
                icon: const Icon(Icons.ios_share, size: 18),
                label: const Text('مشاركة'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: K.text,
                  side: const BorderSide(color: K.borderStrong),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: K.neon,
                  foregroundColor: K.ink,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                ),
                child: const Text('خروج', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat({required this.label, required this.value, this.color = K.text});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: K.surface,
            borderRadius: BorderRadius.circular(K.radius),
            border: Border.all(color: K.border),
          ),
          child: Column(children: [
            Text(value, style: TextStyle(fontFamily: K.mono, fontSize: 17, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: K.muted, fontSize: 11.5)),
          ]),
        ),
      );
}
