// واجهات الأقفال الموسّعة: ما يراه العميل (رسوم وأجهزة)، ملفّ المحلّل، وطرق الإدخال.
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/ext_locks.dart';
import '../../../core/game.dart';
import '../../../core/services.dart';
import '../../../core/stages.dart';
import 'locks.dart';

class ExtLockView extends StatelessWidget {
  final GameState state;
  final String role;
  final Dispatch dispatch;
  const ExtLockView({super.key, required this.state, required this.role, required this.dispatch});

  @override
  Widget build(BuildContext context) {
    final x = extFor(state);
    final mods = stageMods(state.stage);
    final info = kExtInfo[x.id];
    if (role == 'op') {
      final body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Brief(
          x.id == 'print'
              ? 'المحلّل سيصف بصمة الجاني. اختر رقمها.'
              : 'صِف ما تراه للمحلّل بدقّة، ثم نفّذ ما يمليه عليك. ${info?.how ?? ''}',
          icon: Icons.record_voice_over_outlined,
        ),
        if (mods.contains('decoy') || x.id == 'lamps')
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: K.cell, border: Border.all(color: K.amber.withAlpha(150))),
              child: Text('الرقم التسلسلي: ${x.serial}',
                  textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: K.mono, color: K.amber, fontSize: 15)),
            ),
          ),
        for (final it in x.op) Padding(padding: const EdgeInsets.only(bottom: 14), child: OpItemView(item: it)),
        ExtInput(key: ValueKey('${state.seed}-${state.room}'), x: x, state: state, dispatch: dispatch, role: 'op'),
      ]);
      return mods.contains('blackout') ? Blackout(seed: state.seed + state.room, child: body) : body;
    }
    // المحلّل
    final torn = mods.contains('torn');
    final pages = <(String, ManualPage)>[(x.serial, x.manual)];
    if (mods.contains('decoy') && x.id != kVaultCode) {
      final fake = extPuzzle(x.id, state.seed ^ 0x5bd1e995, state.diff, room: state.room + 50, rooms: state.rooms);
      final f = (fake.serial == x.serial ? '${fake.serial}*' : fake.serial, fake.manual);
      if ((state.seed + state.room).isEven) {
        pages.add(f);
      } else {
        pages.insert(0, f);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Brief(
        x.id == 'print'
            ? 'ملف البصمات: صِف للعميل بصمة الجاني ليختارها.'
            : 'ملفّ ${info?.title ?? ''}: اسأل العميل عمّا يراه، ثم أمْلِ عليه الحلّ. ${info?.how ?? ''}',
        icon: Icons.folder_open,
      ),
      if (pages.length > 1)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('🎭 ملفّان لهذا القفل: اسأل العميل عن الرقم التسلسلي لتعرف الصحيح.',
              style: TextStyle(color: K.amber, fontWeight: FontWeight.w700)),
        ),
      for (final (serial, page) in pages)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: ManualView(
            page: page,
            serial: pages.length > 1 ? serial : null,
            torn: torn,
            seed: state.seed + state.room,
          ),
        ),
      if (x.id == 'sync') ExtInput(key: ValueKey('ex-${state.seed}-${state.room}'), x: x, state: state, dispatch: dispatch, role: 'ex'),
    ]);
  }
}

// ───── المؤثّر: انقطاع الكهرباء ─────
class Blackout extends StatefulWidget {
  final Widget child;
  final int seed;
  const Blackout({super.key, required this.child, required this.seed});

  @override
  State<Blackout> createState() => _BlackoutState();
}

class _BlackoutState extends State<Blackout> {
  late final Random _r = Random(widget.seed);
  Timer? _t;
  double _dark = 0;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    _t = Timer(Duration(milliseconds: 5000 + _r.nextInt(5000)), () async {
      for (var i = 0; i < 4 && mounted; i++) {
        setState(() => _dark = i.isEven ? 0.97 : 0.5);
        await Future.delayed(Duration(milliseconds: 120 + _r.nextInt(160)));
      }
      if (!mounted) return;
      setState(() => _dark = 0.97);
      await Future.delayed(Duration(milliseconds: 1500 + _r.nextInt(1800)));
      if (!mounted) return;
      setState(() => _dark = 0);
      _schedule();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: _dark < 0.9,
            child: AnimatedOpacity(
              opacity: _dark,
              duration: const Duration(milliseconds: 90),
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: const Text('🌑 انقطعت الكهرباء…', style: TextStyle(color: K.muted, fontSize: 16)),
              ),
            ),
          ),
        ),
      ]);
}

// ───── ملفّ المحلّل ─────
class ManualView extends StatelessWidget {
  final ManualPage page;
  final String? serial;
  final bool torn;
  final int seed;
  const ManualView({super.key, required this.page, this.serial, this.torn = false, this.seed = 0});

