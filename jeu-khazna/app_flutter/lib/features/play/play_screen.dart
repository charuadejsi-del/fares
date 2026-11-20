// شاشة المهمّة: غرفة الانتظار (أونلاين)، اللعب، والنهاية.
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/services.dart';
import '../../core/shop.dart' show gameRulesProvider;
import '../../core/social.dart';
import '../../core/stages.dart';
import '../../core/team.dart';
import '../../core/voice.dart';
import '../shop/shop_screen.dart' show showShopSheet;
import '../../widgets/spy_ui.dart';
import '../../widgets/stage_brief.dart';
import '../../widgets/coach_card.dart';
import '../../widgets/stage_map.dart';
import '../../core/ext_locks.dart' show vaultDigit, kVaultCode;
import '../../widgets/ui_kit.dart';
import '../briefing/briefing_screen.dart';
import 'locks/locks.dart';
import 'social_bar.dart';

String fmtTime(double sec) {
  final s = sec.ceil().clamp(0, 99999).toInt();
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class PlayScreen extends ConsumerStatefulWidget {
  final GameController controller;
  const PlayScreen({super.key, required this.controller});

  @override
  ConsumerState<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends ConsumerState<PlayScreen> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  /// وميض الخطر الأحمر عند الخطأ.
  late final AnimationController _danger = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  StreamSubscription<GameEvent>? _sub;
  bool _recorded = false;
  String? _flash; // رسالة قصيرة فوق الشاشة
  String? _transition; // اسم القفل التالي أثناء مشهد «تمّ الاختراق»
  Timer? _transitionTimer;
  Color _flashColor = K.neon;
  Timer? _flashTimer;

  VoiceService? _voice;
  int? _unlocked; // المرحلة التي فُتحت بهذا الفوز
  bool _autoStageTried = false;

  GameController get c => widget.controller;

  /// المؤثّر «الصمت»: الميكروفون مقفل طوال المرحلة.
  bool get _silent => stageMods(c.stage).contains('silent');

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
    c.addListener(_onChange);
    // مع شريك من الرادار يبدأ الميكروفون مكتوماً (الرسائل السريعة متاحة دائماً)
    if (c.online) _voice = (VoiceService()..muted = c.matched || _silent)..join(c.channel);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flashTimer?.cancel();
    _transitionTimer?.cancel();
    c.removeListener(_onChange);
    _voice?.dispose();
    _shake.dispose();
    _danger.dispose();
    c.dispose();
    super.dispose();
  }

  void _showFlash(String text, Color color) {
    _flashTimer?.cancel();
    setState(() {
      _flash = text;
      _flashColor = color;
    });
    _flashTimer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  /// غرفة أونلاين: بمجرد انضمام الشريك يختار القائد تلقائياً مرحلة الفريق الحالية.
  /// (كانت الغرفة تبقى على «المهمّة الكلاسيكية» stage 0 فلا يُسجَّل الفوز ولا تُفتح المرحلة التالية.)
  Future<void> _maybeAutoStage() async {
    final s = c.state;
    if (_autoStageTried || !c.online || !c.isHost || s == null || s.phase != 'lobby' || s.stage > 0 || !c.teamReady) return;
    final partner = c.partnerUid;
    if (partner == null) return;
    _autoStageTried = true;
    try {
      final p = await ref.read(teamProgressProvider(partner).future);
      final st = c.state;
      if (!mounted || st == null || st.phase != 'lobby' || st.stage > 0) return;
      c.chooseStage(p.current < 1 ? 1 : p.current);
    } catch (_) {
      _autoStageTried = false;
    }
  }

  void _onChange() {
    _maybeAutoStage();
    final s = c.state;
    if (s == null) return;
    // مهمّة جديدة في نفس الغرفة: نسمح بتسجيل نتيجتها.
    // (كان هذا السطر بعد «if (_recorded) return» فلا يُنفَّذ أبداً، فتُسجَّل نتيجة أوّل مهمّة فقط في كل غرفة.)
    if (s.phase == 'lobby' || s.phase == 'playing') {
      _recorded = false;
      return;
    }
    if (_recorded) return;
    if (s.phase == 'won' || s.phase == 'lost') {
      _recorded = true;
      final won = s.phase == 'won';
      final stars = starsFor(won: won, finishedIn: s.finishedIn, penalty: s.penalty);
      final stage = s.stage;
      _unlocked = null;
      ref.read(progressProvider.notifier).record(won: won, finishedIn: s.finishedIn, stars: stars, mission: stage, coins: 0);
      if (won && stage > 0) {
        final partner = c.online ? c.partnerUid : null;
        if (!c.online || partner != null) {
          final before = ref.read(teamProgressProvider(partner)).valueOrNull;
          if (stage > (before?.top ?? 0)) _unlocked = stage + 1;
          TeamService.recordWin(partner: partner, stage: stage, stars: stars, seconds: s.finishedIn)
              .then((_) => ref.invalidate(teamProgressProvider(partner)))
              .catchError((_) {});
        }
      }
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) ref.invalidate(statsProvider);
      });
      final audio = ref.read(audioProvider);
      if (won) {
        audio.fx(Sfx.vault, HapticKind.heavy);
      } else {
        audio.fx(Sfx.alarm, HapticKind.heavy, volume: 0.6);
      }
    }
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    final audio = ref.read(audioProvider);
    switch (e.type) {
      case 'wrong':
        audio.fx(Sfx.error, HapticKind.heavy);
        audio.fx(Sfx.alarm, HapticKind.heavy, volume: 0.3);
        _shake.forward(from: 0);
        _danger.forward(from: 0);
        _showFlash('إنذار! −${e.pen} ثانية', K.danger);
        break;
      case 'bump':
        audio.fx(Sfx.bump, HapticKind.medium);
        _shake.forward(from: 0);
        _danger.forward(from: 0);
        _showFlash('جدار! −${e.pen} ثوانٍ', K.danger);
        break;
      case 'solved':
        final st = c.state;
        if (st != null && st.phase == 'playing') {
          // رقم الخزنة الذي كشفه هذا القفل
          if (st.rooms.last == kVaultCode && st.room < st.rooms.length - 1 && st.room > 0) {
            _showFlash('🔓 رقم مكشوف: ${vaultDigit(st.seed, st.room - 1)}', K.amber);
          }
          if (stageMods(st.stage).contains('swap') && st.rooms.length >= 4 && st.room == st.rooms.length ~/ 2) {
            Timer(const Duration(milliseconds: 1400), () {
              if (mounted) _showFlash('🔄 تبادل الأدوار!', K.agent);
            });
          }
          audio.fx(Sfx.success, HapticKind.medium);
          _transitionTimer?.cancel();
          setState(() => _transition = K.room(st.roomId));
          _transitionTimer = Timer(const Duration(milliseconds: 1400), () {
            if (mounted) setState(() => _transition = null);
          });
        }
        break;
      case 'stage':
        audio.fx(Sfx.success, HapticKind.light, volume: 0.5);
        _showFlash('المرحلة التالية', K.neon);
        break;
      case 'hint':
        audio.fx(Sfx.light, HapticKind.medium);
        _showFlash('💡 تلميح جديد', K.amber);
        break;
      case 'pause':
        audio.fx(Sfx.beep, HapticKind.medium);
        break;
      case 'resume':
        audio.fx(Sfx.success, HapticKind.light, volume: 0.5);
        _showFlash('▶ استئناف المهمّة', K.neon);
        break;
      case 'press':
        audio.fx(Sfx.beep, HapticKind.tap, volume: 0.5);
        break;
      case 'moved':
        audio.fx(Sfx.click, HapticKind.tap, volume: 0.4);
        break;
      case 'start':
        audio.play(Sfx.success, volume: 0.5);
        if (c.replayed) _showFlash('خزنة جديدة: تغيّرت الرموز والترتيب', K.neon);
        break;
      case 'twist':
        audio.fx(Sfx.alarm, HapticKind.heavy, volume: 0.6);
        _danger.forward(from: 0);
        _showFlash('الحارس غيّر الشيفرة! صِف القفل من جديد', K.danger);
        break;
      case 'bought':
        audio.fx(Sfx.light, HapticKind.light, volume: .6);
        break;
      case 'part2':
        audio.fx(Sfx.success, HapticKind.medium);
        _showFlash('الجزء الأوّل فُتح — بقي الجزء الثاني!', K.neon);
        break;
    }
  }

  Future<void> _leave() async {
    final playing = c.state?.phase == 'playing';
    if (playing) {
      final ok = await confirmDialog(context,
          title: 'إلغاء المهمّة؟', body: 'ستخسر تقدّمك في هذه المهمّة.', confirm: 'انسحاب');
      if (!ok || !mounted) return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SpyBackground(
          image: 'assets/images/panel_bg.jpg',
          dim: 0.8,
          child: SafeArea(
            child: Stack(children: [
              AnimatedBuilder(
                animation: c,
                builder: (context, _) {
                  final s = c.state;
                  Widget body;
                  if (c.error != null) {
                    body = _Message(icon: Icons.block, text: c.error!);
                  } else if (s == null || !c.joined) {
                    body = const _Message(icon: Icons.satellite_alt, text: 'جارٍ الاتصال بالمضيف…', loading: true);
                  } else if (s.phase == 'lobby') {
                    body = _Lobby(c: c, voice: _voice);
                  } else if (s.phase == 'playing') {
                    body = Stack(children: [
                      Positioned.fill(
                        child: c.table
                            ? _TableGame(c: c, shake: _shake, onExit: _leave)
                            : _Game(c: c, shake: _shake, onExit: _leave, voice: _voice),
                      ),
                      if (s.paused || c.hostLost) Positioned.fill(child: _PauseOverlay(c: c, onExit: _leave)),
                    ]);
                  } else {
                    body = _End(c: c, unlocked: _unlocked);
                  }
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: KeyedSubtree(key: ValueKey('${s?.phase}-${s?.seed}'), child: body),
                  );
                },
              ),
              if (_flash != null)
                Positioned(
                  top: 70,
                  left: 24,
                  right: 24,
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(_flash),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, v, child) => Opacity(
                          opacity: v, child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: K.surface2,
                          borderRadius: BorderRadius.circular(K.radius),
                          border: Border.all(color: _flashColor),
                          boxShadow: K.glow(_flashColor, 30, 160),
                        ),
                        child: Text(_flash!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _flashColor, fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                ),
              // وميض الخطر: حوافّ حمراء تنبض ثم تختفي
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _danger,
                    builder: (context, _) {
                      final v = _danger.isAnimating ? sin(_danger.value * pi) : 0.0;
                      if (v <= 0) return const SizedBox.shrink();
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            radius: 1.1,
                            colors: [Colors.transparent, K.danger.withAlpha((150 * v).round())],
                            stops: const [.55, 1],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (_transition != null) Positioned.fill(child: _AccessGranted(next: _transition!)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// مشهد قصير بين قفلين: قفل معدني ينفتح (الحلقة ترتفع وتدور)، ضوء أخضر، ثم اسم القفل التالي.
class _AccessGranted extends StatelessWidget {
  final String next;
  const _AccessGranted({required this.next});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1400),
        builder: (context, t, _) {
          final fadeIn = (t / 0.12).clamp(0.0, 1.0).toDouble();
          final fadeOut = ((1 - t) / 0.18).clamp(0.0, 1.0).toDouble();
          final open = Curves.easeOutBack.transform(((t - 0.12) / 0.3).clamp(0.0, 1.0).toDouble());
          final green = ((t - 0.3) / 0.15).clamp(0.0, 1.0).toDouble();
          return Opacity(
            opacity: min(fadeIn, fadeOut),
            child: Container(
              color: K.bg.withAlpha(235),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 120, height: 150, child: CustomPaint(painter: _PadlockPainter(open, green))),
                const SizedBox(height: 18),
                Opacity(
                  opacity: green,
                  child: Column(children: [
                    const MonoLabel('ACCESS GRANTED', color: K.ok, size: 13),
                    const SizedBox(height: 6),
                    const Text('تمّ الاختراق', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: ((t - 0.5) / 0.15).clamp(0.0, 1.0).toDouble(),
                  child: Column(children: [
                    const MonoLabel('NEXT TARGET', color: K.muted),
                    const SizedBox(height: 4),
                    Text(next, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: K.neon)),
                  ]),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// قفل معدني: الجسم فولاذي والحلقة ترتفع ثم تدور، والمؤشّر يتحوّل للأخضر.
class _PadlockPainter extends CustomPainter {
  final double open; // 0..1
  final double green; // 0..1
  _PadlockPainter(this.open, this.green);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = Rect.fromLTWH(w * .1, h * .45, w * .8, h * .52);
    // الحلقة
    final lift = open * h * .16;
    canvas.save();
    final pivot = Offset(w * .74, h * .45 - lift);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(-open.clamp(0.0, 1.0) * .55);
    canvas.translate(-pivot.dx, -pivot.dy);
    final shackle = Path()
      ..moveTo(w * .26, h * .5 - lift)
      ..lineTo(w * .26, h * .27 - lift)
      ..arcToPoint(Offset(w * .74, h * .27 - lift), radius: Radius.circular(w * .24))
      ..lineTo(w * .74, h * .5 - lift);
    canvas.drawPath(
        shackle,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .1
          ..strokeCap = StrokeCap.butt
          ..shader = const LinearGradient(colors: [Color(0xFF9AA1A8), Color(0xFFE1E4E7), Color(0xFF7C838A)])
              .createShader(Rect.fromLTWH(0, 0, w, h * .5)));
    canvas.restore();
    // الجسم
    final rr = RRect.fromRectAndRadius(body, Radius.circular(w * .08));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5B6168), Color(0xFF2E3237), Color(0xFF1C1F23)],
          ).createShader(body));
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF6E757C));
    // ثقب المفتاح + المؤشّر
    final c = body.center;
    canvas.drawCircle(c - Offset(0, body.height * .08), w * .06, Paint()..color = const Color(0xFF0B0C0E));
    canvas.drawRect(Rect.fromCenter(center: c + Offset(0, body.height * .08), width: w * .05, height: body.height * .22),
        Paint()..color = const Color(0xFF0B0C0E));
    final led = Color.lerp(K.danger, K.ok, green)!;
    canvas.drawCircle(Offset(body.right - w * .1, body.top + w * .1), w * .035, Paint()..color = led);
    canvas.drawCircle(Offset(body.right - w * .1, body.top + w * .1), w * .08, Paint()..color = led.withAlpha(50));
  }

  @override
  bool shouldRepaint(covariant _PadlockPainter o) => o.open != open || o.green != green;
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool loading;
  const _Message({required this.icon, required this.text, this.loading = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 52, color: K.neon),
            const SizedBox(height: 14),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            if (loading) ...[const SizedBox(height: 18), const CircularProgressIndicator(color: K.neon)],
            const SizedBox(height: 18),
            TextButton(onPressed: () => context.pop(), child: const Text('رجوع', style: TextStyle(color: K.muted))),
          ]),
        ),
      );
}

// ───────── غرفة الانتظار ─────────
class _Lobby extends ConsumerWidget {
  final GameController c;
  final VoiceService? voice;
  const _Lobby({required this.c, this.voice});

  Future<void> _pickStage(BuildContext context, WidgetRef ref) async {
    final partner = c.partnerUid;
    if (partner == null) {
      showToast(context, 'انتظر انضمام شريكك لتظهر خريطة الفريق', error: true);
      return;
    }
    TeamProgress p;
    try {
      p = await ref.read(teamProgressProvider(partner).future);
    } catch (_) {
      if (context.mounted) showToast(context, 'تعذّر تحميل تقدّم الفريق — تحقّق من الإنترنت', error: true);
      return;
    }
    if (!context.mounted) return;
    final n = await showStageMap(context, progress: p, selected: c.stage, canPick: c.isHost);
    if (n != null) c.chooseStage(n);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = c.players.entries.toList();
    final s = c.state!;
    final def = s.stage > 0 ? stageDef(s.stage) : null;
    return ListView(padding: const EdgeInsets.all(18), children: [
      Row(children: [
        IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.text2)),
        const Spacer(),
        PartnerChip(c: c),
        const SizedBox(width: 8),
        if (voice != null) VoiceButton(voice: voice!),
        const SizedBox(width: 8),
        const BalanceChip(),
      ]),
      if (c.matched)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(K.radius),
            color: K.surface,
            border: Border.all(color: K.borderStrong),
          ),
          child: const Text('شريك من الرادار: الميكروفون مكتوم افتراضياً — فعّله إن أردت، أو استعمل الرسائل السريعة. احترم شريكك.',
              style: TextStyle(fontSize: 12.5, color: K.text2)),
        ),
      HudPanel(
        label: 'ROOM CODE',
        child: Column(children: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: c.code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الرمز')));
            },
            child: Text(streamerMode.value ? '••••' : c.code,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontFamily: K.mono, fontSize: 52, color: K.text, letterSpacing: 14)),
          ),
          Text(streamerMode.value ? 'وضع البثّ: الرمز مخفي — اضغط لنسخه وأرسله لشريكك سرّاً' : 'أرسل الرمز لشريكك (اضغط لنسخه)',
              textAlign: TextAlign.center, style: const TextStyle(color: K.muted, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 14),
      HudPanel(
        label: 'TEAM',
        child: Column(children: [
          for (final e in list)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                RoleBadge(e.value.role),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.value.name}${e.key == c.meId ? ' (أنت)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(K.roleDesc(e.value.role), style: const TextStyle(color: K.muted, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          if (list.length < 2)
            // مقعد الشريك الفارغ: يشرح ما يُنتظر ويعطي فعلاً مباشراً (كانت الغرفة تبدو فارغة بلا توجيه).
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(K.radius),
                border: Border.all(color: K.borderStrong),
              ),
              child: Row(children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(list.isNotEmpty && list.first.value.role == 'ex' ? 'العميل الميداني' : 'المحلّل',
                        style: const TextStyle(fontFamily: K.mono, fontSize: 11, color: K.muted, letterSpacing: 1)),
                    const Text('بانتظار الاتصال…', style: TextStyle(color: K.text2, fontWeight: FontWeight.w700)),
                  ]),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: K.text,
                    side: const BorderSide(color: K.borderStrong),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.code));
                    showToast(context, 'نُسخ الرمز ${c.code} — أرسله لصديقك');
                  },
                  child: const Text('نسخ الرمز'),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      HudPanel(
        label: 'TARGET // الهدف',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(def == null ? 'المهمّة الكلاسيكية' : 'المرحلة ${def.n}: ${def.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (def != null)
            StageBrief(def: def)
          else
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final r in s.rooms)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(border: Border.all(color: K.line), color: K.cell),
                  child: Text(K.room(r), style: const TextStyle(fontSize: 12.5)),
                ),
            ]),
          const SizedBox(height: 6),
          Text('الصعوبة: ${s.difficulty.name} · الوقت يُحدَّد من الخادم عند البدء',
              style: const TextStyle(color: K.muted, fontSize: 12.5)),
          const SizedBox(height: 10),
          NeonButton(
              label: c.isHost ? 'اختر المرحلة من خريطة الفريق' : 'خريطة الفريق',
              icon: Icons.map_outlined,
              filled: false,
              height: 46,
              color: K.amber,
              onTap: c.teamReady ? () => _pickStage(context, ref) : null),
          if (!c.teamReady)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('تظهر الخريطة عند انضمام شريكك', textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
            ),
        ]),
      ),
      if (list.length >= 2) ...[
        const SizedBox(height: 12),
        ChatStrip(c: c),
        QuickBar(c: c),
      ],
      const SizedBox(height: 18),
      if (c.isHost) ...[
        NeonButton(label: 'تبديل الأدوار', icon: Icons.swap_horiz, filled: false, color: K.muted, onTap: list.length >= 2 ? c.swapRoles : null),
        const SizedBox(height: 10),
        if (c.notice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: K.danger.withAlpha(20),
              borderRadius: BorderRadius.circular(K.radius),
              border: Border.all(color: K.danger.withAlpha(120)),
            ),
            child: Row(children: [
              const Icon(Icons.timer_off_outlined, color: K.danger),
              const SizedBox(width: 10),
              Expanded(child: Text(c.notice!, style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700))),
              TextButton(onPressed: () => showShopSheet(context), child: const Text('المتجر', style: TextStyle(color: K.neon))),
            ]),
          ),
          const SizedBox(height: 10),
        ],
        GlowButton(label: 'ابدأ المهمّة', busy: c.starting, onTap: c.canStart ? c.hostStart : null),
        if (!c.canStart && !c.starting)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(list.length < 2 ? 'يتفعّل الزرّ عند انضمام شريكك' : 'انتظر لحظة…',
                textAlign: TextAlign.center, style: const TextStyle(color: K.muted, fontSize: 12)),
          ),
      ] else
        const Text('قائد الفريق هو من يبدأ المهمّة.', textAlign: TextAlign.center, style: TextStyle(color: K.muted)),
    ]);
  }
}

