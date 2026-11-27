import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../core/pricing.dart';

SupabaseClient get sb => Supabase.instance.client;
String? get uid => sb.auth.currentUser?.id;

class AppSettings {
  final PricingSettings pricing;
  final double filmWidthCm;
  final double gapCm;
  final bool allowRotation;
  final String workshopName;
  final String? workshopPhone;
  final String? workshopAddress;

  AppSettings.fromMap(Map<String, dynamic> m)
      : pricing = PricingSettings(
          pricePerMeter: (m['price_per_meter'] as num).toDouble(),
          minOrderAmount: (m['min_order_amount'] as num).toDouble(),
          meterRoundingStep: (m['meter_rounding_step'] as num).toDouble(),
        ),
        filmWidthCm = (m['film_width_cm'] as num).toDouble(),
        gapCm = (m['gap_cm'] as num).toDouble(),
        allowRotation = m['allow_rotation'] as bool,
        workshopName = m['workshop_name'] as String,
        workshopPhone = m['workshop_phone'] as String?,
        workshopAddress = m['workshop_address'] as String?;
}

class Api {
  // ---------- Compte ----------

  /// Inscription : les infos du profil voyagent dans les métadonnées, puis le
  /// profil est créé dès qu'une session existe (même si l'e-mail doit d'abord
  /// être confirmé).
  static Future<bool> signUp({
    required String email,
    required String password,
    required Map<String, dynamic> profile,
  }) async {
    final res = await sb.auth
        .signUp(email: email, password: password, data: {'dtf': profile});
    if (res.session != null) await ensureProfile();
    return res.session != null; // false = e-mail de confirmation envoyé
  }

  static Future<void> signIn(String email, String password) async {
    await sb.auth.signInWithPassword(email: email, password: password);
    await ensureProfile();
  }

  static Future<void> signOut() => sb.auth.signOut();

  static Future<Map<String, dynamic>?> myProfile() async {
    if (uid == null) return null;
    return sb.from('dtf_profiles').select().eq('id', uid!).maybeSingle();
  }

  /// Crée le profil client à partir des métadonnées d'inscription s'il manque.
  static Future<Map<String, dynamic>?> ensureProfile() async {
    final existing = await myProfile();
    if (existing != null) return existing;
    final meta = sb.auth.currentUser?.userMetadata?['dtf'];
    if (meta is! Map) return null;
    await sb.from('dtf_profiles').insert({
      'id': uid,
      'role': 'client',
      'full_name': meta['full_name'],
      'phone': meta['phone'],
      'wilaya': meta['wilaya'],
      'commune': meta['commune'],
      'address': meta['address'],
    });
    return myProfile();
  }

  static Future<void> updateProfile(Map<String, dynamic> values) =>
      sb.from('dtf_profiles').update(values).eq('id', uid!);

  // ---------- Paramètres ----------
  static Future<AppSettings> settings() async =>
      AppSettings.fromMap(await sb.from('dtf_settings').select().single());

  // ---------- Commandes ----------
  static Stream<List<Map<String, dynamic>>> myOrders() => sb
      .from('dtf_orders')
      .stream(primaryKey: ['id'])
      .eq('client_id', uid!)
      .order('created_at', ascending: false);

  static Stream<List<Map<String, dynamic>>> order(String id) =>
      sb.from('dtf_orders').stream(primaryKey: ['id']).eq('id', id);

  static Future<List<Map<String, dynamic>>> orderEvents(String id) => sb
      .from('dtf_order_events')
      .select()
      .eq('order_id', id)
      .order('created_at');

  static Future<List<Map<String, dynamic>>> orderImages(String id) =>
      sb.from('dtf_order_images').select().eq('order_id', id);

  static Future<String> signedUrl(String path) =>
      sb.storage.from(imagesBucket).createSignedUrl(path, 3600);

  /// Crée la commande (prix recalculé par le serveur) puis envoie les images.
  static Future<Map<String, dynamic>> createOrder({
    required double estimatedLengthCm,
    required String deliveryMode,
    required double deliveryFee,
    required Map<String, String?> ship,
    String? note,
    required List<OrderImageUpload> images,
    void Function(int done, int total)? onProgress,
  }) async {
    final order = Map<String, dynamic>.from(await sb.rpc('dtf_create_order', params: {
      'p_estimated_length_cm': estimatedLengthCm,
      'p_delivery_mode': deliveryMode,
      'p_delivery_fee': deliveryFee,
      'p_ship_name': ship['name'],
      'p_ship_phone': ship['phone'],
      'p_ship_wilaya': ship['wilaya'],
      'p_ship_commune': ship['commune'],
      'p_ship_address': ship['address'],
      'p_note': note,
    }) as Map);
    final orderId = order['id'] as String;
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      final safe = img.fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$uid/$orderId/${i + 1}_$safe';
      await sb.storage.from(imagesBucket).uploadBinary(path, img.bytes,
          fileOptions: FileOptions(contentType: img.contentType, upsert: true));
      await sb.from('dtf_order_images').insert({
        'order_id': orderId,
        'storage_path': path,
        'width_cm': img.widthCm,
        'height_cm': img.heightCm,
        'quantity': img.quantity,
      });
      onProgress?.call(i + 1, images.length);
    }
    return order;
  }

  static Future<void> reportIssue(String orderId, String text) => sb.rpc(
      'dtf_report_issue',
      params: {'p_order': orderId, 'p_description': text});

  // ---------- Notifications ----------
  static Stream<List<Map<String, dynamic>>> notifications() => sb
      .from('dtf_notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid!)
      .order('created_at', ascending: false);

  static Future<void> markRead(int id) =>
      sb.from('dtf_notifications').update({'read': true}).eq('id', id);
}

class OrderImageUpload {
  final String fileName;
  final Uint8List bytes;
  final double widthCm;
  final double heightCm;
  final int quantity;

  OrderImageUpload(
      this.fileName, this.bytes, this.widthCm, this.heightCm, this.quantity);

  String get contentType {
    final n = fileName.toLowerCase();
    if (n.endsWith('.png')) return 'image/png';
    if (n.endsWith('.webp')) return 'image/webp';
    if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }
}
