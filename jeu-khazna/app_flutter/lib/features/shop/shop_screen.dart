// المتجر: شراء دقائق عبر بريدي موب (يدوياً) + المكافأة اليومية + «طلباتي».
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/services.dart';
import '../../core/session.dart';
import '../../core/shop.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';

final shopProvider = FutureProvider.autoDispose<ShopInfo>((ref) => ShopService.load());
final myRequestsProvider = FutureProvider.autoDispose<List<PaymentRequest>>((ref) => ShopService.myRequests());

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(shopProvider);
    final reqs = ref.watch(myRequestsProvider);
    return RefreshIndicator(
      color: K.neon,
      backgroundColor: K.surface,
      onRefresh: () async {
        ref.invalidate(shopProvider);
        ref.invalidate(myRequestsProvider);
        await authService.refreshProfile();
      },
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        const _Header(),
        const SizedBox(height: 16),
        const DailyRewardCard(),
        const SizedBox(height: 22),
        const SectionTitle('باقات الوقت', tag: 'TIME PACKS'),
        shop.when(
          loading: () => const _Loading(height: 150),
          error: (e, _) => _ErrorBox(onRetry: () => ref.invalidate(shopProvider)),
          data: (info) => info.packages.isEmpty
              ? const _Empty(icon: Icons.inventory_2_outlined, text: 'لا توجد باقات حالياً')
              : Column(children: [
                  for (int i = 0; i < info.packages.length; i++) ...[
                    _PackageTile(
                      pkg: info.packages[i],
                      best: info.packages.length > 1 &&
                          info.packages[i].perMinute == info.packages.map((p) => p.perMinute).reduce((a, b) => a < b ? a : b),
                      onTap: () => _buy(context, ref, info, info.packages[i]),
                    ),
                    const SizedBox(height: 12),
                  ],
                ]),
        ),
        const SizedBox(height: 10),
        const _HowItWorks(),
        const SizedBox(height: 12),
        const _GiftCard(),
        const SizedBox(height: 22),
        SectionTitle('طلباتي', tag: 'MY ORDERS', trailing: IconButton(
          onPressed: () => ref.invalidate(myRequestsProvider),
          icon: const Icon(Icons.refresh, color: K.muted, size: 20),
        )),
        reqs.when(
          loading: () => const _Loading(height: 80),
          error: (e, _) => _ErrorBox(onRetry: () => ref.invalidate(myRequestsProvider)),
          data: (list) => list.isEmpty
              ? const _Empty(icon: Icons.receipt_long_outlined, text: 'لم ترسل أي طلب بعد')
              : Column(children: [for (final r in list) _RequestTile(r)]),
        ),
        const SizedBox(height: 10),
        const Text('🔒 لا إعلانات · لا جوائز مالية · الدقائق تُستعمل للعب فقط',
            textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
      ]),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, ShopInfo info, Package pkg) async {
    if (!info.ready) {
      showToast(context, 'الشراء غير متاح حالياً، حاول لاحقاً', error: true);
      return;
    }
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CheckoutSheet(info: info, pkg: pkg),
    );
    if (sent == true) {
      ref.invalidate(myRequestsProvider);
      if (context.mounted) showToast(context, 'وصل طلبك ✓ ستُضاف الدقائق بعد التحقّق');
    }
  }
}

/// المتجر كنافذة سفلية (من داخل المهمّة أو الغرفة) دون مغادرة اللعب.
Future<void> showShopSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * .9,
        decoration: const BoxDecoration(
          color: Color(0xFF070D0E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: K.borderStrong)),
        ),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 44, height: 4, decoration: BoxDecoration(color: K.borderStrong, borderRadius: BorderRadius.circular(4))),
          Row(children: [
            const SizedBox(width: 18),
            const Text('المتجر', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close, color: K.muted)),
          ]),
          const Expanded(child: ShopScreen()),
        ]),
      ),
    );

/// إهداء دقائق لصديق باسمه الحركي.
class _GiftCard extends ConsumerWidget {
  const _GiftCard();