  Widget _cell(String t, {bool head = false}) {
    if (t.startsWith('#c:')) {
      final v = int.tryParse(t.substring(3)) ?? 0xFF888888;
      return Center(
        child: Container(width: 34, height: 22, decoration: BoxDecoration(color: Color(v), border: Border.all(color: K.line))),
      );
    }
    return Text(t,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: head ? 12 : 14.5,
          color: head ? K.muted : (t.contains('▒') ? K.line : K.text),
          fontWeight: head ? FontWeight.w700 : FontWeight.w600,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final r = Random(seed);
    var rows = [for (int i = 0; i < page.rows.length; i++) (i, page.rows[i])];
    if (torn && rows.length > 3) {
      rows.shuffle(r);
      rows = [
        for (final (i, row) in rows)
          (i, page.keyRows.contains(i) ? row : [for (int c = 0; c < row.length; c++) c > 0 && r.nextInt(3) == 0 ? '▒▒▒' : row[c]])
      ];
    }
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0C1310), border: Border.all(color: K.line)),
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (serial != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('ملفّ رقم $serial', textDirection: TextDirection.rtl, style: const TextStyle(color: K.amber, fontWeight: FontWeight.w900)),
          ),
        for (final rule in page.rules)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(rule, style: const TextStyle(color: Color(0xFFCFE9DD), fontSize: 14, height: 1.5)),
          ),
        if (page.rows.isNotEmpty) ...[
          const SizedBox(height: 4),
          Table(
            border: TableBorder.all(color: K.line),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              if (page.header.isNotEmpty)
                TableRow(
                  decoration: const BoxDecoration(color: K.cell),
                  children: [for (final h in page.header) Padding(padding: const EdgeInsets.all(6), child: _cell(h, head: true))],
                ),
              for (final (_, row) in rows)
                TableRow(children: [for (final c in row) Padding(padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4), child: _cell(c))]),
            ],
          ),
        ],
      ]),
    );
  }
}

// ───── ما يراه العميل ─────
class OpItemView extends StatelessWidget {
  final OpItem item;
  const OpItemView({super.key, required this.item});

  Widget _glowGlyph(String g, {double size = 34, Color color = K.neon}) => Text(g,
      style: TextStyle(fontSize: size, color: color, shadows: [Shadow(color: color.withAlpha(150), blurRadius: 12)]));

