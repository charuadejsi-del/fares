// يدير جلسة لعب: وضع الهاتف الواحد، أو أونلاين (المضيف هو المرجع، والضيف يرسل أفعاله فقط).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../net/transport.dart';
import 'auth.dart';
import 'bot.dart';
import 'game.dart';
import 'session.dart';
import 'stages.dart';

class Player {
  final String name;
  String role; // op | ex
  /// معرّف الحساب (Supabase) — لربط تقدّم الفريق في الخادم.
  final String? uid;
  Player(this.name, this.role, [this.uid]);
  Map<String, dynamic> toJson() => {'name': name, 'role': role, if (uid != null) 'uid': uid};
}

/// سطر في محادثة المهمّة (رسالة سريعة أو كلام العميل الآلي).
class ChatLine {
  final bool mine;
  final String text;
  final int at;
  final bool bot;
  const ChatLine(this.mine, this.text, this.at, {this.bot = false});
}

/// الرسائل السريعة: بديل آمن للميكروفون مع الغرباء.
const Map<String, String> kQuickMessages = {
  'hello': '👋 مرحباً',
  'repeat': '🔁 أعد من فضلك',
  'wait': '✋ انتظر',
  'ok': '✅ صحيح',
  'no': '❌ خطأ',
  'code': '🔢 ما هو الرمز؟',
  'color': '🎨 أي لون؟',
  'thanks': '🙏 شكراً',
};

/// لقطة المهمّة الجارية لاستئنافها بعد إغلاق التطبيق أو انقطاع الإنترنت.
class RejoinData {
  final String code;
  final String channel;
  final bool host;
  final String meId;
  final String? sessionId;
  final bool matched;
  final int at;
  final Map<String, dynamic>? state;
  final Map<String, dynamic>? players;
  const RejoinData(this.code, this.channel, this.host, this.meId, this.sessionId, this.matched, this.at, this.state, this.players);

  static const _k = 'khazna.rejoin';

  Map<String, dynamic> toJson() => {
        'code': code, 'channel': channel, 'host': host, 'me': meId, 'session': sessionId,
        'matched': matched, 'at': at, 'state': state, 'players': players,
      };

  static Future<RejoinData?> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_k);
      if (raw == null) return null;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final d = RejoinData('${m['code']}', '${m['channel']}', m['host'] == true, '${m['me']}', m['session'] as String?,
          m['matched'] == true, (m['at'] as num?)?.toInt() ?? 0,
          m['state'] == null ? null : Map<String, dynamic>.from(m['state'] as Map),
          m['players'] == null ? null : Map<String, dynamic>.from(m['players'] as Map));
      if (DateTime.now().millisecondsSinceEpoch - d.at > 10 * 60 * 1000) {
        await clear();
        return null;
      }
      return d;
    } catch (_) {
      return null;
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_k, jsonEncode(toJson()));
    } catch (_) {}
  }

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_k);
    } catch (_) {}
  }
}

class GameController extends ChangeNotifier {
  final bool online;
  final bool isHost;
  final String code;

  /// القناة السرّية للغرفة (الرمز + مفتاح فريد): الصوت والبيانات لا تختلط بين غرفتين أبداً.
  final String channel;
  final String meId;
  final String meName;

  /// وضع الطاولة: الهاتف بين اللاعبَين، والشاشة مقسومة نصفين.
  final bool table;

  /// اللعب مع العميل الآلي (المحلّل آلي، واللاعب هو العميل الميداني).
  final bool bot;

  /// الشريك جاء من الرادار (غريب): الميكروفون مكتوم افتراضياً.
  final bool matched;

  /// لقطة للاستئناف (أونلاين).
  final RejoinData? resume;

  /// محادثة المهمّة.
  final List<ChatLine> chat = [];

  /// أقفال المهمّة ومستوى الصعوبة (وضع الهاتف الواحد).
  final List<String> rooms;
  final String diff;

  /// رقم المرحلة في وضع الهاتف الواحد (0 = مهمّة حرّة). أونلاين تأتي المرحلة من الحالة.
  final int missionId;

