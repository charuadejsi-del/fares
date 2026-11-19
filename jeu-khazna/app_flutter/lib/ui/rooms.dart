// شاشات الأقفال الخمسة: لكل قفل شاشة للمشغّل وشاشة للخبير.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game.dart';
import 'theme.dart';

typedef Dispatch = void Function(Map<String, dynamic> action);

class RoomView extends StatelessWidget {
  final GameState state;
  final Puzzles puzzles;
  final String role;
  final Dispatch dispatch;
  const RoomView({super.key, required this.state, required this.puzzles, required this.role, required this.dispatch});

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
class Lead extends StatelessWidget {
  final String text;
  const Lead(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(color: Color(0xFFCFD4DE), fontSize: 15.5, height: 1.5)),
      );
}

class Tile extends StatelessWidget {
  final Widget child;
  final Color? border;
  final Color color;
  final EdgeInsetsGeometry padding;
  const Tile(
      {super.key, required this.child, this.border, this.color = K.cell, this.padding = const EdgeInsets.all(6)});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border ?? K.line),
        ),
        child: child,
      );
}

/// شبكة ثابتة الأعمدة داخل عمود قابل للتمرير.
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
    final cell = Tile(
      border: selected ? K.gold : null,
      color: selected ? const Color(0xFF2B2616) : K.cell,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(sym.s, style: const TextStyle(fontSize: 26, height: 1.1)),
        Text(sym.n, style: const TextStyle(color: K.muted, fontSize: 11)),
        if (value != null)
          Text(value!, style: const TextStyle(color: K.gold, fontSize: 19, fontWeight: FontWeight.w900)),
      ]),
    );
    if (onTap == null) return cell;
    return GestureDetector(onTap: onTap, child: cell);
  }
}

class BigKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color fg;
  final Widget? child;
  const BigKey(
      {super.key, required this.label, required this.onTap, this.color = const Color(0xFF232835), this.fg = K.text, this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Center(
            child: child ?? Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: fg)),
          ),
        ),
      );
}

// ───── 1. باب الرموز ─────
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
      } else if (k == '✔') {
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
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✔'];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Lead('صِف هذه الرموز للخبير بالترتيب (من اليسار إلى اليمين)، ثم أدخل الرمز الذي يعطيك إياه.'),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final i in widget.p.keypad.shown)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Tile(
                padding: EdgeInsets.zero,
                child: SizedBox(
                    width: 64, height: 64, child: Center(child: Text(kSymbols[i].s, style: const TextStyle(fontSize: 36)))),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      Text(entry.padRight(4, '•'),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 14)),
      const SizedBox(height: 10),
      Directionality(
        textDirection: TextDirection.ltr,
        child: FixedGrid(
          columns: 3,
          spacing: 8,
          aspect: 1.7,
          children: [
            for (final k in keys)
              BigKey(
                label: k,
                onTap: () => _key(k),
                color: k == '✔' ? K.gold : const Color(0xFF232835),
                fg: k == '✔' ? const Color(0xFF1A1406) : K.text,
                child: k == '⌫' ? const Icon(Icons.backspace_outlined) : null,
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
        const Lead('المشغّل سيصف لك 4 رموز. أعطه الرقم المقابل لكل رمز، بنفس الترتيب.'),
        FixedGrid(
          columns: 4,
          aspect: 0.82,
          children: [
            for (int i = 0; i < kSymbols.length; i++) SymbolCell(sym: kSymbols[i], value: '${p.keypad.manual[i]}'),
          ],
        ),
      ]);
}

// ───── 2. صندوق الأسلاك ─────
class WiresOp extends StatelessWidget {
  final Puzzles p;
  final GameState state;
  final Dispatch dispatch;
  const WiresOp({super.key, required this.p, required this.state, required this.dispatch});

  Future<void> _confirm(BuildContext context, int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: K.card,
        title: Text('قطع السلك رقم ${i + 1}؟'),
        content: const Text('إذا كان خطأً ستخسر 30 ثانية.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: K.bad, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('✂️ اقطع'),
          ),
        ],
      ),
    );
    if (ok == true) dispatch({'type': 'cut', 'idx': i});
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Lead('صِف للخبير عدد الأسلاك وألوانها من الأعلى إلى الأسفل، ثم اقطع السلك الذي يحدّده.'),
        for (int i = 0; i < p.wires.wires.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      textAlign: TextAlign.center, style: const TextStyle(color: K.muted, fontWeight: FontWeight.w800))),
              Expanded(child: _WireBar(color: Color(kColors[p.wires.wires[i]].argb), cut: state.cut.contains(i))),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: K.text,
                      side: const BorderSide(color: K.line),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: state.cut.contains(i) ? null : () => _confirm(context, i),
                  child: Text(state.cut.contains(i) ? 'مقطوع' : '✂️ اقطع'),
                ),
              ),
            ]),
          ),
      ]);
}

