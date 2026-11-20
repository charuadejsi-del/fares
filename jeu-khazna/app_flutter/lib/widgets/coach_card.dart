// بطاقة الإرشاد فوق كل قفل:
// - سطر دائم: ماذا يفعل دورك في هذا القفل.
// - شرح كامل (ما يراه العميل / ما يراه المحلّل / مثال) يُفتح تلقائياً أوّل مرة
//   يظهر فيها القفل، ودائماً في المرحلة الأولى (الوضع الموجَّه).
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme.dart';
import '../core/coach.dart';
import 'spy_ui.dart';

class CoachCard extends StatefulWidget {
  final String lockId;
  final String role;
  final bool guided;
  const CoachCard({super.key, required this.lockId, required this.role, this.guided = false});

  @override
  State<CoachCard> createState() => _CoachCardState();
}

class _CoachCardState extends State<CoachCard> {
  static final Set<String> _seenCache = {};
  bool _open = false;

  String get _key => 'khazna.coach.${widget.lockId}';

  @override
  void initState() {
    super.initState();
    _decide();
  }

  @override
  void didUpdateWidget(covariant CoachCard old) {
    super.didUpdateWidget(old);
    if (old.lockId != widget.lockId) _decide();
  }

  Future<void> _decide() async {
    if (widget.guided) {
      setState(() => _open = true);
      return;
    }
    if (_seenCache.contains(widget.lockId)) {
      if (mounted) setState(() => _open = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool(_key) ?? false;
      if (seen) _seenCache.add(widget.lockId);
      if (mounted) setState(() => _open = !seen);
    } catch (_) {}
  }

  Future<void> _close() async {
    setState(() => _open = false);
    _seenCache.add(widget.lockId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = coachFor(widget.lockId);
    final me = widget.role == 'ex' ? 'ex' : 'op';
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          color: K.surface,
          borderRadius: BorderRadius.circular(K.radius),
          border: Border.all(color: _open ? K.neon.withAlpha(120) : K.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // السطر الدائم: مهمّة دورك
          InkWell(
            onTap: () => _open ? _close() : setState(() => _open = true),
            borderRadius: BorderRadius.circular(K.radius),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(K.roleIcon(me), color: K.role(me), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(c.forRole(me), style: const TextStyle(color: K.text2, fontSize: 13, height: 1.5)),
                ),
                const SizedBox(width: 6),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: K.muted, size: 20),
              ]),
            ),
          ),
          if (_open) ...[
            const Divider(height: 1, color: K.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (widget.guided)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: MonoLabel('GUIDED · المرحلة الأولى موجَّهة', color: K.neon, size: 10.5),
                  ),
                _Part(title: 'العميل الميداني يرى', body: c.agent, mine: me == 'op', color: K.agent),
                const SizedBox(height: 8),
                _Part(title: 'المحلّل يرى', body: c.analyst, mine: me == 'ex', color: K.analyst),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: K.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: K.border),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const MonoLabel('EXAMPLE · مثال', size: 10),
                    const SizedBox(height: 4),
                    Text(c.example, style: const TextStyle(fontSize: 12.5, height: 1.6, color: K.text)),
                  ]),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _close,
                    style: TextButton.styleFrom(foregroundColor: K.neon),
                    child: const Text('فهمت', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Part extends StatelessWidget {
  final String title;
  final String body;
  final bool mine;
  final Color color;
  const _Part({required this.title, required this.body, required this.mine, required this.color});

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 3, height: 40, color: mine ? color : K.border),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mine ? '$title (أنت)' : title,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: mine ? color : K.muted)),
            const SizedBox(height: 2),
            Text(body, style: TextStyle(fontSize: 13, height: 1.55, color: mine ? K.text : K.text2)),
          ]),
        ),
      ]);
}