  /// المرحلة الحالية (محلياً أو أونلاين).
  int get stage => state?.stage ?? missionId;

  GameState? state;
  Puzzles? puzzles;
  Map<String, Player> players = {};
  String? error;

  // ───── الجلسة في الخادم (خصم الوقت) ─────
  String? sessionId;
  String? _endedSession;
  bool starting = false;

  /// رسالة للّاعب (رصيد غير كافٍ...).
  String? notice;
  bool meBroke = false;
  bool _peerBroke = false;
  int _lastPeerSeen = 0;
  Timer? _beat;
  Timer? _ping;
  String _penaltyKey = '';
  int _lastTouch = 0;

  /// الضيف: انقطع وصول حالة القائد.
  bool get hostLost => online && !isHost && state?.phase == 'playing' && _recvAt > 0 && _now() - _recvAt > 9000;

  /// الدور المعروض في وضع الهاتف الواحد (يتبدّل بزرّ).
  String localRole = 'op';

  Transport? _net;
  Timer? _loop;
  Timer? _hello;
  int _lastBroadcast = 0;
  double _recvRem = kDuration.toDouble();
  int _recvAt = 0;
  String _seenKey = '';
  bool _disposed = false;
  final StreamController<GameEvent> _events = StreamController<GameEvent>.broadcast();

  Stream<GameEvent> get events => _events.stream;

  static final Random _rand = Random();
  static String _rid() => _rand.nextInt(1 << 30).toRadixString(36);
  static int _newSeed() => _rand.nextInt(0x7FFFFFFF);
  static String newRoomCode() => (1000 + _rand.nextInt(9000)).toString();
  static int _now() => DateTime.now().millisecondsSinceEpoch;

