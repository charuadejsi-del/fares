// الجانب الاجتماعي: الرادار (مطابقة عشوائية)، الأصدقاء والدعوات، الحظر والإبلاغ، كود الدعوة، التحديات اليومية.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';

/// نتيجة بحث الرادار.
class MatchResult {
  final bool matched;
  final int waited;
  final int others;
  final int botAfter;
  final String code;
  final String channel;
  final bool host;
  final String? partner;
  final String partnerNick;
  final int partnerSkill;
  const MatchResult({
    required this.matched,
    this.waited = 0,
    this.others = 0,
    this.botAfter = 60,
    this.code = '',
    this.channel = '',
    this.host = false,
    this.partner,
    this.partnerNick = '',
    this.partnerSkill = 0,
  });

  factory MatchResult.fromJson(Map m) => MatchResult(
        matched: m['status'] == 'matched',
        waited: (m['waited'] as num?)?.toInt() ?? 0,
        others: (m['others'] as num?)?.toInt() ?? 0,
        botAfter: (m['bot_after'] as num?)?.toInt() ?? 60,
        code: '${m['code'] ?? ''}',
        channel: '${m['channel'] ?? ''}',
        host: m['host'] == true,
        partner: m['partner'] as String?,
        partnerNick: '${m['partner_nick'] ?? ''}',
        partnerSkill: (m['partner_skill'] as num?)?.toInt() ?? 0,
      );
}

class Friend {
  final String id;
  final String nickname;
  final bool accepted;
  final bool incoming;
  final bool online;
  final int skill;
  const Friend(this.id, this.nickname, this.accepted, this.incoming, this.online, this.skill);
  factory Friend.fromJson(Map m) => Friend('${m['id']}', '${m['nickname']}', m['status'] == 'accepted',
      m['incoming'] == true, m['online'] == true, (m['skill'] as num?)?.toInt() ?? 0);
}

class RoomInvite {
  final int id;
  final String from;
  final String nickname;
  final String code;
  const RoomInvite(this.id, this.from, this.nickname, this.code);
  factory RoomInvite.fromJson(Map m) =>
      RoomInvite((m['id'] as num).toInt(), '${m['from']}', '${m['nickname']}', '${m['code']}');
}

class Referral {
  final String code;
  final bool used;
  final bool canApply;
  final int invited;
  final int rewarded;
  final int bonusMinutes;
  const Referral(this.code, this.used, this.canApply, this.invited, this.rewarded, this.bonusMinutes);
  factory Referral.fromJson(Map m) => Referral('${m['code'] ?? ''}', m['used'] == true, m['can_apply'] == true,
      (m['invited'] as num?)?.toInt() ?? 0, (m['rewarded'] as num?)?.toInt() ?? 0, (m['bonus_minutes'] as num?)?.toInt() ?? 30);
}

class Challenge {
  final String code;
  final int progress;
  final int target;
  final bool claimed;
  final int rewardMinutes;
  const Challenge(this.code, this.progress, this.target, this.claimed, this.rewardMinutes);
  factory Challenge.fromJson(Map m) => Challenge('${m['code']}', (m['progress'] as num?)?.toInt() ?? 0,
      (m['target'] as num?)?.toInt() ?? 1, m['claimed'] == true, (m['reward_minutes'] as num?)?.toInt() ?? 5);

  bool get ready => !claimed && progress >= target;

  String get title => switch (code) {
        'win2' => 'افتح خزنتين اليوم',
        'win3' => 'افتح 3 خزنات اليوم',
        'flawless' => 'فُز بمهمّة بلا أي خطأ',
        'nohint' => 'فُز بمهمّة بلا تلميح',
        'stranger' => 'العب مهمّة مع عميل من الرادار',
        'play20' => 'العب 20 دقيقة',
        _ => code,
      };

  String get icon => switch (code) {
        'win2' || 'win3' => '🔓',
        'flawless' => '🎯',
        'nohint' => '🧠',
        'stranger' => '📡',
        'play20' => '⏱',
        _ => '⭐',
      };
}

