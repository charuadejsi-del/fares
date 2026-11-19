import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/controller.dart';
import '../../core/services.dart';
import '../../net/transport.dart';
import '../../widgets/spy_ui.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(audioProvider).startMusic());
  }

  String get _name {
    final n = ref.read(settingsProvider).name;
    return n.isEmpty ? 'عميل' : n;
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: K.font)),
        backgroundColor: K.panelSolid,
        behavior: SnackBarBehavior.floating,
      ));

  Future<void> _online({required bool host, String code = ''}) async {
    if (!onlineAvailable) {
      _toast('اللعب أونلاين غير مفعّل في هذه النسخة بعد.');
      return;
    }
    setState(() => _busy = true);
    final c = GameController.online(meName: _name, code: host ? GameController.newRoomCode() : code, isHost: host);
    try {
      await c.connect();
    } catch (_) {
      c.dispose();
      if (mounted) {
        setState(() => _busy = false);
        _toast('تعذّر الاتصال بالقاعدة. تحقّق من الإنترنت.');
      }
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _busy = false);
    context.push('/play', extra: c);
  }

  Future<void> _joinDialog() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: HudPanel(
          label: 'JOIN // رمز الغرفة',
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontFamily: K.mono, fontSize: 34, color: K.neon, letterSpacing: 12),
              decoration: fieldDecoration('0000'),
            ),
            const SizedBox(height: 14),
            NeonButton(label: 'دخول', icon: Icons.login, onTap: () => Navigator.of(ctx).pop(ctl.text.trim())),
          ]),
        ),
      ),
    );
    ctl.dispose();
    if (code == null) return;
    if (!RegExp(r'^\d{4}$').hasMatch(code)) {
      _toast('الرمز يتكوّن من 4 أرقام.');
      return;
    }
    await _online(host: false, code: code);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      body: SpyBackground(
        image: 'assets/images/home_bg.jpg',
        dim: 0.55,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    _IconBtn(icon: Icons.person_outline, onTap: () => context.push('/profile')),
                    const Spacer(),
                    const MonoLabel('HQ-07 // ONLINE'),
                    const Spacer(),
                    _IconBtn(icon: Icons.tune, onTap: () => context.push('/settings')),
                  ]),
                  const SizedBox(height: 36),
                  const Center(child: GlitchTitle('الخزنة', size: 64)),
                  const SizedBox(height: 4),
                  const Text('مهمّة تجسّس جماعية',
                      textAlign: TextAlign.center, style: TextStyle(color: K.text, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('عميل في الميدان + محلّل في القاعدة = خزنة مفتوحة',
                      textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 13.5)),
                  const SizedBox(height: 28),
                  HudPanel(
                    label: 'AGENT FILE',
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(border: Border.all(color: K.neon), color: K.neon.withAlpha(20)),
                        child: const Icon(Icons.badge_outlined, color: K.neon),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(settings.name.isEmpty ? 'عميل بلا اسم' : settings.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          Text(progress.rank, style: const TextStyle(color: K.amber, fontSize: 13)),
                        ]),
                      ),
                      _Stat(icon: Icons.monetization_on, value: '${progress.coins}', color: K.amber),
                      const SizedBox(width: 12),
                      _Stat(icon: Icons.flag, value: '${progress.bestStage}', color: K.neon),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  NeonButton(
                    label: 'الحملة: 60 مرحلة + الخريطة الاحترافية',
                    icon: Icons.map_outlined,
                    onTap: _busy ? null : () => context.push('/campaign'),
                  ),
                  const SizedBox(height: 12),
                  NeonButton(
                    label: 'مهمّة حرّة',
                    icon: Icons.play_arrow_rounded,
                    filled: false,
                    onTap: _busy ? null : () => context.push('/briefing'),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: NeonButton(
                        label: 'إنشاء غرفة',
                        icon: Icons.wifi_tethering,
                        filled: false,
                        color: K.agent,
                        onTap: _busy ? null : () => _online(host: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: NeonButton(
                        label: 'دخول برمز',
                        icon: Icons.login,
                        filled: false,
                        color: K.agent,
                        onTap: _busy ? null : _joinDialog,
                      ),
                    ),
                  ]),
                  if (_busy) ...[
                    const SizedBox(height: 18),
                    const Center(child: CircularProgressIndicator(color: K.neon)),
                  ],
                  if (!onlineAvailable) ...[
                    const SizedBox(height: 8),
                    const Text('اللعب أونلاين يُفعَّل قريباً — جرّب الآن على هاتف واحد مع صديقك.',
                        textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  NeonButton(
                    label: 'الترتيب العالمي',
                    icon: Icons.leaderboard_outlined,
                    filled: false,
                    color: K.amber,
                    height: 50,
                    onTap: () => context.push('/leaderboard'),
                  ),
                  const SizedBox(height: 10),
                  NeonButton(
                    label: 'التدريب: كيف تُلعب؟',
                    icon: Icons.school_outlined,
                    filled: false,
                    color: K.amber,
                    height: 50,
                    onTap: () => context.push('/tutorial'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends ConsumerWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) => InkWell(
        onTap: () {
          ref.read(audioProvider).fx(Sfx.click, HapticKind.tap, volume: 0.5);
          onTap();
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(border: Border.all(color: K.line), color: K.panel),
          child: Icon(icon, color: K.neon),
        ),
      );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _Stat({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(children: [
        Icon(icon, color: color, size: 20),
        Text(value, style: TextStyle(fontFamily: K.mono, color: color, fontSize: 16)),
      ]);
}
