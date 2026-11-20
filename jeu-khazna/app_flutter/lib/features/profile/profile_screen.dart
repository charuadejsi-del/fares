import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';
import '../play/play_screen.dart' show fmtTime;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: authService.profile?.nickname ?? ref.read(settingsProvider).name);
  String? _nickMsg;

  Future<void> _saveNick() async {
    final v = _name.text.trim();
    if (v == authService.profile?.nickname) return;
    try {
      await authService.setNickname(v);
      ref.read(settingsProvider.notifier).setName(v);
      setState(() => _nickMsg = 'تم الحفظ ✓');
    } catch (e) {
      setState(() => _nickMsg = authErrorText(e));
    }
  }

  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final rate = p.played == 0 ? 0 : (p.won * 100 / p.played).round();
    final toNext = p.nextRankAt - p.stars;
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Row(children: [
              IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
              const Spacer(),
              const MonoLabel('AGENT DOSSIER // الملف'),
            ]),
            const SizedBox(height: 10),
            HudPanel(
              label: 'IDENTITY',
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(
                  controller: _name,
                  maxLength: 20,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  decoration: fieldDecoration('الاسم الحركي', icon: Icons.badge_outlined),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveNick(),
                  onEditingComplete: _saveNick,
                ),
                if (_nickMsg != null) Text(_nickMsg!, style: const TextStyle(color: K.muted, fontSize: 12.5)),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.military_tech, color: K.amber, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.rank, style: const TextStyle(color: K.amber, fontSize: 20, fontWeight: FontWeight.w900)),
                      Text(toNext > 0 ? 'باقي $toNext نجمة للرتبة التالية' : 'أعلى رتبة!',
                          style: const TextStyle(color: K.muted, fontSize: 12.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: p.nextRankAt == 0 ? 1 : (p.stars / p.nextRankAt).clamp(0.0, 1.0).toDouble(),
                    minHeight: 6,
                    color: K.amber,
                    backgroundColor: K.line,
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            HudPanel(
              label: 'SERVICE RECORD',
              color: K.agent,
              child: Column(children: [
                _Line(Icons.flag_outlined, 'المهمّات', '${p.played}'),
                _Line(Icons.lock_open, 'الخزائن المفتوحة', '${p.won}'),
                _Line(Icons.percent, 'نسبة النجاح', '$rate%'),
                _Line(Icons.star_rounded, 'النجوم', '${p.stars}'),
                _Line(Icons.flag, 'أعلى مرحلة', '${p.bestStage}'),
                _Line(Icons.monetization_on, 'العملات', '${p.coins}'),
                _Line(Icons.timer_outlined, 'أفضل وقت', p.bestTime == 0 ? '—' : fmtTime(p.bestTime.toDouble())),
              ]),
            ),
            const SizedBox(height: 14),
            ListenableBuilder(
              listenable: authService,
              builder: (context, _) {
                final pr = authService.profile;
                return HudPanel(
                  label: 'ACCOUNT',
                  color: K.amber,
                  child: Column(children: [
                    _Line(Icons.alternate_email, 'البريد', authService.email ?? '—'),
                    _Line(Icons.timer_outlined, 'رصيد الوقت', pr == null ? '—' : '${pr.balanceMinutes} دقيقة'),
                    _Line(Icons.event, 'تاريخ التسجيل', pr == null ? '—' : _date(pr.createdAt)),
                    _Line(Icons.login, 'آخر دخول', pr == null ? '—' : _date(pr.lastSeen)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: NeonButton(
                          label: 'الخصوصية',
                          icon: Icons.privacy_tip_outlined,
                          filled: false,
                          height: 46,
                          color: K.agent,
                          onTap: () => context.push('/privacy'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: NeonButton(
                          label: 'خروج',
                          icon: Icons.logout,
                          filled: false,
                          height: 46,
                          color: K.danger,
                          onTap: () async {
                            final ok = await confirmDialog(context,
                                title: 'تسجيل الخروج', body: 'ستعود لشاشة الدخول.', confirm: 'خروج');
                            if (ok) await authService.signOut();
                          },
                        ),
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String k;
  final String v;
  const _Line(this.icon, this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Icon(icon, color: K.agent, size: 20),
          const SizedBox(width: 10),
          Text(k, style: const TextStyle(fontSize: 15)),
          const Spacer(),
          Text(v, style: const TextStyle(fontFamily: K.mono, fontSize: 18, color: K.text)),
        ]),
      );
}
