// ملف المهمّة قبل البدء (وضع الهاتف الواحد).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/game.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

const _codenames = ['الصقر', 'الظلّ', 'القمر الأسود', 'الأفعى', 'العاصفة', 'المرجان', 'الذئب الرمادي', 'السراب', 'النسر', 'الكوبرا'];
String codenameFor(int seed) => 'عملية ${_codenames[seed % _codenames.length]}';

class BriefingScreen extends ConsumerStatefulWidget {
  const BriefingScreen({super.key});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  final _codename = codenameFor(Random().nextInt(1000));
  String _diff = 'agent';
  bool _table = false;
  bool _newLocks = false;

  List<String> get _rooms => _newLocks ? const ['keypad', 'dial', 'wires', 'cipher', 'radio', 'maze', 'lights'] : kRooms;

  void _start() {
    final name = ref.read(settingsProvider).name;
    final c = GameController.local(meName: name.isEmpty ? 'عميل' : name, diff: _diff, table: _table, rooms: _rooms);
    context.pushReplacement('/play', extra: c);
  }

  Widget _chip(String label, bool on, VoidCallback tap, {Color color = K.neon}) => GestureDetector(
        onTap: () {
          ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
          tap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: on ? color.withAlpha(40) : K.cell,
            border: Border.all(color: on ? color : K.line, width: on ? 1.5 : 1),
            boxShadow: on ? K.glow(color, 10, 80) : null,
          ),
          child: Text(label, style: TextStyle(color: on ? color : K.muted, fontWeight: FontWeight.w800)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpyBackground(
        image: 'assets/images/panel_bg.jpg',
        dim: 0.6,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            children: [
              Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
                const Spacer(),
                const MonoLabel('CLASSIFIED // سرّي للغاية', color: K.danger),
              ]),
              const SizedBox(height: 8),
              HudPanel(
                label: 'MISSION BRIEFING',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TypewriterText(_codename,
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: K.neon), sound: true),
                  const SizedBox(height: 10),
                  const Text(
                    'الهدف: خزنة سرّية محمية بخمسة أقفال. عميلنا داخل المبنى، ومحلّلنا في القاعدة معه الملفّات. '
                    'لا أحد منكما يستطيع فتحها وحده.',
                    style: TextStyle(fontSize: 15.5, height: 1.6),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              Row(children: const [
                Expanded(child: _RoleCard('op')),
                SizedBox(width: 10),
                Expanded(child: _RoleCard('ex')),
              ]),
              const SizedBox(height: 14),
              HudPanel(
                label: 'SETUP // الإعداد',
                color: K.agent,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('الصعوبة', style: TextStyle(color: K.muted, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final d in kDifficulties.values)
                      _chip(d.name, _diff == d.id, () => setState(() => _diff = d.id), color: K.amber),
                  ]),
                  const SizedBox(height: 12),
                  const Text('طريقة اللعب', style: TextStyle(color: K.muted, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip('هاتف واحد', !_table, () => setState(() => _table = false), color: K.agent),
                    _chip('وضع الطاولة', _table, () => setState(() => _table = true), color: K.agent),
                  ]),
                  const SizedBox(height: 12),
                  const Text('الأقفال', style: TextStyle(color: K.muted, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip('5 أقفال كلاسيكية', !_newLocks, () => setState(() => _newLocks = false)),
                    _chip('7 أقفال (مع القرص والراديو)', _newLocks, () => setState(() => _newLocks = true)),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              HudPanel(
                label: 'OBJECTIVES',
                color: K.amber,
                child: Column(children: [
                  for (int i = 0; i < _rooms.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        MonoLabel('0${i + 1}', color: K.amber, size: 14),
                        const SizedBox(width: 12),
                        Icon(K.roomIcons[_rooms[i]], color: K.text, size: 20),
                        const SizedBox(width: 10),
                        Text(K.roomNames[_rooms[i]]!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  const Divider(color: K.line, height: 22),
                  Row(children: [
                    const Icon(Icons.timer_outlined, color: K.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('الوقت: ${diffOf(_diff).duration ~/ 60} دقائق · كل خطأ −${diffOf(_diff).penalty} ثانية',
                          style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              Text(
                  _table
                      ? 'وضع الطاولة: ضعا الهاتف بينكما. النصف العلوي للمحلّل (مقلوب نحوه) والسفلي للعميل.'
                      : 'على هاتف واحد: اضغط على شارة الدور في الأعلى للتبديل بين شاشة العميل وشاشة المحلّل.',
                  textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 13)),
              const SizedBox(height: 16),
              NeonButton(label: 'ابدأ المهمّة', icon: Icons.bolt, onTap: _start),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String role;
  const _RoleCard(this.role);

  @override
  Widget build(BuildContext context) => HudPanel(
        color: K.role(role),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(K.roleIcon(role), color: K.role(role), size: 30),
          const SizedBox(height: 6),
          Text(K.roleTitle(role), style: TextStyle(color: K.role(role), fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(K.roleDesc(role), style: const TextStyle(color: K.muted, fontSize: 12.5, height: 1.45)),
        ]),
      );
}
