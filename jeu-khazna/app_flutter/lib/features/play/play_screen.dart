// شاشة المهمّة: غرفة الانتظار (أونلاين)، اللعب، والنهاية.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/services.dart';
import '../../core/shop.dart' show gameRulesProvider;
import '../../core/stages.dart';
import '../../core/team.dart';
import '../../core/voice.dart';
import '../shop/shop_screen.dart' show showShopSheet;
import '../../widgets/spy_ui.dart';
import '../../widgets/stage_map.dart';
import '../../widgets/ui_kit.dart';
import '../briefing/briefing_screen.dart';
import 'locks/locks.dart';

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

class _PlayScreenState extends ConsumerState<PlayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  StreamSubscription<GameEvent>? _sub;
  bool _recorded = false;
  String? _flash; // رسالة قصيرة فوق الشاشة
  String? _transition; // اسم القفل التالي أثناء مشهد «تمّ الاختراق»
  Timer? _transitionTimer;
  Color _flashColor = K.neon;
  Timer? _flashTimer;

  VoiceService? _voice;
  int? _unlocked; // المرحلة التي فُتحت بهذا الفوز

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
    c.addListener(_onChange);
    if (c.online) _voice = VoiceService()..join(c.code);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flashTimer?.cancel();
    _transitionTimer?.cancel();
    c.removeListener(_onChange);
    _voice?.dispose();
    _shake.dispose();
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

  void _onChange() {
    final s = c.state;
    if (s == null || _recorded) return;
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
      final audio = ref.read(audioProvider);
      if (won) {
        audio.fx(Sfx.vault, HapticKind.heavy);
      } else {
        audio.fx(Sfx.alarm, HapticKind.heavy, volume: 0.6);
      }
    }
    if (s.phase == 'lobby' || s.phase == 'playing') _recorded = false;
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    final audio = ref.read(audioProvider);
    switch (e.type) {
      case 'wrong':
        audio.fx(Sfx.error, HapticKind.heavy);
        _shake.forward(from: 0);
        _showFlash('إنذار! −${e.pen} ثانية', K.danger);
        break;
      case 'bump':
        audio.fx(Sfx.bump, HapticKind.medium);
        _shake.forward(from: 0);
        _showFlash('جدار! −${e.pen} ثوانٍ', K.danger);
        break;
      case 'solved':
        final st = c.state;
        if (st != null && st.phase == 'playing') {
          audio.fx(Sfx.success, HapticKind.medium);
          _transitionTimer?.cancel();
          setState(() => _transition = K.roomNames[st.roomId] ?? '');
          _transitionTimer = Timer(const Duration(milliseconds: 1250), () {
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
                          color: _flashColor.withAlpha(235),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: K.glow(_flashColor, 30, 160),
                        ),
                        child: Text(_flash!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF02110A), fontSize: 18, fontWeight: FontWeight.w900)),
                      ),
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