// ───────── اللعب ─────────
class _Game extends StatelessWidget {
  final GameController c;
  final AnimationController shake;
  final VoidCallback onExit;
  final VoiceService? voice;
  const _Game({required this.c, required this.shake, required this.onExit, this.voice});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final p = c.puzzles!;
    final role = c.myRole ?? 'op';
    final total = s.rooms.length;
    final silent = stageMods(c.stage).contains('silent');
    final idx = min(s.room + 1, total);
    return Column(children: [
      // ── الشريط العلوي: خروج · الشريك/الدور · المؤقّت
      Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 14, 8),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: K.border))),
        child: Row(children: [
          _SquareBtn(icon: Icons.close, label: 'انسحاب', onTap: onExit),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (c.online || c.bot) PartnerChip(c: c) else _RoleSwitch(c: c),
              const SizedBox(height: 2),
              MonoLabel('LOCK ${idx.toString().padLeft(2, '0')}/${total.toString().padLeft(2, '0')} · ERR ${s.errors}', size: 10.5),
            ]),
          ),
          _RadarTimer(c: c),
        ]),
      ),
      // ── شريط التقدّم الرفيع
      _Progress(room: s.room, total: total, codename: codenameFor(s.seed)),
      Expanded(
        child: AnimatedBuilder(
          animation: shake,
          builder: (context, child) => Transform.translate(
              offset: Offset(sin(shake.value * pi * 7) * 12 * (1 - shake.value), 0), child: child),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              layoutBuilder: (cur, prev) => cur ?? const SizedBox.shrink(),
              transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
              child: Column(
                key: ValueKey('${s.seed}-${s.room}-${s.curVariant}-$role'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── عنوان القفل + أزرار التلميح والشرح والصوت
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        MonoLabel('LOCK ${idx.toString().padLeft(2, '0')} · ${K.roleName(role)}', color: K.neon, size: 10.5),
                        const SizedBox(height: 2),
                        Text(
                            twoPartStage(s.stage) && s.room == specialRoomFor(s)
                                ? '${K.room(s.roomId)} · الجزء ${s.curVariant == 2 ? 2 : 1}/2'
                                : K.room(s.roomId),
                            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                    if (voice != null && !silent) ...[VoiceButton(voice: voice!), const SizedBox(width: 6)],
                    if (silent) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.mic_off, color: K.danger, size: 20)),
                    HintButton(c: c),
                    const SizedBox(width: 6),
                    _SquareBtn(icon: Icons.question_mark, label: 'شرح القفل', onTap: () => showLockHelp(context, s)),
                  ]),
                  const SizedBox(height: 10),
                  if (streamerMode.value) ...[const _LiveBanner(), const SizedBox(height: 8)],
                  CoachCard(lockId: s.roomId, role: role, guided: s.stage == 1),
                  if (s.hint.isNotEmpty) ...[const SizedBox(height: 8), HintBanner(text: s.hint)],
                  const SizedBox(height: 10),
                  HudPanel(
                    padding: const EdgeInsets.all(14),
                    child: LockView(state: s, puzzles: p, role: role, dispatch: c.dispatch, buy: c.sessionId == null ? null : c.buy),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      if (c.online || c.bot)
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: K.border))),
          padding: const EdgeInsets.only(top: 6, bottom: 6),
          child: Column(mainAxisSize: MainAxisSize.min, children: [ChatStrip(c: c), QuickBar(c: c)]),
        ),
    ]);
  }
}

