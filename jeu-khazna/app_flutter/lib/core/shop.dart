// المتجر: الباقات، حساب بريدي موب، رفع الوصل، وطلبات اللاعب.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import 'auth.dart';

class Package {
  final int id;
  final int minutes;
  final int priceDzd;
  const Package(this.id, this.minutes, this.priceDzd);
  double get perMinute => priceDzd / minutes;
}

class ShopInfo {
  final List<Package> packages;
  final String rip;
  final String holder;
  const ShopInfo(this.packages, this.rip, this.holder);
  bool get ready => rip.trim().isNotEmpty;
}

class PaymentRequest {
  final String id;
  final int minutes;
  final int amountDzd;
  final String ref;
  final String status; // pending | approved | rejected
  final String? note;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  const PaymentRequest(this.id, this.minutes, this.amountDzd, this.ref, this.status, this.note, this.createdAt, this.reviewedAt);

  factory PaymentRequest.fromJson(Map<String, dynamic> j) => PaymentRequest(
        '${j['id']}',
        (j['minutes'] as num).toInt(),
        (j['amount_dzd'] as num).toInt(),
        '${j['transaction_ref']}',
        '${j['status']}',
        j['admin_note'] as String?,
        DateTime.parse('${j['created_at']}').toLocal(),
        j['reviewed_at'] == null ? null : DateTime.parse('${j['reviewed_at']}').toLocal(),
      );
}

class ShopService {
  static Future<ShopInfo> load() async {
    final rows = await supa.from('packages').select('id, minutes, price_dzd').eq('active', true).order('sort');
    final st = await supa.from('settings').select('key, value').inFilter('key', ['baridimob_rip', 'baridimob_name']);
    final s = {for (final r in st) '${r['key']}': r['value']};
    return ShopInfo(
      [for (final r in rows) Package((r['id'] as num).toInt(), (r['minutes'] as num).toInt(), (r['price_dzd'] as num).toInt())],
      '${s['baridimob_rip'] ?? ''}',
      '${s['baridimob_name'] ?? ''}',
    );
  }

  static Future<List<PaymentRequest>> myRequests() async {
    final uid = authService.uid;
    if (uid == null) return const [];
    final rows = await supa
        .from('payment_requests')
        .select('id, minutes, amount_dzd, transaction_ref, status, admin_note, created_at, reviewed_at')
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(30);
    return [for (final r in rows) PaymentRequest.fromJson(Map<String, dynamic>.from(r))];
  }

  /// يرفع صورة الوصل في مجلد اللاعب الخاص، ثم يسجّل الطلب.
  static Future<void> submit({required Package pkg, required String ref, required Uint8List image, required String ext}) async {
    final uid = authService.uid;
    if (uid == null) throw const AuthException('not signed in');
    final e = ext.toLowerCase() == 'png' ? 'png' : (ext.toLowerCase() == 'webp' ? 'webp' : 'jpg');
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$e';
    await supa.storage.from('receipts').uploadBinary(
          path,
          image,
          fileOptions: FileOptions(contentType: e == 'jpg' ? 'image/jpeg' : 'image/$e', upsert: false),
        );
    await supa.rpc('request_payment', params: {'p_package': pkg.id, 'p_ref': ref, 'p_receipt': path});
  }

  /// طلبات عولجت منذ آخر مرّة (لإشعار اللاعب بالقبول أو الرفض).
  static Future<List<PaymentRequest>> newlyReviewed(SharedPreferences prefs) async {
    final list = await myRequests();
    final seen = prefs.getStringList('khazna.seenReviews') ?? const [];
    final fresh = list.where((r) => r.status != 'pending' && !seen.contains(r.id)).toList();
    if (fresh.isNotEmpty) {
      prefs.setStringList('khazna.seenReviews', [...seen, ...fresh.map((r) => r.id)].take(200).toList());
    }
    return fresh;
  }
}

/// قواعد اللعبة كما يضبطها المدير (لعرضها للاعب).
class GameRules {
  final int hintMinutes;
  final int penaltySeconds;
  final int dailyMinutes;
  const GameRules(this.hintMinutes, this.penaltySeconds, this.dailyMinutes);
}

final gameRulesProvider = FutureProvider<GameRules>((ref) async {
  final rows = await supa
      .from('settings')
      .select('key, value')
      .inFilter('key', ['hint_cost_seconds', 'error_penalty_seconds', 'daily_free_seconds']);
  int v(String k, int d) {
    for (final r in rows) {
      if (r['key'] == k) return int.tryParse('${r['value']}') ?? d;
    }
    return d;
  }

  return GameRules((v('hint_cost_seconds', 120) / 60).ceil(), v('error_penalty_seconds', 30), v('daily_free_seconds', 600) ~/ 60);
});
