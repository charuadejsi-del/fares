import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n.dart';
import '../utils.dart';
import 'session.dart';
import 'models.dart';

/// Source unique des données de l'application (Supabase).
class AppData extends ChangeNotifier {
  AppData._();
  static final AppData instance = AppData._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Ouvrier> ouvriers = [];
  List<Dessin> dessins = [];
  List<Machine> machines = [];
  List<TypeTravail> types = [];
  List<Tache> taches = [];
  List<Lot> lots = [];
  Map<String, AvancementLot> avancements = {};
  Map<String, Solde> soldes = {};
  bool refsLoaded = false;

  static const departementsParDefaut = ['Broderie', 'Couture', 'Coupe', 'Appliqué', 'Repassage', 'Finition', 'Emballage'];

  /// Départements utilisés + ceux par défaut.
  List<String> get departements {
    final set = <String>{...departementsParDefaut, ...ouvriers.map((o) => o.departement)};
    return set.toList();
  }

  Solde solde(String ouvrierId) => soldes[ouvrierId] ?? const Solde();
  double get totalResteAPayer => soldes.values.fold<double>(0, (s, v) => s + (v.solde > 0 ? v.solde : 0));
  double get totalAvancesNonCouvertes => soldes.values.fold<double>(0, (s, v) => s + (v.solde < 0 ? -v.solde : 0));

  /// Incrémenté à chaque modification de la production, pour que les écrans rechargent.
  int productionVersion = 0;

  Ouvrier? ouvrier(String? id) => _find(ouvriers, id, (o) => o.id);
  Dessin? dessin(String? id) => _find(dessins, id, (d) => d.id);
  Machine? machine(String? id) => _find(machines, id, (m) => m.id);
  TypeTravail? type(String? id) => _find(types, id, (t) => t.id);
  Tache? tache(String? id) => _find(taches, id, (t) => t.id);
  Lot? lot(String? id) => _find(lots, id, (l) => l.id);
  AvancementLot avancement(String id) => avancements[id] ?? AvancementLot();

  /// Tâches actives d'un département (toutes si aucune ne correspond).
  List<Tache> tachesPour(String departement) {
    final actives = taches.where((t) => t.actif).toList();
    final dep = actives.where((t) => t.departement.toLowerCase() == departement.toLowerCase()).toList();
    return dep.isNotEmpty ? dep : actives;
  }