  @override
  Widget build(BuildContext context) {
    final n = item.nums;
    switch (item.kind) {
      case 'switches':
        final k = item.cols;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (int i = 0; i < k; i++)
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Color(kColors[n[i]].argb).withAlpha(40),
                  border: Border.all(color: Color(kColors[n[i]].argb), width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(children: [
                  Text('${i + 1}', style: const TextStyle(fontFamily: K.mono, color: K.muted, fontSize: 12)),
                  Text(kSymbols[n[k + i]].s, style: const TextStyle(fontSize: 26)),
                ]),
              ),
          ]),
        );
      case 'equation':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final g in item.glyphs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _glowGlyph(g, size: g.length == 1 && '+−×'.contains(g) ? 30 : 38, color: '+−×'.contains(g) ? K.amber : K.neon),
              ),
            const Text(' = ?', style: TextStyle(fontSize: 30, color: K.muted)),
          ]),
        );
      case 'clock':
        return Center(child: SizedBox(width: 190, height: 190, child: CustomPaint(painter: _ClockPainter(n[0], n[1], kSymbols[n[2]].s))));
      case 'flash':
        return MorseFlasher(patterns: item.glyphs);
      case 'flags':
        final count = n.length ~/ 4;
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < count; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(children: [
                  SizedBox(width: 74, height: 50, child: CustomPaint(painter: _FlagPainter(n.sublist(i * 4, i * 4 + 4)))),
                  const SizedBox(height: 4),
                  Text('${i + 1}', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
                ]),
              ),
          ]),
        );
      case 'dice':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < n.length ~/ 2; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(width: 58, height: 58, child: CustomPaint(painter: _DicePainter(n[i * 2], Color(kLights[n[i * 2 + 1]].argb)))),
              ),
          ]),
        );
      case 'shapes':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < n.length ~/ 2; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(width: 64, height: 64, child: CustomPaint(painter: _PolyPainter(n[i * 2], n[i * 2 + 1] == 1))),
              ),
          ]),
        );
      case 'scale':
        return Center(child: SizedBox(width: 260, height: 150, child: CustomPaint(painter: _ScalePainter(item.glyphs))));
      case 'tiles':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final g in item.glyphs)
              Container(
                width: 48,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3A2A12), Color(0xFF241A0B)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  border: Border.all(color: K.amber.withAlpha(160)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(g, style: const TextStyle(fontSize: 26, color: K.amber, fontWeight: FontWeight.w900)),
              ),
          ]),
        );
      case 'face':
        return Center(child: SizedBox(width: 170, height: 190, child: CustomPaint(painter: _FacePainter(n))));
      case 'prints':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            for (int i = 0; i < n.length ~/ 3; i++)
              Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 72, height: 86, child: CustomPaint(painter: _PrintPainter(n[i * 3], n[i * 3 + 1], Color(kLights[n[i * 3 + 2]].argb)))),
                Text('${i + 1}', style: const TextStyle(fontFamily: K.mono, color: K.muted)),
              ]),
          ]),
        );
      case 'indicator':
        return Center(
          child: Container(
            width: 120,
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF151A18),
              border: Border.all(color: K.amber, width: 3),
              boxShadow: K.glow(K.amber, 20, 90),
            ),
            child: _glowGlyph(item.glyphs.first, size: 54, color: K.amber),
          ),
        );
      case 'landmarks':
        return Column(children: [
          const Text('تراه من موقعك:', style: TextStyle(color: K.muted)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final g in item.glyphs) Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(g, style: const TextStyle(fontSize: 46))),
          ]),
        ]);
      case 'notes':
        return MelodyPlayer(notes: n, instrument: item.text);
      case 'target':
        return Center(
          child: Column(children: [
            const Text('حرف الهدف', style: TextStyle(color: K.muted)),
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: K.danger, width: 3), boxShadow: K.glow(K.danger, 22, 120)),
              child: Text(item.text, style: const TextStyle(fontFamily: K.mono, fontSize: 40, color: K.danger)),
            ),
          ]),
        );
      case 'frame':
        return Center(
          child: Text('🔶 إطار الأنابيب ملوّن — صِف لونه للمحلّل',
              style: TextStyle(color: Color(n.first), fontWeight: FontWeight.w800)),
        );
      case 'sample':
        return Center(
          child: Column(children: [
            const Text('عيّنة اللون', style: TextStyle(color: K.muted)),
            const SizedBox(height: 6),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Color(n.first), border: Border.all(color: Colors.white24, width: 3)),
            ),
          ]),
        );
      case 'volt':
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF020805), border: Border.all(color: K.amber, width: 2)),
            child: Text('⚡ ${item.text} V', textDirection: TextDirection.ltr, style: const TextStyle(fontFamily: K.mono, fontSize: 30, color: K.amber)),
          ),
        );
      case 'lamps':
        return Center(
          child: SizedBox(
            width: 180,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (int i = 0; i < 9; i++)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: n[i] == 1 ? const Color(0xFFFFE082) : const Color(0xFF1A1F1C),
                        boxShadow: n[i] == 1 ? K.glow(const Color(0xFFFFD54F), 18, 160) : null,
                        border: Border.all(color: K.line),
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(color: n[i] == 1 ? Colors.black54 : K.muted, fontFamily: K.mono)),
                    ),
                ],
              ),
            ),
          ),
        );
      case 'board':
        return Center(child: SizedBox(width: 250, height: 250, child: CustomPaint(painter: _BoardPainter(n))));
      case 'sonar':
        return Column(children: [
          Text('الهدف: ${item.text}', style: const TextStyle(color: K.agent, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Center(child: SizedBox(width: 230, height: 230, child: CustomPaint(painter: _SonarPainter(n)))),
        ]);
      case 'evidence':
        return Column(children: [
          for (int i = 0; i < item.glyphs.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: K.cell, border: Border.all(color: K.line)),
              child: Row(children: [
                const Icon(Icons.lock_open, color: K.neonDim, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(item.glyphs[i])),
                Text('${n[i]}', style: const TextStyle(fontFamily: K.mono, fontSize: 24, color: K.neon)),
              ]),
            ),
        ]);
    }
    return const SizedBox.shrink();
  }
}

// ───── شفرة مورس المتحرّكة ─────
class MorseFlasher extends ConsumerStatefulWidget {
  final List<String> patterns;
  const MorseFlasher({super.key, required this.patterns});

  @override
  ConsumerState<MorseFlasher> createState() => _MorseFlasherState();
}

class _MorseFlasherState extends ConsumerState<MorseFlasher> {
  bool _on = false;
  int _digit = -1;
  bool _alive = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 600));
    while (_alive) {
      for (int d = 0; d < widget.patterns.length && _alive; d++) {
        if (mounted) setState(() => _digit = d);
        for (final ch in widget.patterns[d].split('')) {
          if (!_alive || !mounted) return;
          setState(() => _on = true);
          await Future.delayed(Duration(milliseconds: ch == '.' ? 260 : 780));
          if (!_alive || !mounted) return;
          setState(() => _on = false);
          await Future.delayed(const Duration(milliseconds: 280));
        }
        await Future.delayed(const Duration(milliseconds: 1100));
      }
      if (mounted) setState(() => _digit = -1);
      await Future.delayed(const Duration(milliseconds: 2600));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _on ? const Color(0xFFFFF59D) : const Color(0xFF1B1F1D),
          boxShadow: _on ? K.glow(const Color(0xFFFFEB3B), 40, 220) : null,
          border: Border.all(color: K.line, width: 3),
        ),
      ),
      const SizedBox(height: 10),
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (int i = 0; i < widget.patterns.length; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 26,
              height: 6,
              color: i == _digit ? K.amber : K.line,
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Text(_digit < 0 ? 'تتكرّر الإشارة بعد لحظة…' : 'الرقم ${_digit + 1} من ${widget.patterns.length}',
          style: const TextStyle(color: K.muted, fontSize: 12.5)),
    ]);
  }
}