  /// وضع الهاتف الواحد: اللعبة تبدأ مباشرة.
  GameController.local({
    required this.meName,
    this.table = false,
    this.rooms = kRooms,
    this.diff = 'agent',
    this.missionId = 0,
    this.bot = false,
  })  : online = false,
        isHost = true,
        code = '',
        channel = '',
        matched = false,
        resume = null,
        meId = _rid() {
    players = {meId: Player(meName, 'op', authService.uid), if (bot) 'bot': Player(kBotName, 'ex')};
    authService.addListener(_onAuth);
    _startLocal();
    _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tickLoop());
  }

  GameController.online({
    required this.meName,
    required this.code,
    required this.isHost,
    String? channel,
    this.matched = false,
    this.resume,
  })  : channel = channel ?? code,
        online = true,
        table = false,
        bot = false,
        rooms = kRooms,
        diff = 'agent',
        missionId = 0,
        meId = resume?.host == true ? resume!.meId : _rid() {
    authService.addListener(_onAuth);
  }

  Future<void> connect() async {
    _net = await SupabaseTransport.connect(channel, _onMessage);
    if (isHost) {
      final r = resume;
      if (r != null && r.state != null && r.players != null) {
        _restore(r);
      } else {
        state = newState(_newSeed());
        puzzles = generatePuzzles(state!.seed);
        players = {meId: Player(meName, 'op', authService.uid)};
      }
      _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tickLoop());
      _broadcast();
    } else {
      _sendHello();
      _hello = Timer.periodic(const Duration(milliseconds: 1500), (_) => _sendHello());
      _ping = Timer.periodic(const Duration(seconds: 4), (_) {
        if (joined && players.containsKey(meId)) _net?.send({'kind': 'ping', 'id': meId, 'broke': meBroke});
      });
    }
    _notify();
  }

  /// القائد يستعيد المهمّة كما كانت، والوقت الضائع أثناء الغياب لا يُحسب.
  void _restore(RejoinData r) {
    var s = GameState.fromJson(r.state!);
    final now = _now();
    if (s.phase == 'playing' && !s.paused) s = resumeGame(pauseGame(s, r.at, 'peer'), now);
    state = s;
    puzzles = generatePuzzles(s.seed, s.diff);
    players = {
      for (final e in r.players!.entries)
        if (e.value is Map)
          e.key: Player('${(e.value as Map)['name']}', '${(e.value as Map)['role']}', (e.value as Map)['uid'] as String?),
    };
    players.putIfAbsent(meId, () => Player(meName, 'op', authService.uid));
    _lastPeerSeen = now;
    if (r.sessionId != null && s.phase == 'playing') {
      sessionId = r.sessionId;
      _startBeat();
    }
  }

  // ───── قراءة الحالة ─────
  /// حساب الشريك (أونلاين) أو null للعب الفردي على هاتف واحد.
  String? get partnerUid {
    if (!online) return null;
    for (final e in players.entries) {
      if (e.key != meId) return e.value.uid;
    }
    return null;
  }

  String? get partnerName {
    for (final e in players.entries) {
      if (e.key != meId) return e.value.name;
    }
    return null;
  }

  /// معرّف الشريك للإبلاغ والحظر والصداقة (أونلاين فقط).
  String? get partnerAccount => online ? partnerUid : null;

  bool get teamReady => !online || (players.length >= 2 && partnerUid != null);

  String? get myRole => online ? players[meId]?.role : localRole;
  bool get joined => !online || players.containsKey(meId);
  bool get canStart => isHost && players.length >= 2 && state?.phase == 'lobby';

  double get remaining {
    final s = state;
    if (s == null) return kDuration.toDouble();
    if (s.phase != 'playing') return s.phase == 'lobby' ? s.effectiveDuration.toDouble() : 0;
    if (isHost) return remainingSeconds(s, _now());
    if (s.paused || hostLost) return _recvRem;
    final r = _recvRem - (_now() - _recvAt) / 1000;
    return r < 0 ? 0 : r;
  }

  // ───── الأفعال ─────
  void dispatch(Map<String, dynamic> action) {
    if (isHost) {
      _apply(action);
    } else {
      _net?.send({'kind': 'action', 'id': meId, 'action': action});
    }
  }

  /// رسالة سريعة للشريك (أو للعميل الآلي).
  void sendQuick(String q) {
    final text = kQuickMessages[q];
    if (text == null) return;
    _addChat(ChatLine(true, text, _now()));
    if (bot) {
      final reply = botReply(q, _botScript, _botShown);
      if (reply != null) {
        Timer(Duration(milliseconds: 900 + _rand.nextInt(900)), () {
          if (!_disposed) _addChat(ChatLine(false, reply, _now(), bot: true));
        });
      }
      return;
    }
    if (online) _net?.send({'kind': 'quick', 'id': meId, 'q': q});
  }

  void _addChat(ChatLine l) {
    chat.add(l);
    if (chat.length > 40) chat.removeAt(0);
    _notify();
  }

  // ───── العميل الآلي ─────
  String _botKey = '';
  List<String> _botScript = const [];
  int _botShown = 0;
  int _botNextAt = 0;

  void _botTick() {
    final s = state, p = puzzles;
    if (!bot || s == null || p == null || s.phase != 'playing' || s.paused) return;
    final now = _now();
    final key = botKey(s);
    if (key != _botKey) {
      final first = _botKey.isEmpty;
      _botKey = key;
      _botScript = botScript(s, p);
      _botShown = 0;
      _botNextAt = now + (first ? 2500 : 1600 + _rand.nextInt(1200));
    }
    if (_botShown < _botScript.length && now >= _botNextAt) {
      _addChat(ChatLine(false, _botScript[_botShown], now, bot: true));
      _botShown++;
      _botNextAt = now + 4200 + _rand.nextInt(2600);
    }
  }

  void toggleLocalRole() {
    if (bot) return; // مع الآلي أنت العميل الميداني دائماً
    localRole = localRole == 'op' ? 'ex' : 'op';
    _notify();
  }

  /// بداية المهمّة: الخادم يتحقّق من رصيد اللاعبَين ويعطي مدّة المرحلة.
  Future<void> hostStart() async {
    if (!canStart || starting) return;
    starting = true;
    notice = null;
    _notify();
    try {
      final r = await SessionService.start(room: code, partner: partnerUid, stage: state!.stage);
      if (_disposed) return;
      sessionId = r.id;
      var s = state!;
      if (r.timeLimit != null && s.stage > 0) s = s.withDuration(r.timeLimit!);
      _lastPeerSeen = _now();
      state = startGame(s, puzzles!, _now());
      _broadcast();
      _changed();
      _startBeat();
    } catch (e) {
      notice = authErrorText(e);
      _notify();
    } finally {
      starting = false;
      _notify();
    }
  }

  /// تلميح مدفوع من رصيد من يطلبه. يُرجع رسالة خطأ أو null.
  Future<String?> buyHint() async {
    final sid = sessionId;
    final s = state;
    if (sid == null || s == null || s.phase != 'playing') return 'التلميح متاح أثناء المهمّة فقط';
    if (s.paused) return 'المهمّة متوقّفة';
    try {
      final bal = await SessionService.hint(sid);
      authService.setBalance(bal);
      dispatch({'type': 'hint'});
      return null;
    } catch (e) {
      return authErrorText(e);
    }
  }

  void swapRoles() {
    if (!isHost) return;
    for (final p in players.values) {
      p.role = p.role == 'op' ? 'ex' : 'op';
    }
    _broadcast();
    _notify();
  }

  /// قائد الغرفة يختار مرحلة من الحملة (0 = المهمّة الكلاسيكية).
  void chooseStage(int n) {
    if (!isHost || !online || state?.phase == 'playing') return;
    _finishSession('abandoned');
    sessionId = null;
    final seed = _newSeed();
    if (n <= 0) {
      state = newState(seed);
    } else {
      final d = stageDef(n);
      state = newState(seed, rooms: d.rooms, diff: d.diff, stage: n);
    }
    puzzles = generatePuzzles(seed, state!.diff);
    _broadcast();
    _notify();
  }

  void newGame() {
    if (!isHost) return;
    _finishSession('abandoned');
    sessionId = null;
    notice = null;
    if (!online) {
      _startLocal();
      _changed();
      return;
    }
    final old = state;
    final seed = _newSeed();
    state = old == null ? newState(seed) : newState(seed, rooms: old.rooms, diff: old.diff, stage: old.stage);
    puzzles = generatePuzzles(seed, state!.diff);
    _broadcast();
    _notify();
  }

  // ───── داخلي ─────
  void _startLocal() {
    final seed = _newSeed();
    puzzles = generatePuzzles(seed, diff);
    state = startGame(newState(seed, rooms: rooms, diff: diff, stage: missionId), puzzles!, _now());
    localRole = 'op';
    _openLocalSession();
  }

  /// هاتف واحد: الجلسة تُفتح في الخلفية؛ إن لم يكفِ الرصيد تتوقّف المهمّة حتى الشحن.
  Future<void> _openLocalSession() async {
    try {
      final r = await SessionService.start(stage: missionId);
      if (_disposed) return;
      sessionId = r.id;
      final s = state;
      if (s != null && r.timeLimit != null && s.stage > 0 && s.duration == 0) state = s.withDuration(r.timeLimit!);
      _startBeat();
      _notify();
    } catch (e) {
      if (_disposed) return;
      notice = authErrorText(e);
      if (notice!.contains('رصيد')) {
        meBroke = true;
        _evalPause();
      }
      _notify();
    }
  }

  void _startBeat() {
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 15), (_) => _doBeat());
  }

  Future<void> _doBeat() async {
    final sid = sessionId, s = state;
    if (sid == null || s == null || s.phase != 'playing') return;
    final active = !s.paused && !hostLost;
    try {
      final bal = await SessionService.beat(sid, active: active);
      authService.setBalance(bal);
      _setBroke(bal <= 0);
    } catch (_) {}
  }

  void _setBroke(bool v) {
    if (meBroke == v) return;
    meBroke = v;
    if (isHost) {
      _evalPause();
    } else {
      _net?.send({'kind': 'ping', 'id': meId, 'broke': v});
    }
    _notify();
  }

  void _onAuth() {
    final b = authService.profile?.balanceSeconds ?? 0;
    if (meBroke && b > 0) {
      notice = null;
      if (sessionId == null && !online && state?.phase == 'playing') {
        meBroke = false;
        _openLocalSession().then((_) => _evalPause());
        return;
      }
      _setBroke(false);
    }
  }

  /// القائد يقرّر التوقّف: نفاد رصيد أحد اللاعبَين أو انقطاع الشريك.
  void _evalPause() {
    if (!isHost) return;
    final s = state;
    if (s == null || s.phase != 'playing') return;
    var reason = '';
    if (meBroke || _peerBroke) {
      reason = 'balance';
    } else if (online && players.length >= 2 && _now() - _lastPeerSeen > 10000) {
      reason = 'peer';
    }
    final ns = reason.isEmpty ? resumeGame(s, _now()) : pauseGame(s, _now(), reason);
    if (identical(ns, s)) return;
    state = ns;
    _broadcast();
    _changed();
  }

  void _finishSession(String status) {
    final sid = sessionId;
    if (sid == null || _endedSession == sid) return;
    _endedSession = sid;
    _beat?.cancel();
    SessionService.end(sid, status).then(authService.setBalance).catchError((_) {});
  }

  void _apply(Map<String, dynamic> action) {
    final s = state, p = puzzles;
    if (s == null || p == null) return;
    if (action['type'] == 'hint') {
      final ns = applyHint(s, p);
      if (identical(ns, s)) return;
      state = ns;
      _broadcast();
      _changed();
      return;
    }
    final ns = applyAction(s, p, action, _now());
    if (identical(ns, s)) return;
    state = ns;
    _broadcast();
    _changed();
  }

  int _lastSnap = 0;

  void _snapshot() {
    final s = state;
    if (!online || s == null) return;
    if (s.phase != 'playing') return;
    _lastSnap = _now();
    RejoinData(code, channel, isHost, meId, sessionId, matched, _lastSnap, isHost ? s.toJson() : null,
            isHost ? {for (final e in players.entries) e.key: e.value.toJson()} : null)
        .save();
  }

  void _tickLoop() {
    final s = state;
    if (s == null) return;
    _botTick();
    if (online && s.phase == 'playing' && _now() - _lastSnap > 3000) _snapshot();
    _evalPause();
    if (!isHost && s.phase == 'playing') _notify(); // تحديث شريط «انقطع الاتصال»
    final t = tick(state!, _now());
    if (!identical(t, state)) {
      state = t;
      _broadcast();
      _changed();
      return;
    }
    if (online && _now() - _lastBroadcast > 2000) _broadcast(); // للمتأخرين ومزامنة المؤقّت
    if (online && isHost && s.phase != 'playing' && _now() - _lastTouch > 60000) {
      _lastTouch = _now();
      SessionService.roomTouch(code).catchError((_) {});
    }
  }

  void _sendHello() => _net?.send({'kind': 'hello', 'id': meId, 'name': meName, 'uid': authService.uid});

  void _broadcast() {
    if (!online || !isHost || _net == null || state == null) return;
    _lastBroadcast = _now();
    _net!.send({
      'kind': 'state',
      'state': state!.toJson(),
      'players': {for (final e in players.entries) e.key: e.value.toJson()},
      'rem': remainingSeconds(state!, _now()),
      if (sessionId != null) 'session': sessionId,
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    if (_disposed) return;
    final kind = m['kind'];
    if (kind == 'quick') {
      final id = m['id'], q = m['q'];
      final t = q is String ? kQuickMessages[q] : null;
      if (id is String && id != meId && players.containsKey(id) && t != null) _addChat(ChatLine(false, t, _now()));
      if (isHost && id is String && players.containsKey(id)) _lastPeerSeen = _now();
      return;
    }
    if (isHost) {
      final id = m['id'];
      if (id is String && id != meId && players.containsKey(id)) _lastPeerSeen = _now();
      if (kind == 'ping' && id is String && players.containsKey(id)) {
        final b = m['broke'] == true;
        if (b != _peerBroke) {
          _peerBroke = b;
          _evalPause();
        }
        return;
      }
      if (kind == 'hello' && id is String) {
        final huid = m['uid'];
        if (!players.containsKey(id) && huid is String) {
          // الشريك نفسه عاد بعد انقطاع: نُبقي دوره ومكانه
          final old = players.entries.where((e) => e.key != meId && e.value.uid == huid).map((e) => e.key).toList();
          if (old.isNotEmpty) {
            final p = players.remove(old.first)!;
            players[id] = p;
            _lastPeerSeen = _now();
            _evalPause();
            _notify();
          }
        }
        if (!players.containsKey(id)) {
          if (players.length >= 2) return; // الغرفة ممتلئة
          final hostRole = players[meId]!.role;
          final name = '${m['name'] ?? 'لاعب'}';
          final uid = m['uid'];
          players[id] = Player(name.length > 20 ? name.substring(0, 20) : name, hostRole == 'op' ? 'ex' : 'op',
              uid is String && uid.length == 36 ? uid : null);
          _lastPeerSeen = _now();
          _notify();
        }
        _broadcast();
      } else if (kind == 'action' && id is String && players.containsKey(id) && m['action'] is Map) {
        _apply(Map<String, dynamic>.from(m['action'] as Map));
      }
      return;
    }
    if (kind != 'state' || m['state'] is! Map || m['players'] is! Map) return;
    final ps = Map<String, dynamic>.from(m['players'] as Map);
    if (!ps.containsKey(meId)) {
      if (ps.length >= 2) {
        error = 'الغرفة ممتلئة.';
        _notify();
      }
      return; // ننتظر أن يضيفنا المضيف
    }
    _hello?.cancel();
    _hello = null;
    final sid = m['session'];
    if (sid is String && sid != sessionId) {
      sessionId = sid;
      _startBeat();
    }
    final ns = GameState.fromJson(m['state'] as Map);
    if (puzzles == null || state?.seed != ns.seed) puzzles = generatePuzzles(ns.seed, ns.diff);
    state = ns;
    players = {
      for (final e in ps.entries)
        if (e.value is Map)
          e.key: Player('${(e.value as Map)['name']}', '${(e.value as Map)['role']}', (e.value as Map)['uid'] as String?),
    };
    final rem = m['rem'];
    _recvRem = rem is num ? rem.toDouble() : kDuration.toDouble();
    _recvAt = _now();
    if (ns.phase == 'playing' && _now() - _lastSnap > 5000) _snapshot();
    _changed();
  }

  void _changed() {
    final s = state;
    if (s != null && s.lastEvent != null) {
      final key = '${s.seed}:${s.eventId}';
      if (key != _seenKey) {
        _seenKey = key;
        _events.add(s.lastEvent!);
        // عقوبة الخطأ من رصيد اللاعبَين (القائد يبلّغ الخادم مرّة واحدة)
        if (isHost && s.lastEvent!.type == 'wrong' && sessionId != null && key != _penaltyKey) {
          _penaltyKey = key;
          SessionService.error(sessionId!).then((_) => _doBeat()).catchError((_) {});
        }
      }
    }
    if (s != null && (s.phase == 'won' || s.phase == 'lost')) {
      _finishSession(s.phase);
      if (online) RejoinData.clear();
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// خروج إرادي: لا استئناف بعده.
  bool leftOnPurpose = true;

  @override
  void dispose() {
    if (online && leftOnPurpose) RejoinData.clear();
    _finishSession('abandoned');
    if (online && isHost) SessionService.roomClose(code).catchError((_) {});
    authService.removeListener(_onAuth);
    _disposed = true;
    _loop?.cancel();
    _beat?.cancel();
    _ping?.cancel();
    _hello?.cancel();
    _net?.close();
    _events.close();
    super.dispose();
  }
}
