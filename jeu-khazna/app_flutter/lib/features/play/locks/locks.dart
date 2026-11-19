// الأقفال الخمسة: لكل قفل جهاز للعميل الميداني وملفّ للمحلّل.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/game.dart';
import '../../../core/services.dart';
import '../../../widgets/spy_ui.dart';

typedef Dispatch = void Function(Map<String, dynamic> action);

class LockView extends StatelessWidget {
  final GameState state;
  final Puzzles puzzles;
  final String role;
  final Dispatch dispatch;
  const LockView({super.key, required this.state, required this.puzzles, required this.role, required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final op = role == 'op';
    switch (state.roomId) {
      case 'keypad':
        return op ? KeypadOp(p: puzzles, dispatch: dispatch) : KeypadEx(p: puzzles);
      case 'wires':
        return op ? WiresOp(p: puzzles, state: state, dispatch: dispatch) : WiresEx(p: puzzles);
      case 'cipher':
        return op ? CipherOp(p: puzzles, dispatch: dispatch) : CipherEx(p: puzzles);
      case 'maze':
        return op ? MazeOp(dispatch: dispatch) : MazeEx(p: puzzles, state: state);
      default:
        return op ? LightsOp(p: puzzles, state: state, dispatch: dispatch) : LightsEx(p: puzzles, state: state);
    }
  }
}

// ───── عناصر مشتركة ─────
class Brief extends StatelessWidget {
  final String text;
  final IconData icon;
  const Brief(this.text, {super.key, this.icon = Icons.info_outline});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 18, color: K.neonDim)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFBFDCD0), fontSize: 15, height: 1.55))),
        ]),
      );
}

class Cell extends StatelessWidget {
  final Widget child;
  final Color border;
  final Color color;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadow;
  const Cell(
      {super.key,
      required this.child,
      this.border = K.line,
      this.color = K.cell,
      this.padding = const EdgeInsets.all(6),
      this.shadow});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, border: Border.all(color: border), boxShadow: shadow),
        child: child,
      );
}

class FixedGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;
  final double spacing;
  final double aspect;
  const FixedGrid({super.key, required this.columns, required this.children, this.spacing = 6, this.aspect = 1});

  @override
  Widget build(BuildContext context) => GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspect,
        children: children,
      );
}

class SymbolCell extends StatelessWidget {
  final Sym sym;
  final String? value;
  final bool selected;
  final VoidCallback? onTap;
  const SymbolCell({super.key, required this.sym, this.value, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cell = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: selected ? K.amber.withAlpha(35) : K.cell,
        border: Border.all(color: selected ? K.amber : K.line),
        boxShadow: selected ? K.glow(K.amber, 12, 90) : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(sym.s, style: TextStyle(fontSize: 26, height: 1.1, color: selected ? K.amber : K.text)),
        Text(sym.n, style: const TextStyle(color: K.muted, fontSize: 11)),
        if (value != null) Text(value!, style: const TextStyle(fontFamily: K.mono, color: K.amber, fontSize: 21)),
      ]),
    );
    if (onTap == null) return cell;
    return GestureDetector(onTap: onTap, child: cell);
  }
}

/// زرّ جهاز معدني.
class DeviceKey extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color color;
  final Sfx sfx;
  const DeviceKey({super.key, required this.onTap, required this.child, this.color = const Color(0xFF1A2420), this.sfx = Sfx.beep});

  @override
  ConsumerState<DeviceKey> createState() => _DeviceKeyState();
}

class _DeviceKeyState extends ConsumerState<DeviceKey> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        ref.read(audioProvider).fx(widget.sfx, HapticKind.tap, volume: 0.55);
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, _down ? 2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(widget.color, Colors.white, 0.12)!, widget.color, Color.lerp(widget.color, Colors.black, 0.35)!],
          ),
          border: Border.all(color: _down ? K.neon : const Color(0xFF2A3A34)),
          boxShadow: _down
              ? K.glow(K.neon, 12, 90)
              : const [BoxShadow(color: Colors.black, offset: Offset(0, 3), blurRadius: 2)],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

