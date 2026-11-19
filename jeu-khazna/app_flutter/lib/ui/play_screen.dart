import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/game.dart';
import 'rooms.dart';
import 'theme.dart';

String fmtTime(double sec) {
  final s = sec.ceil().clamp(0, 99999);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

class PlayScreen extends StatefulWidget {
  final GameController controller;
  const PlayScreen({super.key, required this.controller});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  StreamSubscription<GameEvent>? _sub;

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _sub = c.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _shake.dispose();
    c.dispose();
    super.dispose();
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    void banner(String text, Color color, [Color fg = Colors.white]) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(text,
            textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
    }

    switch (e.type) {
      case 'wrong':
        HapticFeedback.heavyImpact();
        _shake.forward(from: 0);
        banner('❌ خطأ! −${e.pen} ثانية', K.bad);
        break;
      case 'bump':
        HapticFeedback.mediumImpact();
        _shake.forward(from: 0);
        banner('💥 اصطدمت بجدار! −${e.pen} ثوانٍ', K.bad);
        break;
      case 'solved':
        HapticFeedback.mediumImpact();
        if (c.state?.phase == 'playing') banner('✅ فُتح القفل!', K.good, const Color(0xFF062014));
        break;
      case 'stage':
        HapticFeedback.lightImpact();
        banner('✨ المرحلة التالية', K.good, const Color(0xFF062014));
        break;
      case 'press':
      case 'moved':
        HapticFeedback.selectionClick();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final s = c.state;
        Widget body;
        if (c.error != null) {
          body = _Message(icon: Icons.block, text: c.error!);
        } else if (s == null || !c.joined) {
          body = const _Message(icon: Icons.hourglass_top, text: 'جاري الاتصال بالمضيف…', loading: true);
        } else if (s.phase == 'lobby') {
          body = _Lobby(c: c);
        } else if (s.phase == 'playing') {
          body = _Game(c: c, shake: _shake);
        } else {
          body = _End(c: c);
        }
        return Scaffold(
          appBar: AppBar(
            backgroundColor: K.bg,
            elevation: 0,
            title: Text(c.online ? 'غرفة ${c.code}' : 'هاتف واحد', style: const TextStyle(fontSize: 17)),
            centerTitle: true,
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: KeyedSubtree(key: ValueKey(s?.phase ?? 'none'), child: body),
            ),
          ),
        );
      },
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
            Icon(icon, size: 48, color: K.gold),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
            if (loading) ...[const SizedBox(height: 16), const CircularProgressIndicator()],
          ]),
        ),
      );
}

// ───────── غرفة الانتظار ─────────
class _Lobby extends StatelessWidget {
  final GameController c;
  const _Lobby({required this.c});

  @override
  Widget build(BuildContext context) {
    final list = c.players.entries.toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Panel(
          child: Column(children: [
            const Text('رمز الغرفة', style: TextStyle(color: K.muted)),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: c.code));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نُسخ الرمز')));
              },
              child: Text(c.code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: K.gold, letterSpacing: 10)),
            ),
            const Text('أرسل هذا الرمز لصديقك (اضغط لنسخه)', style: TextStyle(color: K.muted, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 12),
        for (final e in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Panel(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                RoleChip(e.value.role),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e.value.name}${e.key == c.meId ? ' (أنت)' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(K.roleDesc(e.value.role), style: const TextStyle(color: K.muted, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
          ),
        if (list.length < 2)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('في انتظار اللاعب الثاني…', textAlign: TextAlign.center, style: TextStyle(color: K.muted)),
          ),
        const SizedBox(height: 8),
        if (c.isHost) ...[
          OutlinedButton.icon(
              style: outlineButton(), onPressed: c.swapRoles, icon: const Icon(Icons.swap_horiz), label: const Text('تبديل الأدوار')),
          const SizedBox(height: 10),
          FilledButton(style: bigButton(), onPressed: c.canStart ? c.hostStart : null, child: const Text('ابدأ اللعبة')),
        ] else
          const Text('المضيف هو من يبدأ اللعبة.', textAlign: TextAlign.center, style: TextStyle(color: K.muted)),
      ],
    );
  }
}

