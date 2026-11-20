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
import '../../net/transport.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';
import '../shop/shop_screen.dart';

/// تبويب «المقرّ»: البطاقة الرئيسية للّعب مع صديق، المكافأة اليومية، والتقدّم.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioProvider).startMusic();
      _checkReviews();
    });
    authService.refreshProfile().catchError((_) {});
  }

  String get _name {
    final n = authService.profile?.nickname ?? ref.read(settingsProvider).name;
    return n.isEmpty ? 'عميل' : n;
  }

  void _toast(String m) => showToast(context, m, error: true);

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
              Avatar(name, size: 46),
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
            GlowButton(label: 'أنشئ غرفة وادعُ صديقك', icon: Icons.wifi_tethering, busy: _busy, onTap: () => _online(host: true)),
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
            _Tile(icon: Icons.leaderboard_rounded, title: 'الترتيب العالمي', sub: 'أقوى الفرق', color: K.amber, onTap: () => context.push('/leaderboard')),
            _Tile(icon: Icons.school_outlined, title: 'التدريب', sub: 'كيف تُلعب؟', color: K.agent, onTap: () => context.push('/tutorial')),
            _Tile(icon: Icons.bolt_rounded, title: 'مهمّة حرّة', sub: 'اختر الأقفال والصعوبة', color: K.violet, onTap: () => context.push('/briefing')),
            _Tile(icon: Icons.storefront_outlined, title: 'المتجر', sub: 'اشحن دقائقك', color: K.neon, onTap: () => ref.read(tabProvider.notifier).state = 2),
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