/// لافتة وضع البثّ: تدعو المشاهدين للمشاركة في التعليقات.
class _LiveBanner extends StatelessWidget {
  const _LiveBanner();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A0E0F),
          borderRadius: BorderRadius.circular(K.radius),
          border: Border.all(color: K.danger.withAlpha(150)),
        ),
        child: const Row(children: [
          Icon(Icons.fiber_manual_record, color: K.danger, size: 14),
          SizedBox(width: 8),
          Expanded(
            child: Text('مباشر · ساعدونا في التعليقات: ما الحلّ؟ أسرع جواب صحيح يُذكر اسمه!',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

/// زرّ مربّع صغير بحدّ رفيع (انسحاب، شرح…).
class _SquareBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SquareBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(K.radius),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(K.radius),
              color: K.surface,
              border: Border.all(color: K.borderStrong),
            ),
            child: Icon(icon, color: K.text2, size: 18),
          ),
        ),
      );
}

/// وضع الطاولة: النصف العلوي للمحلّل (مقلوب باتجاهه)، والسفلي للعميل.
class _TableGame extends StatelessWidget {
  final GameController c;
  final AnimationController shake;
  final VoidCallback onExit;
  const _TableGame({required this.c, required this.shake, required this.onExit});

  Widget _half(GameState s, Puzzles p, String role) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: KeyedSubtree(
            key: ValueKey('${s.seed}-${s.room}-${s.curVariant}-$role'),
            child: HudPanel(
              color: K.role(role),
              padding: const EdgeInsets.all(12),
              label: '${K.roleName(role)} // ${K.room(s.roomId)}',
              child: LockView(state: s, puzzles: p, role: role, dispatch: c.dispatch),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final p = c.puzzles!;
    return AnimatedBuilder(
      animation: shake,
      builder: (context, child) =>
          Transform.translate(offset: Offset(sin(shake.value * pi * 7) * 10 * (1 - shake.value), 0), child: child),
      child: Column(children: [
        Expanded(child: RotatedBox(quarterTurns: 2, child: _half(s, p, 'ex'))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: const BoxDecoration(
            color: K.panelSolid,
            border: Border.symmetric(horizontal: BorderSide(color: K.line)),
          ),
          child: Row(children: [
            InkWell(onTap: onExit, child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, color: K.muted))),
            const SizedBox(width: 8),
            Expanded(child: _Progress(room: s.room, total: s.rooms.length, codename: codenameFor(s.seed))),
            const SizedBox(width: 10),
            _RadarTimer(c: c),
          ]),
        ),
        Expanded(child: _half(s, p, 'op')),
      ]),
    );
  }
}