// ───── 1. لوحة الدخول ─────
class KeypadOp extends StatefulWidget {
  final Puzzles p;
  final Dispatch dispatch;
  const KeypadOp({super.key, required this.p, required this.dispatch});

  @override
  State<KeypadOp> createState() => _KeypadOpState();
}

class _KeypadOpState extends State<KeypadOp> {
  String entry = '';

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        if (entry.isNotEmpty) entry = entry.substring(0, entry.length - 1);
      } else if (k == 'OK') {
        if (entry.length == 4) {
          widget.dispatch({'type': 'submit', 'value': entry});
          entry = '';
        }
      } else if (entry.length < 4) {
        entry += k;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Brief('صِف هذه الرموز للمحلّل بالترتيب (من اليسار إلى اليمين)، ثم أدخل الرمز الذي يمليه عليك.',
          icon: Icons.record_voice_over_outlined),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final i in widget.p.keypad.shown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Cell(
                padding: EdgeInsets.zero,
                border: K.neonDim,
                shadow: K.glow(K.neon, 10, 50),
                child: SizedBox(
                    width: 62,
                    height: 62,
                    child: Center(
                        child: Text(kSymbols[i].s,
                            style: TextStyle(
                                fontSize: 34, color: K.neon, shadows: [Shadow(color: K.neon.withAlpha(150), blurRadius: 12)])))),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      // شاشة LED
      Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF020805),
          border: Border.all(color: const Color(0xFF1C2C26), width: 3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: entry.length == 4 ? K.neon : K.danger,
                boxShadow: K.glow(entry.length == 4 ? K.neon : K.danger, 8, 200)),
          ),
          const SizedBox(width: 16),
          Text(entry.padRight(4, '_'),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontFamily: K.mono,
                  fontSize: 44,
                  letterSpacing: 18,
                  color: K.neon,
                  shadows: [Shadow(color: K.neon.withAlpha(200), blurRadius: 16)])),
        ]),
      ),
      const SizedBox(height: 14),
      Directionality(
        textDirection: TextDirection.ltr,
        child: FixedGrid(
          columns: 3,
          spacing: 9,
          aspect: 1.75,
          children: [
            for (final k in keys)
              DeviceKey(
                onTap: () => _key(k),
                color: k == 'OK' ? const Color(0xFF0E5E3C) : const Color(0xFF1A2420),
                sfx: k == 'OK' ? Sfx.click : Sfx.beep,
                child: k == '⌫'
                    ? const Icon(Icons.backspace_outlined, color: K.text)
                    : Text(k,
                        style: TextStyle(
                            fontFamily: K.mono, fontSize: 26, color: k == 'OK' ? K.neon : K.text, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    ]);
  }
}

class KeypadEx extends StatelessWidget {
  final Puzzles p;
  const KeypadEx({super.key, required this.p});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brief('ملف شيفرة اللوحة: العميل سيصف لك 4 رموز. أمْلِ عليه الرقم المقابل لكل رمز، بنفس الترتيب.',
            icon: Icons.folder_open),
        FixedGrid(columns: 4, aspect: 0.8, children: [
          for (int i = 0; i < kSymbols.length; i++) SymbolCell(sym: kSymbols[i], value: '${p.keypad.manual[i]}'),
        ]),
      ]);
}

