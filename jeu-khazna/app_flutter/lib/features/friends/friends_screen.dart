// الأصدقاء: إضافة باسم حركي، طلبات واردة، قائمة مع حالة «متصل» ودعوة مباشرة، كود الدعوة، والمحظورون.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/social.dart';
import '../../widgets/online_launch.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _nick = TextEditingController();
  bool _busy = false;
  String? _inviting;

  @override
  void dispose() {
    _nick.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, {String? ok}) async {
    try {
      await f();
      if (ok != null && mounted) showToast(context, ok);
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
    ref.invalidate(friendsProvider);
  }

  Future<void> _add() async {
    final n = _nick.text.trim();
    if (n.length < 2) return;
    setState(() => _busy = true);
    try {
      final r = await SocialService.request(n);
      _nick.clear();
      if (mounted) showToast(context, r == 'accepted' ? '🤝 أصبحتما صديقين' : 'أُرسل طلب الصداقة');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(friendsProvider);
    }
  }

  Future<void> _invite(Friend f) async {
    setState(() => _inviting = f.id);
    try {
      final (code, channel) = await SocialService.invite(f.id);
      if (!mounted) return;
      showToast(context, 'أُرسلت الدعوة إلى ${f.nickname} — انتظره في الغرفة');
      await launchOnline(context, code: code, channel: channel, host: true);
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _inviting = null);
    }
  }

  Future<void> _menu(Friend f) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: K.surface,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(f.nickname, style: const TextStyle(fontWeight: FontWeight.w900))),
          ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: K.amber),
              title: const Text('إزالة من الأصدقاء'),
              onTap: () => Navigator.pop(ctx, 'remove')),
          ListTile(
              leading: const Icon(Icons.block, color: K.danger),
              title: const Text('حظر'),
              onTap: () => Navigator.pop(ctx, 'block')),
          ListTile(
              leading: const Icon(Icons.flag_outlined, color: K.danger),
              title: const Text('إبلاغ'),
              onTap: () => Navigator.pop(ctx, 'report')),
        ]),
      ),
    );
    if (!mounted || a == null) return;
    if (a == 'remove') await _run(() => SocialService.remove(f.id), ok: 'أُزيل ${f.nickname}');
    if (a == 'block') await _run(() => SocialService.block(f.id), ok: 'حُظر ${f.nickname}');
    if (a == 'report' && mounted) await showReportSheet(context, f.id, f.nickname);
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider);
    return Scaffold(
      body: SpyBackground(
        dim: .8,
        child: SafeArea(
          child: RefreshIndicator(
            color: K.neon,
            onRefresh: () async {
              ref.invalidate(friendsProvider);
              ref.invalidate(referralProvider);
            },
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('الأصدقاء', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  MonoLabel('NETWORK // شبكتك', size: 10),
                ]),
              ]),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _nick,
                      maxLength: 20,
                      onSubmitted: (_) => _add(),
                      decoration: fieldDecoration('الاسم الحركي لصديقك', icon: Icons.person_search_outlined)
                          .copyWith(counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // عرض ثابت كافٍ وبلا أيقونة: كان النص «إضافة» يُقصّ.
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 96),
                    child: GlowButton(label: 'إضافة', height: 48, busy: _busy, onTap: _add),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              const ReferralCard(),
              const SizedBox(height: 18),
              friends.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator(color: K.neon))),
                error: (e, _) => Text(authErrorText(e), style: const TextStyle(color: K.danger)),
                data: (list) {
                  final incoming = list.where((f) => f.incoming).toList();
                  final sent = list.where((f) => !f.accepted && !f.incoming).toList();
                  final ok = list.where((f) => f.accepted).toList()
                    ..sort((a, b) => (b.online ? 1 : 0) - (a.online ? 1 : 0));
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (incoming.isNotEmpty) ...[
                      SectionTitle('طلبات واردة', tag: '${incoming.length}'),
                      for (final f in incoming)
                        _FriendRow(f: f, trailing: [
                          IconButton(
                              onPressed: () => _run(() => SocialService.respond(f.id, true), ok: '🤝 أصبحتما صديقين'),
                              icon: const Icon(Icons.check_circle, color: K.neon)),
                          IconButton(
                              onPressed: () => _run(() => SocialService.respond(f.id, false)),
                              icon: const Icon(Icons.cancel_outlined, color: K.muted)),
                        ]),
                      const SizedBox(height: 14),
                    ],
                    SectionTitle('أصدقائي', tag: '${ok.where((f) => f.online).length} متصل'),
                    if (ok.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('لا أصدقاء بعد — أضف صديقك باسمه الحركي، أو العب على الرادار وأضف شريكك بعد المهمّة.',
                            textAlign: TextAlign.center, style: TextStyle(color: K.muted)),
                      ),
                    for (final f in ok)
                      _FriendRow(f: f, onLong: () => _menu(f), trailing: [
                        SizedBox(
                          width: 104,
                          child: GlowButton(
                            label: 'ادعُ',
                            icon: Icons.send_rounded,
                            height: 40,
                            outline: !f.online,
                            color: f.online ? K.neon : K.agent,
                            busy: _inviting == f.id,
                            onTap: _inviting == null ? () => _invite(f) : null,
                          ),
                        ),
                        IconButton(onPressed: () => _menu(f), icon: const Icon(Icons.more_vert, color: K.muted)),
                      ]),
                    if (sent.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const SectionTitle('بانتظار القبول'),
                      for (final f in sent)
                        _FriendRow(f: f, trailing: [
                          IconButton(
                              onPressed: () => _run(() => SocialService.remove(f.id)),
                              icon: const Icon(Icons.close, color: K.muted)),
                        ]),
                    ],
                    const SizedBox(height: 18),
                    const _BlockedSection(),
                  ]);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatelessWidget {
  final Friend f;
  final List<Widget> trailing;
  final VoidCallback? onLong;
  const _FriendRow({required this.f, required this.trailing, this.onLong});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onLongPress: onLong,
          child: GlassCard(
            accent: f.online ? K.neon : K.border,
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Stack(children: [
                Avatar(f.nickname, size: 42),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: f.online ? K.neon : K.muted,
                      border: Border.all(color: K.surface, width: 2),
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                  Text('${f.online ? 'متصل الآن' : 'غير متصل'} · المستوى ${f.skill}',
                      style: TextStyle(color: f.online ? K.neon : K.muted, fontSize: 12)),
                ]),
              ),
              ...trailing,
            ]),
          ),
        ),
      );
}