class _RoleSwitch extends ConsumerWidget {
  final GameController c;
  const _RoleSwitch({required this.c});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = c.localRole;
    return GestureDetector(
      onTap: () {
        ref.read(audioProvider).fx(Sfx.click, HapticKind.light, volume: 0.6);
        c.toggleLocalRole();
      },
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        RoleBadge(role, big: true),
        const SizedBox(width: 6),
        const Icon(Icons.swap_horiz, color: K.muted, size: 20),
      ]),
    );
  }
}

class _Progress extends StatelessWidget {
  final int room;
  final int total;
  final String codename;
  const _Progress({required this.room, required this.total, required this.codename});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 0; i < total; i++)
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            margin: EdgeInsets.only(left: i == total - 1 ? 0 : 2),
            height: 3,
            color: i < room ? K.neon : (i == room ? K.neon.withAlpha(110) : K.border),
          ),
        ),
    ]);
  }
}

class _RadarTimer extends ConsumerStatefulWidget {
  final GameController c;
  const _RadarTimer({required this.c});

  @override
  ConsumerState<_RadarTimer> createState() => _RadarTimerState();
}

class _RadarTimerState extends ConsumerState<_RadarTimer> {
  Timer? _t;
  bool _warned60 = false;
  bool _warned30 = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final r = widget.c.remaining;
      if (!_warned60 && r <= 60 && r > 0) {
        _warned60 = true;
        ref.read(audioProvider).fx(Sfx.alarm, HapticKind.heavy, volume: 0.5);
      }
      if (!_warned30 && r <= 30 && r > 0) {
        _warned30 = true;
        ref.read(audioProvider).fx(Sfx.alarm, HapticKind.heavy, volume: 0.6);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.c.remaining;
    final frac = (r / (widget.c.state?.effectiveDuration ?? kDuration)).clamp(0.0, 1.0).toDouble();
    final warn = r < 60;
    final color = warn ? K.danger : K.neon;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(fmtTime(r),
          textDirection: TextDirection.ltr,
          style: TextStyle(
              fontFamily: K.mono,
              fontSize: 26,
              color: color)),
      const SizedBox(width: 8),
      SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _RingPainter(frac, color)),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double frac;
  final Color color;
  _RingPainter(this.frac, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..color = K.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(rect.deflate(3), 0, 2 * pi, false, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(rect.deflate(3), -pi / 2, 2 * pi * frac, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.frac != frac || old.color != color;
}

// ───────── النهاية ─────────
final GlobalKey _endShareKey = GlobalKey();

/// يحفظ بطاقة الفوز كصورة PNG ويفتح المشاركة (تيك توك، إنستغرام، واتساب…).
Future<void> _shareWin(BuildContext context, GameState s, int stars) async {
  try {
    final box = _endShareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (box == null) return;
    final image = await box.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return;
    final bytes = data.buffer.asUint8List();
    final name = s.stage > 0 ? 'المرحلة ${s.stage} «${stageDef(s.stage).name}»' : 'مهمّة';
    await Share.shareXFiles(
      [XFile.fromData(bytes, mimeType: 'image/png', name: 'khazna-win.png')],
      text: 'فتحنا الخزنة! $name في ${fmtTime(s.finishedIn.toDouble())} ${'★' * stars} — هل تستطيعون أسرع؟ #الخزنة',
    );
  } catch (_) {
    if (context.mounted) showToast(context, 'تعذّرت المشاركة', error: true);
  }
}

class _End extends ConsumerWidget {
  final GameController c;
  final int? unlocked;
  const _End({required this.c, this.unlocked});

  void _next(BuildContext context, WidgetRef ref, int n) {
    if (c.online) {
      c.chooseStage(n);
      return;
    }
    final d = stageDef(n);
    final name = ref.read(settingsProvider).name;
    final next = GameController.local(
        meName: name.isEmpty ? 'عميل' : name, rooms: d.rooms, diff: d.diff, table: c.table, missionId: n, bot: c.bot);
    context.pushReplacement('/play', extra: next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = c.state!;
    final won = s.phase == 'won';
    final stars = starsFor(won: won, finishedIn: s.finishedIn, penalty: s.penalty);
    final color = won ? K.neon : K.danger;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // صورة الخزنة الحقيقية: دافئة ذهبية عند النجاح، حمراء باهتة عند الفشل.
          // محاطة بـ RepaintBoundary لتُحفظ كصورة للمشاركة.
          RepaintBoundary(
            key: _endShareKey,
            child: ClipRRect(
            borderRadius: BorderRadius.circular(K.radius),
            child: SizedBox(
              height: 270,
              width: double.infinity,
              child: Stack(fit: StackFit.expand, children: [
                ColorFiltered(
                  colorFilter: won
                      ? const ColorFilter.matrix([1.1, .15, 0, 0, 12, .1, .9, 0, 0, 2, 0, .05, .45, 0, 0, 0, 0, 0, 1, 0])
                      : const ColorFilter.matrix([.7, .3, .1, 0, 0, .15, .25, .05, 0, 0, .15, .2, .1, 0, 0, 0, 0, 0, 1, 0]),
                  child: Image.asset('assets/images/vault.jpg',
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: K.surface)),
                ),
                // باب الخزنة ينفتح: نصفان فولاذيان ينزلقان للجانبين ويكشفان الضوء الذهبي
                if (won)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1500),
                    curve: const Interval(.25, 1, curve: Curves.easeInOutCubic),
                    builder: (context, v, _) => v >= 1
                        ? const SizedBox.shrink()
                        : Stack(fit: StackFit.expand, children: [
                            for (final left in [true, false])
                              Align(
                                alignment: left ? Alignment.centerLeft : Alignment.centerRight,
                                child: FractionallySizedBox(
                                  widthFactor: .5,
                                  heightFactor: 1,
                                  child: FractionalTranslation(
                                    translation: Offset(left ? -v : v, 0),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: left ? Alignment.centerLeft : Alignment.centerRight,
                                          end: left ? Alignment.centerRight : Alignment.centerLeft,
                                          colors: const [Color(0xFF2A2E33), Color(0xFF4A5057), Color(0xFF6B7178)],
                                        ),
                                        border: Border(
                                          left: left ? BorderSide.none : const BorderSide(color: Color(0xFF15171A), width: 2),
                                          right: left ? const BorderSide(color: Color(0xFF15171A), width: 2) : BorderSide.none,
                                        ),
                                      ),
                                      child: Align(
                                        alignment: left ? Alignment.centerRight : Alignment.centerLeft,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                                            for (int b = 0; b < 3; b++)
                                              Container(
                                                width: 26 * (1 - v),
                                                height: 10,
                                                margin: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFB9BEC4),
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                          ]),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ]),
                  ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeOut,
                  builder: (context, v, _) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(radius: .6, colors: [color.withAlpha((90 * v).round()), Colors.transparent]),
                    ),
                  ),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x990A0C0E), Color(0x000A0C0E), Color(0xFF0A0C0E)],
                      stops: [0, .35, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 14,
                  left: 14,
                  child: Row(children: [
                    MonoLabel(s.stage > 0 ? 'FILE ${s.stage.toString().padLeft(2, '0')}' : 'OPERATION', color: K.steel, size: 10.5),
                    const Spacer(),
                    MonoLabel(won ? 'ACCESS GRANTED' : 'ACCESS DENIED', color: won ? K.ok : K.danger, size: 10.5),
                  ]),
                ),
                Positioned(
                  right: 16,
                  left: 16,
                  bottom: 14,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MonoLabel(won ? 'MISSION COMPLETE' : 'MISSION FAILED', color: color, size: 11),
                    const SizedBox(height: 4),
                    Text(won ? 'فُتحت الخزنة.' : 'أُغلقت الخزنة.',
                        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    if (s.stage > 0)
                      Text(stageDef(s.stage).name, style: const TextStyle(color: K.text2, fontSize: 13.5)),
                    if (won) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('★' * stars + '☆' * (3 - stars), style: const TextStyle(color: K.neon, fontSize: 16, letterSpacing: 2)),
                        const SizedBox(width: 10),
                        MonoLabel('${fmtTime(s.finishedIn.toDouble())} · ERR ${s.errors}', color: K.steel, size: 11),
                        const Spacer(),
                        const MonoLabel('KHAZNA · الخزنة', color: K.muted, size: 10),
                      ]),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
          ),
          if (won) ...[
            const SizedBox(height: 10),
            NeonButton(label: 'شارك الفوز', icon: Icons.ios_share, filled: false, onTap: () => _shareWin(context, s, stars)),
          ],
          const SizedBox(height: 18),
          if (won)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < 3; i++)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 500 + i * 300),
                  curve: Curves.elasticOut,
                  builder: (context, v, _) => Transform.scale(
                    scale: v,
                    child: Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40, color: i < stars ? K.neon : K.borderStrong),
                  ),
                ),
            ]),
          if (won && unlocked != null) ...[
            const SizedBox(height: 14),
            UnlockBanner(stage: unlocked!),
          ],
          const SizedBox(height: 12),
          HudPanel(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              if (s.stage > 0) _Row('المرحلة', '${s.stage} · ${stageDef(s.stage).name}'),
              _Row('الوقت', won ? fmtTime(s.finishedIn.toDouble()) : '—'),
              _Row('العقوبات', '${s.penalty} ث'),
              _Row('الأقفال', '${s.room.clamp(0, s.rooms.length)}/${s.rooms.length}'),
              if (c.online || c.bot || s.stage > 0)
                _Row('الخبرة', '+${xpForSession(won: won, errors: s.errors, hints: s.hints, stage: s.stage)} XP'),
              _Row('الصعوبة', s.difficulty.name),
              _Row('العملية', codenameFor(s.seed)),
            ]),
          ),
          const SizedBox(height: 20),
          if (c.isHost && won && s.stage > 0) ...[
            NeonButton(label: 'المرحلة التالية ${s.stage + 1}', icon: Icons.arrow_back, onTap: () => _next(context, ref, s.stage + 1)),
            const SizedBox(height: 10),
          ],
          if (c.isHost)
            NeonButton(label: won ? 'إعادة المرحلة' : 'حاول مرّة أخرى', icon: Icons.refresh, filled: !(won && s.stage > 0), onTap: c.newGame)
          else
            const Text('قائد الفريق يستطيع بدء مهمّة جديدة.', style: TextStyle(color: K.muted)),
          if (c.online && c.partnerAccount != null && c.sessionId != null) ...[
            const SizedBox(height: 14),
            RatePartner(c: c),
          ],
          if (c.matched && c.partnerAccount != null) ...[
            const SizedBox(height: 10),
            NeonButton(
                label: 'أضف ${c.partnerName ?? 'شريكك'} أو أبلغ عنه',
                icon: Icons.person_add_alt_1,
                filled: false,
                color: K.muted,
                onTap: () => showPartnerMenu(context, c)),
          ],
          const SizedBox(height: 10),
          NeonButton(label: 'العودة إلى القاعدة', icon: Icons.home_outlined, filled: false, onTap: () => context.pop()),
        ]),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String k;
  final String v;
  const _Row(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Text(k, style: const TextStyle(color: K.muted)),
          const Spacer(),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}


