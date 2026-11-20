// ملفّي: بطاقة العميل (الهوية، الرتبة، الرصيد)، سجلّ الخدمة، والحساب.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/services.dart';
import '../../core/social.dart';
import '../../core/team.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/title_frame.dart';
import '../../widgets/ui_kit.dart';
import '../play/play_screen.dart' show fmtTime;

class ProfileScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const ProfileScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _rename() async {
    final ctl = TextEditingController(text: authService.profile?.nickname ?? '');
    final v = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassCard(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('الاسم الحركي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(controller: ctl, autofocus: true, maxLength: 20, decoration: fieldDecoration('اسمك في اللعبة', icon: Icons.badge_outlined)),
            GlowButton(label: 'حفظ', icon: Icons.check, height: 48, onTap: () => Navigator.of(ctx).pop(ctl.text.trim())),
          ]),
        ),
      ),
    );
    ctl.dispose();
    if (v == null || v.isEmpty || v == authService.profile?.nickname) return;
    try {
      await authService.setNickname(v);
      ref.read(settingsProvider.notifier).setName(v);
      if (mounted) showToast(context, 'تمّ تغيير الاسم ✓');
    } catch (e) {
      if (mounted) showToast(context, authErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    final team = ref.watch(teamProgressProvider(null)).valueOrNull ?? TeamProgress.empty;
    final rate = p.played == 0 ? 0 : (p.won * 100 / p.played).round();
    final toNext = p.nextRankAt - p.stars;
    final content = ListenableBuilder(
      listenable: authService,
      builder: (context, _) {
        final pr = authService.profile;
        final name = pr?.nickname ?? '—';
        return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Row(children: [
            if (!widget.embedded) IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.neon)),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ملفّي', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              MonoLabel('AGENT DOSSIER // الملف السرّي', size: 10),
            ]),
            const Spacer(),
            IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.tune_rounded, color: K.muted)),
          ]),
          const SizedBox(height: 12),
          // ── بطاقة العميل
          GlassCard(
            accent: K.amber,
            padding: const EdgeInsets.all(18),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFF1E1A0E), Color(0xFF111614), Color(0xFF0A1011)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const MonoLabel('CLASSIFIED · AGENT ID', color: K.amber, size: 10),
                const Spacer(),
                Icon(Icons.verified_user, color: K.amber.withAlpha(200), size: 18),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                TitleAvatar(name, title: ref.watch(seasonProvider).valueOrNull?.myTitle, size: 72),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
                      IconButton(onPressed: _rename, icon: const Icon(Icons.edit_outlined, size: 18, color: K.muted), visualDensity: VisualDensity.compact),
                    ]),
                    Row(children: [
                      const Icon(Icons.military_tech, color: K.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(p.rank, style: const TextStyle(color: K.amber, fontWeight: FontWeight.w800)),
                    ]),
                    TitleBadge(ref.watch(seasonProvider).valueOrNull?.myTitle),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: p.nextRankAt == 0 ? 1 : (p.stars / p.nextRankAt).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        color: K.amber,
                        backgroundColor: K.border,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(toNext > 0 ? 'باقي $toNext نجمة للرتبة التالية' : 'أعلى رتبة!', style: const TextStyle(color: K.muted, fontSize: 11.5)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _Big('${pr?.balanceMinutes ?? '—'}', 'دقيقة رصيد', K.neon)),
                Expanded(child: _Big('${team.top}', 'مراحل الحملة', K.agent)),
                Expanded(child: _Big('${p.stars}', 'نجمة', K.amber)),
              ]),
            ]),
          ),
          const SizedBox(height: 22),
          const SectionTitle('سجلّ الخدمة', tag: 'SERVICE RECORD'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              _Stat(Icons.flag_outlined, '${p.played}', 'مهمّة', K.text2),
              _Stat(Icons.lock_open_rounded, '${p.won}', 'خزنة مفتوحة', K.neon),
              _Stat(Icons.percent, '$rate%', 'نسبة النجاح', K.agent),
              _Stat(Icons.timer_outlined, p.bestTime == 0 ? '—' : fmtTime(p.bestTime.toDouble()), 'أفضل وقت', K.violet),
              _Stat(Icons.star_rounded, '${team.totalStars}', 'نجوم الحملة', K.amber),
              _Stat(Icons.local_fire_department, '${team.top ~/ 20}', 'زعماء هُزموا', K.danger),
            ],
          ),
          const SizedBox(height: 22),
          const SectionTitle('الحساب', tag: 'ACCOUNT'),
          GlassCard(
            accent: K.border,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(children: [
              _Line(Icons.alternate_email, 'البريد', authService.email ?? '—'),
              _Line(Icons.event_outlined, 'تاريخ التسجيل', pr == null ? '—' : _date(pr.createdAt)),
              _Line(Icons.login_rounded, 'آخر دخول', pr == null ? '—' : _date(pr.lastSeen)),
            ]),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: GlowButton(label: 'الخصوصية', icon: Icons.privacy_tip_outlined, outline: true, color: K.agent, height: 48, onTap: () => context.push('/privacy'))),
            const SizedBox(width: 10),
            Expanded(
              child: GlowButton(
                label: 'خروج',
                icon: Icons.logout_rounded,
                outline: true,
                color: K.danger,
                height: 48,
                onTap: () async {
                  final ok = await confirmDialog(context, title: 'تسجيل الخروج', body: 'ستعود لشاشة الدخول.', confirm: 'خروج');
                  if (ok) {
                    ref.read(tabProvider.notifier).state = 0;
                    await authService.signOut();
                  }
                },
              ),
            ),
          ]),
        ]);
      },
    );
    if (widget.embedded) return content;
    return Scaffold(body: SpyBackground(child: SafeArea(child: content)));
  }
}

class _Big extends StatelessWidget {
  final String v;
  final String k;
  final Color c;
  const _Big(this.v, this.k, this.c);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(v, style: TextStyle(fontFamily: K.mono, fontSize: 24, color: c, shadows: [Shadow(color: c.withAlpha(120), blurRadius: 12)])),
        Text(k, style: const TextStyle(color: K.muted, fontSize: 11.5)),
      ]);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String v;
  final String k;
  final Color c;
  const _Stat(this.icon, this.v, this.k, this.c);

  @override
  Widget build(BuildContext context) => GlassCard(
        accent: c,
        radius: 16,
        padding: const EdgeInsets.all(10),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 20),
          const SizedBox(height: 6),
          FittedBox(child: Text(v, style: const TextStyle(fontFamily: K.mono, fontSize: 19))),
          Text(k, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: K.muted, fontSize: 11)),
        ]),
      );
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String k;
  final String v;
  const _Line(this.icon, this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Icon(icon, color: K.muted, size: 19),
          const SizedBox(width: 10),
          Text(k, style: const TextStyle(color: K.text2)),
          const Spacer(),
          Flexible(
            child: Text(v,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: K.mono, fontSize: 13.5, color: K.text)),
          ),
        ]),
      );
}