class _BlockedSection extends StatefulWidget {
  const _BlockedSection();

  @override
  State<_BlockedSection> createState() => _BlockedSectionState();
}

class _BlockedSectionState extends State<_BlockedSection> {
  List<(String, String)>? _list;

  Future<void> _load() async {
    try {
      final l = await SocialService.blocks();
      if (mounted) setState(() => _list = l);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l = _list;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        onExpansionChanged: (o) {
          if (o) _load();
        },
        leading: const Icon(Icons.block, color: K.muted),
        title: const Text('المحظورون', style: TextStyle(color: K.muted, fontWeight: FontWeight.w700)),
        children: [
          if (l == null)
            const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: K.neon))
          else if (l.isEmpty)
            const Padding(padding: EdgeInsets.all(12), child: Text('لا أحد', style: TextStyle(color: K.muted)))
          else
            for (final (id, nick) in l)
              ListTile(
                title: Text(nick),
                trailing: TextButton(
                  onPressed: () async {
                    await SocialService.unblock(id).catchError((_) {});
                    _load();
                  },
                  child: const Text('رفع الحظر', style: TextStyle(color: K.neon)),
                ),
              ),
        ],
      ),
    );
  }
}

/// بطاقة كود الدعوة: انسخه وشاركه، وكلاكما ينال دقائق عند أول مهمّة ناجحة لصديقك.
class ReferralCard extends ConsumerWidget {
  const ReferralCard({super.key});

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.surface,
        title: const Text('كود دعوة صديق'),
        content: TextField(
          controller: ctl,
          maxLength: 6,
          autofocus: true,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          decoration: fieldDecoration('مثال: A1B2C3'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(color: K.muted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: K.neon, foregroundColor: K.ink),
            onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      await SocialService.applyReferral(code);
      if (context.mounted) showToast(context, '🎁 تمّ! تنالان الهدية عند أول مهمّة ناجحة لك');
    } catch (e) {
      if (context.mounted) showToast(context, authErrorText(e), error: true);
    }
    ref.invalidate(referralProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(referralProvider).valueOrNull;
    if (r == null) return const SizedBox.shrink();
    return GlassCard(
      accent: K.amber,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('🎁', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('ادعُ صديقاً: لكما ${r.bonusMinutes} دقيقة',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 6),
        const Text('يسجّل صديقك بكودك، وعند أول مهمّة ناجحة له تنالان الهدية معاً.',
            style: TextStyle(color: K.text2, fontSize: 12.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(
                    text: 'العب معي «الخزنة» 🔐 لعبة ألغاز جماعية. سجّل بكودي ${r.code} ونربح ${r.bonusMinutes} دقيقة مجاناً!'));
                showToast(context, 'نُسخت رسالة الدعوة — ألصقها لصديقك');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(K.radius),
                  color: K.amber.withAlpha(20),
                  border: Border.all(color: K.amber.withAlpha(140)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(r.code,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontFamily: K.mono, fontSize: 24, color: K.amber, letterSpacing: 6)),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded, color: K.amber, size: 18),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Text('دعوت ${r.invited} · نال الهدية ${r.rewarded}', style: const TextStyle(color: K.muted, fontSize: 12)),
        if (r.canApply)
          TextButton.icon(
            onPressed: () => _apply(context, ref),
            icon: const Icon(Icons.card_giftcard, color: K.neon, size: 18),
            label: const Text('عندي كود دعوة من صديق', style: TextStyle(color: K.neon)),
          ),
      ]),
    );
  }
}

