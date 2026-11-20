// فتح مهمّة أونلاين من أي مكان (دعوة صديق، قبول دعوة، العودة للمهمّة) + مستمع الدعوات الواردة.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme.dart';
import '../core/auth.dart';
import '../core/controller.dart';
import '../core/social.dart';
import 'ui_kit.dart';

Future<bool> launchOnline(
  BuildContext context, {
  required String code,
  required String channel,
  required bool host,
  bool matched = false,
  RejoinData? resume,
}) async {
  final name = authService.profile?.nickname ?? 'عميل';
  final c = GameController.online(meName: name, code: code, channel: channel, isHost: host, matched: matched, resume: resume);
  try {
    await c.connect();
  } catch (_) {
    c.dispose();
    if (context.mounted) showToast(context, 'تعذّر الاتصال بالقاعدة. تحقّق من الإنترنت.', error: true);
    return false;
  }
  if (!context.mounted) {
    c.dispose();
    return false;
  }
  context.push('/play', extra: c);
  return true;
}

/// يستقبل دعوات الأصدقاء (كل 12 ثانية) ويحدّث حالة «متصل».
class InviteListener extends StatefulWidget {
  final Widget child;
  const InviteListener({super.key, required this.child});

  @override
  State<InviteListener> createState() => _InviteListenerState();
}

class _InviteListenerState extends State<InviteListener> with WidgetsBindingObserver {
  Timer? _t;
  final Set<int> _seen = {};
  bool _open = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tick();
    _t = Timer.periodic(const Duration(seconds: 12), (_) => _tick());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (_active) _tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    if (!_active || _open || authService.uid == null) return;
    // لا دعوات أثناء مهمّة (الشاشة الحالية ليست القاعدة)
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    try {
      await SocialService.presence();
      final list = await SocialService.invites();
      final fresh = list.where((i) => !_seen.contains(i.id)).toList();
      if (fresh.isEmpty || !mounted) return;
      final inv = fresh.first;
      _seen.add(inv.id);
      _open = true;
      final ok = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) => AlertDialog(
          backgroundColor: K.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: K.borderStrong)),
          title: Row(children: [
            Avatar(inv.nickname, size: 40),
            const SizedBox(width: 10),
            Expanded(child: Text(inv.nickname, style: const TextStyle(fontWeight: FontWeight.w900))),
          ]),
          content: const Text('يدعوك إلى مهمّة الآن 🔐', style: TextStyle(fontSize: 16)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('لاحقاً', style: TextStyle(color: K.muted))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: K.neon, foregroundColor: K.ink),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('انضمّ', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      );
      _open = false;
      if (!mounted) return;
      try {
        final ch = await SocialService.respondInvite(inv.id, ok == true);
        if (ok == true && ch != null && mounted) await launchOnline(context, code: inv.code, channel: ch, host: false);
      } catch (e) {
        if (mounted && ok == true) showToast(context, authErrorText(e), error: true);
      }
    } catch (_) {
      _open = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