/// زرّ الميكروفون: كتم/تشغيل، مع إشارة عندما يتكلّم الشريك.
class VoiceButton extends StatelessWidget {
  final VoiceService voice;
  const VoiceButton({super.key, required this.voice});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: voice,
      builder: (context, _) {
        final on = voice.joined && !voice.muted;
        final color = voice.error != null ? K.danger : (on ? K.neon : K.muted);
        return GestureDetector(
          onTap: () {
            if (voice.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(voice.error!)));
              return;
            }
            voice.toggleMute();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: color),
              color: color.withAlpha(voice.meSpeaking ? 60 : 20),
              boxShadow: voice.remoteSpeaking ? K.glow(K.agent, 14, 160) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (voice.starting)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.neon))
              else
                Icon(on ? Icons.mic : Icons.mic_off, size: 18, color: color),
              const SizedBox(width: 4),
              Icon(Icons.headset_mic, size: 16, color: voice.remoteCount > 0 ? (voice.remoteSpeaking ? K.agent : K.neonDim) : K.line),
            ]),
          ),
        );
      },
    );
  }
}


// ───────── التلميحات والتوقّف ─────────
class HintButton extends ConsumerStatefulWidget {
  final GameController c;
  const HintButton({super.key, required this.c});

  @override
  ConsumerState<HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends ConsumerState<HintButton> {
  bool _busy = false;

  Future<void> _buy() async {
    final cost = ref.read(gameRulesProvider).valueOrNull?.hintMinutes ?? 2;
    final ok = await confirmDialog(context,
        title: 'شراء تلميح؟',
        body: 'يكشف جزءاً من حلّ القفل الحالي لكما معاً، ويُخصم $cost دقيقة من رصيدك.',
        confirm: 'اشترِ التلميح');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final err = await widget.c.buyHint();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showToast(context, err, error: true);
  }

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: _busy || widget.c.sessionId == null ? null : _buy,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: K.amber.withAlpha(22),
            borderRadius: BorderRadius.circular(K.radius),
            border: Border.all(color: K.amber.withAlpha(110)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.amber))
                : const Icon(Icons.lightbulb_outline, color: K.amber, size: 18),
            const SizedBox(width: 4),
            const Text('تلميح', style: TextStyle(color: K.amber, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      );
}

class HintBanner extends StatelessWidget {
  final String text;
  const HintBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: TweenAnimationBuilder<double>(
          key: ValueKey(text),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Transform.scale(scale: .9 + .1 * v, child: Opacity(opacity: v.clamp(0.0, 1.0), child: child)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(K.radius),
              color: K.surface,
              border: Border.all(color: K.amber.withAlpha(140)),
            ),
            child: Row(children: [
              const Icon(Icons.lightbulb, color: K.amber),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
          ),
        ),
      );
}

/// شاشة التوقّف: نفاد الرصيد (مع زر الشحن) أو انقطاع الشريك. تُستأنف المهمّة من نفس النقطة.
class _PauseOverlay extends StatelessWidget {
  final GameController c;
  final VoidCallback onExit;
  const _PauseOverlay({required this.c, required this.onExit});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final balance = s.pauseReason == 'balance';
    final lost = c.hostLost;
    final (icon, title, body, color) = lost
        ? (Icons.wifi_off_rounded, 'انقطع الاتصال بالقائد', 'ننتظر عودة الاتصال… الوقت لا يُخصم أثناء الانقطاع.', K.agent)
        : balance
            ? (Icons.timer_off_outlined, 'نفد الرصيد', c.meBroke
                ? 'رصيدك انتهى. اشحن دقائق وستُستأنف المهمّة من نفس النقطة.'
                : 'رصيد شريكك انتهى. ننتظر أن يشحن ليُستأنف اللعب.', K.danger)
            : (Icons.person_off_outlined, 'الشريك غير متّصل', 'المؤقّت متوقّف حتى يعود شريكك. لا يُخصم أي وقت.', K.amber);
    return Container(
      color: K.bg.withAlpha(225),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: GlassCard(
          accent: color,
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 56),
            const SizedBox(height: 12),
            const MonoLabel('MISSION PAUSED // متوقّفة', size: 11),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(color: K.text2, height: 1.5)),
            const SizedBox(height: 8),
            Text('الوقت المتبقّي محفوظ: ${fmtTime(c.remaining)}', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
            const SizedBox(height: 18),
            if (balance && c.meBroke) ...[
              GlowButton(label: 'اشحن الآن', icon: Icons.bolt, onTap: () => showShopSheet(context)),
              const SizedBox(height: 10),
            ],
            if (!lost && !balance) const LinearProgressIndicator(color: K.amber, backgroundColor: K.border),
            const SizedBox(height: 10),
            TextButton(onPressed: onExit, child: const Text('الخروج من المهمّة', style: TextStyle(color: K.muted))),
          ]),
        ),
      ),
    );
  }
}
