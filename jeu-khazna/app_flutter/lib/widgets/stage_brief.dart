// بطاقة هوية المرحلة: القصّة، الأقفال (مع شارة «جديد»)، المؤثّرات، وطريقة فتح الخزنة الأخيرة.
import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/ext_locks.dart';
import '../core/game.dart';
import '../core/stages.dart';

class StageBrief extends StatelessWidget {
  final StageDef def;
  const StageBrief({super.key, required this.def});

  @override
  Widget build(BuildContext context) {
    final color = def.region.color;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (def.story.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withAlpha(16), border: Border(right: BorderSide(color: color, width: 3))),
          child: Text('📜 ${def.story}', style: const TextStyle(color: K.text2, fontSize: 13.5, height: 1.5)),
        ),
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (int i = 0; i < def.rooms.length; i++) _LockChip(id: def.rooms[i], isNew: def.rooms[i] == def.newLock, finale: i == def.rooms.length - 1 && def.rooms.length > 3),
      ]),
      if (def.mods.isNotEmpty) ...[
        const SizedBox(height: 10),
        for (final m in def.mods)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kModInfo[m]?.icon ?? '⚠️', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '${kModInfo[m]?.title ?? m}${m == def.newMod ? ' (جديد!)' : ''}: ',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: K.danger)),
                  TextSpan(text: kModInfo[m]?.desc ?? '', style: const TextStyle(color: K.text2)),
                ]), style: const TextStyle(fontSize: 12.5)),
              ),
            ]),
          ),
      ],
      if (def.newLock != null && kExtInfo[def.newLock] != null) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: K.amber.withAlpha(18), border: Border.all(color: K.amber.withAlpha(120))),
          child: Text('🆕 ${kExtInfo[def.newLock]!.title}: ${kExtInfo[def.newLock]!.how}',
              style: const TextStyle(color: K.amber, fontSize: 12.5, height: 1.45)),
        ),
      ],
    ]);
  }
}

class _LockChip extends StatelessWidget {
  final String id;
  final bool isNew;
  final bool finale;
  const _LockChip({required this.id, required this.isNew, required this.finale});

  @override
  Widget build(BuildContext context) {
    final emoji = K.roomEmoji(id);
    final c = isNew ? K.amber : (finale ? K.neon : K.line);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(border: Border.all(color: c), color: K.cell),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (emoji != null) Text(emoji, style: const TextStyle(fontSize: 14)) else Icon(K.roomIcons[id], size: 16, color: K.neonDim),
        const SizedBox(width: 5),
        Text(K.room(id), style: const TextStyle(fontSize: 12.5)),
        if (isNew) const Text(' • جديد', style: TextStyle(color: K.amber, fontSize: 11, fontWeight: FontWeight.w800)),
        if (finale) const Text(' • الخزنة', style: TextStyle(color: K.neon, fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

/// شرح سريع للقفل الحالي ومؤثّرات المرحلة (زرّ «؟» أثناء اللعب).
void showLockHelp(BuildContext context, GameState s) {
  final info = kExtInfo[s.roomId];
  final mods = stageMods(s.stage);
  showModalBottomSheet(
    context: context,
    backgroundColor: K.surface,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${info?.icon ?? '🔐'} ${K.room(s.roomId)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(info?.how ?? 'العميل يصف ما يراه، والمحلّل يقرأ الدليل ويُملي الحلّ.', style: const TextStyle(color: K.text2, height: 1.5)),
          if (mods.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('مؤثّرات هذه المرحلة', style: TextStyle(color: K.danger, fontWeight: FontWeight.w800)),
            for (final m in mods) Text('${kModInfo[m]?.icon} ${kModInfo[m]?.title}: ${kModInfo[m]?.desc}', style: const TextStyle(color: K.text2, height: 1.6)),
          ],
          if (mods.contains('limited'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('الأخطاء: ${s.errors} من $kLimitedTries', style: const TextStyle(color: K.amber, fontWeight: FontWeight.w800)),
            ),
        ]),
      ),
    ),
  );
}