class _WireBar extends StatelessWidget {
  final Color color;
  final bool cut;
  const _WireBar({required this.color, required this.cut});

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black, width: 1),
      ),
    );
    if (!cut) return bar;
    return Row(children: [
      Expanded(child: bar),
      const SizedBox(width: 18, child: Icon(Icons.content_cut, size: 16, color: K.bad)),
      Expanded(child: bar),
    ]);
  }
}

class WiresEx extends StatelessWidget {
  final Puzzles p;
  const WiresEx({super.key, required this.p});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Lead('اسأل المشغّل عن عدد الأسلاك وألوانها. السلك رقم 1 هو الأعلى. طبّق أوّل قاعدة صحيحة فقط.'),
        for (int n = 3; n <= 6; n++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tile(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إذا كان هناك $n أسلاك', style: const TextStyle(fontWeight: FontWeight.w800, color: K.gold)),
                const SizedBox(height: 4),
                for (int i = 0; i < p.wires.rules[n]!.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('${i + 1}. ${p.wires.rules[n]![i].text}', style: const TextStyle(height: 1.4)),
                  ),
              ]),
            ),
          ),
      ]);
}

// ───── 3. المخطوط المشفّر ─────
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
      const Lead('صِف الرمز للخبير، ثم اقرأ له الحروف المشفّرة واحداً واحداً من اليمين إلى اليسار. هو يقول لك الحرف الأصلي لكل واحد.'),
      Center(
        child: Tile(
          padding: EdgeInsets.zero,
          child: SizedBox(
              width: 90, height: 90, child: Center(child: Text(kSymbols[c.sym].s, style: const TextStyle(fontSize: 52)))),
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final ch in c.cipher.split(''))
            Tile(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(ch, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(
          child: TextField(
            controller: _ctl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: fieldDecoration('الكلمة بعد فكّ الشيفرة'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: K.gold,
                foregroundColor: const Color(0xFF1A1406),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _submit,
            child: const Text('تحقّق', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ]);
  }
}

class CipherEx extends StatefulWidget {
  final Puzzles p;
  const CipherEx({super.key, required this.p});

  @override
  State<CipherEx> createState() => _CipherExState();
}

class _CipherExState extends State<CipherEx> {
  int selected = -1;

  @override
  Widget build(BuildContext context) {
    final c = widget.p.cipher;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Lead('1) اسأل المشغّل عن الرمز، واضغط عليه هنا. 2) سيظهر جدول الفكّ. 3) المشغّل يقرأ لك الحروف، وأنت تقول له الحرف الأصلي لكل واحد.'),
      FixedGrid(
        columns: 4,
        aspect: 1.1,
        children: [
          for (int i = 0; i < kSymbols.length; i++)
            SymbolCell(
              sym: kSymbols[i],
              selected: selected == i,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => selected = i);
              },
            ),
        ],
      ),
      const SizedBox(height: 14),
      if (selected < 0)
        const Text('اختر الرمز لترى جدول الفكّ.', textAlign: TextAlign.center, style: TextStyle(color: K.muted))
      else ...[
        Text('جدول الفكّ للرمز ${kSymbols[selected].s} (${kSymbols[selected].n})',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const Text('ابحث عن الحرف الذي يقرؤه المشغّل في الأعلى، والحرف الأصلي هو الذي تحته.',
            style: TextStyle(color: K.muted, fontSize: 12.5)),
        const SizedBox(height: 8),
        FixedGrid(
          columns: 7,
          spacing: 4,
          aspect: 0.7,
          children: [
            for (final ch in kAlphabet)
              Tile(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(ch, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
                  const Text('↓', style: TextStyle(color: K.muted, fontSize: 10, height: 1)),
                  Text(c.decode(ch, selected),
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: K.gold, height: 1.1)),
                ]),
              ),
          ],
        ),
      ],
    ]);
  }
}

// ───── 4. السرداب المظلم ─────
class MazeOp extends StatelessWidget {
  final Dispatch dispatch;
  const MazeOp({super.key, required this.dispatch});

