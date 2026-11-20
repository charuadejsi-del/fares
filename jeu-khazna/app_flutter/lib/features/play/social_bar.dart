// أدوات المهمّة الاجتماعية: الرسائل السريعة، فقاعات المحادثة، وبطاقة الشريك (صداقة، إبلاغ، حظر).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/bot.dart';
import '../../core/controller.dart';
import '../../core/services.dart';
import '../../core/social.dart';
import '../../widgets/ui_kit.dart';
import '../friends/friends_screen.dart' show showReportSheet;

/// شريط الرسائل السريعة.
class QuickBar extends ConsumerWidget {
  final GameController c;
  const QuickBar({super.key, required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            for (final e in kQuickMessages.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: ActionChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  backgroundColor: K.surface2,
                  side: const BorderSide(color: K.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
                    c.sendQuick(e.key);
                  },
                ),
              ),
          ],
        ),
      );
}

/// فقاعات المحادثة الأخيرة. مع العميل الآلي يبقى آخر توجيهَين ظاهرَين.
class ChatStrip extends StatefulWidget {
  final GameController c;
  const ChatStrip({super.key, required this.c});

  @override
  State<ChatStrip> createState() => _ChatStripState();
}

class _ChatStripState extends State<ChatStrip> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final now = DateTime.now().millisecondsSinceEpoch;
    final lines = c.bot
        ? c.chat.reversed.take(3).toList().reversed.toList()
        : c.chat.where((l) => now - l.at < 9000).toList().reversed.take(3).toList().reversed.toList();
    if (lines.isEmpty) {
      if (!c.bot) return const SizedBox.shrink();
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: K.violet)),
          SizedBox(width: 8),
          Text('$kBotName يفتح الدليل…', style: TextStyle(color: K.violet, fontSize: 12.5)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(children: [
        for (final l in lines)
          Align(
            alignment: l.mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('${l.at}-${l.text}'),
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 260),
              builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)),
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(maxWidth: 330),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: (l.mine ? K.agent : (l.bot ? K.violet : K.analyst)).withAlpha(30),
                  border: Border.all(color: (l.mine ? K.agent : (l.bot ? K.violet : K.analyst)).withAlpha(130)),
                ),
                child: Text(
                  l.mine ? l.text : '${l.bot ? kBotName : (c.partnerName ?? 'الشريك')}: ${l.text}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// بطاقة الشريك: الاسم + قائمة (إضافة صديق، إبلاغ، حظر).
class PartnerChip extends StatelessWidget {
  final GameController c;
  const PartnerChip({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final name = c.partnerName;
    if (c.bot) return const Pill(icon: Icons.smart_toy_outlined, text: kBotName, color: K.violet);
    if (name == null || c.partnerAccount == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showPartnerMenu(context, c),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: K.surface2,
          border: Border.all(color: K.borderStrong),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Avatar(name, size: 24),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 90),
            child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 4),
          ConnBars(q: c.connQuality),
          const Icon(Icons.expand_more, size: 16, color: K.muted),
        ]),
      ),
    );
  }
}

Future<void> showPartnerMenu(BuildContext context, GameController c) async {
  final uid = c.partnerAccount, name = c.partnerName ?? 'الشريك';
  if (uid == null) return;
  final a = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: K.surface,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Avatar(name, size: 36), title: Text(name, style: const TextStyle(fontWeight: FontWeight.w900))),
        ListTile(
            leading: const Icon(Icons.person_add_alt_1, color: K.neon),
            title: const Text('أضفه صديقاً'),
            onTap: () => Navigator.pop(ctx, 'friend')),
        ListTile(
            leading: const Icon(Icons.flag_outlined, color: K.danger),
            title: const Text('إبلاغ'),
            onTap: () => Navigator.pop(ctx, 'report')),
        ListTile(
            leading: const Icon(Icons.block, color: K.danger),
            title: const Text('حظر (لن يُطابَق معك ثانية)'),
            onTap: () => Navigator.pop(ctx, 'block')),
      ]),
    ),
  );
  if (a == null || !context.mounted) return;
  try {
    if (a == 'friend') {
      final r = await SocialService.request(name);
      if (context.mounted) showToast(context, r == 'accepted' ? '🤝 أصبحتما صديقين' : 'أُرسل طلب الصداقة');
    } else if (a == 'report') {
      await showReportSheet(context, uid, name);
    } else if (a == 'block') {
      await SocialService.block(uid);
      if (context.mounted) showToast(context, 'حُظر $name');
    }
  } catch (e) {
    if (context.mounted) showToast(context, authErrorText(e), error: true);
  }
}


/// مؤشّر جودة اتصال الشريك (أعمدة).
class ConnBars extends StatelessWidget {
  final String q;
  const ConnBars({super.key, required this.q});

  @override
  Widget build(BuildContext context) {
    final (n, color, tip) = switch (q) {
      'good' => (3, K.neon, 'اتصال ممتاز'),
      'ok' => (2, K.amber, 'اتصال متوسّط'),
      'bad' => (1, K.danger, 'اتصال ضعيف'),
      'lost' => (0, K.danger, 'انقطع اتصال الشريك'),
      _ => (0, K.muted, 'يقيس الاتصال…'),
    };
    return Tooltip(
      message: tip,
      child: SizedBox(
        width: 16,
        height: 14,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.only(right: 1.5),
              width: 3.5,
              height: 5.0 + i * 4,
              color: i < n ? color : K.line,
            ),
        ]),
      ),
    );
  }
}

/// تقييم الشريك بعد المهمّة 👍👎.
class RatePartner extends StatefulWidget {
  final GameController c;
  const RatePartner({super.key, required this.c});

  @override
  State<RatePartner> createState() => _RatePartnerState();
}

class _RatePartnerState extends State<RatePartner> {
  bool? _done;

  Future<void> _rate(bool good) async {
    final uid = widget.c.partnerAccount, sid = widget.c.sessionId;
    if (uid == null || sid == null) return;
    setState(() => _done = good);
    try {
      await SeasonService.rate(uid, sid, good);
    } catch (e) {
      if (mounted) {
        setState(() => _done = null);
        showToast(context, authErrorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.c.partnerName ?? 'شريكك';
    if (_done != null) {
      return Text(_done! ? '👍 شكراً! تقييمك يساعد على مطابقة أفضل.' : '👎 سُجّل تقييمك. يمكنك أيضاً الإبلاغ أو الحظر.',
          textAlign: TextAlign.center, style: const TextStyle(color: K.muted));
    }
    return Column(children: [
      Text('كيف كان $name كشريك؟', style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        OutlinedButton(onPressed: () => _rate(true), child: const Text('👍 رائع', style: TextStyle(fontSize: 16))),
        const SizedBox(width: 12),
        OutlinedButton(onPressed: () => _rate(false), child: const Text('👎 سيّئ', style: TextStyle(fontSize: 16))),
      ]),
    ]);
  }
}