// ───── 2. صندوق الإنذار ─────
class WiresOp extends StatelessWidget {
  final Puzzles p;
  final GameState state;
  final Dispatch dispatch;
  const WiresOp({super.key, required this.p, required this.state, required this.dispatch});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brief('صِف للمحلّل عدد الأسلاك وألوانها من الأعلى إلى الأسفل، ثم اضغط على السلك الذي يأمرك بقطعه.',
            icon: Icons.record_voice_over_outlined),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B0F0E),
            border: Border.all(color: const Color(0xFF26332E), width: 3),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: [
            for (int i = 0; i < p.wires.wires.length; i++)
              _WireRow(
                index: i,
                color: Color(kColors[p.wires.wires[i]].argb),
                colorName: kColors[p.wires.wires[i]].n,
                cut: state.cut.contains(i),
                onCut: () => dispatch({'type': 'cut', 'idx': i}),
              ),
          ]),
        ),
      ]);
}

class _WireRow extends ConsumerStatefulWidget {
  final int index;
  final Color color;
  final String colorName;
  final bool cut;
  final VoidCallback onCut;
  const _WireRow({required this.index, required this.color, required this.colorName, required this.cut, required this.onCut});

  @override
  ConsumerState<_WireRow> createState() => _WireRowState();
}

class _WireRowState extends ConsumerState<_WireRow> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  final _seed = Random().nextInt(1 << 20);

  @override
  void initState() {
    super.initState();
    if (widget.cut) _a.value = 1;
  }

  @override
  void didUpdateWidget(covariant _WireRow old) {
    super.didUpdateWidget(old);
    if (widget.cut && !old.cut) _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (widget.cut) return;
    final ok = await confirmDialog(context,
        title: 'قطع السلك رقم ${widget.index + 1} (${widget.colorName})؟',
        body: 'إذا كان السلك الخطأ سينطلق الإنذار وتخسر 30 ثانية.',
        confirm: 'اقطع');
    if (!ok || !mounted) return;
    ref.read(audioProvider).fx(Sfx.cut, HapticKind.heavy);
    widget.onCut();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.cut ? null : _tap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(children: [
          SizedBox(width: 22, child: MonoLabel('${widget.index + 1}', color: K.muted, size: 15)),
          Expanded(
            child: SizedBox(
              height: 34,
              child: AnimatedBuilder(
                animation: _a,
                builder: (context, _) => CustomPaint(painter: _WirePainter(widget.color, widget.cut ? _a.value : 0, _seed)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(widget.cut ? Icons.content_cut : Icons.touch_app_outlined,
              color: widget.cut ? K.danger : K.muted, size: 20),
        ]),
      ),
    );
  }
}

class _WirePainter extends CustomPainter {
  final Color color;
  final double cut; // 0..1 تقدّم حركة القطع
  final int seed;
  _WirePainter(this.color, this.cut, this.seed);

  @override
  void paint(Canvas canvas, Size s) {
    // مسامير الأطراف
    final term = Paint()..color = const Color(0xFF8A9A94);
    canvas.drawCircle(Offset(6, s.height / 2), 6, term);
    canvas.drawCircle(Offset(s.width - 6, s.height / 2), 6, term);
    final wire = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = Colors.black.withAlpha(110)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    final mid = s.width / 2;
    final sag = s.height * 0.35;
    final gap = cut > 0 ? 10.0 + 14 * Curves.easeOut.transform(cut.clamp(0.0, 1.0).toDouble()) : 0.0;
    Path half(double x0, double x1, double drop) => Path()
      ..moveTo(x0, s.height / 2)
      ..quadraticBezierTo((x0 + x1) / 2, s.height / 2 + sag + drop, x1, s.height / 2 + drop * 0.6);
    final drop = cut * 6;
    final left = half(6, mid - gap / 2, cut > 0 ? drop : 0);
    final right = half(mid + gap / 2, s.width - 6, cut > 0 ? drop : 0);
    canvas.drawPath(left.shift(const Offset(0, 2)), shade);
    canvas.drawPath(right.shift(const Offset(0, 2)), shade);
    canvas.drawPath(left, wire);
    canvas.drawPath(right, wire);
    final hl = Paint()
      ..color = Colors.white.withAlpha(60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(left.shift(const Offset(0, -2)), hl);
    canvas.drawPath(right.shift(const Offset(0, -2)), hl);
    // شرارات القطع
    if (cut > 0 && cut < 1) {
      final r = Random(seed);
      final spark = Paint()..strokeCap = StrokeCap.round;
      for (int i = 0; i < 16; i++) {
        final ang = r.nextDouble() * 2 * pi;
        final dist = (8 + r.nextDouble() * 30) * cut;
        final o = Offset(mid, s.height / 2 + sag * 0.9);
        final p = o + Offset(cos(ang) * dist, sin(ang) * dist);
        spark
          ..color = Color.lerp(K.amber, Colors.white, r.nextDouble())!.withAlpha(((1 - cut) * 255).round())
          ..strokeWidth = 2;
        canvas.drawLine(o + Offset(cos(ang) * dist * 0.6, sin(ang) * dist * 0.6), p, spark);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WirePainter old) => old.cut != cut || old.color != color;
}

class WiresEx extends StatelessWidget {
  final Puzzles p;
  const WiresEx({super.key, required this.p});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brief('دليل نزع الإنذار: اسأل العميل عن عدد الأسلاك وألوانها. السلك رقم 1 هو الأعلى. طبّق أوّل قاعدة صحيحة فقط.',
            icon: Icons.folder_open),
        for (int n = 3; n <= 6; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Cell(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إذا كان هناك $n أسلاك', style: const TextStyle(fontWeight: FontWeight.w800, color: K.amber)),
                const SizedBox(height: 4),
                for (int i = 0; i < p.wires.rules[n]!.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      MonoLabel('${i + 1}.', color: K.muted, size: 13),
                      const SizedBox(width: 6),
                      Expanded(child: Text(p.wires.rules[n]![i].text, style: const TextStyle(height: 1.4))),
                    ]),
                  ),
              ]),
            ),
          ),
      ]);
}

