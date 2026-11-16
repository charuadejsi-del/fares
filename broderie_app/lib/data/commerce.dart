import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import 'stock.dart';
import '../i18n.dart';

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0);
String? _s(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();
String? _ne(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

// =================================================================== devis & commandes

enum StatutDoc { enCours, prete, acceptee, refusee, livree, annulee }

extension StatutDocX on StatutDoc {
  String get db => switch (this) {
        StatutDoc.enCours => 'en_cours',
        StatutDoc.prete => 'prete',
        StatutDoc.acceptee => 'acceptee',
        StatutDoc.refusee => 'refusee',
        StatutDoc.livree => 'livree',
        StatutDoc.annulee => 'annulee',
      };
  static StatutDoc parse(String? s) => StatutDoc.values.firstWhere((x) => x.db == s, orElse: () => StatutDoc.enCours);
}

class Commande {
  final String id;
  final bool devis;
  final String numero;
  final String? clientId;
  final String? clientNom;
  final DateTime date;
  final DateTime? echeance;
  final StatutDoc statut;
  final double remise;
  final String? note;
  final String? venteId;
  final double totalBrut;
  final double total;
  final int nbArticles;

  const Commande({
    required this.id,
    required this.devis,
    required this.numero,
    this.clientId,
    this.clientNom,
    required this.date,
    this.echeance,
    this.statut = StatutDoc.enCours,
    this.remise = 0,
    this.note,
    this.venteId,
    this.totalBrut = 0,
    this.total = 0,
    this.nbArticles = 0,
  });

  factory Commande.fromMap(Map<String, dynamic> m) => Commande(
        id: m['id'] as String,
        devis: m['type'] == 'devis',
        numero: (m['numero'] ?? '') as String,
        clientId: m['client_id'] as String?,
        clientNom: _s(m['client_nom']),
        date: DateTime.parse(m['date_doc'] as String),
        echeance: _dt(m['date_echeance']),
        statut: StatutDocX.parse(m['statut'] as String?),
        remise: _d(m['remise']),
        note: _s(m['note']),
        venteId: m['vente_id'] as String?,
        totalBrut: _d(m['total_brut']),
        total: _d(m['total']),
        nbArticles: _i(m['nb_articles']),
      );

  bool get modifiable => venteId == null && (statut == StatutDoc.enCours || statut == StatutDoc.prete);
  bool get enRetard => modifiable && echeance != null && echeance!.isBefore(dayOnly(DateTime.now()));

  String get statutTexte {
    if (venteId != null) return 'Facturé';
    return switch (statut) {
      StatutDoc.enCours => devis ? 'En attente'.tr : 'En préparation'.tr,
      StatutDoc.prete => 'Prête à livrer'.tr,
      StatutDoc.acceptee => 'Accepté'.tr,
      StatutDoc.refusee => 'Refusé'.tr,
      StatutDoc.livree => 'Livrée'.tr,
      StatutDoc.annulee => 'Annulé'.tr,
    };
  }
}

class CommandeLigne {
  final String id;
  final String produitId;
  final int quantite;
  final double prixUnitaire;
  final double montant;
  const CommandeLigne({required this.id, required this.produitId, required this.quantite, required this.prixUnitaire, required this.montant});
  factory CommandeLigne.fromMap(Map<String, dynamic> m) => CommandeLigne(
        id: m['id'] as String,
        produitId: m['produit_id'] as String,
        quantite: _i(m['quantite']),
        prixUnitaire: _d(m['prix_unitaire']),
        montant: _d(m['montant']),
      );
}

// =================================================================== avoirs

class Avoir {
  final String id;
  final String numero;
  final String clientId;
  final String? clientNom;
  final String? venteId;
  final String? venteNumero;
  final DateTime date;
  final double total;
  final bool remisEnStock;
  final String? motif;
  final int nbArticles;

  const Avoir({
    required this.id,
    required this.numero,
    required this.clientId,
    this.clientNom,
    this.venteId,
    this.venteNumero,
    required this.date,
    this.total = 0,
    this.remisEnStock = true,
    this.motif,
    this.nbArticles = 0,
  });

  factory Avoir.fromMap(Map<String, dynamic> m) => Avoir(
        id: m['id'] as String,
        numero: (m['numero'] ?? '') as String,
        clientId: m['client_id'] as String,
        clientNom: _s(m['client_nom']),
        venteId: m['vente_id'] as String?,
        venteNumero: _s(m['vente_numero']),
        date: DateTime.parse(m['date_avoir'] as String),
        total: _d(m['total']),
        remisEnStock: (m['remis_en_stock'] ?? true) as bool,
        motif: _s(m['motif']),
        nbArticles: _i(m['nb_articles']),
      );
}

class AvoirLigne {
  final String produitId;
  final int quantite;
  final double prixUnitaire;
  final double montant;
  const AvoirLigne({required this.produitId, required this.quantite, required this.prixUnitaire, required this.montant});
  factory AvoirLigne.fromMap(Map<String, dynamic> m) =>
      AvoirLigne(produitId: m['produit_id'] as String, quantite: _i(m['quantite']), prixUnitaire: _d(m['prix_unitaire']), montant: _d(m['montant']));
}

// =================================================================== matières, fournisseurs, achats

const unitesMatieres = ['m', 'kg', 'g', 'bobine', 'pièce', 'paquet', 'rouleau', 'litre'];

class Matiere {
  final String id;
  final String nom;
  final String unite;
  final String? categorie;
  final double seuilAlerte;
  final bool actif;
  final double stock;
  final double coutMoyen;

  const Matiere({
    required this.id,
    required this.nom,
    this.unite = 'm',
    this.categorie,
    this.seuilAlerte = 0,
    this.actif = true,
    this.stock = 0,
    this.coutMoyen = 0,
  });

  factory Matiere.fromMap(Map<String, dynamic> m) => Matiere(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        unite: (m['unite'] ?? 'm') as String,
        categorie: _s(m['categorie']),
        seuilAlerte: _d(m['seuil_alerte']),
        actif: (m['actif'] ?? true) as bool,
        stock: _d(m['stock']),
        coutMoyen: _d(m['cout_moyen']),
      );

  bool get enAlerte => stock <= seuilAlerte;
  double get valeur => (stock > 0 ? stock : 0) * coutMoyen;
}

class MatiereMvt {
  final String id;
  final String matiereId;
  final String type;
  final double quantite;
  final String? note;
  final DateTime date;
  const MatiereMvt({required this.id, required this.matiereId, required this.type, required this.quantite, this.note, required this.date});
  factory MatiereMvt.fromMap(Map<String, dynamic> m) => MatiereMvt(
        id: m['id'] as String,
        matiereId: m['matiere_id'] as String,
        type: (m['type'] ?? '') as String,
        quantite: _d(m['quantite']),
        note: _s(m['note']),
        date: DateTime.tryParse((m['created_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
      );

  String get typeTexte => switch (type) {
        'achat' => 'Achat'.tr,
        'consommation' => 'Consommation'.tr,
        'ajustement' => 'Ajustement (inventaire)'.tr,
        'retour' => 'Retour fournisseur'.tr,
        _ => type,
      };
}

class Fournisseur {
  final String id;
  final String nom;
  final String? telephone;
  final String? adresse;
  final String? note;
  final bool actif;
  final double totalAchats;
  final double totalPaye;
  final double solde;

  const Fournisseur({
    required this.id,
    required this.nom,
    this.telephone,
    this.adresse,
    this.note,
    this.actif = true,
    this.totalAchats = 0,
    this.totalPaye = 0,
    this.solde = 0,
  });

  factory Fournisseur.fromMap(Map<String, dynamic> m) => Fournisseur(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        telephone: _s(m['telephone']),
        adresse: _s(m['adresse']),
        note: _s(m['note']),
        actif: (m['actif'] ?? true) as bool,
        totalAchats: _d(m['total_achats']),
        totalPaye: _d(m['total_paye']),
        solde: _d(m['solde']),
      );
}

class Achat {
  final String id;
  final String numero;
  final String? fournisseurId;
  final String? fournisseurNom;
  final DateTime date;
  final double total;
  final double paye;
  final double reste;
  final String? note;

  const Achat({
    required this.id,
    required this.numero,
    this.fournisseurId,
    this.fournisseurNom,
    required this.date,
    this.total = 0,
    this.paye = 0,
    this.reste = 0,
    this.note,
  });

  factory Achat.fromMap(Map<String, dynamic> m) => Achat(
        id: m['id'] as String,
        numero: (m['numero'] ?? '') as String,
        fournisseurId: m['fournisseur_id'] as String?,
        fournisseurNom: _s(m['fournisseur_nom']),
        date: DateTime.parse(m['date_achat'] as String),
        total: _d(m['total']),
        paye: _d(m['paye']),
        reste: _d(m['reste']),
        note: _s(m['note']),
      );
}

class AchatLigne {
  final String matiereId;
  final double quantite;
  final double prixUnitaire;
  final double montant;
  const AchatLigne({required this.matiereId, required this.quantite, required this.prixUnitaire, required this.montant});
  factory AchatLigne.fromMap(Map<String, dynamic> m) =>
      AchatLigne(matiereId: m['matiere_id'] as String, quantite: _d(m['quantite']), prixUnitaire: _d(m['prix_unitaire']), montant: _d(m['montant']));
}

class PaiementFournisseur {
  final String id;
  final String fournisseurId;
  final String? achatId;
  final DateTime date;
  final double montant;
  final String mode;
  final String? note;
  const PaiementFournisseur({required this.id, required this.fournisseurId, this.achatId, required this.date, required this.montant, this.mode = 'especes', this.note});
  factory PaiementFournisseur.fromMap(Map<String, dynamic> m) => PaiementFournisseur(
        id: m['id'] as String,
        fournisseurId: m['fournisseur_id'] as String,
        achatId: m['achat_id'] as String?,
        date: DateTime.parse(m['date_paiement'] as String),
        montant: _d(m['montant']),
        mode: (m['mode'] ?? 'especes') as String,
        note: _s(m['note']),
      );
  String get modeTexte => (modesPaiement[mode] ?? mode).tr;
}

class NomenclatureLigne {
  final String id;
  final String produitId;
  final String matiereId;
  final double quantite;
  const NomenclatureLigne({required this.id, required this.produitId, required this.matiereId, required this.quantite});
  factory NomenclatureLigne.fromMap(Map<String, dynamic> m) =>
      NomenclatureLigne(id: m['id'] as String, produitId: m['produit_id'] as String, matiereId: m['matiere_id'] as String, quantite: _d(m['quantite']));
}

/// Ligne d'achat pendant la saisie.
class LigneAchat {
  final Matiere matiere;
  double quantite;
  double prix;
  LigneAchat(this.matiere, {this.quantite = 1, double? prix}) : prix = prix ?? matiere.coutMoyen;
  double get montant => quantite * prix;
}

// =================================================================== données

class CommerceData extends ChangeNotifier {
  CommerceData._();
  static final CommerceData instance = CommerceData._();

  SupabaseClient get _db => Supabase.instance.client;

  List<Matiere> matieres = [];
  List<Fournisseur> fournisseurs = [];
  bool loaded = false;
  int version = 0;

  Matiere? matiere(String? id) {
    for (final m in matieres) {
      if (m.id == id) return m;
    }
    return null;
  }

  Fournisseur? fournisseur(String? id) {
    for (final f in fournisseurs) {
      if (f.id == id) return f;
    }
    return null;
  }

  double get valeurMatieres => matieres.where((m) => m.actif).fold<double>(0, (s, m) => s + m.valeur);
  double get totalDettes => fournisseurs.fold<double>(0, (s, f) => s + (f.solde > 0 ? f.solde : 0));
  int get nbAlertesMatieres => matieres.where((m) => m.actif && m.enAlerte).length;

  Future<void> load() async {
    final r = await Future.wait<List<Map<String, dynamic>>>([
      _db.from('stock_matieres_etat').select().order('nom'),
      _db.from('stock_fournisseurs_soldes').select().order('nom'),
    ]);
    matieres = r[0].map(Matiere.fromMap).toList();
    fournisseurs = r[1].map(Fournisseur.fromMap).toList();
    loaded = true;
    notifyListeners();
  }

  void clear() {
    matieres = [];
    fournisseurs = [];
    loaded = false;
  }

  /// Recharge tout (matières + stock produits/clients).
  Future<void> _changed({bool stockAussi = true}) async {
    version++;
    await Future.wait<void>([load(), if (stockAussi) stock.changed()]);
  }

  // ---------------- devis & commandes

  Future<List<Commande>> commandes({bool? devis, String? clientId, DateTime? from}) async {
    var q = _db.from('stock_commandes_etat').select();
    if (devis != null) q = q.eq('type', devis ? 'devis' : 'commande');
    if (clientId != null) q = q.eq('client_id', clientId);
    if (from != null) q = q.gte('date_doc', dateKey(from));
    final rows = await q.order('date_doc', ascending: false).order('created_at', ascending: false).limit(1000);
    return rows.map(Commande.fromMap).toList();
  }

  Future<Commande> commande(String id) async => Commande.fromMap(await _db.from('stock_commandes_etat').select().eq('id', id).single());

  Future<List<CommandeLigne>> commandeLignes(String id) async {
    final rows = await _db.from('stock_commande_lignes').select().eq('commande_id', id);
    return rows.map(CommandeLigne.fromMap).toList();
  }

  List<Map<String, dynamic>> _lignes(List<LignePanier> l) => [
        for (final x in l) {'produit_id': x.produit.id, 'quantite': x.quantite, 'prix': x.prix},
      ];

  Future<String> creerCommande({
    required bool devis,
    String? clientId,
    required DateTime date,
    DateTime? echeance,
    required List<LignePanier> lignes,
    double remise = 0,
    String? note,
  }) async {
    final id = await _db.rpc('stock_creer_commande', params: {
      'p_type': devis ? 'devis' : 'commande',
      'p_client': clientId,
      'p_date': dateKey(date),
      'p_echeance': echeance == null ? null : dateKey(echeance),
      'p_lignes': _lignes(lignes),
      'p_remise': remise,
      'p_note': note,
    });
    await _changed();
    return id as String;
  }

  Future<void> modifierCommande(
    String id, {
    String? clientId,
    required DateTime date,
    DateTime? echeance,
    required List<LignePanier> lignes,
    double remise = 0,
    String? note,
  }) async {
    await _db.from('stock_commandes').update({
      'client_id': clientId,
      'date_doc': dateKey(date),
      'date_echeance': echeance == null ? null : dateKey(echeance),
      'remise': remise,
      'note': _ne(note),
    }).eq('id', id);
    await _db.from('stock_commande_lignes').delete().eq('commande_id', id);
    await _db.from('stock_commande_lignes').insert([
      for (final l in lignes) {'commande_id': id, 'produit_id': l.produit.id, 'quantite': l.quantite, 'prix_unitaire': l.prix},
    ]);
    await _changed();
  }

  Future<void> statutCommande(String id, StatutDoc s) async {
    await _db.from('stock_commandes').update({'statut': s.db}).eq('id', id);
    await _changed();
  }

  Future<String> devisVersCommande(String id) async {
    final r = await _db.rpc('stock_devis_vers_commande', params: {'p_devis': id});
    await _changed();
    return r as String;
  }

  Future<String> commandeVersVente(String id, {double versement = 0, String mode = 'especes', bool autoriserNegatif = false}) async {
    final r = await _db.rpc('stock_commande_vers_vente', params: {
      'p_commande': id,
      'p_versement': versement,
      'p_mode': mode,
      'p_autoriser_negatif': autoriserNegatif,
    });
    await _changed();
    return r as String;
  }

  Future<void> supprimerCommande(String id) async {
    await _db.from('stock_commandes').delete().eq('id', id);
    await _changed();
  }

  // ---------------- avoirs

  Future<List<Avoir>> avoirs({String? clientId, String? venteId}) async {
    var q = _db.from('stock_avoirs_etat').select();
    if (clientId != null) q = q.eq('client_id', clientId);
    if (venteId != null) q = q.eq('vente_id', venteId);
    final rows = await q.order('date_avoir', ascending: false).order('created_at', ascending: false).limit(500);
    return rows.map(Avoir.fromMap).toList();
  }

  Future<List<AvoirLigne>> avoirLignes(String id) async {
    final rows = await _db.from('stock_avoir_lignes').select().eq('avoir_id', id);
    return rows.map(AvoirLigne.fromMap).toList();
  }

  Future<String> creerAvoir({
    required String clientId,
    String? venteId,
    required List<(String produitId, int quantite, double prix)> lignes,
    String? motif,
    bool remettreEnStock = true,
  }) async {
    final r = await _db.rpc('stock_creer_avoir', params: {
      'p_client': clientId,
      'p_vente': venteId,
      'p_lignes': [for (final l in lignes) {'produit_id': l.$1, 'quantite': l.$2, 'prix': l.$3}],
      'p_motif': motif,
      'p_remettre': remettreEnStock,
    });
    await _changed();
    return r as String;
  }

  // ---------------- prix spéciaux

  Future<void> setPrixClient(String clientId, String produitId, double? prix) async {
    if (prix == null) {
      await _db.from('stock_prix_clients').delete().eq('client_id', clientId).eq('produit_id', produitId);
    } else {
      await _db.from('stock_prix_clients').upsert({'client_id': clientId, 'produit_id': produitId, 'prix': prix}, onConflict: 'client_id,produit_id');
    }
    await stock.changed();
  }

  // ---------------- matières

  Future<String> saveMatiere(Map<String, dynamic> row, {String? id}) async {
    String mid;
    if (id == null) {
      final r = await _db.from('stock_matieres').insert(row).select('id').single();
      mid = r['id'] as String;
    } else {
      await _db.from('stock_matieres').update(row).eq('id', id);
      mid = id;
    }
    await _changed(stockAussi: false);
    return mid;
  }

  Future<void> deleteMatiere(String id) async {
    await _db.from('stock_matieres').delete().eq('id', id);
    await _changed(stockAussi: false);
  }

  Future<void> mouvementMatiere(String matiereId, String type, double quantiteSignee, {String? note}) async {
    await _db.from('stock_matiere_mvts').insert({'matiere_id': matiereId, 'type': type, 'quantite': quantiteSignee, 'note': _ne(note)});
    await _changed();
  }

  Future<List<MatiereMvt>> mouvementsMatiere(String matiereId) async {
    final rows = await _db.from('stock_matiere_mvts').select().eq('matiere_id', matiereId).order('created_at', ascending: false).limit(200);
    return rows.map(MatiereMvt.fromMap).toList();
  }

  // ---------------- fournisseurs

  Future<String> saveFournisseur(Map<String, dynamic> row, {String? id}) async {
    String fid;
    if (id == null) {
      final r = await _db.from('stock_fournisseurs').insert(row).select('id').single();
      fid = r['id'] as String;
    } else {
      await _db.from('stock_fournisseurs').update(row).eq('id', id);
      fid = id;
    }
    await _changed(stockAussi: false);
    return fid;
  }

  Future<void> deleteFournisseur(String id) async {
    await _db.from('stock_fournisseurs').delete().eq('id', id);
    await _changed(stockAussi: false);
  }

  // ---------------- achats

  Future<List<Achat>> achats({String? fournisseurId, DateTime? from, DateTime? to}) async {
    var q = _db.from('stock_achats_etat').select();
    if (fournisseurId != null) q = q.eq('fournisseur_id', fournisseurId);
    if (from != null) q = q.gte('date_achat', dateKey(from));
    if (to != null) q = q.lte('date_achat', dateKey(to));
    final rows = await q.order('date_achat', ascending: false).order('created_at', ascending: false).limit(1000);
    return rows.map(Achat.fromMap).toList();
  }

  Future<List<AchatLigne>> achatLignes(String id) async {
    final rows = await _db.from('stock_achat_lignes').select().eq('achat_id', id);
    return rows.map(AchatLigne.fromMap).toList();
  }

  Future<String> creerAchat({
    String? fournisseurId,
    required DateTime date,
    required List<LigneAchat> lignes,
    double paiement = 0,
    String mode = 'especes',
    String? note,
  }) async {
    final r = await _db.rpc('stock_creer_achat', params: {
      'p_fournisseur': fournisseurId,
      'p_date': dateKey(date),
      'p_lignes': [for (final l in lignes) {'matiere_id': l.matiere.id, 'quantite': l.quantite, 'prix': l.prix}],
      'p_paiement': paiement,
      'p_mode': mode,
      'p_note': note,
    });
    await _changed();
    return r as String;
  }

  Future<List<PaiementFournisseur>> paiementsFournisseur({String? fournisseurId, String? achatId}) async {
    var q = _db.from('stock_paiements_fournisseurs').select();
    if (fournisseurId != null) q = q.eq('fournisseur_id', fournisseurId);
    if (achatId != null) q = q.eq('achat_id', achatId);
    final rows = await q.order('date_paiement', ascending: false).limit(1000);
    return rows.map(PaiementFournisseur.fromMap).toList();
  }

  Future<void> savePaiementFournisseur({
    required String fournisseurId,
    String? achatId,
    required DateTime date,
    required double montant,
    String mode = 'especes',
    String? note,
  }) async {
    await _db.from('stock_paiements_fournisseurs').insert({
      'fournisseur_id': fournisseurId,
      'achat_id': achatId,
      'date_paiement': dateKey(date),
      'montant': montant,
      'mode': mode,
      'note': _ne(note),
    });
    await _changed(stockAussi: false);
  }

  Future<void> deletePaiementFournisseur(String id) async {
    await _db.from('stock_paiements_fournisseurs').delete().eq('id', id);
    await _changed(stockAussi: false);
  }

  // ---------------- nomenclature & fabrication

  Future<List<NomenclatureLigne>> nomenclature(String produitId) async {
    final rows = await _db.from('stock_nomenclature').select().eq('produit_id', produitId);
    return rows.map(NomenclatureLigne.fromMap).toList();
  }

  Future<void> setNomenclature(String produitId, String matiereId, double? quantite) async {
    if (quantite == null || quantite <= 0) {
      await _db.from('stock_nomenclature').delete().eq('produit_id', produitId).eq('matiere_id', matiereId);
    } else {
      await _db.from('stock_nomenclature').upsert({'produit_id': produitId, 'matiere_id': matiereId, 'quantite': quantite}, onConflict: 'produit_id,matiere_id');
    }
    await stock.changed();
  }

  Future<void> fabrication(String produitId, int quantite, {String? note}) async {
    await _db.rpc('stock_fabrication', params: {'p_produit': produitId, 'p_quantite': quantite, 'p_note': note});
    await _changed();
  }
}

final commerce = CommerceData.instance;