// ───── اللحن ─────
class MelodyPlayer extends ConsumerStatefulWidget {
  final List<int> notes;
  final String instrument;
  const MelodyPlayer({super.key, required this.notes, required this.instrument});

  @override
  ConsumerState<MelodyPlayer> createState() => _MelodyPlayerState();
}

class _MelodyPlayerState extends ConsumerState<MelodyPlayer> {
  int _lit = -1;
  bool _playing = false;

  Future<void> _play() async {
    if (_playing) return;
    setState(() => _playing = true);
    for (final n in widget.notes) {
      if (!mounted) return;
      setState(() => _lit = n);
      ref.read(audioProvider).fx(Sfx.beep, HapticKind.light, volume: 0.35 + n * 0.15);
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      setState(() => _lit = -1);
      await Future.delayed(const Duration(milliseconds: 220));
    }
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Text('الآلة: ${widget.instrument}', style: const TextStyle(color: K.agent, fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 10),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int c = 0; c < 4; c++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 54,
                height: 84,
                decoration: BoxDecoration(
                  color: Color(kLights[c].argb).withAlpha(_lit == c ? 255 : 60),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _lit == c ? K.glow(Color(kLights[c].argb), 26, 200) : null,
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _playing ? null : _play,
          icon: const Icon(Icons.play_arrow_rounded, color: K.neon),
          label: Text(_playing ? 'يُعزف…' : 'استمع للّحن (${widget.notes.length} نغمات)', style: const TextStyle(color: K.neon)),
        ),
      ]);
}

// ───── الإدخال ─────
class ExtInput extends ConsumerStatefulWidget {
  final ExtPuzzle x;
  final GameState state;
  final Dispatch dispatch;
  final String role;
  const ExtInput({super.key, required this.x, required this.state, required this.dispatch, required this.role});

  @override
  ConsumerState<ExtInput> createState() => _ExtInputState();
}

class _ExtInputState extends ConsumerState<ExtInput> {
  String _digits = '';
  final List<int> _seq = [];
  late List<bool> _toggles = List.filled(widget.x.input.labels.length, false);
  late List<int> _cyc = List.filled(widget.x.input.options.length, 0);

  InputSpec get spec => widget.x.input;

  void _submit(String v) {
    ref.read(audioProvider).fx(Sfx.click, HapticKind.medium, volume: 0.6);
    widget.dispatch({'type': 'ext', 'value': v});
  }