  /// Prix proposé pour un travail : tarif de la tâche, sinon prix à la pièce de l'ouvrier.
  /// Un ouvrier payé au mois n'est payé que si le travail est « en extra ».
  double prixTravail(Ouvrier o, Tache? t, {bool extra = false}) {
    if (o.modePaie == ModePaie.mois && !extra) return 0;
    if (t != null && t.prix > 0) return t.prix;
    return o.prixPiece;
  }
  String typeNom(String? id) => id == null ? '—' : (type(id)?.nom ?? '(supprimé)');

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
      _db.from('broderie_types').select().order('ordre').order('nom'),
    ]);
    ouvriers = res[0].map(Ouvrier.fromMap).toList();
    dessins = res[1].map(Dessin.fromMap).toList();
    machines = res[2].map(Machine.fromMap).toList();
    types = res[3].map(TypeTravail.fromMap).toList();
    // Premier lancement : types par défaut
    if (types.isEmpty && session.admin) {
      final rows = await _db.from('broderie_types').insert([
        TypeTravail.toRow(nom: 'Passé plat', tarif1000: 10, ordre: 0),
        TypeTravail.toRow(nom: 'Cordon', tarif1000: 15, ordre: 1),
      ]).select();
      types = rows.map(TypeTravail.fromMap).toList()..sort((a, b) => a.ordre.compareTo(b.ordre));
    }
    await Future.wait([_loadSoldes(), loadTaches(notify: false), loadLots(notify: false)]);
    refsLoaded = true;
    notifyListeners();
  }

  /// Tâches & tarifs (tolérant : liste vide si la table n'existe pas encore).
  Future<void> loadTaches({bool notify = true}) async {
    try {
      final rows = await _db.from('travail_taches').select().order('departement').order('ordre').order('nom');
      taches = rows.map(Tache.fromMap).toList();
      if (taches.isEmpty && session.admin) {
        final defaut = [
          ('Robe cousue', 'Couture'),
          ('Montage', 'Couture'),
          ('Coupe', 'Coupe'),
          ('Repassage', 'Repassage'),
          ('Finition', 'Finition'),
          ('Emballage', 'Emballage'),
        ];
        final ins = await _db
            .from('travail_taches')
            .insert([for (var i = 0; i < defaut.length; i++) Tache.toRow(nom: defaut[i].$1, departement: defaut[i].$2, prix: 0, ordre: i)])
            .select();
        taches = ins.map(Tache.fromMap).toList();
      }
    } catch (_) {
      taches = [];
    }
    if (notify) notifyListeners();
  }

  /// Paquets de broderie et leur avancement (tolérant si la table n'existe pas).
  Future<void> loadLots({bool notify = true}) async {
    try {
      final res = await Future.wait([
        _db.from('broderie_lots').select().order('created_at', ascending: false),
        _db.from('broderie_production_lots').select('lot_id, production_id, pieces, broderie_production(date_prod, ouvrier_id, total_points, created_at)'),
      ]);
      lots = res[0].map(Lot.fromMap).toList();
      final liens = res[1];
      final parSaisie = <String, (int, int)>{}; // production -> (pièces, nb paquets)
      for (final r in liens) {
        final k = r['production_id'] as String;
        final a = parSaisie[k] ?? (0, 0);
        parSaisie[k] = (a.$1 + ((r['pieces'] as num?)?.toInt() ?? 0), a.$2 + 1);
      }
      final av = <String, AvancementLot>{};
      final chrono = <String, List<(DateTime, String, int)>>{};
      for (final r in liens) {
        final p = r['broderie_production'] as Map?;
        if (p == null) continue;
        final lotId = r['lot_id'] as String;
        final pcs = (r['pieces'] as num?)?.toInt() ?? 0;
        final s = parSaisie[r['production_id'] as String]!;
        final a = av.putIfAbsent(lotId, AvancementLot.new);
        a.pieces += pcs;
        a.points += partPoints((p['total_points'] as num?)?.toInt() ?? 0, pcs, s.$1, s.$2);
        final d = DateTime.parse(p['date_prod'] as String);
        if (a.debut == null || d.isBefore(a.debut!)) a.debut = d;
        if (a.dernier == null || d.isAfter(a.dernier!)) a.dernier = d;
        a.ouvriers.add(p['ouvrier_id'] as String);
        chrono.putIfAbsent(lotId, () => []).add((d, '${p['created_at']}', pcs));
      }
      for (final l in lots) {
        final c = chrono[l.id];
        if (c == null) continue;
        c.sort((x, y) => x.$1 != y.$1 ? x.$1.compareTo(y.$1) : x.$2.compareTo(y.$2));
        var cumul = 0;
        for (final e in c) {
          cumul += e.$3;
          if (cumul >= l.nbPieces) {
            av[l.id]!.fin = e.$1;
            break;
          }
        }
      }
      avancements = av;
    } catch (_) {
      lots = [];
      avancements = {};
    }
    if (notify) notifyListeners();
  }

  /// Paquets liés à une saisie : (paquet, pièces).
  Future<List<(String, int)>> fetchLiensSaisie(String productionId) async {
    try {
      final rows = await _db.from('broderie_production_lots').select('lot_id, pieces').eq('production_id', productionId);
      return [for (final r in rows) (r['lot_id'] as String, (r['pieces'] as num?)?.toInt() ?? 0)];
    } catch (_) {
      return [];
    }
  }

  Future<String> saveLot(Map<String, dynamic> row, {String? id}) async {
    late String rid;
    if (id == null) {
      rid = (await _db.from('broderie_lots').insert(row).select('id').single())['id'] as String;
    } else {
      await _db.from('broderie_lots').update(row).eq('id', id);
      rid = id;
    }
    await loadLots();
    return rid;
  }

  /// Livraison d'un paquet par la broderie : il part à l'étape suivante de son parcours.
  /// [date] nulle : annule la livraison et ramène le paquet en broderie.
  Future<void> livrerLot(String id, DateTime? date) async {
    final l = lot(id);
    if (l == null) return;
    if (date == null) {
      await _db.from('broderie_lots').update({'date_livraison': null, 'etape': 'broderie'}).eq('id', id);
      await _db.from('lot_mouvements').delete().eq('lot_id', id).eq('de', 'broderie');
    } else {
      final vers = l.enBroderie ? (l.suivante ?? 'couture') : l.etape;
      await _db.from('broderie_lots').update({'date_livraison': dateKey(date), 'etape': vers}).eq('id', id);
      if (l.enBroderie) {
        await _db.from('lot_mouvements').insert({'lot_id': id, 'de': 'broderie', 'vers': vers, 'pieces': l.nbPieces, 'date_mvt': dateKey(date)});
      }
    }
    await loadLots();
  }

  /// Fait passer un paquet à une autre étape et garde la trace du mouvement.
  Future<void> deplacerLot(Lot l, String vers, DateTime date, {String? note}) async {
    final row = <String, dynamic>{'etape': vers};
    final iB = l.circuit.indexOf('broderie'), iV = l.circuit.indexOf(vers);
    if (l.passeBroderie) row['date_livraison'] = iV > iB ? (l.dateLivraison == null ? dateKey(date) : dateKey(l.dateLivraison!)) : null;
    await _db.from('broderie_lots').update(row).eq('id', l.id);
    await _db.from('lot_mouvements').insert({
      'lot_id': l.id,
      'de': l.etape,
      'vers': vers,
      'pieces': l.nbPieces,
      'date_mvt': dateKey(date),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    await loadLots();
  }

  /// Travail des ateliers internes (coupe, appliqué, akkach, finition) sur un paquet.
  Future<List<Piece>> fetchPiecesLot(String lotId) async {
    final rows = await _db.from('broderie_pieces').select().eq('lot_id', lotId).order('date_travail').order('created_at');
    return rows.map(Piece.fromMap).toList();
  }

  /// Entrée du paquet terminé au stock (compté par modèle).
  Future<void> entrerStock(Lot l, int pieces, DateTime date) async {
    await _db.from('broderie_lots').update({'pieces_stock': pieces, 'date_stock': dateKey(date)}).eq('id', l.id);
    await deplacerLot(l, 'stock', date, note: '{0} pièces au stock'.trf([pieces]));
  }

  /// Derniers mouvements de tous les paquets (lot_id -> mouvements), pour le suivi.
  Future<Map<String, List<(MouvementLot, String)>>> fetchTousMouvements() async {
    final rows = await _db.from('lot_mouvements').select().order('date_mvt').order('created_at').limit(10000);
    final out = <String, List<(MouvementLot, String)>>{};
    for (final r in rows) {
      out.putIfAbsent(r['lot_id'] as String, () => []).add((MouvementLot.fromMap(r), r['lot_id'] as String));
    }
    return out;
  }

  Future<List<MouvementLot>> fetchMouvementsLot(String lotId) async {
    final rows = await _db.from('lot_mouvements').select().eq('lot_id', lotId).order('date_mvt').order('created_at');
    return rows.map(MouvementLot.fromMap).toList();
  }

  Future<void> deleteLot(String id) async {
    await _db.from('broderie_lots').delete().eq('id', id);
    await loadLots();
  }

  /// Journées d'un paquet, dans l'ordre chronologique.
  Future<List<JourneeLot>> fetchProductionLot(String lotId) async {
    final rows = await _db.from('broderie_production_lots').select('production_id, pieces, broderie_production(*)').eq('lot_id', lotId);
    final ids = [for (final r in rows) r['production_id'] as String];
    final freres = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : await _db.from('broderie_production_lots').select('production_id, pieces').inFilter('production_id', ids);
    final parSaisie = <String, (int, int)>{};
    for (final r in freres) {
      final k = r['production_id'] as String;
      final a = parSaisie[k] ?? (0, 0);
      parSaisie[k] = (a.$1 + ((r['pieces'] as num?)?.toInt() ?? 0), a.$2 + 1);
    }
    final out = <JourneeLot>[];
    for (final r in rows) {
      final m = r['broderie_production'];
      if (m == null) continue;
      final p = Production.fromMap(Map<String, dynamic>.from(m as Map));
      final pcs = (r['pieces'] as num?)?.toInt() ?? 0;
      final s = parSaisie[p.id] ?? (pcs, 1);
      out.add(JourneeLot(p, pcs, partPoints(p.totalPoints, pcs, s.$1, s.$2)));
    }
    out.sort((a, b) => a.p.dateProd != b.p.dateProd ? a.p.dateProd.compareTo(b.p.dateProd) : a.p.createdAt.compareTo(b.p.createdAt));
    return out;
  }

  Future<void> saveTache(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _db.from('travail_taches').insert(row);
    } else {
      await _db.from('travail_taches').update(row).eq('id', id);
    }
    await loadTaches();
  }

  Future<void> deleteTache(String id) async {
    await _db.from('travail_taches').delete().eq('id', id);
    await loadTaches();
  }

  Future<void> _loadSoldes() async {
    try {
      final rows = await _db.from('broderie_soldes').select();
      soldes = {for (final r in rows) r['ouvrier_id'] as String: Solde.fromMap(r)};
    } catch (_) {}
  }

  Future<void> refreshSoldes() async {
    await _loadSoldes();
    notifyListeners();
  }

  void clear() {
    ouvriers = [];
    dessins = [];
    machines = [];
    types = [];
    taches = [];
    lots = [];
    avancements = {};
    soldes = {};
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

  /// Enregistre une saisie. [lots] : paquets brodés dans cette saisie (paquet, pièces) ;
  /// null = ne pas toucher aux paquets déjà liés.
  Future<void> saveProduction(Map<String, dynamic> row, {String? id, List<(String, int)>? lots}) async {
    final liens = [for (final l in lots ?? const <(String, int)>[]) if (l.$2 > 0) l];
    if (liens.isNotEmpty) row = {...row, 'nb_robes': liens.fold<int>(0, (s, l) => s + l.$2)};
    late String pid;
    if (id == null) {
      pid = (await _db.from('broderie_production').insert(row).select('id').single())['id'] as String;
    } else {
      await _db.from('broderie_production').update(row).eq('id', id);
      pid = id;
    }
    if (lots != null) {
      await _db.from('broderie_production_lots').delete().eq('production_id', pid);
      if (liens.isNotEmpty) {
        await _db.from('broderie_production_lots').insert([for (final l in liens) {'production_id': pid, 'lot_id': l.$1, 'pieces': l.$2}]);
      }
    }
    _productionChanged();
  }

  Future<void> deleteProduction(String id) async {
    await _db.from('broderie_production').delete().eq('id', id);
    _productionChanged();
  }

  void _productionChanged() {
    productionVersion++;
    Future.wait([_loadSoldes(), loadLots(notify: false)]).whenComplete(notifyListeners);
    notifyListeners();
  }

  // ---------------- Pièces & argent ----------------

  Future<List<Piece>> fetchPieces(DateTime from, DateTime to, {String? ouvrierId}) async {
    var q = _db.from('broderie_pieces').select().gte('date_travail', dateKey(from)).lte('date_travail', dateKey(to));
    if (ouvrierId != null) q = q.eq('ouvrier_id', ouvrierId);
    final rows = await q.order('date_travail', ascending: false).order('created_at', ascending: false).limit(5000);
    return rows.map(Piece.fromMap).toList();
  }

  Future<List<Mouvement>> fetchMouvements(DateTime from, DateTime to, {String? ouvrierId}) async {
    var q = _db.from('broderie_mouvements').select().gte('date_mvt', dateKey(from)).lte('date_mvt', dateKey(to));
    if (ouvrierId != null) q = q.eq('ouvrier_id', ouvrierId);
    final rows = await q.order('date_mvt', ascending: false).order('created_at', ascending: false).limit(5000);
    return rows.map(Mouvement.fromMap).toList();
  }

  Future<void> savePiece(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _db.from('broderie_pieces').insert(row);
    } else {
      await _db.from('broderie_pieces').update(row).eq('id', id);
    }
    _productionChanged();
  }

  Future<void> savePieces(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    await _db.from('broderie_pieces').insert(rows);
    _productionChanged();
  }

  Future<void> deletePiece(String id) async {
    await _db.from('broderie_pieces').delete().eq('id', id);
    _productionChanged();
  }

  Future<void> saveMouvement(Map<String, dynamic> row, {String? id}) async {
    if (id == null) {
      await _db.from('broderie_mouvements').insert(row);
    } else {
      await _db.from('broderie_mouvements').update(row).eq('id', id);
    }
    _productionChanged();
  }

  Future<void> deleteMouvement(String id) async {
    await _db.from('broderie_mouvements').delete().eq('id', id);
    _productionChanged();
  }

  Future<Bilan> bilan(String ouvrierId, DateTime from, DateTime to) async {
    final rows = await _db.rpc('broderie_bilan', params: {
      'p_ouvrier': ouvrierId,
      'p_debut': dateKey(from),
      'p_fin': dateKey(to),
    });
    final list = rows as List;
    if (list.isEmpty) return const Bilan();
    return Bilan.fromMap(Map<String, dynamic>.from(list.first as Map));
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

  /// Octets d'une photo de dessin (pour les PDF), ou null.
  Future<Uint8List?> photoBytes(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _db.storage.from(_bucket).download(path);
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadPhoto(String dessinId, Uint8List bytes, String ext) async {
    final uid = session.atelierId ?? _db.auth.currentUser!.id;
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