  Future<void> _open(BuildContext context) async {
    final name = TextEditingController();
    final mins = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          accent: K.violet,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Row(children: [
              Icon(Icons.redeem, color: K.violet),
              SizedBox(width: 10),
              Text('أهدِ دقائق لصديق', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 14),
            TextField(controller: name, decoration: fieldDecoration('الاسم الحركي لصديقك', icon: Icons.person_search_outlined)),
            const SizedBox(height: 10),
            TextField(
              controller: mins,
              keyboardType: TextInputType.number,
              decoration: fieldDecoration('عدد الدقائق (5 – 500)', icon: Icons.timer_outlined),
            ),
            const SizedBox(height: 14),
            GlowButton(label: 'إرسال الهديّة', icon: Icons.send_rounded, color: K.violet, height: 50, onTap: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      ),
    );
    final n = name.text.trim();
    final m = int.tryParse(mins.text.trim()) ?? 0;
    name.dispose();
    mins.dispose();
    if (ok != true || !context.mounted) return;
    if (n.isEmpty || m < 5) {
      showToast(context, 'اكتب الاسم وعدد الدقائق (5 على الأقل)', error: true);
      return;
    }
    final sure = await confirmDialog(context, title: 'تأكيد الإهداء', body: 'ستُرسل $m دقيقة من رصيدك إلى «$n». لا يمكن التراجع.', confirm: 'أرسل');
    if (!sure || !context.mounted) return;
    try {
      final bal = await SessionService.gift(n, m);
      authService.setBalance(bal);
      if (context.mounted) showToast(context, '🎁 وصلت $m دقيقة إلى $n');
    } catch (e) {
      if (context.mounted) showToast(context, authErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Pressable(
        onTap: () => _open(context),
        child: GlassCard(
          accent: K.violet,
          padding: const EdgeInsets.all(14),
          child: const Row(children: [
            Icon(Icons.redeem, color: K.violet, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('أهدِ دقائق لصديق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('شاركه رصيدك ليلعب معك', style: TextStyle(color: K.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_left, color: K.muted),
          ]),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: authService,
        builder: (context, _) {
          final m = authService.profile?.balanceMinutes ?? 0;
          return GlassCard(
            accent: K.neon,
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const MonoLabel('TIME BALANCE // رصيدك'),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(end: m.toDouble()),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text('${v.round()}',
                          style: TextStyle(
                              fontFamily: K.mono,
                              fontSize: 46,
                              height: 1,
                              color: m < 10 ? K.danger : K.neon,
                              shadows: [Shadow(color: (m < 10 ? K.danger : K.neon).withAlpha(140), blurRadius: 18)])),
                    ),
                    const SizedBox(width: 6),
                    const Padding(padding: EdgeInsets.only(bottom: 6), child: Text('دقيقة', style: TextStyle(color: K.text2, fontSize: 16))),
                  ]),
                  const SizedBox(height: 6),
                  Text(m < 10 ? 'رصيدك ينفد — اشحن لتكمل المهمّات' : 'كل دقيقة لعب تُخصم من رصيدك',
                      style: TextStyle(color: m < 10 ? K.danger : K.muted, fontSize: 12.5)),
                ]),
              ),
              const VaultHero(size: 92),
            ]),
          );
        },
      );
}

/// المكافأة اليومية مع عدّاد حتى الغد.
class DailyRewardCard extends ConsumerStatefulWidget {
  const DailyRewardCard({super.key});

  @override
  ConsumerState<DailyRewardCard> createState() => _DailyRewardCardState();
}

class _DailyRewardCardState extends ConsumerState<DailyRewardCard> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      final before = authService.profile?.balanceSeconds ?? 0;
      final bal = await authService.claimDaily();
      ref.read(audioProvider).fx(Sfx.vault, HapticKind.heavy);
      if (mounted) showToast(context, '🎁 +${(bal - before) ~/ 60} دقيقة أُضيفت لرصيدك');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(gameRulesProvider).valueOrNull ?? const GameRules(2, 30, 10);
    return ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final p = authService.profile;
        final ok = p?.dailyAvailable ?? false;
        final left = untilAlgiersMidnight();
        final day = (p?.nextStreakDay ?? 1).clamp(1, 999);
        final streak = p?.streakNow ?? 0;
        final reward = rules.rewardMinutes(day);
        return GlassCard(
          accent: K.amber,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(colors: ok ? [K.amber, const Color(0xFFFF7A3D)] : [K.surface2, K.surface2]),
                  boxShadow: ok ? [BoxShadow(color: K.amber.withAlpha(90), blurRadius: 18)] : null,
                ),
                child: Text(streak > 0 ? '🔥' : '🎁', style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(streak > 0 ? 'سلسلة $streak ${streak == 1 ? 'يوم' : 'أيام'} 🔥' : 'المكافأة اليومية',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  Text(ok ? 'اليوم: +$reward دقيقة (اليوم $day)' : 'غداً: +${rules.rewardMinutes(day + 1)} د — بعد ${left.inHours} سا ${left.inMinutes % 60} د',
                      style: TextStyle(color: ok ? K.amber : K.muted, fontSize: 13)),
                ]),
              ),
              SizedBox(
                width: 96,
                child: GlowButton(label: ok ? 'خذها' : 'غداً', height: 44, color: K.amber, outline: !ok, busy: _busy, onTap: ok ? _claim : null),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              for (int d = 1; d <= 7; d++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: d <= (ok ? streak : streak) ? K.amber.withAlpha(50) : (d == day && ok ? K.amber.withAlpha(20) : K.surface2),
                      border: Border.all(color: d == day && ok ? K.amber : (d <= streak ? K.amber.withAlpha(140) : K.border)),
                    ),
                    child: Column(children: [
                      Text(d <= streak ? '🔥' : (d == 7 ? '👑' : '·'), style: const TextStyle(fontSize: 12)),
                      Text('${rules.rewardMinutes(d)}د', style: TextStyle(fontSize: 10.5, color: d <= streak ? K.amber : K.muted, fontFamily: K.mono)),
                    ]),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            const Text('العب كل يوم لتكبر المكافأة. يوم واحد بلا مكافأة يعيد السلسلة إلى البداية.',
                style: TextStyle(color: K.muted, fontSize: 11.5)),
          ]),
        );
      },
    );
  }
}