  Widget _okButton(VoidCallback? onTap, {String label = 'تأكيد'}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          height: 50,
          child: DeviceKey(
            onTap: onTap ?? () {},
            color: onTap == null ? K.surface2 : K.neon,
            sfx: Sfx.click,
            child: Text(label, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: onTap == null ? K.muted : K.ink)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    switch (spec.kind) {
      case 'digits':
        final len = spec.len;
        final maxLen = len == 0 ? 4 : len;
        const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', 'OK'];
        final ready = len == 0 ? _digits.isNotEmpty : _digits.length == len;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFF020805), border: Border.all(color: const Color(0xFF1C2C26), width: 3), borderRadius: BorderRadius.circular(6)),
            child: Text(len == 0 ? (_digits.isEmpty ? '_' : _digits) : _digits.padRight(len, '_'),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(fontFamily: K.mono, fontSize: 38, letterSpacing: 14, color: K.neon, shadows: [Shadow(color: K.neon.withAlpha(200), blurRadius: 14)])),
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: FixedGrid(columns: 3, spacing: 8, aspect: 1.7, children: [
              for (final k in keys)
                DeviceKey(
                  onTap: () => setState(() {
                    if (k == '⌫') {
                      if (_digits.isNotEmpty) _digits = _digits.substring(0, _digits.length - 1);
                    } else if (k == 'OK') {
                      if (ready) {
                        _submit(_digits);
                        _digits = '';
                      }
                    } else if (_digits.length < maxLen) {
                      _digits += k;
                    }
                  }),
                  color: k == 'OK' ? K.neon : K.surface2,
                  sfx: k == 'OK' ? Sfx.click : Sfx.beep,
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_outlined, color: K.text)
                      : Text(k, style: TextStyle(fontFamily: K.mono, fontSize: 24, color: k == 'OK' ? K.ink : K.text, fontWeight: FontWeight.w700)),
                ),
            ]),
          ),
        ]);
      case 'choice':
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            for (int i = 0; i < spec.labels.length; i++)
              SizedBox(
                width: spec.labels.length > 4 ? 64 : 120,
                height: 56,
                child: DeviceKey(
                  onTap: () => _submit('$i'),
                  child: Text(spec.labels[i], style: const TextStyle(fontFamily: K.mono, fontSize: 20, color: K.text, fontWeight: FontWeight.w800)),
                ),
              ),
          ]),
        );
      case 'seq':
        final hasColors = spec.colors.isNotEmpty;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الترتيب: ${_seq.length} / ${spec.len}', textAlign: TextAlign.center, style: const TextStyle(color: K.muted)),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              for (int i = 0; i < (hasColors ? spec.colors.length : spec.labels.length); i++)
                GestureDetector(
                  onTap: () {
                    if (!hasColors && _seq.contains(i)) return;
                    ref.read(audioProvider).fx(Sfx.beep, HapticKind.tap, volume: 0.5);
                    setState(() => _seq.add(i));
                    if (_seq.length >= spec.len) {
                      final v = _seq.join(',');
                      _seq.clear();
                      _submit(v);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: hasColors ? 62 : 64,
                    height: hasColors ? 62 : 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: hasColors ? Color(spec.colors[i]) : (_seq.contains(i) ? K.amber.withAlpha(50) : K.cell),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _seq.contains(i) ? K.amber : K.line, width: 2),
                    ),
                    child: hasColors
                        ? null
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(spec.labels[i], style: const TextStyle(fontSize: 28)),
                            if (_seq.contains(i)) Text('${_seq.indexOf(i) + 1}', style: const TextStyle(color: K.amber, fontFamily: K.mono, fontSize: 12)),
                          ]),
                  ),
                ),
            ]),
          ),
          TextButton(onPressed: () => setState(_seq.clear), child: const Text('إعادة', style: TextStyle(color: K.muted))),
        ]);
      case 'toggles':
        final cols = spec.cols;
        final items = [
          for (int i = 0; i < spec.labels.length; i++)
            GestureDetector(
              onTap: () {
                ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
                setState(() => _toggles[i] = !_toggles[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: cols > 0 ? null : 50,
                height: cols > 0 ? null : 78,
                decoration: BoxDecoration(
                  color: _toggles[i] ? K.neon.withAlpha(40) : K.cell,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _toggles[i] ? K.neon : K.line, width: 2),
                  boxShadow: _toggles[i] ? K.glow(K.neon, 10, 80) : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_toggles[i] ? Icons.toggle_on : Icons.toggle_off, color: _toggles[i] ? K.neon : K.muted, size: 30),
                  Text(spec.labels[i], style: const TextStyle(fontFamily: K.mono, color: K.muted)),
                ]),
              ),
            ),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (cols > 0)
            Center(
              child: SizedBox(
                width: 220,
                child: Directionality(textDirection: TextDirection.rtl, child: FixedGrid(columns: cols, spacing: 8, children: items)),
              ),
            )
          else
            Directionality(
              textDirection: TextDirection.ltr,
              child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: items),
            ),
          _okButton(() => _submit(_toggles.map((b) => b ? '1' : '0').join())),
        ]);
      case 'cyclers':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Directionality(
            textDirection: TextDirection.ltr,
            child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              for (int i = 0; i < spec.options.length; i++)
                GestureDetector(
                  onTap: () {
                    ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
                    setState(() => _cyc[i] = (_cyc[i] + 1) % spec.options[i].length);
                  },
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 70,
                      height: 70,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: K.cell,
                        border: Border.all(color: i < spec.colors.length ? Color(spec.colors[i]) : K.line, width: 5),
                        boxShadow: i < spec.colors.length ? K.glow(Color(spec.colors[i]), 10, 70) : null,
                      ),
                      child: Text(spec.options[i][_cyc[i]], style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    ),
                    if (i < spec.labels.length) Text(spec.labels[i], style: const TextStyle(color: K.muted, fontSize: 12)),
                    const Icon(Icons.rotate_right, size: 16, color: K.muted),
                  ]),
                ),
            ]),
          ),
          _okButton(() => _submit(_cyc.join(','))),
        ]);
      case 'grid':
      case 'gridseq':
        final cols = spec.cols;
        final seqMode = spec.kind == 'gridseq';
        final total = spec.labels.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (seqMode)
            Text('المسار: ${_seq.length} / ${spec.len}', textAlign: TextAlign.center, style: const TextStyle(color: K.muted)),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: min(320.0, cols * 62.0),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: FixedGrid(columns: cols, spacing: 4, children: [
                  for (int i = 0; i < total; i++)
                    GestureDetector(
                      onTap: () {
                        ref.read(audioProvider).fx(Sfx.beep, HapticKind.tap, volume: 0.45);
                        if (!seqMode) {
                          _submit('$i');
                          return;
                        }
                        if (_seq.contains(i)) return;
                        setState(() => _seq.add(i));
                        if (_seq.length >= spec.len) {
                          final v = _seq.join(',');
                          _seq.clear();
                          _submit(v);
                        }
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _seq.contains(i) ? const Color(0xFF0D3B5A) : K.cell,
                          border: Border.all(
                            color: seqMode && spec.colors.isNotEmpty && (i == spec.colors[0] || i == spec.colors[1]) ? K.neon : K.line,
                            width: seqMode && spec.colors.isNotEmpty && (i == spec.colors[0] || i == spec.colors[1]) ? 2.5 : 1,
                          ),
                        ),
                        child: Stack(alignment: Alignment.center, children: [
                          Text(spec.labels[i], style: TextStyle(fontSize: seqMode ? 22 : 13, fontFamily: seqMode ? null : K.mono, color: K.text)),
                          if (seqMode && spec.colors.isNotEmpty && i == spec.colors[0])
                            const Positioned(top: 1, left: 3, child: Text('▶', style: TextStyle(color: K.neon, fontSize: 10))),
                          if (seqMode && spec.colors.isNotEmpty && i == spec.colors[1])
                            const Positioned(top: 1, left: 3, child: Text('■', style: TextStyle(color: K.danger, fontSize: 10))),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
          if (seqMode) TextButton(onPressed: () => setState(_seq.clear), child: const Text('إعادة المسار', style: TextStyle(color: K.muted))),
        ]);
      case 'sync':
        final s = widget.state;
        final now = DateTime.now().millisecondsSinceEpoch;
        final otherAt = widget.role == 'op' ? s.syncEx : s.syncOp;
        final otherReady = otherAt > 0 && (now - otherAt).abs() < 4000;
        final isOp = widget.role == 'op';
        final n = isOp ? spec.colors.length : spec.labels.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(isOp ? 'ثقوبك (عُدّا معاً ثم أدِر):' : 'ثقوبك أنت (أدِر معه في اللحظة نفسها):',
              textAlign: TextAlign.center, style: const TextStyle(color: K.muted)),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (int i = 0; i < n; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () {
                      ref.read(audioProvider).fx(Sfx.click, HapticKind.heavy, volume: 0.7);
                      widget.dispatch({'type': 'sync', 'role': widget.role, 'idx': i});
                    },
                    child: Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(colors: [Color(0xFF2B302D), Color(0xFF0E1110)]),
                        border: Border.all(color: isOp ? Color(spec.colors[i]) : K.amber, width: 4),
                      ),
                      child: isOp ? const Text('🗝', style: TextStyle(fontSize: 30)) : Text(spec.labels[i], style: const TextStyle(fontSize: 30, color: K.amber)),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          Text(otherReady ? (isOp ? '🔑 المحلّل أدار مفتاحه للتوّ!' : '🔑 العميل أدار مفتاحه للتوّ!') : 'الفرق المسموح: ثانية ونصف',
              textAlign: TextAlign.center, style: TextStyle(color: otherReady ? K.amber : K.muted, fontWeight: FontWeight.w700)),
        ]);
    }
    return const SizedBox.shrink();
  }
}