/// أسباب الإبلاغ (المفتاح يُرسل للخادم).
const Map<String, String> kReportReasons = {
  'insult': 'شتم أو إساءة',
  'inappropriate': 'كلام غير لائق',
  'cheat': 'غشّ أو تخريب المهمّة',
  'spam': 'إزعاج أو إعلانات',
  'other': 'سبب آخر',
};

class SocialService {
  // ── الرادار
  static Future<MatchResult> search() async =>
      MatchResult.fromJson(Map<String, dynamic>.from(await supa.rpc('match_search') as Map));
  static Future<void> cancel() => supa.rpc('match_cancel');

  // ── الأصدقاء
  static Future<List<Friend>> friends() async =>
      [for (final m in (await supa.rpc('friend_list') as List? ?? const [])) Friend.fromJson(m as Map)];
  static Future<String> request(String nickname) async =>
      '${await supa.rpc('friend_request', params: {'p_nickname': nickname.trim()})}';
  static Future<void> respond(String user, bool accept) =>
      supa.rpc('friend_respond', params: {'p_user': user, 'p_accept': accept});
  static Future<void> remove(String user) => supa.rpc('friend_remove', params: {'p_user': user});

  /// دعوة صديق: يُنشئ غرفة جديدة (أنا القائد). يُرجع (الرمز، القناة).
  static Future<(String, String)> invite(String user) async {
    final r = Map<String, dynamic>.from(await supa.rpc('friend_invite', params: {'p_user': user}) as Map);
    final code = '${r['code']}';
    return (code, '$code-${r['key']}');
  }

  static Future<List<RoomInvite>> invites() async =>
      [for (final m in (await supa.rpc('my_invites') as List? ?? const [])) RoomInvite.fromJson(m as Map)];

  /// يُرجع القناة السرّية عند القبول.
  static Future<String?> respondInvite(int id, bool accept) async {
    final r = await supa.rpc('invite_respond', params: {'p_id': id, 'p_accept': accept});
    return r == null ? null : '$r';
  }

  // ── الحظر والإبلاغ
  static Future<void> block(String user) => supa.rpc('block_player', params: {'p_user': user});
  static Future<void> unblock(String user) => supa.rpc('unblock_player', params: {'p_user': user});
  static Future<List<(String, String)>> blocks() async => [
        for (final m in (await supa.rpc('my_blocks') as List? ?? const []))
          ('${(m as Map)['id']}', '${m['nickname']}')
      ];
  static Future<void> report(String user, String reason, String details) =>
      supa.rpc('report_player', params: {'p_user': user, 'p_reason': reason, 'p_details': details});

  // ── كود الدعوة
  static Future<Referral> referral() async => Referral.fromJson(Map<String, dynamic>.from(await supa.rpc('my_referral') as Map));
  static Future<void> applyReferral(String code) => supa.rpc('referral_apply', params: {'p_code': code.trim()});

  // ── التحديات
  static Future<List<Challenge>> challenges() async =>
      [for (final m in (await supa.rpc('challenges_today') as List? ?? const [])) Challenge.fromJson(m as Map)];
  static Future<int> claim(String code) async => ((await supa.rpc('challenge_claim', params: {'p_code': code})) as num).toInt();

  // ── العودة للمهمّة
  static Future<Map<String, dynamic>?> resume(String session) async {
    final r = await supa.rpc('session_resume', params: {'p_session': session});
    return r == null ? null : Map<String, dynamic>.from(r as Map);
  }

  /// حضور «متصل» للأصدقاء.
  static Future<void> presence() => supa.rpc('touch_profile');
}

final friendsProvider = FutureProvider.autoDispose<List<Friend>>((ref) => SocialService.friends());
final challengesProvider = FutureProvider.autoDispose<List<Challenge>>((ref) => SocialService.challenges());
final referralProvider = FutureProvider.autoDispose<Referral>((ref) => SocialService.referral());
