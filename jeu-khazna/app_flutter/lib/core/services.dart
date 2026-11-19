// خدمات التطبيق: الإعدادات، التقدّم والإحصائيات، الصوت، الاهتزاز.
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يُملأ في main() قبل تشغيل التطبيق.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefs not ready'));

// ───────── الإعدادات ─────────
class Settings {
  final bool sound;
  final bool music;
  final bool haptics;
  final String name;
  const Settings({this.sound = true, this.music = true, this.haptics = true, this.name = ''});

  Settings copyWith({bool? sound, bool? music, bool? haptics, String? name}) => Settings(
        sound: sound ?? this.sound,
        music: music ?? this.music,
        haptics: haptics ?? this.haptics,
        name: name ?? this.name,
      );
}

class SettingsNotifier extends Notifier<Settings> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Settings build() => Settings(
        sound: _p.getBool('sound') ?? true,
        music: _p.getBool('music') ?? true,
        haptics: _p.getBool('haptics') ?? true,
        name: _p.getString('name') ?? '',
      );

  void setSound(bool v) {
    _p.setBool('sound', v);
    state = state.copyWith(sound: v);
  }

  void setMusic(bool v) {
    _p.setBool('music', v);
    state = state.copyWith(music: v);
    ref.read(audioProvider).syncMusic();
  }

  void setHaptics(bool v) {
    _p.setBool('haptics', v);
    state = state.copyWith(haptics: v);
  }

  void setName(String v) {
    final n = v.trim();
    final name = n.length > 20 ? n.substring(0, 20) : n;
    _p.setString('name', name);
    state = state.copyWith(name: name);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);

// ───────── التقدّم ─────────
class Progress {
  final int played;
  final int won;
  final int stars;
  final int bestTime; // ثوانٍ، 0 = لا يوجد
  const Progress({this.played = 0, this.won = 0, this.stars = 0, this.bestTime = 0});

  String get rank {
    if (stars >= 60) return 'أسطورة الاستخبارات';
    if (stars >= 30) return 'عميل نخبة';
    if (stars >= 15) return 'عميل خاص';
    if (stars >= 5) return 'عميل ميداني';
    return 'مجنّد جديد';
  }

  int get nextRankAt {
    for (final t in [5, 15, 30, 60]) {
      if (stars < t) return t;
    }
    return stars;
  }
}

/// النجوم: 3 بلا عقوبات وفي أقل من 5 دقائق، 2 إذا كانت العقوبات دقيقة أو أقل، وإلا 1.
int starsFor({required bool won, required int finishedIn, required int penalty}) {
  if (!won) return 0;
  if (penalty == 0 && finishedIn <= 300) return 3;
  if (penalty <= 60) return 2;
  return 1;
}

class ProgressNotifier extends Notifier<Progress> {
  SharedPreferences get _p => ref.read(prefsProvider);

  @override
  Progress build() => Progress(
        played: _p.getInt('played') ?? 0,
        won: _p.getInt('won') ?? 0,
        stars: _p.getInt('stars') ?? 0,
        bestTime: _p.getInt('bestTime') ?? 0,
      );

  void record({required bool won, required int finishedIn, required int stars}) {
    final best = won && (state.bestTime == 0 || finishedIn < state.bestTime) ? finishedIn : state.bestTime;
    state = Progress(
      played: state.played + 1,
      won: state.won + (won ? 1 : 0),
      stars: state.stars + stars,
      bestTime: best,
    );
    _p.setInt('played', state.played);
    _p.setInt('won', state.won);
    _p.setInt('stars', state.stars);
    _p.setInt('bestTime', state.bestTime);
  }

  void reset() {
    for (final k in ['played', 'won', 'stars', 'bestTime']) {
      _p.remove(k);
    }
    state = const Progress();
  }
}

final progressProvider = NotifierProvider<ProgressNotifier, Progress>(ProgressNotifier.new);

// ───────── الصوت والاهتزاز ─────────
enum Sfx { click, beep, error, success, cut, bump, light, alarm, vault, type }

class AudioService {
  final Ref ref;
  final List<AudioPlayer> _pool = List.generate(5, (_) => AudioPlayer());
  final AudioPlayer _music = AudioPlayer();
  int _next = 0;
  bool _musicWanted = false;
  bool _musicPlaying = false;

  AudioService(this.ref) {
    for (final p in _pool) {
      p.setPlayerMode(PlayerMode.lowLatency);
    }
    _music.setReleaseMode(ReleaseMode.loop);
  }

  Settings get _s => ref.read(settingsProvider);

  void play(Sfx s, {double volume = 0.8}) {
    if (!_s.sound) return;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    p.stop().then((_) => p.play(AssetSource('sfx/${s.name}.wav'), volume: volume)).catchError((_) {});
  }

  void haptic(HapticKind k) {
    if (!_s.haptics) return;
    switch (k) {
      case HapticKind.tap:
        HapticFeedback.selectionClick();
        break;
      case HapticKind.light:
        HapticFeedback.lightImpact();
        break;
      case HapticKind.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticKind.heavy:
        HapticFeedback.heavyImpact();
        break;
    }
  }

  /// صوت + اهتزاز معاً.
  void fx(Sfx s, HapticKind k, {double volume = 0.8}) {
    play(s, volume: volume);
    haptic(k);
  }

  void startMusic() {
    _musicWanted = true;
    syncMusic();
  }

  void stopMusic() {
    _musicWanted = false;
    syncMusic();
  }

  void pauseForBackground() {
    if (_musicPlaying) _music.pause().catchError((_) {});
    _musicPlaying = false;
  }

  void syncMusic() {
    final should = _musicWanted && _s.music;
    if (should && !_musicPlaying) {
      _musicPlaying = true;
      _music.play(AssetSource('audio/theme.mp3'), volume: 0.32).catchError((_) {
        _musicPlaying = false;
      });
    } else if (!should && _musicPlaying) {
      _musicPlaying = false;
      _music.pause().catchError((_) {});
    }
  }
}

enum HapticKind { tap, light, medium, heavy }

final audioProvider = Provider<AudioService>((ref) => AudioService(ref));
