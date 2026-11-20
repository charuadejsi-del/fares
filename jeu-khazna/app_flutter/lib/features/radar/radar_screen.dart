// الرادار: يبحث عن عميل متصل للّعب معه (مطابقة حسب المستوى)، ومع غياب اللاعبين يقترح العميل الآلي.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/bot.dart';
import '../../core/controller.dart';
import '../../core/services.dart';
import '../../core/social.dart';
import '../../core/stages.dart';
import '../../core/team.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';
import '../shop/shop_screen.dart' show showShopSheet;

class RadarScreen extends ConsumerStatefulWidget {
  const RadarScreen({super.key});

  @override
  ConsumerState<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends ConsumerState<RadarScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  Timer? _poll;
  Timer? _clock;
  final DateTime _started = DateTime.now();
  int _others = 0;
  int _botAfter = 60;
  String? _error;
  MatchResult? _found;
  bool _busy = false;
  bool _left = false;

  int get _waited => DateTime.now().difference(_started).inSeconds;

  @override
  void initState() {
    super.initState();
    _search();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _search());
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _clock?.cancel();
    _sweep.dispose();
    if (_found == null && !_left) SocialService.cancel().catchError((_) {});
    super.dispose();
  }

  String get _name {
    final n = authService.profile?.nickname ?? ref.read(settingsProvider).name;
    return n.isEmpty ? 'عميل' : n;
  }

  Future<void> _search() async {
    if (_busy || _found != null || _error != null) return;
    _busy = true;
    try {
      final r = await SocialService.search();
      if (!mounted) return;
      if (r.matched) {
        _poll?.cancel();
        setState(() => _found = r);
        ref.read(audioProvider).fx(Sfx.success, HapticKind.heavy);
        await Future.delayed(const Duration(milliseconds: 1600));
        if (mounted) await _enter(r);
        return;
      }
      setState(() {
        _others = r.others;
        _botAfter = r.botAfter;
      });
      if (_waited % 6 == 0) ref.read(audioProvider).fx(Sfx.beep, HapticKind.tap, volume: 0.35);
    } catch (e) {
      if (!mounted) return;
      final t = authErrorText(e);
      if (t.contains('رصيد')) {
        _poll?.cancel();
        setState(() => _error = t);
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _enter(MatchResult r) async {
    final c = GameController.online(meName: _name, code: r.code, channel: r.channel, isHost: r.host, matched: true);
    try {
      await c.connect();
    } catch (_) {
      c.dispose();
      if (mounted) {
        showToast(context, 'تعذّر الاتصال بالشريك. تحقّق من الإنترنت.', error: true);
        context.pop();
      }
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    _left = true;
    context.pushReplacement('/play', extra: c);
  }

  Future<void> _playBot() async {
    _poll?.cancel();
    _left = true;
    await SocialService.cancel().catchError((_) {});
    if (!mounted) return;
    final team = ref.read(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty;
    final d = stageDef(team.current);
    final c = GameController.local(meName: _name, rooms: d.rooms, diff: d.diff, missionId: d.n, bot: true);
    context.pushReplacement('/play', extra: c);
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    final canBot = _waited >= _botAfter;
    return Scaffold(
      body: SpyBackground(
        image: 'assets/images/map4.jpg',
        dim: .92,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(children: [
              Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.text2)),
                const Spacer(),
                const BalanceChip(),
              ]),
              const SizedBox(height: 6),
              MonoLabel(found != null ? 'TARGET ACQUIRED' : 'SIGINT · SEARCHING', color: K.ok, size: 11),
              const SizedBox(height: 6),
              Text(
                found != null
                    ? 'وجدنا شريكك!'
                    : _error != null
                        ? 'الرادار متوقّف'
                        : 'نبحث عن عميل متصل…',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: AnimatedBuilder(
                      animation: _sweep,
                      builder: (context, _) => CustomPaint(
                        painter: _RadarPainter(
                          angle: _sweep.value * 2 * pi,
                          blips: found != null ? 1 : _others.clamp(0, 8),
                          locked: found != null,
                          seed: _started.millisecondsSinceEpoch,
                        ),
                        child: Center(
                            child: found != null
                                ? _FoundBadge(r: found)
                                : Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: K.neon,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: K.neon.withAlpha(70), width: 4, strokeAlign: BorderSide.strokeAlignOutside),
                                    ),
                                  )),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                GlowButton(label: 'اشحن دقائقك', icon: Icons.storefront_outlined, onTap: () => showShopSheet(context)),
              ] else if (found == null) ...[
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill(icon: Icons.timer_outlined, text: _fmt(_waited), color: K.text2),
                  const SizedBox(width: 8),
                  Pill(icon: Icons.people_alt_outlined, text: _others == 0 ? 'لا أحد يبحث الآن' : '$_others يبحثون الآن', color: K.text2),
                ]),
                const SizedBox(height: 10),
                Text(
                  _waited < 20 ? 'نطابقك مع عميل من مستواك' : 'وسّعنا البحث لمستويات قريبة منك',
                  style: const TextStyle(color: K.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: canBot
                      ? GlassCard(
                          key: const ValueKey('bot'),
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            const Text('لا يوجد عملاء كثيرون الآن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('العب مع «$kBotName»: يقرأ الدليل ويوجّهك كتابةً خطوة بخطوة. نواصل البحث إن فضّلت الانتظار.',
                                style: const TextStyle(color: K.text2, fontSize: 12.5)),
                            const SizedBox(height: 10),
                            GlowButton(label: 'التدريب مع $kBotName', icon: Icons.smart_toy_outlined, outline: true, height: 48, onTap: _playBot),
                          ]),
                        )
                      : Text('بعد ${_botAfter - _waited} ث يمكنك اللعب مع العميل الآلي',
                          key: const ValueKey('wait'), style: const TextStyle(color: K.muted, fontSize: 12)),
                ),
                const SizedBox(height: 12),
                GlowButton(label: 'إلغاء البحث', icon: Icons.close, outline: true, color: K.danger, height: 48, onTap: () => context.pop()),
              ] else
                const Text('جارٍ فتح القناة السرّية…', style: TextStyle(color: K.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  static String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class _FoundBadge extends StatelessWidget {
  final MatchResult r;
  const _FoundBadge({required this.r});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Avatar(r.partnerNick, size: 66),
          const SizedBox(height: 8),
          Text(r.partnerNick, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('المستوى ${r.partnerSkill}', style: const TextStyle(color: K.muted, fontSize: 12)),
        ]),
      );
}

class _RadarPainter extends CustomPainter {
  final double angle;
  final int blips;
  final bool locked;
  final int seed;
  _RadarPainter({required this.angle, required this.blips, required this.locked, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    const color = K.ok;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0B140F));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withAlpha(locked ? 90 : 45);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(c, r * i / 4, ring);
    }
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), ring);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), ring);
    if (!locked) {
      final sweep = Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: pi / 2,
          colors: [color.withAlpha(0), color.withAlpha(110)],
          transform: GradientRotation(angle - pi / 2),
        ).createShader(Rect.fromCircle(center: c, radius: r));
      // قطاع 90° فقط خلف خطّ المسح (كان القرص كلّه يمتلئ لأن التدرّج يمتدّ خارج نطاقه).
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), angle - pi / 2, pi / 2, true, sweep);
      final tip = Offset(c.dx + r * cos(angle), c.dy + r * sin(angle));
      canvas.drawLine(c, tip, Paint()
        ..color = color.withAlpha(200)
        ..strokeWidth = 1.5);
    }
    final rnd = Random(seed);
    for (var i = 0; i < blips; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final d = r * (0.35 + rnd.nextDouble() * 0.55);
      final p = Offset(c.dx + d * cos(a), c.dy + d * sin(a));
      // يضيء النقطة عند مرور الخطّ عليها
      var diff = (angle - a) % (2 * pi);
      if (diff < 0) diff += 2 * pi;
      final glow = locked ? 1.0 : (1 - diff / (2 * pi)).clamp(0.15, 1.0);
      canvas.drawCircle(p, 7, Paint()..color = color.withAlpha((50 * glow).round()));
      canvas.drawCircle(p, 3.5, Paint()..color = color.withAlpha((255 * glow).round()));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => true;
}