// ───── الرسّامات ─────
class _ClockPainter extends CustomPainter {
  final int h, m;
  final String glyph;
  _ClockPainter(this.h, this.m, this.glyph);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFEDE6D3));
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = const Color(0xFF6B4F2A));
    for (int i = 0; i < 60; i++) {
      final a = i * pi / 30;
      final l = i % 5 == 0 ? 12.0 : 5.0;
      canvas.drawLine(Offset(c.dx + (r - 6) * sin(a), c.dy - (r - 6) * cos(a)), Offset(c.dx + (r - 6 - l) * sin(a), c.dy - (r - 6 - l) * cos(a)),
          Paint()
            ..color = Colors.black87
            ..strokeWidth = i % 5 == 0 ? 3 : 1.2);
    }
    final ha = ((h % 12) + m / 60) * pi / 6, ma = m * pi / 30;
    canvas.drawLine(c, Offset(c.dx + r * 0.5 * sin(ha), c.dy - r * 0.5 * cos(ha)), Paint()
      ..color = Colors.black
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round);
    canvas.drawLine(c, Offset(c.dx + r * 0.78 * sin(ma), c.dy - r * 0.78 * cos(ma)), Paint()
      ..color = const Color(0xFF8B1A1A)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 18, Paint()..color = const Color(0xFF2B2B2B));
    final tp = TextPainter(text: TextSpan(text: glyph, style: const TextStyle(fontSize: 20, color: Color(0xFFFFD54F))), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ClockPainter o) => o.h != h || o.m != m || o.glyph != glyph;
}

class _FlagPainter extends CustomPainter {
  final List<int> f; // c1,c2,c3,orient
  _FlagPainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 3; i++) {
      final p = Paint()..color = Color(kColors[f[i]].argb);
      // عمودي: من اليمين إلى اليسار
      final rect = f[3] == 0
          ? Rect.fromLTWH(0, size.height * i / 3, size.width, size.height / 3)
          : Rect.fromLTWH(size.width * (2 - i) / 3, 0, size.width / 3, size.height);
      canvas.drawRect(rect, p);
    }
    canvas.drawRect(Offset.zero & size, Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white30);
  }

  @override
  bool shouldRepaint(covariant _FlagPainter o) => o.f.join() != f.join();
}