/// نافذة الإبلاغ عن لاعب.
Future<void> showReportSheet(BuildContext context, String user, String nick, {bool offerBlock = true}) async {
  String reason = 'insult';
  bool block = true;
  final details = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: K.surface,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الإبلاغ عن $nick', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('يراجع المدير البلاغ. البلاغات الكاذبة قد توقف حسابك.', style: TextStyle(color: K.muted, fontSize: 12)),
          const SizedBox(height: 10),
          for (final e in kReportReasons.entries)
            RadioListTile<String>(
              dense: true,
              value: e.key,
              groupValue: reason,
              activeColor: K.danger,
              title: Text(e.value),
              onChanged: (v) => set(() => reason = v ?? reason),
            ),
          TextField(controller: details, maxLength: 300, maxLines: 2, decoration: fieldDecoration('تفاصيل (اختياري)')),
          if (offerBlock)
            CheckboxListTile(
              dense: true,
              value: block,
              activeColor: K.danger,
              title: const Text('احظره أيضاً (لن يُطابَق معك ثانية)'),
              onChanged: (v) => set(() => block = v ?? true),
            ),
          const SizedBox(height: 8),
          GlowButton(label: 'إرسال البلاغ', icon: Icons.flag, color: K.danger, height: 50, onTap: () => Navigator.pop(ctx, true)),
        ]),
      ),
    ),
  );
  final text = details.text;
  details.dispose();
  if (ok != true) return;
  try {
    await SocialService.report(user, reason, text);
    if (block && offerBlock) await SocialService.block(user);
    if (context.mounted) showToast(context, 'وصل بلاغك، شكراً لحماية المجتمع');
  } catch (e) {
    if (context.mounted) showToast(context, authErrorText(e), error: true);
  }
}
