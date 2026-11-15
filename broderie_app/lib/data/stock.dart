import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import 'session.dart';

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
String? _s(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();
String? _ne(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

// =================================================================== modèles

class Produit {
  final String id;
  final String reference;
  final String designation;
  final String? categorie;
  final String? taille;
  final String? couleur;
  final double prixGros;
  final double prixDetail;
  final double coutRevient;
  final int seuilAlerte;
  final bool actif;
  final int stock;
  final int vendus;
  final int reserve;
  final double coutMatieres;
  final String? modele;

  const Produit({
    required this.id,
    required this.reference,
    required this.designation,
    this.categorie,
    this.taille,
    this.couleur,
    this.prixGros = 0,
    this.prixDetail = 0,
    this.coutRevient = 0,
    this.seuilAlerte = 0,
    this.actif = true,
    this.stock = 0,
    this.vendus = 0,
    this.reserve = 0,
    this.coutMatieres = 0,
    this.modele,
  });

  factory Produit.fromMap(Map<String, dynamic> m) => Produit(
        id: m['id'] as String,
        reference: (m['reference'] ?? '') as String,
        designation: (m['designation'] ?? '') as String,
        categorie: _s(m['categorie']),
        taille: _s(m['taille']),
        couleur: _s(m['couleur']),
        prixGros: _d(m['prix_gros']),
        prixDetail: _d(m['prix_detail']),
        coutRevient: _d(m['cout_revient']),
        seuilAlerte: _i(m['seuil_alerte']),
        actif: (m['actif'] ?? true) as bool,
        stock: _i(m['stock']),
        vendus: _i(m['vendus']),
        reserve: _i(m['reserve']),
        coutMatieres: _d(m['cout_matieres']),
        modele: _s(m['modele']),
      );

  static Map<String, dynamic> toRow({
    required String reference,
    required String designation,
    String? categorie,
    String? taille,
    String? couleur,
    double prixGros = 0,
    double prixDetail = 0,
    double coutRevient = 0,
    int seuilAlerte = 0,
    bool actif = true,
  }) =>
      {
        'reference': reference.trim().toUpperCase(),
        'designation': designation.trim(),
        'categorie': _ne(categorie),
        'taille': _ne(taille),
        'couleur': _ne(couleur),
        'prix_gros': prixGros,
        'prix_detail': prixDetail,
        'cout_revient': coutRevient,
        'seuil_alerte': seuilAlerte,
        'actif': actif,
      };

  String get variante => [if (couleur != null) couleur!, if (taille != null) 'T. $taille'].join(' · ');
  String get cleModele => modele ?? id;
  String get libelle => variante.isEmpty ? designation : '$designation ($variante)';
  int get disponible => stock - reserve;
  double get coutTotal => coutMatieres + coutRevient;
  double get marge => prixGros - coutTotal;
  bool get enAlerte => stock <= seuilAlerte;
  bool get rupture => stock <= 0;
  double get valeurStock => (stock > 0 ? stock : 0) * prixGros;
}

/// Un modèle de robe = toutes ses variantes (couleur × taille), une référence/QR par variante.
class Modele {
  final String cle;
  final List<Produit> variantes;
  Modele(this.cle, this.variantes);

  Produit get base => variantes.first;
  String get reference => base.modele ?? base.reference;
  String get designation => base.designation;
  String? get categorie => base.categorie;
  double get prixGros => base.prixGros;
  bool get actif => variantes.any((v) => v.actif);
  int get stock => variantes.fold<int>(0, (s, v) => s + v.stock);
  int get disponible => variantes.fold<int>(0, (s, v) => s + v.disponible);
  int get reserve => variantes.fold<int>(0, (s, v) => s + v.reserve);
  int get vendus => variantes.fold<int>(0, (s, v) => s + v.vendus);
  bool get enAlerte => variantes.any((v) => v.actif && v.enAlerte);
  bool get rupture => stock <= 0;
  double get valeurStock => variantes.fold<double>(0, (s, v) => s + v.valeurStock);

  List<String?> get couleurs {
    final out = <String?>[];
    for (final v in variantes) {
      if (!out.contains(v.couleur)) out.add(v.couleur);
    }
    return out;
  }

  List<String?> get tailles {
    final out = <String?>[];
    for (final v in variantes) {
      if (!out.contains(v.taille)) out.add(v.taille);
    }
    out.sort((a, b) => ordreTaille(a).compareTo(ordreTaille(b)));
    return out;
  }

  Produit? variante(String? couleur, String? taille) {
    for (final v in variantes) {
      if (v.couleur == couleur && v.taille == taille) return v;
    }
    return null;
  }

  bool contient(String q) {
    final x = q.toLowerCase();
    return designation.toLowerCase().contains(x) ||
        reference.toLowerCase().contains(x) ||
        variantes.any((v) => v.reference.toLowerCase().contains(x) || (v.couleur ?? '').toLowerCase().contains(x) || (v.taille ?? '').toLowerCase().contains(x));
  }
}

const taillesStandard = ['XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', '5XL', '36', '38', '40', '42', '44', '46', '48', '50', '52', '54', 'Standard'];

int ordreTaille(String? t) {
  if (t == null) return -1;
  final i = taillesStandard.indexOf(t);
  if (i >= 0) return i;
  final n = int.tryParse(t);
  return n != null ? 100 + n : 1000;
}

String _code(String? s) {
  if (s == null) return '';
  const a = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿ';
  const b = 'aaaaaaceeeeiiiinooooouuuuyy';
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = a.indexOf(ch);
    final c = i >= 0 ? b[i] : ch;
    if (RegExp(r'[a-z0-9]').hasMatch(c)) buf.write(c);
  }
  return buf.toString().toUpperCase();
}

String referenceVariante(String base, String? couleur, String? taille) =>
    [base.trim().toUpperCase(), if (couleur != null) _code(couleur), if (taille != null) _code(taille)].where((e) => e.isNotEmpty).join('-');

enum TypeStock { entree, sortie, vente, retour, ajustement, annulation }

extension TypeStockX on TypeStock {
  String get label => switch (this) {
        TypeStock.entree => 'Entrée',
        TypeStock.sortie => 'Sortie',
        TypeStock.vente => 'Vente',
        TypeStock.retour => 'Retour client',
        TypeStock.ajustement => 'Ajustement (inventaire)',
        TypeStock.annulation => 'Annulation de vente',
      };
  static TypeStock parse(String? s) => TypeStock.values.firstWhere((t) => t.name == s, orElse: () => TypeStock.entree);
}

class StockMvt {
  final String id;
  final String produitId;
  final TypeStock type;
  final int quantite;
  final String? venteId;
  final String? note;
  final DateTime date;

  const StockMvt({required this.id, required this.produitId, required this.type, required this.quantite, this.venteId, this.note, required this.date});

  factory StockMvt.fromMap(Map<String, dynamic> m) => StockMvt(
        id: m['id'] as String,
        produitId: m['produit_id'] as String,
        type: TypeStockX.parse(m['type'] as String?),
        quantite: _i(m['quantite']),
        venteId: m['vente_id'] as String?,
        note: _s(m['note']),
        date: DateTime.tryParse((m['created_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      );
}

class Client {
  final String id;
  final String nom;
  final String? telephone;
  final String? adresse;
  final String? wilaya;
  final String? rc;
  final String? nif;
  final String? note;
  final bool actif;
  final double totalAchats;
  final double totalVerse;
  final double solde;
  final int nbVentes;
  final DateTime? derniereVente;
  final double totalAvoirs;

  const Client({
    required this.id,
    required this.nom,
    this.telephone,
    this.adresse,
    this.wilaya,
    this.rc,
    this.nif,
    this.note,
    this.actif = true,
    this.totalAchats = 0,
    this.totalVerse = 0,
    this.solde = 0,
    this.nbVentes = 0,
    this.derniereVente,
    this.totalAvoirs = 0,
  });

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        telephone: _s(m['telephone']),
        adresse: _s(m['adresse']),
        wilaya: _s(m['wilaya']),
        rc: _s(m['rc']),
        nif: _s(m['nif']),
        note: _s(m['note']),
        actif: (m['actif'] ?? true) as bool,
        totalAchats: _d(m['total_achats']),
        totalVerse: _d(m['total_verse']),
        solde: _d(m['solde']),
        nbVentes: _i(m['nb_ventes']),
        derniereVente: m['derniere_vente'] == null ? null : DateTime.tryParse(m['derniere_vente'] as String),
        totalAvoirs: _d(m['total_avoirs']),
      );

  static Map<String, dynamic> toRow({
    required String nom,
    String? telephone,
    String? adresse,
    String? wilaya,
    String? rc,
    String? nif,
    String? note,
    bool actif = true,
  }) =>
      {
        'nom': nom.trim(),
        'telephone': _ne(telephone),
        'adresse': _ne(adresse),
        'wilaya': _ne(wilaya),
        'rc': _ne(rc),
        'nif': _ne(nif),
        'note': _ne(note),
        'actif': actif,
      };
}

class Vente {
  final String id;
  final String numero;
  final String numeroBl;
  final String? clientId;
  final String? clientNom;
  final DateTime date;
  final double remise;
  final double tvaTaux;
  final double totalBrut;
  final double totalHt;
  final double totalTva;
  final double totalTtc;
  final bool annulee;
  final String? chauffeur;
  final String? vehicule;
  final String? adresseLivraison;
  final String? note;
  final double verse;
  final double reste;
  final int nbArticles;
  final double avoirs;

  const Vente({
    required this.id,
    required this.numero,
    required this.numeroBl,
    this.clientId,
    this.clientNom,
    required this.date,
    this.remise = 0,
    this.tvaTaux = 0,
    this.totalBrut = 0,
    this.totalHt = 0,
    this.totalTva = 0,
    this.totalTtc = 0,
    this.annulee = false,
    this.chauffeur,
    this.vehicule,
    this.adresseLivraison,
    this.note,
    this.verse = 0,
    this.reste = 0,
    this.nbArticles = 0,
    this.avoirs = 0,
  });

  factory Vente.fromMap(Map<String, dynamic> m) => Vente(
        id: m['id'] as String,
        numero: (m['numero'] ?? '') as String,
        numeroBl: (m['numero_bl'] ?? '') as String,
        clientId: m['client_id'] as String?,
        clientNom: _s(m['client_nom']),
        date: DateTime.parse(m['date_vente'] as String),
        remise: _d(m['remise']),
        tvaTaux: _d(m['tva_taux']),
        totalBrut: _d(m['total_brut']),
        totalHt: _d(m['total_ht']),
        totalTva: _d(m['total_tva']),
        totalTtc: _d(m['total_ttc']),
        annulee: m['statut'] == 'annulee',
        chauffeur: _s(m['chauffeur']),
        vehicule: _s(m['vehicule']),
        adresseLivraison: _s(m['adresse_livraison']),
        note: _s(m['note']),
        verse: _d(m['verse']),
        reste: _d(m['reste']),
        nbArticles: _i(m['nb_articles']),
        avoirs: _d(m['avoirs']),
      );

  String get statutTexte {
    if (annulee) return 'Annulée';
    if (reste <= 0.005) return 'Payée';
    if (verse > 0) return 'Partielle';
    return 'Non payée';
  }
}

class VenteLigne {
  final String id;
  final String produitId;
  final String reference;
  final String designation;
  final int quantite;
  final double prixUnitaire;
  final double montant;

  const VenteLigne({
    required this.id,
    required this.produitId,
    required this.reference,
    required this.designation,
    required this.quantite,
    required this.prixUnitaire,
    required this.montant,
  });

  factory VenteLigne.fromMap(Map<String, dynamic> m) => VenteLigne(
        id: m['id'] as String,
        produitId: m['produit_id'] as String,
        reference: (m['reference'] ?? '') as String,
        designation: (m['designation'] ?? '') as String,
        quantite: _i(m['quantite']),
        prixUnitaire: _d(m['prix_unitaire']),
        montant: _d(m['montant']),
      );
}

const modesPaiement = {'especes': 'Espèces', 'cheque': 'Chèque', 'virement': 'Virement', 'ccp': 'CCP', 'autre': 'Autre'};

class Versement {
  final String id;
  final String clientId;
  final String? venteId;
  final DateTime date;
  final double montant;
  final String mode;
  final String? note;

  const Versement({required this.id, required this.clientId, this.venteId, required this.date, required this.montant, this.mode = 'especes', this.note});

  factory Versement.fromMap(Map<String, dynamic> m) => Versement(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        venteId: m['vente_id'] as String?,
        date: DateTime.parse(m['date_versement'] as String),
        montant: _d(m['montant']),
        mode: (m['mode'] ?? 'especes') as String,
        note: _s(m['note']),
      );

  String get modeTexte => modesPaiement[mode] ?? mode;
}

/// Ligne du panier pendant une vente.
class LignePanier {
  final Produit produit;
  int quantite;
  double prix;
  LignePanier(this.produit, {this.quantite = 1, double? prix}) : prix = prix ?? produit.prixGros;
  double get montant => quantite * prix;
}

/// Informations du site vitrine pour un modèle (photos, description, publication).
class InfoModele {
  final String modele;
  final String? description;
  final List<String> photos;
  final bool publie;
  final bool vedette;
  const InfoModele({required this.modele, this.description, this.photos = const [], this.publie = true, this.vedette = false});
  factory InfoModele.fromMap(Map<String, dynamic> m) => InfoModele(
        modele: m['modele'] as String,
        description: _s(m['description']),
        photos: [for (final x in (m['photos'] as List? ?? const [])) x.toString()],
        publie: (m['publie'] ?? true) as bool,
        vedette: (m['vedette'] ?? false) as bool,
      );
}

String cleGrille(String? couleur, String? taille) => '${couleur ?? ''}|${taille ?? ''}';

// =================================================================== données

class StockData extends ChangeNotifier {
  StockData._();
  static final StockData instance = StockData._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Produit> produits = [];
  List<Client> clients = [];
  /// clientId -> (produitId -> prix spécial)
  Map<String, Map<String, double>> prixClients = {};
  bool loaded = false;
  int version = 0;

  double prixPour(Produit p, String? clientId) => prixClients[clientId]?[p.id] ?? p.prixGros;

  Produit? produit(String? id) {
    for (final p in produits) {
      if (p.id == id) return p;
    }
    return null;
  }

  Produit? parReference(String ref) {
    final r = ref.trim().toUpperCase();
    for (final p in produits) {
      if (p.reference.toUpperCase() == r) return p;
    }
    return null;
  }

  Client? client(String? id) {
    for (final c in clients) {
      if (c.id == id) return c;
    }
    return null;
  }

  int get totalReserve => produits.where((p) => p.actif).fold<int>(0, (s, p) => s + p.reserve);
  int get totalPieces => produits.where((p) => p.actif).fold<int>(0, (s, p) => s + (p.stock > 0 ? p.stock : 0));
  double get valeurStock => produits.where((p) => p.actif).fold<double>(0, (s, p) => s + p.valeurStock);
  int get nbAlertes => produits.where((p) => p.actif && p.enAlerte).length;
  double get totalCreances => clients.fold<double>(0, (s, c) => s + (c.solde > 0 ? c.solde : 0));

  Future<void> load() async {
    final res = await Future.wait<List<Map<String, dynamic>>>([
      _db.from('stock_etat').select().order('reference'),
      _db.from('stock_clients_soldes').select().order('nom'),
      _db.from('stock_prix_clients').select('client_id, produit_id, prix'),
      _db.from('stock_modeles_info').select('modele, description, photos, publie, vedette'),
    ]);
    infos = {for (final r in res[3]) r['modele'] as String: InfoModele.fromMap(r)};
    produits = res[0].map(Produit.fromMap).toList();
    clients = res[1].map(Client.fromMap).toList();
    final pc = <String, Map<String, double>>{};
    for (final r in res[2]) {
      pc.putIfAbsent(r['client_id'] as String, () => {})[r['produit_id'] as String] = _d(r['prix']);
    }
    prixClients = pc;
    loaded = true;
    notifyListeners();
  }

  Map<String, InfoModele> infos = {};
  InfoModele info(String cle) => infos[cle] ?? InfoModele(modele: cle);

  /// Adresse publique d'une photo du site.
  String urlPublique(String path) => _db.storage.from('vitrine').getPublicUrl(path);

  Future<String> envoyerPhotoVitrine(Uint8List bytes, {String ext = 'jpg', String dossier = 'modeles'}) async {
    final path = '${session.atelierId}/$dossier/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('vitrine').uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true, cacheControl: '31536000'));
    return path;
  }

  Future<void> retirerPhotoVitrine(String path) async {
    try {
      await _db.storage.from('vitrine').remove([path]);
    } catch (_) {}
  }

  Future<void> saveInfo(String cle, {String? description, List<String>? photos, bool? publie, bool? vedette}) async {
    final cur = info(cle);
    final row = {
      'modele': cle,
      'description': description ?? cur.description,
      'photos': photos ?? cur.photos,
      'publie': publie ?? cur.publie,
      'vedette': vedette ?? cur.vedette,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _db.from('stock_modeles_info').upsert(row, onConflict: 'atelier_id,modele');
    infos[cle] = InfoModele.fromMap(row);
    notifyListeners();
  }

  void clear() {
    infos = {};
    produits = [];
    clients = [];
    loaded = false;
  }

  Future<void> changed() => _changed();

  Future<void> _changed() async {
    version++;
    await load();
  }

  // ---------------- produits

  /// Modèles regroupant les variantes (ordre : référence).
  List<Modele> get modeles {
    final map = <String, List<Produit>>{};
    for (final p in produits) {
      (map[p.cleModele] ??= []).add(p);
    }
    final out = [
      for (final e in map.entries)
        Modele(e.key, e.value..sort((a, b) {
          final c = (a.couleur ?? '').compareTo(b.couleur ?? '');
          return c != 0 ? c : ordreTaille(a.taille).compareTo(ordreTaille(b.taille));
        }))
    ];
    out.sort((a, b) => a.reference.compareTo(b.reference));
    return out;
  }

  Modele? modeleDe(String? produitId) {
    final p = produit(produitId);
    if (p == null) return null;
    return Modele(p.cleModele, produits.where((x) => x.cleModele == p.cleModele).toList());
  }

  Modele? modeleParCle(String cle) {
    final v = produits.where((x) => x.cleModele == cle).toList();
    return v.isEmpty ? null : Modele(cle, v);
  }

  /// Toutes les couleurs déjà utilisées (pour proposer la liste).
  List<String> get couleursUtilisees => produits.map((p) => p.couleur).whereType<String>().toSet().toList()..sort();
  List<String> get taillesUtilisees => produits.map((p) => p.taille).whereType<String>().toSet().toList()..sort((a, b) => ordreTaille(a).compareTo(ordreTaille(b)));

  String _refLibre(String ref) {
    var r = ref;
    var i = 2;
    while (parReference(r) != null) {
      r = '$ref-${i++}';
    }
    return r;
  }

  /// Crée les variantes manquantes d'un modèle et ajoute les quantités initiales.
  /// [quantites] : clé '$couleur|$taille' (vide si null) -> pièces.
  Future<String> creerVariantes({
    required String reference,
    required Map<String, dynamic> champs,
    required List<String?> couleurs,
    required List<String?> tailles,
    Map<String, int> quantites = const {},
    Modele? existant,
  }) async {
    final cle = reference.trim().toUpperCase();
    if (existant != null && existant.base.modele == null) {
      await _db.from('stock_produits').update({'modele': cle}).eq('id', existant.base.id);
    }
    final rows = <Map<String, dynamic>>[];
    final cs = couleurs.isEmpty ? <String?>[null] : couleurs;
    final ts = tailles.isEmpty ? <String?>[null] : tailles;
    final unique = cs.length == 1 && ts.length == 1 && cs.first == null && ts.first == null && existant == null;
    final prises = <String>{};
    for (final c in cs) {
      for (final t in ts) {
        if (existant?.variante(c, t) != null) continue;
        var ref = unique ? cle : _refLibre(referenceVariante(cle, c, t));
        while (prises.contains(ref)) {
          ref = '$ref-X';
        }
        prises.add(ref);
        rows.add({...champs, 'reference': ref, 'couleur': c, 'taille': t, 'modele': cle});
      }
    }
    final mvts = <Map<String, dynamic>>[];
    if (rows.isNotEmpty) {
      final ins = await _db.from('stock_produits').insert(rows).select('id, couleur, taille');
      for (final r in ins) {
        final q = quantites[cleGrille(r['couleur'] as String?, r['taille'] as String?)] ?? 0;
        if (q > 0) mvts.add({'produit_id': r['id'], 'type': 'entree', 'quantite': q, 'note': 'Stock initial'});
      }
    }
    if (existant != null) {
      for (final v in existant.variantes) {
        final q = quantites[cleGrille(v.couleur, v.taille)] ?? 0;
        if (q > 0) mvts.add({'produit_id': v.id, 'type': 'entree', 'quantite': q, 'note': 'Entrée de stock'});
      }
    }
    if (mvts.isNotEmpty) await _db.from('stock_mouvements').insert(mvts);
    await _changed();
    return cle;
  }

  /// Entrées / sorties groupées : produitId -> quantité signée.
  Future<void> mouvementsGroupes(Map<String, int> parProduit, TypeStock type, {String? note}) async {
    final rows = [
      for (final e in parProduit.entries)
        if (e.value != 0) {'produit_id': e.key, 'type': type.name, 'quantite': e.value, 'note': _ne(note)},
    ];
    if (rows.isEmpty) return;
    await _db.from('stock_mouvements').insert(rows);
    await _changed();
  }

  Future<void> modifierModele(Modele m, Map<String, dynamic> champs) async {
    await _db.from('stock_produits').update(champs).inFilter('id', [for (final v in m.variantes) v.id]);
    await _changed();
  }

  Future<String> prochaineReference([String prefixe = 'ROB']) async {
    final n = await _db.rpc('atelier_prochain_numero', params: {'p_cle': 'produit_$prefixe', 'p_annee': 0});
    var ref = '$prefixe-${(n as num).toInt().toString().padLeft(4, '0')}';
    // éviter un doublon si la référence a été saisie à la main
    while (parReference(ref) != null) {
      final m = await _db.rpc('atelier_prochain_numero', params: {'p_cle': 'produit_$prefixe', 'p_annee': 0});
      ref = '$prefixe-${(m as num).toInt().toString().padLeft(4, '0')}';
    }
    return ref;
  }

  Future<String> saveProduit(Map<String, dynamic> row, {String? id, int stockInitial = 0}) async {
    String pid;
    if (id == null) {
      final r = await _db.from('stock_produits').insert(row).select('id').single();
      pid = r['id'] as String;
      if (stockInitial > 0) {
        await _db.from('stock_mouvements').insert({'produit_id': pid, 'type': 'entree', 'quantite': stockInitial, 'note': 'Stock initial'});
      }
    } else {
      await _db.from('stock_produits').update(row).eq('id', id);
      pid = id;
    }
    await _changed();
    return pid;
  }

  Future<void> deleteProduit(String id) async {
    await _db.from('stock_produits').delete().eq('id', id);
    await _changed();
  }

  /// Ajoute (+) ou retire (−) des pièces du stock.
  Future<void> mouvement(String produitId, TypeStock type, int quantiteSignee, {String? note}) async {
    if (quantiteSignee == 0) return;
    await _db.from('stock_mouvements').insert({
      'produit_id': produitId,
      'type': type.name,
      'quantite': quantiteSignee,
      'note': _ne(note),
    });
    await _changed();
  }

  Future<List<StockMvt>> mouvements({String? produitId, int limit = 200}) async {
    var q = _db.from('stock_mouvements').select();
    if (produitId != null) q = q.eq('produit_id', produitId);
    final rows = await q.order('created_at', ascending: false).limit(limit);
    return rows.map(StockMvt.fromMap).toList();
  }

  // ---------------- clients

  Future<String> saveClient(Map<String, dynamic> row, {String? id}) async {
    String cid;
    if (id == null) {
      final r = await _db.from('stock_clients').insert(row).select('id').single();
      cid = r['id'] as String;
    } else {
      await _db.from('stock_clients').update(row).eq('id', id);
      cid = id;
    }
    await _changed();
    return cid;
  }

  Future<void> deleteClient(String id) async {
    await _db.from('stock_clients').delete().eq('id', id);
    await _changed();
  }

  // ---------------- ventes

  Future<List<Vente>> ventes({DateTime? from, DateTime? to, String? clientId, int limit = 1000}) async {
    var q = _db.from('stock_ventes_etat').select();
    if (from != null) q = q.gte('date_vente', dateKey(from));
    if (to != null) q = q.lte('date_vente', dateKey(to));
    if (clientId != null) q = q.eq('client_id', clientId);
    final rows = await q.order('date_vente', ascending: false).order('created_at', ascending: false).limit(limit);
    return rows.map(Vente.fromMap).toList();
  }

  Future<Vente> vente(String id) async {
    final r = await _db.from('stock_ventes_etat').select().eq('id', id).single();
    return Vente.fromMap(r);
  }

  Future<List<VenteLigne>> lignes(String venteId) async {
    final rows = await _db.from('stock_vente_lignes').select().eq('vente_id', venteId).order('reference');
    return rows.map(VenteLigne.fromMap).toList();
  }

  Future<String> creerVenteAvecOption({
    required String? clientId,
    required DateTime date,
    required List<LignePanier> lignes,
    double remise = 0,
    double versement = 0,
    String mode = 'especes',
    String? chauffeur,
    String? vehicule,
    String? adresse,
    String? note,
    bool autoriserNegatif = false,
  }) async {
    final id = await _db.rpc('stock_creer_vente', params: {
      'p_client': clientId,
      'p_date': dateKey(date),
      'p_lignes': [
        for (final l in lignes) {'produit_id': l.produit.id, 'quantite': l.quantite, 'prix': l.prix},
      ],
      'p_remise': remise,
      'p_versement': versement,
      'p_mode': mode,
      'p_chauffeur': chauffeur,
      'p_vehicule': vehicule,
      'p_adresse': adresse,
      'p_note': note,
      'p_autoriser_negatif': autoriserNegatif,
    });
    await _changed();
    return id as String;
  }

  Future<void> annulerVente(String id, String? motif) async {
    await _db.rpc('stock_annuler_vente', params: {'p_vente': id, 'p_motif': motif});
    await _changed();
  }

  /// Lignes vendues (ventes validées) sur une période, pour les analyses.
  Future<List<Map<String, dynamic>>> lignesVendues(DateTime from, DateTime to) async {
    final rows = await _db
        .from('stock_lignes_detail')
        .select('produit_id, quantite, montant, client_id, date_vente, statut')
        .gte('date_vente', dateKey(from))
        .lte('date_vente', dateKey(to))
        .eq('statut', 'validee')
        .limit(10000);
    return rows;
  }

  // ---------------- versements

  Future<List<Versement>> versements({String? clientId, String? venteId, DateTime? from, DateTime? to}) async {
    var q = _db.from('stock_versements').select();
    if (clientId != null) q = q.eq('client_id', clientId);
    if (venteId != null) q = q.eq('vente_id', venteId);
    if (from != null) q = q.gte('date_versement', dateKey(from));
    if (to != null) q = q.lte('date_versement', dateKey(to));
    final rows = await q.order('date_versement', ascending: false).order('created_at', ascending: false).limit(2000);
    return rows.map(Versement.fromMap).toList();
  }

  Future<void> saveVersement({
    String? id,
    required String clientId,
    String? venteId,
    required DateTime date,
    required double montant,
    String mode = 'especes',
    String? note,
  }) async {
    final row = {
      'client_id': clientId,
      'vente_id': venteId,
      'date_versement': dateKey(date),
      'montant': montant,
      'mode': mode,
      'note': _ne(note),
    };
    if (id == null) {
      await _db.from('stock_versements').insert(row);
    } else {
      await _db.from('stock_versements').update(row).eq('id', id);
    }
    await _changed();
  }

  Future<void> deleteVersement(String id) async {
    await _db.from('stock_versements').delete().eq('id', id);
    await _changed();
  }
}

final stock = StockData.instance;
