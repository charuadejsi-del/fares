// الحسابات: Supabase Auth (بريد + كلمة سر) + ملف اللاعب (الاسم، الرصيد، التواريخ).
// عميل Supabase واحد مشترك في كل التطبيق، والجلسة محفوظة محلياً لتبقى مسجَّلاً.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../net/transport.dart';

/// العميل المشترك: كل الطلبات (الغرف، الصوت، الرصيد) تمرّ به برمز اللاعب.
final SupabaseClient supa = SupabaseClient(kSupabaseUrl, kSupabaseAnonKey);

class Profile {
  final String id;
  final String nickname;
  final String role;
  final int balanceSeconds;
  final bool banned;
  final DateTime createdAt;
  final DateTime lastSeen;
  const Profile({
    required this.id,
    required this.nickname,
    required this.role,
    required this.balanceSeconds,
    required this.banned,
    required this.createdAt,
    required this.lastSeen,
  });

  bool get isAdmin => role == 'admin';
  int get balanceMinutes => balanceSeconds ~/ 60;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: '${j['id']}',
        nickname: '${j['nickname']}',
        role: '${j['role'] ?? 'player'}',
        balanceSeconds: (j['balance_seconds'] as num?)?.toInt() ?? 0,
        banned: j['banned'] == true,
        createdAt: DateTime.tryParse('${j['created_at']}')?.toLocal() ?? DateTime.now(),
        lastSeen: DateTime.tryParse('${j['last_seen']}')?.toLocal() ?? DateTime.now(),
      );
}

class AuthService extends ChangeNotifier {
  static const _kSession = 'khazna.session';
  SharedPreferences? _prefs;
  StreamSubscription<AuthState>? _sub;

  Profile? profile;
  bool ready = false;

  Session? get session => supa.auth.currentSession;
  bool get signedIn => session != null;
  String? get email => supa.auth.currentUser?.email;

  /// يُستدعى مرّة واحدة قبل تشغيل التطبيق: يستعيد الجلسة المحفوظة.
  Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
    _sub = supa.auth.onAuthStateChange.listen((s) {
      final sess = s.session;
      if (sess == null) {
        _prefs?.remove(_kSession);
      } else {
        _prefs?.setString(_kSession, jsonEncode(sess.toJson()));
      }
    });
    final saved = prefs.getString(_kSession);
    if (saved != null) {
      try {
        await supa.auth.recoverSession(saved).timeout(const Duration(seconds: 8));
        await refreshProfile();
      } catch (_) {
        // بلا إنترنت أو جلسة منتهية: نُبقي الجلسة إن كانت صالحة محلياً
        if (supa.auth.currentSession == null) await prefs.remove(_kSession);
      }
    }
    ready = true;
    notifyListeners();
  }

  /// يحدّث آخر دخول ويجلب الملف (الرصيد، الاسم...).
  Future<void> refreshProfile() async {
    if (!signedIn) return;
    final row = await supa.rpc('touch_profile');
    if (row is Map) profile = Profile.fromJson(Map<String, dynamic>.from(row));
    if (profile?.banned == true) {
      await signOut();
      throw const AuthException('banned');
    }
    notifyListeners();
  }

  Future<void> signUp({required String email, required String password, required String nickname}) async {
    final res = await supa.auth.signUp(email: email.trim(), password: password, data: {'nickname': nickname.trim()});
    if (res.session == null) {
      throw const AuthException('confirm_email');
    }
    await refreshProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    await supa.auth.signInWithPassword(email: email.trim(), password: password);
    await refreshProfile();
  }

  Future<void> setNickname(String nickname) async {
    await supa.rpc('set_nickname', params: {'p_nickname': nickname.trim()});
    await refreshProfile();
  }

  Future<void> signOut() async {
    try {
      await supa.auth.signOut();
    } catch (_) {}
    profile = null;
    await _prefs?.remove(_kSession);
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final AuthService authService = AuthService();

/// رسالة خطأ مفهومة بالعربية.
String authErrorText(Object e) {
  final m = (e is AuthException ? e.message : '$e').toLowerCase();
  if (m.contains('banned')) return 'هذا الحساب موقوف، تواصل مع الإدارة';
  if (m.contains('confirm_email')) return 'تم إنشاء الحساب: أكّد بريدك ثم سجّل الدخول';
  if (m.contains('invalid login') || m.contains('invalid_credentials')) return 'البريد أو كلمة السر غير صحيحة';
  if (m.contains('already registered') || m.contains('already been registered')) return 'هذا البريد مسجَّل من قبل';
  if (m.contains('password') && m.contains('6')) return 'كلمة السر 6 أحرف على الأقل';
  if (m.contains('email') && m.contains('invalid')) return 'البريد غير صحيح';
  if (m.contains('nickname taken')) return 'هذا الاسم مأخوذ';
  if (m.contains('rate limit')) return 'محاولات كثيرة، انتظر قليلاً';
  if (m.contains('socket') || m.contains('failed host') || m.contains('timeout')) return 'لا يوجد اتصال بالإنترنت';
  return 'تعذّر الطلب، حاول مجدّداً';
}