class _PackageTile extends StatelessWidget {
  final Package pkg;
  final bool best;
  final VoidCallback onTap;
  const _PackageTile({required this.pkg, required this.best, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = best ? K.amber : K.neon;
    return Pressable(
      onTap: onTap,
      child: GlassCard(
        accent: c,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.withAlpha(140), width: 2),
              boxShadow: [BoxShadow(color: c.withAlpha(50), blurRadius: 16)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${pkg.minutes}', style: TextStyle(fontFamily: K.mono, fontSize: 22, color: c, height: 1)),
              Text('دقيقة', style: TextStyle(fontSize: 10.5, color: c.withAlpha(200))),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${pkg.minutes} دقيقة لعب', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                if (best) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: K.amber, borderRadius: BorderRadius.circular(8)),
                    child: const Text('الأوفر', style: TextStyle(color: K.ink, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('≈ ${(pkg.minutes / 8).round()} مهمّة · ${pkg.perMinute.toStringAsFixed(2)} دج/دقيقة',
                  style: const TextStyle(color: K.muted, fontSize: 12.5)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${pkg.priceDzd}', style: TextStyle(fontFamily: K.mono, fontSize: 22, color: c)),
            const Text('دج', style: TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ]),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.touch_app_outlined, 'اختر باقة'),
      (Icons.account_balance_outlined, 'حوّل المبلغ ببريدي موب'),
      (Icons.photo_camera_outlined, 'أرسل صورة الوصل'),
      (Icons.verified_outlined, 'تُضاف الدقائق بعد التحقّق'),
    ];
    return GlassCard(
      accent: K.agent,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        for (int i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(children: [
              Icon(steps[i].$1, color: K.agent, size: 24),
              const SizedBox(height: 6),
              Text(steps[i].$2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: K.text2, height: 1.3)),
            ]),
          ),
          if (i < steps.length - 1) const Icon(Icons.chevron_left, color: K.border, size: 18),
        ],
      ]),
    );
  }
}

class _RequestTile extends StatelessWidget {
  final PaymentRequest r;
  const _RequestTile(this.r);

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (r.status) {
      'approved' => ('مقبول · أُضيفت الدقائق', K.neon, Icons.check_circle),
      'rejected' => ('مرفوض', K.danger, Icons.cancel),
      _ => ('قيد المراجعة', K.amber, Icons.hourglass_top),
    };
    final d = r.createdAt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        accent: color,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text('${r.minutes} دقيقة · ${r.amountDzd} دج', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
            Text(label, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('رقم العملية ${r.ref} · ${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}',
              textDirection: TextDirection.rtl, style: const TextStyle(color: K.muted, fontSize: 12)),
          if (r.status == 'rejected' && (r.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('السبب: ${r.note}', style: const TextStyle(color: K.danger, fontSize: 13)),
          ],
        ]),
      ),
    );
  }
}

