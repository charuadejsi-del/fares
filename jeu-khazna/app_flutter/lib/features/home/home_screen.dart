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
              style: const TextStyle(fontFamily: K.mono, fontSize: 34, color: K.text, letterSpacing: 12),
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
        ref.invalidate(statsProvider);
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
                  Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  _LevelLine(stats: ref.watch(statsProvider).valueOrNull, rank: progress.rank),
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
        // ── البطاقة البطلة: صورة باب الخزنة الحقيقية + زرّ واحد واضح
        ClipRRect(
          borderRadius: BorderRadius.circular(K.radius),
          child: SizedBox(
            height: 330,
            child: Stack(fit: StackFit.expand, children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([.5, .4, .1, 0, -8, .4, .5, .1, 0, -8, .4, .4, .2, 0, -8, 0, 0, 0, 1, 0]),
                child: Image.asset('assets/images/vault.jpg', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: K.surface)),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x990A0C0E), Color(0x000A0C0E), Color(0x000A0C0E), Color(0xFF0A0C0E)],
                    stops: [0, .25, .45, 1],
                  ),
                ),
              ),
              Positioned(top: 12, right: 14, left: 14, child: _LiveRow(online: ref.watch(statsProvider).valueOrNull?.online)),
              Positioned(
                right: 16,
                left: 16,
                bottom: 16,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const MonoLabel('OPERATION // CO-OP', color: K.neon, size: 10.5),
                  const SizedBox(height: 6),
                  const Text('اخترق الخزنة.\nمعاً فقط.', style: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('عميل أمام الأقفال، ومحلّل يملك الملفّات. لا أحد يفتحها وحده.',
                      style: TextStyle(color: K.text2, fontSize: 13, height: 1.5)),
                  const SizedBox(height: 14),
                  _PlayButton(busy: _busy, onTap: _busy ? null : _radar),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        // ── ثلاث طرق أخرى للّعب (بلا تكرار)
        Container(
          decoration: BoxDecoration(
            color: K.surface,
            borderRadius: BorderRadius.circular(K.radius),
            border: Border.all(color: K.border),
          ),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Mode(icon: Icons.group_add_outlined, label: 'غرفة مع صديق', onTap: _busy ? null : () => _online(host: true))),
              const VerticalDivider(width: 1, color: K.border),
              Expanded(child: _Mode(icon: Icons.dialpad, label: 'رمز غرفة', onTap: _busy ? null : _joinDialog)),
              const VerticalDivider(width: 1, color: K.border),
              Expanded(child: _Mode(icon: Icons.smart_toy_outlined, label: 'تدريب مع نَسْر', onTap: _bot)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('مهامّ اليوم', tag: 'DAILY'),
        const DailyRewardCard(),
        const SizedBox(height: 10),
        const ChallengesCard(),
        const SizedBox(height: 20),
        const SectionTitle('حملتك', tag: 'CAMPAIGN'),
        Pressable(
          onTap: () => ref.read(tabProvider.notifier).state = 1,
          child: GlassCard(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: K.neon.withAlpha(150)),
                ),
                child: Text(next.toString().padLeft(2, '0'), style: const TextStyle(fontFamily: K.mono, fontSize: 20, color: K.neon)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(def.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text('${def.region.name}${def.boss ? ' · مرحلة الزعيم' : ''}', style: const TextStyle(color: K.muted, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (team.top / kCampaignStages).clamp(0.0, 1.0).toDouble(),
                    minHeight: 3,
                    color: K.steel,
                    backgroundColor: K.border,
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Text('${team.top.clamp(0, kCampaignStages)}/$kCampaignStages', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('المزيد', tag: 'OPERATIONS'),
        Container(
          decoration: BoxDecoration(
            color: K.surface,
            borderRadius: BorderRadius.circular(K.radius),
            border: Border.all(color: K.border),
          ),
          child: Column(children: [
            _Row(icon: Icons.group_outlined, title: 'الأصدقاء', sub: 'ادعُ واربح دقائق', onTap: () => context.push('/friends')),
            _Row(icon: Icons.leaderboard_outlined, title: 'الترتيب والموسم', sub: 'أقوى الفرق هذا الأسبوع', onTap: () => context.push('/leaderboard')),
            _Row(icon: Icons.tune, title: 'مهمّة حرّة', sub: 'اختر الأقفال والصعوبة', onTap: () => context.push('/briefing')),
            _Row(icon: Icons.school_outlined, title: 'كيف تُلعب؟', sub: 'شرح قصير للدورين', last: true, onTap: () => context.push('/tutorial')),
          ]),
        ),
      ]),
    );
  }
}

/// المستوى + شريط الخبرة تحت الاسم.
class _LevelLine extends StatelessWidget {
  final PlayerStats? stats;
  final String rank;
  const _LevelLine({required this.stats, required this.rank});

  @override
  Widget build(BuildContext context) {
    final st = stats;
    if (st == null) return Text(rank, style: const TextStyle(color: K.muted, fontSize: 12));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('المستوى ${st.level} · ${st.xp} XP', style: const TextStyle(color: K.text2, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      SizedBox(
        width: 120,
        child: LinearProgressIndicator(value: st.levelFrac, minHeight: 3, color: K.neon, backgroundColor: K.border),
      ),
    ]);
  }
}

/// «LIVE · عدد العملاء» + ساعة بطابع كاميرا مراقبة.
class _LiveRow extends StatefulWidget {
  final int? online;
  const _LiveRow({this.online});

  @override
  State<_LiveRow> createState() => _LiveRowState();
}

class _LiveRowState extends State<_LiveRow> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = TimeOfDay.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    const st = TextStyle(fontFamily: K.mono, fontSize: 10.5, color: K.steel, letterSpacing: 1);
    return Row(children: [
      FadeTransition(
        opacity: Tween(begin: .25, end: 1.0).animate(_a),
        child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: K.danger, shape: BoxShape.circle)),
      ),
      const SizedBox(width: 6),
      Text(widget.online == null ? 'LIVE · غرفة العمليات' : 'LIVE · ${widget.online} عميل متّصل', style: st),
      const Spacer(),
      Text('CAM 01 · $t', style: st),
    ]);
  }
}

class _PlayButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onTap;
  const _PlayButton({required this.busy, this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: busy ? null : onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: K.neon, borderRadius: BorderRadius.circular(K.radius)),
          child: busy
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: K.ink)))
              : const Row(children: [
                  Text('العب الآن', style: TextStyle(color: K.ink, fontSize: 17, fontWeight: FontWeight.w800)),
                  Spacer(),
                  Text('ابحث عن شريك', style: TextStyle(color: Color(0xB3120C02), fontSize: 12.5, fontWeight: FontWeight.w700)),
                  SizedBox(width: 6),
                  Icon(Icons.radar, color: K.ink, size: 20),
                ]),
        ),
      );
}

class _Mode extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _Mode({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Column(children: [
            Icon(icon, color: K.steel, size: 22),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;
  final bool last;
  const _Row({required this.icon, required this.title, required this.sub, required this.onTap, this.last = false});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.border))),
          child: Row(children: [
            Icon(icon, color: K.text2, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(color: K.muted, fontSize: 12)),
              ]),
            ),
            const Icon(Icons.chevron_left, color: K.muted, size: 20),
          ]),
        ),
      );
}
