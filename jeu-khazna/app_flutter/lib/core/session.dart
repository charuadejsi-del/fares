// جلسات اللعب في الخادم: بداية، نبضات خصم الوقت، عقوبات الأخطاء، التلميحات، النهاية، وسجلّ الغرف.
import 'auth.dart';

class SessionStart {
  final String id;
  final int? timeLimit;
  const SessionStart(this.id, this.timeLimit);
}

class SessionService {
  static Future<SessionStart> start({String room = '', String? partner, required int stage}) async {
    final r = await supa.rpc('session_start', params: {'p_room': room, 'p_partner': partner, 'p_stage': stage});
    final m = Map<String, dynamic>.from(r as Map);
    return SessionStart('${m['id']}', (m['time_limit'] as num?)?.toInt());
  }

  /// يُرجع رصيد اللاعب بالثواني بعد الخصم.
  static Future<int> beat(String session, {required bool active}) async =>
      ((await supa.rpc('session_beat', params: {'p_session': session, 'p_active': active})) as num).toInt();

  static Future<int> error(String session) async => ((await supa.rpc('session_error', params: {'p_session': session})) as num).toInt();

  static Future<int> hint(String session) async => ((await supa.rpc('session_hint', params: {'p_session': session})) as num).toInt();

  static Future<int> end(String session, String status) async =>
      ((await supa.rpc('session_end', params: {'p_session': session, 'p_status': status})) as num).toInt();

  static Future<void> roomOpen(String code) => supa.rpc('room_open', params: {'p_code': code});
  static Future<void> roomJoin(String code) => supa.rpc('room_join', params: {'p_code': code});
  static Future<void> roomClose(String code) => supa.rpc('room_close', params: {'p_code': code});

  /// إهداء دقائق لصديق باسمه الحركي. يُرجع رصيدي الجديد بالثواني.
  static Future<int> gift(String nickname, int minutes) async =>
      ((await supa.rpc('gift_minutes', params: {'p_nickname': nickname, 'p_minutes': minutes})) as num).toInt();
}