class _DicePainter extends CustomPainter {
  final int v;
  final Color color;
  _DicePainter(this.v, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10));
    canvas.drawRRect(rr, Paint()..color = color);
    canvas.drawRRect(rr, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black38);
    const pos = {
      1: [[0.5, 0.5]],
      2: [[0.27, 0.27], [0.73, 0.73]],
      3: [[0.25, 0.25], [0.5, 0.5], [0.75, 0.75]],
      4: [[0.27, 0.27], [0.73, 0.27], [0.27, 0.73], [0.73, 0.73]],
      5: [[0.25, 0.25], [0.75, 0.25], [0.5, 0.5], [0.25, 0.75], [0.75, 0.75]],
      6: [[0.27, 0.22], [0.73, 0.22], [0.27, 0.5], [0.73, 0.5], [0.27, 0.78], [0.73, 0.78]],
    };
    for (final p in pos[v]!) {
      canvas.drawCircle(Offset(size.width * p[0], size.height * p[1]), size.width * 0.08, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _DicePainter o) => o.v != v || o.color != color;
}

class _PolyPainter extends CustomPainter {
  final int sides;
  final bool filled;
  _PolyPainter(this.sides, this.filled);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final a = -pi / 2 + i * 2 * pi / sides;
      final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    if (filled) canvas.drawPath(path, Paint()..color = K.agent);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = K.agent);
  }

  @override
  bool shouldRepaint(covariant _PolyPainter o) => o.sides != sides || o.filled != filled;
}

class _ScalePainter extends CustomPainter {
  final List<String> glyphs;
  _ScalePainter(this.glyphs);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final metal = Paint()
      ..color = const Color(0xFFB0A27A)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(w / 2, h - 10), Offset(w / 2, 30), metal);
    canvas.drawLine(Offset(w * 0.12, 42), Offset(w * 0.88, 18), metal);
    canvas.drawLine(Offset(w * 0.3, h - 10), Offset(w * 0.7, h - 10), metal);
    // الكفّتان
    final l = Offset(w * 0.18, 92), rr = Offset(w * 0.82, 68);
    canvas.drawLine(Offset(w * 0.12, 42), l, Paint()..color = Colors.white38);
    canvas.drawLine(Offset(w * 0.88, 18), rr, Paint()..color = Colors.white38);
    canvas.drawArc(Rect.fromCenter(center: l, width: 96, height: 30), 0, pi, true, Paint()..color = const Color(0xFF6B5B3A));
    canvas.drawArc(Rect.fromCenter(center: rr, width: 96, height: 30), 0, pi, true, Paint()..color = const Color(0xFF6B5B3A));
    final tp = TextPainter(text: TextSpan(text: glyphs.join(' '), style: const TextStyle(fontSize: 22, color: K.neon)), textDirection: TextDirection.ltr)
      ..layout(maxWidth: 110);
    tp.paint(canvas, Offset(l.dx - tp.width / 2, l.dy - tp.height - 2));
    final q = TextPainter(text: const TextSpan(text: '?', style: TextStyle(fontSize: 26, color: K.amber)), textDirection: TextDirection.ltr)..layout();
    q.paint(canvas, Offset(rr.dx - q.width / 2, rr.dy - q.height - 2));
  }

  @override
  bool shouldRepaint(covariant _ScalePainter o) => o.glyphs.join() != glyphs.join();
}

class _FacePainter extends CustomPainter {
  final List<int> f; // hair, glasses, hat, scar, eyes
  _FacePainter(this.f);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.56);
    final r = size.width * 0.34;
    // الشعر
    canvas.drawCircle(c - Offset(0, r * 0.18), r * 1.08, Paint()..color = Color(kColors[f[0]].argb));
    // الوجه
    canvas.drawOval(Rect.fromCenter(center: c + Offset(0, r * 0.08), width: r * 1.75, height: r * 2.0), Paint()..color = const Color(0xFFE0B48C));
    // العيون
    final eye = Color(kLights[f[4]].argb);
    for (final dx in [-0.38, 0.38]) {
      final e = c + Offset(r * dx, -r * 0.1);
      canvas.drawOval(Rect.fromCenter(center: e, width: r * 0.4, height: r * 0.24), Paint()..color = Colors.white);
      canvas.drawCircle(e, r * 0.1, Paint()..color = eye);
    }
    // النظّارة
    if (f[1] == 1) {
      final g = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.black;
      for (final dx in [-0.38, 0.38]) {
        canvas.drawCircle(c + Offset(r * dx, -r * 0.1), r * 0.24, g);
      }
      canvas.drawLine(c + Offset(-r * 0.14, -r * 0.1), c + Offset(r * 0.14, -r * 0.1), g);
    }
    // الفم
    canvas.drawArc(Rect.fromCenter(center: c + Offset(0, r * 0.5), width: r * 0.6, height: r * 0.3), 0.2, pi - 0.4, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF7A3B2E));
    // الندبة
    if (f[3] == 1) {
      final s = Paint()
        ..strokeWidth = 3
        ..color = const Color(0xFFB0413E);
      canvas.drawLine(c + Offset(r * 0.45, r * 0.12), c + Offset(r * 0.75, r * 0.45), s);
      for (final t in [0.25, 0.5, 0.75]) {
        final p = c + Offset(r * (0.45 + 0.3 * t), r * (0.12 + 0.33 * t));
        canvas.drawLine(p + const Offset(-5, 4), p + const Offset(5, -4), s..strokeWidth = 2);
      }
    }
    // القبّعة
    if (f[2] == 1) {
      final top = c - Offset(0, r * 1.05);
      canvas.drawArc(Rect.fromCenter(center: top, width: r * 1.9, height: r * 1.1), pi, pi, true, Paint()..color = const Color(0xFF1E5AA8));
      canvas.drawRect(Rect.fromLTWH(top.dx - r * 0.2, top.dy - 2, r * 1.3, 8), Paint()..color = const Color(0xFF16457F));
    } else if (f[2] == 2) {
      final top = c - Offset(0, r * 1.0);
      canvas.drawRect(Rect.fromCenter(center: top - Offset(0, r * 0.3), width: r * 1.2, height: r * 0.7), Paint()..color = const Color(0xFF2B2B2B));
      canvas.drawRect(Rect.fromCenter(center: top, width: r * 2.1, height: 10), Paint()..color = const Color(0xFF2B2B2B));
    }
  }

  @override
  bool shouldRepaint(covariant _FacePainter o) => o.f.join() != f.join();
}