// ───── 3. الرسالة المعترَضة ─────
class CipherOp extends StatefulWidget {
  final Puzzles p;
  final Dispatch dispatch;
  const CipherOp({super.key, required this.p, required this.dispatch});

  @override
  State<CipherOp> createState() => _CipherOpState();
}

class _CipherOpState extends State<CipherOp> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _ctl.text.trim();
    if (v.isEmpty) return;
    widget.dispatch({'type': 'submit', 'value': v});
    _ctl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.p.cipher;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Brief('اعترضنا رسالة مشفّرة. صِف الرمز للمحلّل، ثم اقرأ له الحروف واحداً واحداً من اليمين إلى اليسار.',
          icon: Icons.record_voice_over_outlined),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFF020805), border: Border.all(color: K.neonDim)),
        child: Column(children: [
          const MonoLabel('>> INTERCEPTED TRANSMISSION', size: 11),
          const SizedBox(height: 12),
          Text(kSymbols[c.sym].s,
              style: TextStyle(fontSize: 56, color: K.neon, shadows: [Shadow(color: K.neon.withAlpha(180), blurRadius: 20)])),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            for (final ch in c.cipher.split(''))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(border: Border.all(color: K.neon.withAlpha(120)), color: K.neon.withAlpha(12)),
                child: Text(ch, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: K.neon)),
              ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 18),
            decoration: fieldDecoration('الكلمة بعد فكّ الشيفرة', icon: Icons.key),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 100, child: NeonButton(label: 'إرسال', height: 54, onTap: _submit)),
      ]),
    ]);
  }
}

class CipherEx extends ConsumerStatefulWidget {
  final Puzzles p;
  const CipherEx({super.key, required this.p});

  @override
  ConsumerState<CipherEx> createState() => _CipherExState();
}

class _CipherExState extends ConsumerState<CipherEx> {
  int selected = -1;

