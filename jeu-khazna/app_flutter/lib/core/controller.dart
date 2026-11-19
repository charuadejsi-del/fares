// يدير جلسة لعب: وضع الهاتف الواحد، أو أونلاين (المضيف هو المرجع، والضيف يرسل أفعاله فقط).
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../net/transport.dart';
import 'game.dart';
import 'stages.dart';

class Player {
  final String name;
  String role; // op | ex
  Player(this.name, this.role);
  Map<String, dynamic> toJson() => {'name': name, 'role': role};
}

class GameController extends ChangeNotifier {
  final bool online;
  final bool isHost;
  final String code;
  final String meId;
  final String meName;

  /// وضع الطاولة: الهاتف بين اللاعبَين، والشاشة مقسومة نصفين.
  final bool table;

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
  })  : online = false,
        isHost = true,
        code = '',
        meId = _rid() {
    players = {meId: Player(meName, 'op')};
    _startLocal();
    _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tickLoop());
  }

  GameController.online({required this.meName, required this.code, required this.isHost})
      : online = true,
        table = false,
        rooms = kRooms,
        diff = 'agent',
        missionId = 0,
        meId = _rid();

  Future<void> connect() async {
    _net = await SupabaseTransport.connect(code, _onMessage);
    if (isHost) {
      state = newState(_newSeed());
      puzzles = generatePuzzles(state!.seed);
      players = {meId: Player(meName, 'op')};
      _loop = Timer.periodic(const Duration(seconds: 1), (_) => _tickLoop());
      _broadcast();
    } else {
      _sendHello();
      _hello = Timer.periodic(const Duration(milliseconds: 1500), (_) => _sendHello());
    }
    _notify();
  }

  // ───── قراءة الحالة ─────
  String? get myRole => online ? players[meId]?.role : localRole;
  bool get joined => !online || players.containsKey(meId);
  bool get canStart => isHost && players.length >= 2 && state?.phase == 'lobby';

  double get remaining {
    final s = state;
    if (s == null) return kDuration.toDouble();
    if (s.phase != 'playing') return s.phase == 'lobby' ? s.difficulty.duration.toDouble() : 0;
    if (isHost) return remainingSeconds(s, _now());
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

  void toggleLocalRole() {
    localRole = localRole == 'op' ? 'ex' : 'op';
    _notify();
  }

  void hostStart() {
    if (!canStart) return;
    state = startGame(state!, puzzles!, _now());
    _broadcast();
    _changed();
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
  }

  void _apply(Map<String, dynamic> action) {
    final s = state, p = puzzles;
    if (s == null || p == null) return;
    final ns = applyAction(s, p, action, _now());
    if (identical(ns, s)) return;
    state = ns;
    _broadcast();
    _changed();
  }

  void _tickLoop() {
    final s = state;
    if (s == null) return;
    final t = tick(s, _now());
    if (!identical(t, s)) {
      state = t;
      _broadcast();
      _changed();
      return;
    }
    if (online && _now() - _lastBroadcast > 2000) _broadcast(); // للمتأخرين ومزامنة المؤقّت
  }

  void _sendHello() => _net?.send({'kind': 'hello', 'id': meId, 'name': meName});

  void _broadcast() {
    if (!online || !isHost || _net == null || state == null) return;
    _lastBroadcast = _now();
    _net!.send({
      'kind': 'state',
      'state': state!.toJson(),
      'players': {for (final e in players.entries) e.key: e.value.toJson()},
      'rem': remainingSeconds(state!, _now()),
    });
  }

  void _onMessage(Map<String, dynamic> m) {
    if (_disposed) return;
    final kind = m['kind'];
    if (isHost) {
      final id = m['id'];
      if (kind == 'hello' && id is String) {
        if (!players.containsKey(id)) {
          if (players.length >= 2) return; // الغرفة ممتلئة
          final hostRole = players[meId]!.role;
          final name = '${m['name'] ?? 'لاعب'}';
          players[id] = Player(name.length > 20 ? name.substring(0, 20) : name, hostRole == 'op' ? 'ex' : 'op');
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
    final ns = GameState.fromJson(m['state'] as Map);
    if (puzzles == null || state?.seed != ns.seed) puzzles = generatePuzzles(ns.seed, ns.diff);
    state = ns;
    players = {
      for (final e in ps.entries)
        if (e.value is Map) e.key: Player('${(e.value as Map)['name']}', '${(e.value as Map)['role']}'),
    };
    final rem = m['rem'];
    _recvRem = rem is num ? rem.toDouble() : kDuration.toDouble();
    _recvAt = _now();
    _changed();
  }

  void _changed() {
    final s = state;
    if (s != null && s.lastEvent != null) {
      final key = '${s.seed}:${s.eventId}';
      if (key != _seenKey) {
        _seenKey = key;
        _events.add(s.lastEvent!);
      }
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _loop?.cancel();
    _hello?.cancel();
    _net?.close();
    _events.close();
    super.dispose();
  }
}
