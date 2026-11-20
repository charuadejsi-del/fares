import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/controller.dart';
import '../../core/session.dart';
import '../../core/shop.dart';
import '../../core/stages.dart';
import '../../core/team.dart';
import '../../core/services.dart';
import '../../core/social.dart';
import '../../net/transport.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';
import '../../widgets/online_launch.dart';
import '../../widgets/title_frame.dart';
import '../shop/shop_screen.dart';
import 'challenges_card.dart';

/// تبويب «المقرّ»: البطاقة الرئيسية للّعب مع صديق، المكافأة اليومية، والتقدّم.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;
  RejoinData? _rejoin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioProvider).startMusic();
      _checkReviews();
      _checkRejoin();
    });
    authService.refreshProfile().catchError((_) {});
  }

  String get _name {
    final n = authService.profile?.nickname ?? ref.read(settingsProvider).name;
    return n.isEmpty ? 'عميل' : n;
  }

  void _toast(String m) => showToast(context, m, error: true);

  /// مهمّة جارية لم تكتمل (إغلاق التطبيق أو انقطاع الإنترنت)؟
  Future<void> _checkRejoin() async {
    final d = await RejoinData.load();
    if (d == null) return;
    if (d.sessionId != null) {
      try {
        final r = await SocialService.resume(d.sessionId!);
        if (r == null) {
          await RejoinData.clear();
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _rejoin = d);
  }

  Future<void> _doRejoin() async {
    final d = _rejoin;
    if (d == null) return;
    setState(() => _busy = true);
    final ok = await launchOnline(context, code: d.code, channel: d.channel, host: d.host, matched: d.matched, resume: d);
    if (mounted) setState(() {
      _busy = false;
      if (ok) _rejoin = null;
    });
  }

  Future<void> _radar() async {
    if ((authService.profile?.balanceSeconds ?? 0) <= 0) {
      _toast('رصيدك غير كافٍ — اشحن من المتجر أو خذ مكافأتك اليومية');
      return;
    }
    context.push('/radar');
  }

  /// يُعلم اللاعب بطلبات الشراء التي قُبلت أو رُفضت منذ آخر مرّة.
  Future<void> _checkReviews() async {
    try {
      final fresh = await ShopService.newlyReviewed(ref.read(prefsProvider));
      if (!mounted || fresh.isEmpty) return;
      final ok = fresh.where((r) => r.status == 'approved').toList();
      if (ok.isNotEmpty) {
        await authService.refreshProfile();
        ref.read(audioProvider).fx(Sfx.vault, HapticKind.heavy);
        if (mounted) showToast(context, '🎉 قُبل طلبك: +${ok.fold<int>(0, (a, r) => a + r.minutes)} دقيقة في رصيدك');
      } else {
        showToast(context, 'رُفض طلب شراء — راجع «طلباتي» في المتجر', error: true);
      }
      ref.invalidate(myRequestsProvider);
    } catch (_) {}
  }

  Future<void> _online({required bool host, String code = ''}) async {
    if (!onlineAvailable) {
      _toast('اللعب أونلاين غير مفعّل في هذه النسخة بعد.');
      return;
    }
    setState(() => _busy = true);
    // رمز فريد من الخادم + قناة سرّية للغرفة
    String channel;
    try {
      if (host) {
        final r = await SessionService.roomCreate();
        code = r.$1;
        channel = r.$2;
      } else {
        channel = await SessionService.roomResolve(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('$e'.contains('room not found')
            ? 'لا توجد غرفة نشطة بهذا الرمز — تأكّد من الرقم'
            : 'تعذّر الاتصال بالخادم. تحقّق من الإنترنت.');
      }
      return;
    }
    final c = GameController.online(meName: _name, code: code, channel: channel, isHost: host);
    try {
      await c.connect();
    } catch (_) {
      c.dispose();
      if (mounted) {
        setState(() => _busy = false);
        _toast('تعذّر الاتصال بالقاعدة. تحقّق من الإنترنت.');
      }
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _busy = false);
    context.push('/play', extra: c);
  }

  void _bot() {
    final team = ref.read(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty;
    final d = stageDef(team.current);
    final c = GameController.local(meName: _name, rooms: d.rooms, diff: d.diff, missionId: d.n, bot: true);
    context.push('/play', extra: c);
  }

  Future<void> _joinDialog() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: HudPanel(
          label: 'JOIN // رمز الغرفة',
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontFamily: K.mono, fontSize: 34, color: K.neon, letterSpacing: 12),
              decoration: fieldDecoration('0000'),
            ),
            const SizedBox(height: 14),
            NeonButton(label: 'دخول', icon: Icons.login, onTap: () => Navigator.of(ctx).pop(ctl.text.trim())),
          ]),
        ),
      ),
    );
    ctl.dispose();
    if (code == null) return;
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      _toast('الرمز يتكوّن من 4 أرقام.');
      return;
    }
    await _online(host: false, code: code);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final team = ref.watch(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty;
    final next = team.current;
    final def = stageDef(next);
    return RefreshIndicator(
      color: K.neon,
      backgroundColor: K.surface,
      onRefresh: () async {
        ref.invalidate(teamProgressProvider(null));
        ref.invalidate(challengesProvider);
        ref.invalidate(seasonProvider);
        await authService.refreshProfile();
        await _checkReviews();
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        // ── الرأس: الهوية + الرصيد + الإعدادات
        ListenableBuilder(
          listenable: authService,
          builder: (context, _) {
            final name = authService.profile?.nickname ?? _name;
            return Row(children: [
              TitleAvatar(name, title: ref.watch(seasonProvider).valueOrNull?.myTitle, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(progress.rank, style: const TextStyle(color: K.amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
              const BalanceChip(),
              const SizedBox(width: 6),
              IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.tune_rounded, color: K.muted)),
            ]);
          },
        ),
        const SizedBox(height: 16),
        if (_rejoin != null) ...[
          GlassCard(
            accent: K.amber,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.restore_rounded, color: K.amber, size: 30),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('لديك مهمّة جارية', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text('انقطعت المهمّة — عُد إليها من حيث توقّفت', style: TextStyle(color: K.text2, fontSize: 12.5)),
                ]),
              ),
              SizedBox(width: 92, child: GlowButton(label: 'عُد', icon: Icons.play_arrow_rounded, height: 42, color: K.amber, busy: _busy, onTap: _doRejoin)),
              IconButton(
                onPressed: () {
                  RejoinData.clear();
                  setState(() => _rejoin = null);
                },
                icon: const Icon(Icons.close, color: K.muted, size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        // ── البطاقة البطلة: العب مع صديق
        GlassCard(
          accent: K.neon,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0E2420), Color(0xFF0B1516), Color(0xFF081011)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MonoLabel('CO-OP MISSION // مهمّة جماعية', size: 10),
                  const SizedBox(height: 8),
                  const Text('افتح الخزنة\nمع صديقك', style: TextStyle(fontSize: 28, height: 1.15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('عميل يرى الأقفال · محلّل يملك الدليل · صوت مباشر',
                      style: TextStyle(color: K.text2.withAlpha(220), fontSize: 12.5)),
                ]),
              ),
              const VaultHero(size: 118),
            ]),
            const SizedBox(height: 18),
            GlowButton(label: 'العب الآن — ابحث عن شريك', icon: Icons.radar, busy: _busy, onTap: _busy ? null : _radar),
            const SizedBox(height: 10),
            GlowButton(label: 'أنشئ غرفة وادعُ صديقك', icon: Icons.wifi_tethering, outline: true, height: 50, onTap: _busy ? null : () => _online(host: true)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: GlowButton(label: 'انضمّ برمز', icon: Icons.login_rounded, outline: true, color: K.agent, height: 48, onTap: _busy ? null : _joinDialog)),
              const SizedBox(width: 10),
              Expanded(child: GlowButton(label: 'هاتف واحد', icon: Icons.smartphone, outline: true, color: K.agent, height: 48, onTap: _busy ? null : () => ref.read(tabProvider.notifier).state = 1)),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        const DailyRewardCard(),
        const SizedBox(height: 14),
        const ChallengesCard(),
        const SizedBox(height: 22),
        const SectionTitle('حملتك', tag: 'SOLO CAMPAIGN'),
        Pressable(
          onTap: () => ref.read(tabProvider.notifier).state = 1,
          child: GlassCard(
            accent: def.region.color,
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: def.region.color.withAlpha(26),
                  border: Border.all(color: def.region.color.withAlpha(140)),
                ),
                child: Text('$next', style: TextStyle(fontFamily: K.mono, fontSize: 24, color: def.region.color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('المرحلة التالية: ${def.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${def.region.name}${def.boss ? ' · مرحلة الزعيم 🔥' : ''}', style: const TextStyle(color: K.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (team.top / kCampaignStages).clamp(0.0, 1.0).toDouble(),
                      minHeight: 6,
                      color: def.region.color,
                      backgroundColor: K.border,
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              Text('${team.top.clamp(0, kCampaignStages)}/$kCampaignStages', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
            ]),
          ),
        ),
        const SizedBox(height: 22),
        const SectionTitle('المزيد', tag: 'OPERATIONS'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _Tile(icon: Icons.group_rounded, title: 'الأصدقاء', sub: 'ادعُ واربح دقائق', color: K.neon, onTap: () => context.push('/friends')),
            _Tile(icon: Icons.smart_toy_outlined, title: 'العميل الآلي', sub: 'تدرّب مع نَسْر 🤖', color: K.violet, onTap: _bot),
            _Tile(icon: Icons.leaderboard_rounded, title: 'الترتيب العالمي', sub: 'أقوى الفرق', color: K.amber, onTap: () => context.push('/leaderboard')),
            _Tile(icon: Icons.school_outlined, title: 'التدريب', sub: 'كيف تُلعب؟', color: K.agent, onTap: () => context.push('/tutorial')),
            _Tile(icon: Icons.bolt_rounded, title: 'مهمّة حرّة', sub: 'اختر الأقفال والصعوبة', color: K.violet, onTap: () => context.push('/briefing')),
            _Tile(icon: Icons.storefront_outlined, title: 'المتجر', sub: 'اشحن دقائقك', color: K.amber, onTap: () => ref.read(tabProvider.notifier).state = 2),
          ],
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color color;
  final VoidCallback onTap;
  const _Tile({required this.icon, required this.title, required this.sub, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: GlassCard(
          accent: color,
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: color.withAlpha(30)),
              child: Icon(icon, color: color, size: 22),
            ),
            const Spacer(),
            Text(title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            Text(sub, style: const TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
      );
}
