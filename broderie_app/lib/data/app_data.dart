import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import 'models.dart';

/// Source unique des données de l'application (Supabase).
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData instance = AppData._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Ouvrier> ouvriers = [];
  List<Dessin> dessins = [];
  List<Machine> machines = [];
  bool refsLoaded = false;

  /// Incrémenté à chaque modification de la production, pour que les écrans rechargent.
  int productionVersion = 0;

  Ouvrier? ouvrier(String? id) => _find(ouvriers, id, (o) => o.id);
  Dessin? dessin(String? id) => _find(dessins, id, (d) => d.id);
  Machine? machine(String? id) => _find(machines, id, (m) => m.id);

  String ouvrierNom(String id) => ouvrier(id)?.nom ?? '(supprimé)';
  String dessinNom(String id) => dessin(id)?.nom ?? '(supprimé)';
  String machineNom(String? id) => id == null ? '' : (machine(id)?.nom ?? '');

  static T? _find<T>(List<T> l, String? id, String Function(T) key) {
    if (id == null) return null;
    for (final x in l) {
      if (key(x) == id) return x;
    }
    return null;
  }

  Future<void> loadRefs() async {
    final res = await Future.wait<List<Map<String, dynamic>>>([
      _db.from('broderie_ouvriers').select().order('nom'),
      _db.from('broderie_dessins').select().order('nom'),
      _db.from('broderie_machines').select().order('nom'),
    ]);
    ouvriers = res[0].map(Ouvrier.fromMap).toList();
    dessins = res[1].map(Dessin.fromMap).toList();
    machines = res[2].map(Machine.fromMap).toList();
    refsLoaded = true;
    notifyListeners();
  }

  void clear() {
    ouvriers = [];
    dessins = [];
    machines = [];
    refsLoaded = false;
    productionVersion = 0;
  }

  // ---------------- Production ----------------

  Future<List<Production>> fetchProduction(DateTime from, DateTime to, {String? ouvrierId}) async {
    final out = <Production>[];
    const page = 1000;
    var start = 0;
    while (true) {
      var q = _db
          .from('broderie_production')
          .select()
          .gte('date_prod', dateKey(from))
          .lte('date_prod', dateKey(to));
      if (ouvrierId != null) q = q.eq('ouvrier_id', ouvrierId);
      final rows = await q
          .order('date_prod', ascending: false)
          .order('created_at', ascending: false)
          .range(start, start + page - 1);
      out.addAll(rows.map(Production.fromMap));
      if (rows.length < page) break;
      start += page;
    }
    return out;
  }

  Future<void> saveProduction(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _db.from('broderie_production').insert(row);
    } else {
      await _db.from('broderie_production').update(row).eq('id', id);
    }
    _productionChanged();
  }

  Future<void> deleteProduction(String id) async {
    await _db.from('broderie_production').delete().eq('id', id);
    _productionChanged();
  }

  void _productionChanged() {
    productionVersion++;
    notifyListeners();
  }

  // ---------------- Référentiels ----------------

  /// Enregistre et renvoie l'id de la ligne.
  Future<String> saveRef(String table, Map<String, dynamic> row, {String? id}) async {
    String newId;
    if (id == null) {
      final r = await _db.from(table).insert(row).select('id').single();
      newId = r['id'] as String;
    } else {
      await _db.from(table).update(row).eq('id', id);
      newId = id;
    }
    await loadRefs();
    return newId;
  }

  Future<void> deleteRef(String table, String id) async {
    await _db.from(table).delete().eq('id', id);
    await loadRefs();
  }

  // ---------------- Photos des dessins (Storage privé) ----------------

  static const _bucket = 'broderie-dessins';
  final Map<String, String> _signed = {};

  /// URL signée (valable 7 jours, mise en cache) ou null.
  Future<String?> photoUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    final cached = _signed[path];
    if (cached != null) return cached;
    try {
      final url = await _db.storage.from(_bucket).createSignedUrl(path, 60 * 60 * 24 * 7);
      _signed[path] = url;
      return url;
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadPhoto(String dessinId, Uint8List bytes, String ext) async {
    final uid = _db.auth.currentUser!.id;
    final e = ext.toLowerCase().replaceAll('.', '');
    final clean = (e == 'jpeg' || e == 'jpg') ? 'jpg' : (e == 'png' || e == 'webp' ? e : 'jpg');
    final mime = clean == 'jpg' ? 'image/jpeg' : 'image/$clean';
    final path = '$uid/$dessinId-${DateTime.now().millisecondsSinceEpoch}.$clean';
    await _db.storage.from(_bucket).uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: true));
    return path;
  }

  Future<void> removePhoto(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _db.storage.from(_bucket).remove([path]);
    } catch (_) {}
    _signed.remove(path);
  }

  Future<void> setDessinPhoto(String dessinId, String? path) async {
    await _db.from('broderie_dessins').update({'photo_path': path}).eq('id', dessinId);
    await loadRefs();
  }
}

final data = AppData.instance;
