// «فريقي»: كل من لعبت معهم، مع مرحلتكما ونجومكما، وزرّ «العب معه الآن» يعيدكما لنفس المرحلة.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/session.dart';
import '../../core/social.dart';
import '../../core/team.dart';
import '../../widgets/online_launch.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/stage_map.dart';
import '../../widgets/ui_kit.dart';

class TeamScreen extends ConsumerStatefulWidget {
  const TeamScreen({super.key});

  @override
  ConsumerState<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends ConsumerState<TeamScreen> {
  String? _busy; // partner الجاري تشغيله

  static String _ago(DateTime? t) {
    if (t == null) return '—';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'الآن';
    if (d.inMinutes < 60) return 'منذ ${d.inMinutes} د';
    if (d.inHours < 24) return 'منذ ${d.inHours} سا';
    if (d.inDays == 1) return 'أمس';
    return 'منذ ${d.inDays} أيام';
  }

  /// يفتح غرفة مع هذا الشريك على مرحلة محدّدة (أو مرحلتكما الحالية).
  Future<void> _play(TeamMate m, {int? stage}) async {
    setState(() => _busy = m.partner);
    try {
      String code, channel;
      if (m.friend) {
        (code, channel) = await SocialService.invite(m.partner); // يصله إشعار الدعوة داخل التطبيق
      } else {
        (code, channel) = await SessionService.roomCreate();
      }
      if (!mounted) return;
      if (!m.friend) showToast(context, 'أرسل له رمز الغرفة من شاشة الانتظار');
      await launchOnline(context, code: code, channel: channel, host: true, stage: stage ?? m.top + 1);
    } catch (e) {
      if (mounted) showToast(context, 'تعذّر إنشاء الغرفة — تحقّق من الإنترنت', error: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _improve(TeamMate m) async {
    TeamProgress p;
    try {
      p = await ref.read(teamProgressProvider(m.partner).future);
    } catch (_) {
      if (mounted) showToast(context, 'تعذّر تحميل خريطة الفريق', error: true);
      return;
    }
    if (!mounted) return;
    final n = await showStageMap(context, progress: p, selected: p.current, canPick: true);
    if (n != null && mounted) await _play(m, stage: n);
  }

  Future<void> _addFriend(TeamMate m) async {
    try {
      await SocialService.request(m.nickname);
      if (mounted) showToast(context, 'أُرسل طلب الصداقة إلى ${m.nickname}');
    } catch (_) {
      if (mounted) showToast(context, 'تعذّر إرسال الطلب', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mates = ref.watch(teamMatesProvider);
    return Scaffold(
      body: SpyBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
              child: Row(children: [
                IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.arrow_forward, color: K.text2)),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MonoLabel('MY TEAMS', size: 10.5),
                    Text('فريقي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                color: K.neon,
                onRefresh: () async => ref.invalidate(teamMatesProvider),
                child: mates.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: K.neon)),
                  error: (_, __) => ListView(children: const [
                    SizedBox(height: 120),
                    Center(child: Text('تعذّر التحميل — اسحب للتحديث', style: TextStyle(color: K.muted))),
                  ]),
                  data: (list) => list.isEmpty
                      ? ListView(padding: const EdgeInsets.all(24), children: const [
                          SizedBox(height: 80),
                          Icon(Icons.group_outlined, color: K.muted, size: 40),
                          SizedBox(height: 10),
                          Text('لم تلعب مع أحد بعد.\nكل شريك تلعب معه يظهر هنا مع مرحلتكما.',
                              textAlign: TextAlign.center, style: TextStyle(color: K.muted, height: 1.6)),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _MateCard(
                            m: list[i],
                            ago: _ago(list[i].lastPlayed),
                            busy: _busy == list[i].partner,
                            onPlay: _busy == null ? () => _play(list[i]) : null,
                            onImprove: _busy == null && list[i].top > 0 ? () => _improve(list[i]) : null,
                            onFriend: list[i].friend ? null : () => _addFriend(list[i]),
                          ),
                        ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MateCard extends StatelessWidget {
  final TeamMate m;
  final String ago;
  final bool busy;
  final VoidCallback? onPlay, onImprove, onFriend;
  const _MateCard({required this.m, required this.ago, required this.busy, this.onPlay, this.onImprove, this.onFriend});

  @override
  Widget build(BuildContext context) {
    final next = m.top + 1;
    final maxStars = m.top * 3;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(m.nickname, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(m.nickname, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                if (m.friend) ...[const SizedBox(width: 6), const Icon(Icons.verified_user_outlined, color: K.ok, size: 16)],
              ]),
              const SizedBox(height: 2),
              Text('آخر لعب: $ago', style: const TextStyle(color: K.muted, fontSize: 12)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${m.top}', style: const TextStyle(fontFamily: K.mono, fontSize: 22, color: K.neon, height: 1)),
            const Text('مرحلة', style: TextStyle(color: K.muted, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.star_rounded, color: K.neon, size: 16),
          const SizedBox(width: 4),
          Text('${m.stars} / $maxStars نجمة', style: const TextStyle(color: K.text2, fontSize: 12.5)),
          const SizedBox(width: 10),
          Expanded(
            child: LinearProgressIndicator(
              value: maxStars == 0 ? 0 : (m.stars / maxStars).clamp(0.0, 1.0).toDouble(),
              minHeight: 3,
              color: K.neon,
              backgroundColor: K.border,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GlowButton(label: 'العب معه الآن · المرحلة $next', icon: Icons.play_arrow_rounded, height: 46, busy: busy, onTap: onPlay),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onImprove,
              icon: const Icon(Icons.star_half_rounded, size: 18),
              label: const Text('حسّن النجوم'),
              style: OutlinedButton.styleFrom(
                foregroundColor: K.text,
                side: const BorderSide(color: K.borderStrong),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
              ),
            ),
          ),
          if (onFriend != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onFriend,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('أضفه صديقاً'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: K.text2,
                  side: const BorderSide(color: K.borderStrong),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(K.radius)),
                ),
              ),
            ),
          ],
        ]),
        if (onFriend != null)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('بعد قبول الصداقة تصله الدعوة مباشرة دون رمز.', style: TextStyle(color: K.muted, fontSize: 11.5)),
          ),
      ]),
    );
  }
}