  @override
  Widget build(BuildContext context) {
    final c = widget.p.cipher;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Brief('آلة فكّ التشفير: اسأل العميل عن الرمز واضغط عليه، فيظهر جدول الفكّ. ثم أمْلِ عليه الحرف الأصلي لكل حرف يقرؤه.',
          icon: Icons.folder_open),
      FixedGrid(columns: 4, aspect: 1.1, children: [
        for (int i = 0; i < kSymbols.length; i++)
          SymbolCell(
            sym: kSymbols[i],
            selected: selected == i,
            onTap: () {
              ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
              setState(() => selected = i);
            },
          ),
      ]),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: selected < 0
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: Text('اختر الرمز لتشغيل آلة الفكّ.', textAlign: TextAlign.center, style: TextStyle(color: K.muted)),
              )
            : Column(key: ValueKey(selected), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const MonoLabel('DECODER', color: K.amber),
                  const SizedBox(width: 10),
                  Text('${kSymbols[selected].s}  ${kSymbols[selected].n}', style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                const Text('ابحث عن الحرف المشفّر في الأعلى، والحرف الأصلي تحته باللون الكهرماني.',
                    style: TextStyle(color: K.muted, fontSize: 12.5)),
                const SizedBox(height: 8),
                FixedGrid(columns: 7, spacing: 4, aspect: 0.68, children: [
                  for (final ch in kAlphabet)
                    Cell(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(ch, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.1, color: K.neon)),
                        const Icon(Icons.arrow_downward, size: 10, color: K.muted),
                        Text(c.decode(ch, selected),
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: K.amber, height: 1.1)),
                      ]),
                    ),
                ]),
              ]),
      ),
    ]);
  }
}

// ───── 4. أنفاق التهوية ─────
class MazeOp extends StatelessWidget {
  final Dispatch dispatch;
  const MazeOp({super.key, required this.dispatch});

  Widget _arrow(IconData icon, String label, String dir) => SizedBox(
        width: 92,
        height: 80,
        child: DeviceKey(
          sfx: Sfx.click,
          onTap: () => dispatch({'type': 'move', 'dir': dir}),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 36, color: K.neon),
            Text(label, style: const TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brief('أنت داخل أنفاق التهوية والكاميرا معطّلة. المحلّل يرى المخطّط ومكانك: اتبع توجيهاته. كل اصطدام بجدار −10 ثوانٍ.',
            icon: Icons.record_voice_over_outlined),
        const SizedBox(height: 120, child: _Static()),
        const SizedBox(height: 14),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(children: [
            _arrow(Icons.keyboard_arrow_up, 'فوق', 'up'),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _arrow(Icons.keyboard_arrow_left, 'يسار', 'left'),
              const SizedBox(width: 100),
              _arrow(Icons.keyboard_arrow_right, 'يمين', 'right'),
            ]),
            const SizedBox(height: 8),
            _arrow(Icons.keyboard_arrow_down, 'تحت', 'down'),
          ]),
        ),
      ]);
}

/// تشويش كاميرا معطّلة.
class _Static extends StatefulWidget {
  const _Static();

  @override
  State<_Static> createState() => _StaticState();
}

class _StaticState extends State<_Static> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: K.line), color: Colors.black),
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(
            child: AnimatedBuilder(
                animation: _a, builder: (context, _) => CustomPaint(painter: _NoisePainter((_a.value * 1000).floor()))),
          ),
          const Center(child: MonoLabel('CAM-03  NO SIGNAL', color: K.danger, size: 14)),
        ]),
      );
}

class _NoisePainter extends CustomPainter {
  final int frame;
  _NoisePainter(this.frame);

  @override
  void paint(Canvas canvas, Size s) {
    final r = Random(frame);
    final p = Paint();
    for (int i = 0; i < 700; i++) {
      final v = r.nextInt(120);
      p.color = Color.fromARGB(255, v, v + 20 > 255 ? 255 : v + 20, v);
      canvas.drawRect(Rect.fromLTWH(r.nextDouble() * s.width, r.nextDouble() * s.height, 2, 2), p);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter old) => old.frame != frame;
}

class MazeEx extends StatefulWidget {
  final Puzzles p;
  final GameState state;
  const MazeEx({super.key, required this.p, required this.state});