class _PrintPainter extends CustomPainter {
  final int type, marks;
  final Color markColor;
  _PrintPainter(this.type, this.marks, this.markColor);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFB8C7C1);
    canvas.drawOval(Rect.fromCenter(center: c, width: size.width - 6, height: size.height - 6), Paint()..color = const Color(0xFF1A2220));
    for (int i = 1; i <= 5; i++) {
      final w = i * size.width / 12, h = i * size.height / 11;
      switch (type) {
        case 0: // حلقيّة
          canvas.drawArc(Rect.fromCenter(center: c + Offset(0, h * 0.2), width: w * 2, height: h * 2), pi, pi * 1.2, false, p);
        case 1: // دوّامية
          canvas.drawOval(Rect.fromCenter(center: c, width: w * 2, height: h * 1.8), p);
        default: // قوسيّة
          canvas.drawArc(Rect.fromCenter(center: c + Offset(0, h * 0.9), width: w * 2.6, height: h * 1.4), pi, pi, false, p);
      }
    }
    for (int k = 0; k < marks; k++) {
      canvas.drawCircle(Offset(size.width * (0.3 + 0.2 * k), size.height * 0.82), 5, Paint()..color = markColor);
    }
  }

  @override
  bool shouldRepaint(covariant _PrintPainter o) => o.type != type || o.marks != marks || o.markColor != markColor;
}

class _BoardPainter extends CustomPainter {
  final List<int> n; // pos, piece, marks×4
  _BoardPainter(this.n);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 5;
    for (int y = 0; y < 5; y++) {
      for (int x = 0; x < 5; x++) {
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), Paint()..color = (x + y).isEven ? const Color(0xFFD9C7A3) : const Color(0xFF7A5C3A));
      }
    }
    void text(String t, int c, double fs, Color color) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontSize: fs, color: color, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset((c % 5) * cell + (cell - tp.width) / 2, (c ~/ 5) * cell + (cell - tp.height) / 2));
    }

    text(const ['♞', '♝', '♜', '♛'][n[1]], n[0], cell * 0.7, Colors.black);
    for (int i = 0; i < 4; i++) {
      final c = n[2 + i];
      canvas.drawCircle(Offset((c % 5 + 0.5) * cell, (c ~/ 5 + 0.5) * cell), cell * 0.32, Paint()..color = const Color(0xCC0D47A1));
      text('${i + 1}', c, cell * 0.36, Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter o) => o.n.join() != n.join();
}

class _SonarPainter extends CustomPainter {
  final List<int> n; // [color, angle, dist]×4
  _SonarPainter(this.n);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF02160E));
    final g = Paint()
      ..style = PaintingStyle.stroke
      ..color = K.neonDim.withAlpha(120);
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(c, r * i / 3, g);
    }
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), g);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), g);
    final north = TextPainter(text: const TextSpan(text: '0°', style: TextStyle(color: K.muted, fontSize: 11)), textDirection: TextDirection.ltr)..layout();
    north.paint(canvas, Offset(c.dx + 3, c.dy - r + 2));
    for (int i = 0; i < n.length ~/ 3; i++) {
      final col = Color(kLights[n[i * 3]].argb);
      final a = n[i * 3 + 1] * pi / 180;
      final d = r * (0.2 + 0.08 * n[i * 3 + 2]);
      final p = Offset(c.dx + d * sin(a), c.dy - d * cos(a));
      canvas.drawCircle(p, 9, Paint()..color = col.withAlpha(90));
      canvas.drawCircle(p, 5, Paint()..color = col);
      final tp = TextPainter(text: TextSpan(text: '${n[i * 3 + 1]}°', style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, p + const Offset(8, -6));
    }
  }

  @override
  bool shouldRepaint(covariant _SonarPainter o) => o.n.join() != n.join();
}
