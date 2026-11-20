// تقدّم الفريق محفوظ في الخادم: كل ثنائي لاعبين (أو لاعب واحد على هاتف واحد) له خريطته.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth.dart';

/// أي مصدر للنجوم لكل مرحلة (تقدّم الفريق في الخادم).
abstract class StarSource {
  int starsOf(int stage);
}

class TeamProgress implements StarSource {
  final Map<int, int> stars;
  final bool loaded;
  const TeamProgress(this.stars, {this.loaded = true});
  static const empty = TeamProgress({}, loaded: false);

  @override
  int starsOf(int stage) => stars[stage] ?? 0;

  /// آخر مرحلة مكتملة.
  int get top => stars.keys.fold(0, (a, b) => b > a ? b : a);
  int get totalStars => stars.values.fold(0, (a, b) => a + b);
  bool unlocked(int stage) => stage <= top + 1;

  /// المرحلة التي يلعبها الفريق الآن (أول مرحلة غير مكتملة).
  int get current => top + 1;
}

class LeaderRow {
  final String nameA;
  final String? nameB;
  final int bestStage;
  final int stars;
  const LeaderRow(this.nameA, this.nameB, this.bestStage, this.stars);
  String get title => nameB == null ? nameA : '$nameA & $nameB';
}

class TeamService {
  static Future<TeamProgress> load(String? partner) async {
    final rows = await supa.rpc('team_progress_with', params: {'p_partner': partner});
    return TeamProgress({
      for (final r in (rows as List)) (r['stage'] as num).toInt(): (r['stars'] as num).toInt(),
    });
  }

  static Future<void> recordWin({String? partner, required int stage, required int stars, required int seconds}) =>
      supa.rpc('record_stage_win', params: {'p_partner': partner, 'p_stage': stage, 'p_stars': stars, 'p_time': seconds});

  static Future<List<LeaderRow>> leaderboard() async {
    final rows = await supa.rpc('leaderboard', params: {'p_limit': 50});
    return [
      for (final r in (rows as List))
        LeaderRow('${r['name_a']}', r['name_b'] as String?, (r['best_stage'] as num).toInt(), (r['stars'] as num? ?? 0).toInt()),
    ];
  }
}

/// تقدّم الفريق: المفتاح هو معرّف الشريك (null = لعب فردي على هاتف واحد).
final teamProgressProvider = FutureProvider.family<TeamProgress, String?>((ref, partner) => TeamService.load(partner));