  @override
  State<MazeEx> createState() => _MazeExState();
}

class _MazeExState extends State<MazeEx> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Brief('مخطّط الأنفاق: وجّه العميل (النقطة الزرقاء) إلى المخرج (الهدف الأخضر). الاتجاهات كما تظهر على شاشتك.',
          icon: Icons.folder_open),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: AspectRatio(
            aspectRatio: 1,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) =>
                  CustomPaint(painter: _MazePainter(widget.p.maze, widget.state.mazePos ?? widget.p.maze.start, _pulse.value)),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MazePainter extends CustomPainter {
  final Maze m;
  final int pos;
  final double t;
  _MazePainter(this.m, this.pos, this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final cs = s.width / m.n;
    canvas.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF041019));
    final grid = Paint()
      ..color = const Color(0xFF0B2A3A)
      ..strokeWidth = 1;
    for (int i = 0; i <= m.n * 4; i++) {
      final d = i * cs / 4;
      canvas.drawLine(Offset(d, 0), Offset(d, s.height), grid);
      canvas.drawLine(Offset(0, d), Offset(s.width, d), grid);
    }
    final wall = Paint()
      ..color = const Color(0xFF6FD3FF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = const Color(0xFF6FD3FF).withAlpha(60)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < m.n * m.n; i++) {
      final x = (i % m.n) * cs, y = (i ~/ m.n) * cs;
      final o = m.open[i];
      final segs = <List<Offset>>[
        if (!o.contains('up')) [Offset(x, y), Offset(x + cs, y)],
        if (!o.contains('down')) [Offset(x, y + cs), Offset(x + cs, y + cs)],
        if (!o.contains('left')) [Offset(x, y), Offset(x, y + cs)],
        if (!o.contains('right')) [Offset(x + cs, y), Offset(x + cs, y + cs)],
      ];
      for (final sg in segs) {
        canvas.drawLine(sg[0], sg[1], glow);
        canvas.drawLine(sg[0], sg[1], wall);
      }
    }
    Offset center(int i) => Offset((i % m.n) * cs + cs / 2, (i ~/ m.n) * cs + cs / 2);
    // المخرج
    final ex = center(m.exit);
    final target = Paint()
      ..color = K.neon
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(ex, cs * 0.28, target);
    canvas.drawCircle(ex, cs * 0.12, Paint()..color = K.neon);
    canvas.drawLine(ex - Offset(cs * 0.38, 0), ex + Offset(cs * 0.38, 0), target);
    canvas.drawLine(ex - Offset(0, cs * 0.38), ex + Offset(0, cs * 0.38), target);
    // العميل
    final ag = center(pos);
    canvas.drawCircle(ag, cs * (0.2 + 0.25 * t), Paint()..color = K.agent.withAlpha(((1 - t) * 150).round()));
    canvas.drawCircle(ag, cs * 0.17, Paint()..color = K.agent);
    canvas.drawCircle(ag, cs * 0.17, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => old.pos != pos || old.t != t;
}

// ───── 5. جهاز الإشارات ─────
class LightsOp extends ConsumerStatefulWidget {
  final Puzzles p;
  final GameState state;
  final Dispatch dispatch;
  const LightsOp({super.key, required this.p, required this.state, required this.dispatch});

