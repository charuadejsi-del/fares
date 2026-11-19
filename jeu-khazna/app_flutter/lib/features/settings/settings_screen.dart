import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    Widget toggle(String title, String sub, IconData icon, bool v, void Function(bool) on) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, color: v ? K.neon : K.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(color: K.muted, fontSize: 12.5)),
              ]),
            ),
            Switch(
              value: v,
              activeColor: K.neon,
              onChanged: (x) {
                ref.read(audioProvider).haptic(HapticKind.tap);
                on(x);
              },
            ),
          ]),
        );

    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
              const Spacer(),
              const MonoLabel('SYSTEM // الإعدادات'),
            ]),
            const SizedBox(height: 10),
            HudPanel(
              label: 'AUDIO & FEEDBACK',
              child: Column(children: [
                toggle('المؤثّرات الصوتية', 'أصوات الأزرار والأقفال والإنذار', Icons.graphic_eq, s.sound, n.setSound),
                toggle('الموسيقى', 'موسيقى التشويق في الخلفية', Icons.music_note, s.music, n.setMusic),
                toggle('الاهتزاز', 'اهتزاز عند الضغط والأخطاء', Icons.vibration, s.haptics, n.setHaptics),
              ]),
            ),
            const SizedBox(height: 14),
            HudPanel(
              label: 'DATA',
              color: K.danger,
              child: NeonButton(
                label: 'مسح الإحصائيات',
                icon: Icons.delete_outline,
                filled: false,
                color: K.danger,
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'مسح كل الإحصائيات؟', body: 'ستُحذف النجوم والرتبة وأفضل وقت. لا يمكن التراجع.', confirm: 'مسح');
                  if (ok) ref.read(progressProvider.notifier).reset();
                },
              ),
            ),
            const SizedBox(height: 24),
            const Center(child: MonoLabel('KHAZNA v0.2 // OPERATION BUILD', color: K.muted, size: 11)),
          ]),
        ),
      ),
    );
  }
}