  Widget _arrow(IconData icon, String label, String dir) => SizedBox(
        width: 92,
        height: 78,
        child: BigKey(
          label: label,
          onTap: () => dispatch({'type': 'move', 'dir': dir}),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 34),
            Text(label, style: const TextStyle(color: K.muted, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Lead('أنت في ظلام دامس 🔦. الخبير يرى الخريطة ومكانك. اتبع توجيهاته. كل اصطدام بجدار يكلّف 10 ثوانٍ.'),
        const SizedBox(height: 8),
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

class MazeEx extends StatelessWidget {
  final Puzzles p;
  final GameState state;
  const MazeEx({super.key, required this.p, required this.state});

  @override
  Widget build(BuildContext context) {
    final m = p.maze;
    const wall = BorderSide(color: K.gold, width: 2.5);
    const none = BorderSide(color: Colors.transparent, width: 2.5);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Lead('وجّه المشغّل (🔦) إلى الباب (🚪). الاتجاهات كما تظهر على شاشتك: فوق، تحت، يمين، يسار.'),
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Container(
              decoration: BoxDecoration(color: K.cell, borderRadius: BorderRadius.circular(6)),
              child: FixedGrid(
                columns: m.n,
                spacing: 0,
                children: [
                  for (int i = 0; i < m.n * m.n; i++)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: m.open[i].contains('up') ? none : wall,
                          bottom: m.open[i].contains('down') ? none : wall,
                          left: m.open[i].contains('left') ? none : wall,
                          right: m.open[i].contains('right') ? none : wall,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            i == state.mazePos ? '🔦' : (i == m.exit ? '🚪' : ''),
                            key: ValueKey('$i-${i == state.mazePos}'),
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ───── 5. قفل الأضواء ─────
class LightsOp extends StatefulWidget {
  final Puzzles p;
  final GameState state;
  final Dispatch dispatch;
  const LightsOp({super.key, required this.p, required this.state, required this.dispatch});

  @override
  State<LightsOp> createState() => _LightsOpState();
}

class _LightsOpState extends State<LightsOp> {
  Color? lamp;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 600), _play);
  }

  @override
  void didUpdateWidget(covariant LightsOp old) {
    super.didUpdateWidget(old);
    if (old.state.lightStage != widget.state.lightStage) Timer(const Duration(milliseconds: 600), _play);
  }

  Future<void> _play() async {
    final tok = ++_token;
    final seq = widget.p.lights.seq.sublist(0, widget.state.lightStage + 1);
    for (final c in seq) {
      if (!mounted || tok != _token) return;
      setState(() => lamp = Color(kLights[c].argb));
      await Future<void>.delayed(const Duration(milliseconds: 750));
      if (!mounted || tok != _token) return;
      setState(() => lamp = null);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.state.lightStage;
    final expected = widget.p.lights.expected(st);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Lead('المرحلة ${st + 1} من 3. شاهد الأضواء وصِفها للخبير، ثم اضغط الأزرار التي يحدّدها بالترتيب.'),
      Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: lamp ?? K.cell,
            border: Border.all(color: K.line, width: 3),
            boxShadow: lamp == null ? null : [BoxShadow(color: lamp!.withAlpha(150), blurRadius: 40, spreadRadius: 4)],
          ),
        ),
      ),
      TextButton.icon(onPressed: _play, icon: const Icon(Icons.replay), label: const Text('أعد عرض الأضواء')),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int i = 0; i < expected.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < widget.state.lightInput.length ? K.gold : Colors.transparent,
              border: Border.all(color: i < widget.state.lightInput.length ? K.gold : K.line, width: 2),
            ),
          ),
      ]),
      const SizedBox(height: 12),
      FixedGrid(
        columns: 2,
        spacing: 10,
        aspect: 2.2,
        children: [
          for (int i = 0; i < kLights.length; i++)
            BigKey(
              label: kLights[i].n,
              color: Color(kLights[i].argb),
              fg: const Color(0xFF111111),
              onTap: () => widget.dispatch({'type': 'press', 'color': i}),
            ),
        ],
      ),
    ]);
  }
}

class LightsEx extends StatelessWidget {
  final Puzzles p;
  final GameState state;
  const LightsEx({super.key, required this.p, required this.state});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Lead('المشغّل يرى أضواء تومض. حوّل كل ضوء حسب جدول المرحلة الحالية. في المرحلة 2 يومض ضوءان وفي المرحلة 3 ثلاثة: يضغط المشغّل على الكل بالترتيب.'),
        for (int st = 0; st < 3; st++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Tile(
              border: st == state.lightStage ? K.gold : null,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المرحلة ${st + 1}${st == state.lightStage ? '  ← الآن' : ''}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: st == state.lightStage ? K.gold : K.text)),
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
                      Text('إذا ومض ${kLights[c].n} ← اضغط '),
                      Text(kLights[p.lights.maps[st][c]].n,
                          style: TextStyle(color: Color(kLights[p.lights.maps[st][c]].argb), fontWeight: FontWeight.w900)),
                    ]),
                  ),
              ]),
            ),
          ),
      ]);
}