  @override
  ConsumerState<LightsOp> createState() => _LightsOpState();
}

class _LightsOpState extends ConsumerState<LightsOp> {
  int? lit;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 700), _play);
  }

  @override
  void didUpdateWidget(covariant LightsOp old) {
    super.didUpdateWidget(old);
    if (old.state.lightStage != widget.state.lightStage) Timer(const Duration(milliseconds: 700), _play);
  }

  Future<void> _play() async {
    final tok = ++_token;
    final seq = widget.p.lights.seq.sublist(0, widget.state.lightStage + 1);
    for (final c in seq) {
      if (!mounted || tok != _token) return;
      setState(() => lit = c);
      ref.read(audioProvider).play(Sfx.light, volume: 0.6);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted || tok != _token) return;
      setState(() => lit = null);
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state.lightStage;
    final expected = widget.p.lights.expected(st);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Brief('المرحلة ${st + 1} من 3. راقب المصابيح وصِف للمحلّل ما يومض، ثم اضغط الأزرار التي يحدّدها بالترتيب.',
          icon: Icons.record_voice_over_outlined),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        for (int i = 0; i < kLights.length; i++) _Bulb(color: Color(kLights[i].argb), on: lit == i),
      ]),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: _play,
        icon: const Icon(Icons.replay, color: K.neon),
        label: const Text('أعد الإشارة', style: TextStyle(color: K.neon)),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < expected.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: i < widget.state.lightInput.length ? K.neon : Colors.transparent,
              border: Border.all(color: i < widget.state.lightInput.length ? K.neon : K.line, width: 2),
              boxShadow: i < widget.state.lightInput.length ? K.glow(K.neon, 8, 150) : null,
            ),
          ),
      ]),
      const SizedBox(height: 14),
      FixedGrid(columns: 2, spacing: 10, aspect: 2.3, children: [
        for (int i = 0; i < kLights.length; i++)
          DeviceKey(
            color: Color.lerp(Color(kLights[i].argb), Colors.black, 0.45)!,
            sfx: Sfx.beep,
            onTap: () => widget.dispatch({'type': 'press', 'color': i}),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: Color(kLights[i].argb), boxShadow: K.glow(Color(kLights[i].argb), 10, 200)),
              ),
              const SizedBox(width: 10),
              Text(kLights[i].n, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
            ]),
          ),
      ]),
    ]);
  }
}

class _Bulb extends StatelessWidget {
  final Color color;
  final bool on;
  const _Bulb({required this.color, required this.on});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: on
                ? [Colors.white, color, Color.lerp(color, Colors.black, 0.3)!]
                : [const Color(0xFF2A2F2D), Color.lerp(color, Colors.black, 0.82)!, Colors.black],
          ),
          border: Border.all(color: const Color(0xFF3A4440), width: 3),
          boxShadow: on ? [BoxShadow(color: color.withAlpha(200), blurRadius: 34, spreadRadius: 6)] : null,
        ),
      );
}

class LightsEx extends StatelessWidget {
  final Puzzles p;
  final GameState state;
  const LightsEx({super.key, required this.p, required this.state});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Brief('شيفرة الإشارات: حوّل كل ضوء يصفه العميل حسب جدول المرحلة الحالية. في المرحلة 2 ضوءان وفي المرحلة 3 ثلاثة، تُضغط كلها بالترتيب.',
            icon: Icons.folder_open),
        for (int st = 0; st < 3; st++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Cell(
              border: st == state.lightStage ? K.amber : K.line,
              shadow: st == state.lightStage ? K.glow(K.amber, 12, 70) : null,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('المرحلة ${st + 1}',
                      style: TextStyle(fontWeight: FontWeight.w800, color: st == state.lightStage ? K.amber : K.text)),
                  if (st == state.lightStage) ...[const SizedBox(width: 8), const MonoLabel('ACTIVE', color: K.amber, size: 11)],
                ]),
                const SizedBox(height: 4),
                for (int c = 0; c < kLights.length; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(color: Color(kLights[c].argb), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text('إذا ومض ${kLights[c].n}'),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(Icons.arrow_back, size: 14, color: K.muted)),
                      Text('اضغط ', style: const TextStyle(color: K.muted)),
                      Text(kLights[p.lights.maps[st][c]].n,
                          style: TextStyle(color: Color(kLights[p.lights.maps[st][c]].argb), fontWeight: FontWeight.w900)),
                    ]),
                  ),
              ]),
            ),
          ),
      ]);
}