/// خطوات الدفع: معلومات الحساب ← الوصل ورقم العملية ← إرسال.
class _CheckoutSheet extends ConsumerStatefulWidget {
  final ShopInfo info;
  final Package pkg;
  const _CheckoutSheet({required this.info, required this.pkg});

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  final _ref = TextEditingController();
  Uint8List? _image;
  String _ext = 'jpg';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final f = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 72);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        setState(() => _error = 'الصورة كبيرة جداً (الحد 5 ميغا)');
        return;
      }
      setState(() {
        _image = bytes;
        _ext = f.name.contains('.') ? f.name.split('.').last : 'jpg';
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'تعذّر فتح الصور');
    }
  }

  Future<void> _send() async {
    final ref = _ref.text.trim();
    if (_image == null) {
      setState(() => _error = 'أرفق صورة الوصل');
      return;
    }
    if (ref.replaceAll(RegExp(r'\s'), '').length < 4) {
      setState(() => _error = 'اكتب رقم العملية كما في الوصل');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ShopService.submit(pkg: widget.pkg, ref: ref, image: _image!, ext: _ext);
      this.ref.read(audioProvider).fx(Sfx.success, HapticKind.medium);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
        decoration: const BoxDecoration(
          color: Color(0xFF0A1112),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          border: Border(top: BorderSide(color: K.borderStrong)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(18, 10, 18, 18), children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: K.borderStrong, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(children: [
              const Icon(Icons.shopping_bag_outlined, color: K.neon),
              const SizedBox(width: 10),
              Expanded(child: Text('${widget.pkg.minutes} دقيقة', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900))),
              Text('${widget.pkg.priceDzd} دج', style: const TextStyle(fontFamily: K.mono, fontSize: 24, color: K.amber)),
            ]),
            const SizedBox(height: 16),
            const _StepLabel(1, 'حوّل المبلغ بالضبط إلى هذا الحساب (بريدي موب)'),
            const SizedBox(height: 8),
            GlassCard(
              accent: K.amber,
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('RIP', style: TextStyle(color: K.muted, fontSize: 12)),
                Row(children: [
                  Expanded(
                    child: Text(info.rip,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontFamily: K.mono, fontSize: 18, color: K.text, letterSpacing: 1)),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: info.rip.replaceAll(' ', '')));
                      showToast(context, 'نُسخ رقم RIP');
                    },
                    icon: const Icon(Icons.copy_rounded, color: K.amber),
                  ),
                ]),
                if (info.holder.trim().isNotEmpty) Text('الاسم: ${info.holder}', style: const TextStyle(color: K.text2)),
                const SizedBox(height: 6),
                Text('المبلغ: ${widget.pkg.priceDzd} دج', style: const TextStyle(color: K.amber, fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 16),
            const _StepLabel(2, 'أرفق صورة الوصل'),
            const SizedBox(height: 8),
            Pressable(
              onTap: () => _pick(ImageSource.gallery),
              child: Container(
                height: _image == null ? 120 : 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _image == null ? K.borderStrong : K.neon.withAlpha(140)),
                  color: Colors.black26,
                ),
                clipBehavior: Clip.antiAlias,
                child: _image == null
                    ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, color: K.neon, size: 34),
                        SizedBox(height: 6),
                        Text('اختر صورة من المعرض', style: TextStyle(color: K.text2)),
                      ])
                    : Image.memory(_image!, fit: BoxFit.cover),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, color: K.agent, size: 18),
                label: const Text('أو التقط صورة', style: TextStyle(color: K.agent)),
              ),
            ),
            const SizedBox(height: 6),
            const _StepLabel(3, 'رقم العملية (كما يظهر في الوصل)'),
            const SizedBox(height: 8),
            TextField(
              controller: _ref,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              maxLength: 40,
              style: const TextStyle(fontFamily: K.mono, fontSize: 18, letterSpacing: 1),
              decoration: fieldDecoration('مثال: 1234567890', icon: Icons.tag),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_error!, style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
            ),
            GlowButton(label: 'إرسال الطلب', icon: Icons.send_rounded, busy: _busy, onTap: _send),
            const SizedBox(height: 10),
            const Text('رقم العملية يُستعمل مرّة واحدة فقط. ستصلك النتيجة في «طلباتي».',
                textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

class _StepLabel extends StatelessWidget {
  final int n;
  final String text;
  const _StepLabel(this.n, this.text);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: K.neon),
          child: Text('$n', style: const TextStyle(color: K.ink, fontWeight: FontWeight.w900, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700))),
      ]);
}

class _Loading extends StatelessWidget {
  final double height;
  const _Loading({required this.height});
  @override
  Widget build(BuildContext context) =>
      SizedBox(height: height, child: const Center(child: CircularProgressIndicator(color: K.neon, strokeWidth: 2.5)));
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Column(children: [
          Icon(icon, color: K.muted, size: 34),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(color: K.muted)),
        ]),
      );
}

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorBox({required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(children: [
          const Text('تعذّر التحميل — تحقّق من الإنترنت', style: TextStyle(color: K.danger)),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة', style: TextStyle(color: K.neon))),
        ]),
      );
}