/// مشهد قصير بين قفلين: «تمّ الاختراق» ثم اسم القفل التالي.
class _AccessGranted extends StatelessWidget {
  final String next;
  const _AccessGranted({required this.next});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1250),
        builder: (context, t, _) {
          final fadeIn = (t / 0.15).clamp(0.0, 1.0).toDouble();
          final fadeOut = ((1 - t) / 0.2).clamp(0.0, 1.0).toDouble();
          final o = min(fadeIn, fadeOut);
          return Opacity(
            opacity: o,
            child: Container(
              color: K.bg.withAlpha(225),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Transform.rotate(
                  angle: Curves.easeOutCubic.transform(min(1.0, t / 0.6)) * pi,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: K.glow(K.neon, 40, 160)),
                    child: ClipOval(
                      child: Image.asset('assets/images/vault.jpg',
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.lock_open, size: 70, color: K.neon)),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const MonoLabel('ACCESS GRANTED', color: K.neon, size: 16),
                const SizedBox(height: 6),
                const Text('تمّ اختراق القفل',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: K.neon)),
                const SizedBox(height: 16),
                Opacity(
                  opacity: (t - 0.35).clamp(0.0, 1.0).toDouble() > 0 ? 1 : 0,
                  child: Column(children: [
                    const MonoLabel('NEXT TARGET', color: K.muted),
                    const SizedBox(height: 4),
                    Text(next, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: K.amber)),
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
        IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
        const Spacer(),
        if (voice != null) VoiceButton(voice: voice!),
        const SizedBox(width: 8),
        const BalanceChip(),
      ]),
      HudPanel(
        label: 'ROOM CODE',
        child: Column(children: [
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: c.code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الرمز')));
            },
            child: Text(c.code,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                    fontFamily: K.mono,
                    fontSize: 60,
                    color: K.neon,
                    letterSpacing: 14,
                    shadows: [Shadow(color: K.neon.withAlpha(160), blurRadius: 20)])),
          ),
          const Text('أرسل الرمز لشريكك (اضغط لنسخه)', style: TextStyle(color: K.muted, fontSize: 13)),
        ]),
      ),
      const SizedBox(height: 14),
      HudPanel(
        label: 'TEAM',
        color: K.agent,
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: K.agent)),
                SizedBox(width: 10),
                Text('في انتظار الشريك…', style: TextStyle(color: K.muted)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      HudPanel(
        label: 'TARGET // الهدف',
        color: def?.region.color ?? K.neon,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(def == null ? 'المهمّة الكلاسيكية' : 'المرحلة ${def.n}: ${def.name}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: def?.region.color ?? K.neon)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in s.rooms)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: K.line), color: K.cell),
                child: Text(K.roomNames[r] ?? r, style: const TextStyle(fontSize: 12.5)),
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
      const SizedBox(height: 18),
      if (c.isHost) ...[
        NeonButton(label: 'تبديل الأدوار', icon: Icons.swap_horiz, filled: false, color: K.agent, onTap: c.swapRoles),
        const SizedBox(height: 10),
        if (c.notice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: K.danger.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
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
        GlowButton(label: 'ابدأ المهمّة', icon: Icons.bolt, busy: c.starting, onTap: c.canStart ? c.hostStart : null),
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
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        child: Row(children: [
          InkWell(onTap: onExit, child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.close, color: K.muted))),
          const SizedBox(width: 4),
          if (c.online) RoleBadge(role) else _RoleSwitch(c: c),
          if (voice != null) ...[const SizedBox(width: 8), VoiceButton(voice: voice!)],
          const SizedBox(width: 8),
          HintButton(c: c),
          const Spacer(),
          _RadarTimer(c: c),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: _Progress(room: s.room, total: s.rooms.length, codename: codenameFor(s.seed)),
      ),
      if (s.hint.isNotEmpty) HintBanner(text: s.hint),
      Expanded(
        child: AnimatedBuilder(
          animation: shake,
          builder: (context, child) => Transform.translate(
              offset: Offset(sin(shake.value * pi * 7) * 12 * (1 - shake.value), 0), child: child),
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: max(0.0, box.maxHeight - 20)),
              child: Center(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(anim), child: child),
              ),
              child: KeyedSubtree(
                key: ValueKey('${s.seed}-${s.room}-$role'),
                child: HudPanel(
                  color: K.role(role),
                  label: '${(s.room + 1).toString().padLeft(2, '0')} // ${K.roomNames[s.roomId]}',
                  child: LockView(state: s, puzzles: p, role: role, dispatch: c.dispatch),
                ),
              ),
            )),
            ),
          ),
          ),
        ),
      ),
    ]);
  }
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
            key: ValueKey('${s.seed}-${s.room}-$role'),
            child: HudPanel(
              color: K.role(role),
              padding: const EdgeInsets.all(12),
              label: '${K.roleName(role)} // ${K.roomNames[s.roomId]}',
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        MonoLabel(codename, color: K.muted, size: 11),
        const Spacer(),
        MonoLabel('${room.clamp(0, total)}/$total', color: K.neon, size: 12),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        for (int i = 0; i < total; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 6,
              decoration: BoxDecoration(
                color: i < room ? K.neon : (i == room ? K.amber : K.line),
                boxShadow: i < room ? K.glow(K.neon, 8, 120) : (i == room ? K.glow(K.amber, 8, 100) : null),
              ),
            ),
          ),
      ]),
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
    final color = warn ? K.danger : (r < 180 ? K.amber : K.neon);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(fmtTime(r),
          textDirection: TextDirection.ltr,
          style: TextStyle(
              fontFamily: K.mono,
              fontSize: 26,
              color: color,
              shadows: [Shadow(color: color.withAlpha(150), blurRadius: 14)])),
      const SizedBox(width: 8),
      SizedBox(
        width: 34,
        height: 34,
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
      ..color = K.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawArc(rect.deflate(3), 0, 2 * pi, false, bg);
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect.deflate(3), -pi / 2, 2 * pi * frac, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.frac != frac || old.color != color;
}

// ───────── النهاية ─────────
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
        meName: name.isEmpty ? 'عميل' : name, rooms: d.rooms, diff: d.diff, table: c.table, missionId: n);
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
          MonoLabel(won ? 'MISSION COMPLETE' : 'MISSION FAILED', color: color, size: 14),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeOutBack,
            builder: (context, v, _) => Transform.rotate(
              angle: won ? (1 - v) * -2.4 : 0,
              child: Transform.scale(
                scale: 0.6 + 0.4 * v,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: K.glow(color, 50, 150)),
                  child: ClipOval(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(won ? Colors.transparent : K.danger.withAlpha(90), BlendMode.srcATop),
                      child: Image.asset('assets/images/vault.jpg',
                          fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.lock_open, size: 90, color: color)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 2.2, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeIn,
            builder: (context, v, child) => Transform.rotate(angle: -0.12, child: Transform.scale(scale: v, child: child)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: color, width: 3)),
              child: Text(won ? 'تمّت المهمّة' : 'فشلت المهمّة',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color)),
            ),
          ),
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
                        size: 54, color: i < stars ? K.amber : K.line),
                  ),
                ),
            ]),
          if (won && unlocked != null) ...[
            const SizedBox(height: 14),
            UnlockBanner(stage: unlocked!),
          ],
          const SizedBox(height: 12),
          HudPanel(
            color: color,
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              if (s.stage > 0) _Row('المرحلة', '${s.stage} · ${stageDef(s.stage).name}'),
              _Row('الوقت', won ? fmtTime(s.finishedIn.toDouble()) : '—'),
              _Row('العقوبات', '${s.penalty} ث'),
              _Row('الأقفال', '${s.room.clamp(0, s.rooms.length)}/${s.rooms.length}'),
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
            borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(14),
              color: K.amber.withAlpha(26),
              border: Border.all(color: K.amber.withAlpha(140)),
              boxShadow: [BoxShadow(color: K.amber.withAlpha(50), blurRadius: 16)],
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
