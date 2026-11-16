import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils.dart';
import 'app_data.dart';
import 'models.dart';
import '../i18n.dart';

double _d(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

/// Une ligne de la clôture de paie : la situation d'un ouvrier pour le mois.
class LignePaie {
  final String ouvrierId;
  final String nom;
  final String departement;
  final String mode;
  final double anterieur;
  final double broderie;
  final double pieces;
  final double salaires;
  final double primes;
  final double avances;
  final double paiements;
  final double retenues;

  /// Paiement du net enregistré au moment de la clôture.
  final double paye;

  const LignePaie({
    required this.ouvrierId,
    required this.nom,
    this.departement = '',
    this.mode = '',
    this.anterieur = 0,
    this.broderie = 0,
    this.pieces = 0,
    this.salaires = 0,
    this.primes = 0,
    this.avances = 0,
    this.paiements = 0,
    this.retenues = 0,
    this.paye = 0,
  });

  double get gains => broderie + pieces + salaires + primes;
  double get deductions => avances + paiements + retenues;

  /// Net à payer avant le paiement de clôture (report compris).
  double get net => anterieur + gains - deductions;
  double get reste => net - paye;

  LignePaie copyWith({double? salaires, double? paye}) => LignePaie(
        ouvrierId: ouvrierId,
        nom: nom,
        departement: departement,
        mode: mode,
        anterieur: anterieur,
        broderie: broderie,
        pieces: pieces,
        salaires: salaires ?? this.salaires,
        primes: primes,
        avances: avances,
        paiements: paiements,
        retenues: retenues,
        paye: paye ?? this.paye,
      );

  Map<String, dynamic> toJson() => {
        'ouvrier_id': ouvrierId,
        'nom': nom,
        'departement': departement,
        'mode': mode,
        'anterieur': anterieur,
        'broderie': broderie,
        'pieces': pieces,
        'salaires': salaires,
        'primes': primes,
        'avances': avances,
        'paiements': paiements,
        'retenues': retenues,
        'paye': paye,
      };

  factory LignePaie.fromJson(Map<String, dynamic> m) => LignePaie(
        ouvrierId: '${m['ouvrier_id']}',
        nom: '${m['nom'] ?? ''}',
        departement: '${m['departement'] ?? ''}',
        mode: '${m['mode'] ?? ''}',
        anterieur: _d(m['anterieur']),
        broderie: _d(m['broderie']),
        pieces: _d(m['pieces']),
        salaires: _d(m['salaires']),
        primes: _d(m['primes']),
        avances: _d(m['avances']),
        paiements: _d(m['paiements']),
        retenues: _d(m['retenues']),
        paye: _d(m['paye']),
      );
}

class Cloture {
  final String id;
  final DateTime mois;
  final List<LignePaie> lignes;
  final DateTime creeLe;

  const Cloture({required this.id, required this.mois, required this.lignes, required this.creeLe});

  factory Cloture.fromMap(Map<String, dynamic> m) => Cloture(
        id: m['id'] as String,
        mois: DateTime.parse(m['mois'] as String),
        lignes: [for (final x in (m['detail'] as List? ?? const [])) LignePaie.fromJson(Map<String, dynamic>.from(x as Map))],
        creeLe: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// Une entrée du journal des actions.
class ActionJournal {
  final int id;
  final String? userNom;
  final String table;
  final String action;
  final String? libelle;
  final double? montant;
  final Map<String, dynamic>? changements;
  final DateTime date;

  const ActionJournal({
    required this.id,
    required this.userNom,
    required this.table,
    required this.action,
    required this.libelle,
    required this.montant,
    required this.changements,
    required this.date,
  });

  factory ActionJournal.fromMap(Map<String, dynamic> m) => ActionJournal(
        id: (m['id'] as num).toInt(),
        userNom: m['user_nom'] as String?,
        table: m['table_nom'] as String,
        action: m['action'] as String,
        libelle: m['libelle'] as String?,
        montant: m['montant'] == null ? null : _d(m['montant']),
        changements: m['changements'] == null ? null : Map<String, dynamic>.from(m['changements'] as Map),
        date: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

/// Noms lisibles des tables suivies par le journal, regroupés par espace.
Map<String, (String, String)> get tablesJournal => <String, (String, String)>{
  'ateliers': ('Paramètres de l\'entreprise'.tr, 'Paramètres'.tr),
  'atelier_membres': ('Compte utilisateur'.tr, 'Paramètres'.tr),
  'broderie_types': ('Type de travail'.tr, 'Paramètres'.tr),
  'broderie_ouvriers': ('Ouvrier'.tr, 'Ouvriers & paie'.tr),
  'broderie_pieces': ('Travail à la pièce'.tr, 'Ouvriers & paie'.tr),
  'broderie_mouvements': ('Avance / paiement ouvrier'.tr, 'Ouvriers & paie'.tr),
  'paie_clotures': ('Clôture de paie'.tr, 'Ouvriers & paie'.tr),
  'broderie_dessins': ('Dessin'.tr, 'Broderie'.tr),
  'broderie_machines': ('Machine'.tr, 'Broderie'.tr),
  'broderie_production': ('Production broderie'.tr, 'Broderie'.tr),
  'stock_produits': ('Article (robe)'.tr, 'Stock & ventes'.tr),
  'stock_mouvements': ('Mouvement de stock manuel'.tr, 'Stock & ventes'.tr),
  'stock_clients': ('Client'.tr, 'Stock & ventes'.tr),
  'stock_ventes': ('Vente / facture'.tr, 'Stock & ventes'.tr),
  'stock_versements': ('Versement client'.tr, 'Stock & ventes'.tr),
  'stock_commandes': ('Commande / devis'.tr, 'Stock & ventes'.tr),
  'stock_avoirs': ('Avoir'.tr, 'Stock & ventes'.tr),
  'stock_prix_clients': ('Prix spécial client'.tr, 'Stock & ventes'.tr),
  'stock_achats': ('Achat'.tr, 'Achats'.tr),
  'stock_fournisseurs': ('Fournisseur'.tr, 'Achats'.tr),
  'stock_matieres': ('Matière'.tr, 'Achats'.tr),
  'stock_matiere_mvts': ('Mouvement de matière'.tr, 'Achats'.tr),
  'stock_paiements_fournisseurs': ('Paiement fournisseur'.tr, 'Achats'.tr),
};

class Gestion {
  Gestion._();
  static final instance = Gestion._();
  SupabaseClient get _db => Supabase.instance.client;

  static DateTime debutMois(DateTime m) => DateTime(m.year, m.month);
  static DateTime finMois(DateTime m) => DateTime(m.year, m.month + 1, 0);

  Future<Cloture?> cloture(DateTime mois) async {
    final row = await _db.from('paie_clotures').select().eq('mois', dateKey(debutMois(mois))).maybeSingle();
    return row == null ? null : Cloture.fromMap(row);
  }

  Future<List<Cloture>> clotures() async {
    final rows = await _db.from('paie_clotures').select().order('mois', ascending: false).limit(24);
    return [for (final r in rows) Cloture.fromMap(r)];
  }

  /// Prépare la paie du mois pour tous les ouvriers actifs (ou ayant un mouvement).
  /// Renvoie aussi les ouvriers « au mois » dont le salaire n'est pas encore saisi.
  Future<(List<LignePaie>, Set<String>)> preparer(DateTime mois) async {
    final from = debutMois(mois), to = finMois(mois);
    final mvts = await data.fetchMouvements(from, to);
    final salariesFaits = {for (final m in mvts.where((m) => m.type == TypeMvt.salaire)) m.ouvrierId};
    final lignes = <LignePaie>[];
    final sansSalaire = <String>{};
    final ouvriers = [...data.ouvriers]..sort((a, b) => a.nom.compareTo(b.nom));
    final bilans = await Future.wait([for (final o in ouvriers) data.bilan(o.id, from, to)]);
    for (var i = 0; i < ouvriers.length; i++) {
      final o = ouvriers[i], b = bilans[i];
      final actif = b.gains != 0 || b.deductions != 0 || b.anterieur != 0;
      if (!o.actif && !actif) continue;
      if (o.modePaie == ModePaie.mois && o.salaireMensuel > 0 && !salariesFaits.contains(o.id)) sansSalaire.add(o.id);
      if (!actif && !sansSalaire.contains(o.id)) continue;
      lignes.add(LignePaie(
        ouvrierId: o.id,
        nom: o.nom,
        departement: o.departement,
        mode: o.modePaie.name,
        anterieur: b.anterieur,
        broderie: b.broderie,
        pieces: b.pieces,
        salaires: b.salaires,
        primes: b.primes,
        avances: b.avances,
        paiements: b.paiements,
        retenues: b.retenues,
      ));
    }
    return (lignes, sansSalaire);
  }

  /// Enregistre les salaires et paiements choisis, puis verrouille le mois.
  Future<Cloture> cloturer(DateTime mois, List<LignePaie> lignes, {required Map<String, double> salairesAjoutes}) async {
    final fin = dateKey(finMois(mois));
    final libMois = fmtMonthYear(mois);
    final rows = <Map<String, dynamic>>[
      for (final e in salairesAjoutes.entries)
        Mouvement.toRow(ouvrierId: e.key, dateKey: fin, type: TypeMvt.salaire, montant: e.value, note: 'Salaire {0} (clôture)'.trf([libMois])),
      for (final l in lignes.where((l) => l.paye > 0))
        Mouvement.toRow(ouvrierId: l.ouvrierId, dateKey: fin, type: TypeMvt.paiement, montant: l.paye, note: 'Paie {0} (clôture)'.trf([libMois])),
    ];
    if (rows.isNotEmpty) await _db.from('broderie_mouvements').insert(rows);
    final gains = lignes.fold<double>(0, (s, l) => s + l.gains);
    final ded = lignes.fold<double>(0, (s, l) => s + l.deductions);
    final net = lignes.fold<double>(0, (s, l) => s + l.net);
    final row = await _db
        .from('paie_clotures')
        .insert({
          'mois': dateKey(debutMois(mois)),
          'nb_ouvriers': lignes.length,
          'total_gains': gains,
          'total_deductions': ded,
          'total_net': net,
          'detail': [for (final l in lignes) l.toJson()],
        })
        .select()
        .single();
    await data.refreshSoldes();
    return Cloture.fromMap(row);
  }

  /// Réouvre un mois (administrateur). Les salaires et paiements de clôture restent enregistrés.
  Future<void> reouvrir(Cloture c) async {
    await _db.from('paie_clotures').delete().eq('id', c.id);
  }

  Future<List<ActionJournal>> journal({
    int offset = 0,
    int limit = 60,
    String? utilisateur,
    List<String>? tables,
    String? action,
    DateTime? depuis,
  }) async {
    var q = _db.from('journal_actions').select();
    if (utilisateur != null) q = q.eq('user_nom', utilisateur);
    if (tables != null) q = q.inFilter('table_nom', tables);
    if (action != null) q = q.eq('action', action);
    if (depuis != null) q = q.gte('created_at', depuis.toUtc().toIso8601String());
    final rows = await q.order('created_at', ascending: false).range(offset, offset + limit - 1);
    return [for (final r in rows) ActionJournal.fromMap(r)];
  }

  Future<List<String>> utilisateursJournal() async {
    final rows = await _db.from('journal_actions').select('user_nom').order('created_at', ascending: false).limit(500);
    return {for (final r in rows) if (r['user_nom'] != null) r['user_nom'] as String}.toList()..sort();
  }
}

final gestion = Gestion.instance;