// ───────── اللعب ─────────
class _Game extends StatelessWidget {
  final GameController c;
  final AnimationController shake;
  const _Game({required this.c, required this.shake});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final p = c.puzzles!;
    final role = c.myRole ?? 'op';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(children: [
          if (c.online) RoleChip(role) else _RoleToggle(c: c),
          const Spacer(),
          _Progress(room: s.room),
          const Spacer(),
          _TimerText(c: c),
        ]),
      ),
      Expanded(
        child: AnimatedBuilder(
          animation: shake,
          builder: (context, child) =>
              Transform.translate(offset: Offset(sin(shake.value * pi * 6) * 10 * (1 - shake.value), 0), child: child),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Panel(
              border: K.role(role).withAlpha(90),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${s.seed}-${s.room}-$role'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('${s.room + 1}. ${kRoomNames[s.roomId]}',
                        style: const TextStyle(color: K.gold, fontSize: 21, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    RoomView(state: s, puzzles: p, role: role, dispatch: c.dispatch),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _RoleToggle extends StatelessWidget {
  final GameController c;
  const _RoleToggle({required this.c});

  @override
  Widget build(BuildContext context) {
    final role = c.localRole;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () {
        HapticFeedback.selectionClick();
        c.toggleLocalRole();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: K.role(role).withAlpha(45),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: K.role(role)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.swap_horiz, size: 18, color: K.role(role)),
          const SizedBox(width: 4),
          Text(K.roleName(role), style: TextStyle(color: K.role(role), fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final int room;
  const _Progress({required this.room});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < kRooms.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == room ? 22 : 11,
              height: 11,
              decoration: BoxDecoration(
                color: i < room ? K.good : (i == room ? K.gold : K.line),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
        ],
      );
}

class _TimerText extends StatefulWidget {
  final GameController c;
  const _TimerText({required this.c});

  @override
  State<_TimerText> createState() => _TimerTextState();
}

class _TimerTextState extends State<_TimerText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) {
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
    final r = widget.c.remaining;
    final warn = r < 60;
    return Text(
      fmtTime(r),
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w900,
        color: warn ? K.bad : K.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ───────── النهاية ─────────
class _End extends StatelessWidget {
  final GameController c;
  const _End({required this.c});

  @override
  Widget build(BuildContext context) {
    final s = c.state!;
    final won = s.phase == 'won';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.elasticOut,
            builder: (context, v, _) => Transform.rotate(
              angle: won ? (1 - v) * -1.2 : 0,
              child: Transform.scale(
                scale: 0.5 + v * 0.5,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: K.card,
                    border: Border.all(color: won ? K.good : K.bad, width: 4),
                    boxShadow: [BoxShadow(color: (won ? K.good : K.bad).withAlpha(70), blurRadius: 40)],
                  ),
                  child: Icon(won ? Icons.lock_open : Icons.timer_off, size: 64, color: won ? K.good : K.bad),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(won ? 'فُتحت الخزنة!' : 'انتهى الوقت…',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: won ? K.good : K.bad)),
          const SizedBox(height: 8),
          Text(
            won
                ? 'الوقت: ${fmtTime(s.finishedIn.toDouble())} · العقوبات: ${s.penalty} ثانية'
                : 'وصلتم إلى: ${kRoomNames[kRooms[min(s.room, kRooms.length - 1)]]}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: K.muted, fontSize: 16),
          ),
          const SizedBox(height: 26),
          if (c.isHost)
            FilledButton(style: bigButton(), onPressed: c.newGame, child: const Text('لعبة جديدة (ألغاز مختلفة)'))
          else
            const Text('المضيف يستطيع بدء لعبة جديدة.', style: TextStyle(color: K.muted)),
          const SizedBox(height: 10),
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع إلى البداية')),
        ]),
      ),
    );
  }
}
