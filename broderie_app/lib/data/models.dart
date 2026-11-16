double _toD(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int _toI(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String? _nullIfEmpty(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// Mode de paie d'un ouvrier.
enum ModePaie { points, mois, piece }

extension ModePaieX on ModePaie {
  String get label => switch (this) {
        ModePaie.points => 'Points broderie',
        ModePaie.mois => 'Au mois',
        ModePaie.piece => 'À la pièce',
      };
  static ModePaie parse(String? s) => ModePaie.values.firstWhere((m) => m.name == s, orElse: () => ModePaie.points);
}

class Ouvrier {
  final String id;
  final String nom;
  final String? telephone;
  final double tarif1000;
  final bool actif;
  final String departement;
  final ModePaie modePaie;
  final double salaireMensuel;
  final double prixPiece;

  const Ouvrier({
    required this.id,
    required this.nom,
    this.telephone,
    this.tarif1000 = 0,
    this.actif = true,
    this.departement = 'Broderie',
    this.modePaie = ModePaie.points,
    this.salaireMensuel = 0,
    this.prixPiece = 0,
  });

  bool get brodeur => modePaie == ModePaie.points;

  /// Travaille sur la machine de broderie : payé aux points, ou au mois / à la pièce
  /// dans le département Broderie (ses points sont comptés sans montant).
  bool get enBroderie => brodeur || departement.toLowerCase() == 'broderie';

  /// Tarif appliqué à ses points : 0 s'il n'est pas payé aux points.
  double tarifPour(double tarifType) => brodeur ? tarifType : 0;

  factory Ouvrier.fromMap(Map<String, dynamic> m) => Ouvrier(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        telephone: m['telephone'] as String?,
        tarif1000: _toD(m['tarif_1000']),
        actif: (m['actif'] ?? true) as bool,
        departement: ((m['departement'] ?? 'Broderie') as String).trim().isEmpty ? 'Broderie' : (m['departement'] as String).trim(),
        modePaie: ModePaieX.parse(m['mode_paie'] as String?),
        salaireMensuel: _toD(m['salaire_mensuel']),
        prixPiece: _toD(m['prix_piece']),
      );

  static Map<String, dynamic> toRow({
    required String nom,
    String? telephone,
    double tarif1000 = 0,
    bool actif = true,
    String departement = 'Broderie',
    ModePaie modePaie = ModePaie.points,
    double salaireMensuel = 0,
    double prixPiece = 0,
  }) =>
      {
        'nom': nom.trim(),
        'telephone': _nullIfEmpty(telephone),
        'tarif_1000': tarif1000,
        'actif': actif,
        'departement': departement.trim().isEmpty ? 'Broderie' : departement.trim(),
        'mode_paie': modePaie.name,
        'salaire_mensuel': salaireMensuel,
        'prix_piece': prixPiece,
      };
}

/// Travail payé à la pièce.
class Piece {
  final String id;
  final String ouvrierId;
  final DateTime date;
  final String libelle;
  final double quantite;
  final double prixUnitaire;
  final double montant;
  final String? note;
  final String? tacheId;

  const Piece({
    required this.id,
    required this.ouvrierId,
    required this.date,
    required this.libelle,
    required this.quantite,
    required this.prixUnitaire,
    required this.montant,
    this.note,
    this.tacheId,
  });

  factory Piece.fromMap(Map<String, dynamic> m) => Piece(
        id: m['id'] as String,
        ouvrierId: m['ouvrier_id'] as String,
        date: DateTime.parse(m['date_travail'] as String),
        libelle: (m['libelle'] ?? '') as String,
        quantite: _toD(m['quantite']),
        prixUnitaire: _toD(m['prix_unitaire']),
        montant: _toD(m['montant']),
        note: m['note'] as String?,
        tacheId: m['tache_id'] as String?,
      );

  static Map<String, dynamic> toRow({
    required String ouvrierId,
    required String dateKey,
    required String libelle,
    required double quantite,
    required double prixUnitaire,
    String? note,
    String? tacheId,
  }) =>
      {
        'ouvrier_id': ouvrierId,
        'date_travail': dateKey,
        'libelle': libelle.trim(),
        'quantite': quantite,
        'prix_unitaire': prixUnitaire,
        'note': _nullIfEmpty(note),
        if (tacheId != null) 'tache_id': tacheId,
      };
}

/// Tâche d'atelier hors broderie (couture, coupe, repassage…) avec son tarif à la pièce.
class Tache {
  final String id;
  final String nom;
  final String departement;
  final double prix;
  final int ordre;
  final bool actif;

  const Tache({required this.id, required this.nom, required this.departement, this.prix = 0, this.ordre = 0, this.actif = true});

  factory Tache.fromMap(Map<String, dynamic> m) => Tache(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        departement: (m['departement'] ?? '') as String,
        prix: _toD(m['prix']),
        ordre: _toI(m['ordre']),
        actif: (m['actif'] ?? true) as bool,
      );

  static Map<String, dynamic> toRow({required String nom, required String departement, required double prix, int ordre = 0, bool actif = true}) => {
        'nom': nom.trim(),
        'departement': departement.trim(),
        'prix': prix,
        'ordre': ordre,
        'actif': actif,
      };
}

/// Types de mouvements d'argent.
enum TypeMvt { avance, paiement, salaire, prime, retenue }

extension TypeMvtX on TypeMvt {
  String get label => switch (this) {
        TypeMvt.avance => 'Avance',
        TypeMvt.paiement => 'Paiement',
        TypeMvt.salaire => 'Salaire',
        TypeMvt.prime => 'Prime',
        TypeMvt.retenue => 'Retenue',
      };

  /// +1 : ajoute au montant dû à l'ouvrier ; −1 : le diminue.
  int get signe => (this == TypeMvt.salaire || this == TypeMvt.prime) ? 1 : -1;

  static TypeMvt parse(String? s) => TypeMvt.values.firstWhere((t) => t.name == s, orElse: () => TypeMvt.avance);
}

/// Mouvement d'argent (avance, paiement, salaire, prime, retenue).
class Mouvement {
  final String id;
  final String ouvrierId;
  final DateTime date;
  final TypeMvt type;
  final double montant;
  final String? note;

  const Mouvement({required this.id, required this.ouvrierId, required this.date, required this.type, required this.montant, this.note});

  factory Mouvement.fromMap(Map<String, dynamic> m) => Mouvement(
        id: m['id'] as String,
        ouvrierId: m['ouvrier_id'] as String,
        date: DateTime.parse(m['date_mvt'] as String),
        type: TypeMvtX.parse(m['type'] as String?),
        montant: _toD(m['montant']),
        note: m['note'] as String?,
      );

  static Map<String, dynamic> toRow({
    required String ouvrierId,
    required String dateKey,
    required TypeMvt type,
    required double montant,
    String? note,
  }) =>
      {
        'ouvrier_id': ouvrierId,
        'date_mvt': dateKey,
        'type': type.name,
        'montant': montant,
        'note': _nullIfEmpty(note),
      };
}

/// Solde global d'un ouvrier (toutes dates). solde > 0 : reste à payer ; < 0 : avance non couverte.
class Solde {
  final double gains;
  final double avances;
  final double paiements;
  final double retenues;
  final double solde;
  const Solde({this.gains = 0, this.avances = 0, this.paiements = 0, this.retenues = 0, this.solde = 0});

  factory Solde.fromMap(Map<String, dynamic> m) => Solde(
        gains: _toD(m['gains_broderie']) + _toD(m['gains_pieces']) + _toD(m['salaires']) + _toD(m['primes']),
        avances: _toD(m['avances']),
        paiements: _toD(m['paiements']),
        retenues: _toD(m['retenues']),
        solde: _toD(m['solde']),
      );
}

/// Bilan d'un ouvrier sur une période.
class Bilan {
  final double anterieur;
  final double broderie;
  final double pieces;
  final double salaires;
  final double primes;
  final double avances;
  final double paiements;
  final double retenues;
  final double reste;

  const Bilan({
    this.anterieur = 0,
    this.broderie = 0,
    this.pieces = 0,
    this.salaires = 0,
    this.primes = 0,
    this.avances = 0,
    this.paiements = 0,
    this.retenues = 0,
    this.reste = 0,
  });

  double get gains => broderie + pieces + salaires + primes;
  double get deductions => avances + paiements + retenues;

  factory Bilan.fromMap(Map<String, dynamic> m) => Bilan(
        anterieur: _toD(m['anterieur']),
        broderie: _toD(m['gains_broderie']),
        pieces: _toD(m['gains_pieces']),
        salaires: _toD(m['salaires']),
        primes: _toD(m['primes']),
        avances: _toD(m['avances']),
        paiements: _toD(m['paiements']),
        retenues: _toD(m['retenues']),
        reste: _toD(m['reste']),
      );
}

class Dessin {
  final String id;
  final String nom;
  final int points;
  final String? client;
  final String? note;
  final bool actif;
  final String? photoPath;

  const Dessin({required this.id, required this.nom, required this.points, this.client, this.note, this.actif = true, this.photoPath});

  factory Dessin.fromMap(Map<String, dynamic> m) => Dessin(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        points: _toI(m['points']),
        client: m['client'] as String?,
        note: m['note'] as String?,
        actif: (m['actif'] ?? true) as bool,
        photoPath: m['photo_path'] as String?,
      );

  static Map<String, dynamic> toRow({required String nom, required int points, String? client, String? note, bool actif = true}) => {
        'nom': nom.trim(),
        'points': points,
        'client': _nullIfEmpty(client),
        'note': _nullIfEmpty(note),
        'actif': actif,
      };
}

class Machine {
  final String id;
  final String nom;
  final int nbTetes;
  final bool actif;

  const Machine({required this.id, required this.nom, this.nbTetes = 1, this.actif = true});

  factory Machine.fromMap(Map<String, dynamic> m) => Machine(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        nbTetes: _toI(m['nb_tetes']),
        actif: (m['actif'] ?? true) as bool,
      );

  static Map<String, dynamic> toRow({required String nom, int nbTetes = 1, bool actif = true}) => {
        'nom': nom.trim(),
        'nb_tetes': nbTetes,
        'actif': actif,
      };
}

/// Type de broderie (passé plat, cordon…) avec son tarif pour 1000 points.
class TypeTravail {
  final String id;
  final String nom;
  final double tarif1000;
  final int ordre;
  final bool actif;

  const TypeTravail({required this.id, required this.nom, required this.tarif1000, this.ordre = 0, this.actif = true});

  factory TypeTravail.fromMap(Map<String, dynamic> m) => TypeTravail(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        tarif1000: _toD(m['tarif_1000']),
        ordre: _toI(m['ordre']),
        actif: (m['actif'] ?? true) as bool,
      );

  static Map<String, dynamic> toRow({required String nom, required double tarif1000, int ordre = 0, bool actif = true}) => {
        'nom': nom.trim(),
        'tarif_1000': tarif1000,
        'ordre': ordre,
        'actif': actif,
      };
}

/// Équipe de travail.
enum Equipe { jour, nuit }

extension EquipeX on Equipe {
  String get label => this == Equipe.jour ? 'Jour' : 'Nuit';
  String get horaire => this == Equipe.jour ? '8 h – 20 h' : '20 h – 8 h';
  static Equipe parse(String? s) => s == 'nuit' ? Equipe.nuit : Equipe.jour;
}

/// Une saisie = un relevé du compteur de points pour un ouvrier, une équipe, un type de broderie.
class Production {
  final String id;
  final DateTime dateProd;
  final Equipe equipe;
  final String ouvrierId;
  final String? typeId;
  final String? machineId;
  final String? dessinId;
  final int? nbRobes;
  final int totalPoints;
  final double tarif1000;
  final double montant;
  final String? note;
  final DateTime createdAt;

  const Production({
    required this.id,
    required this.dateProd,
    required this.equipe,
    required this.ouvrierId,
    this.typeId,
    this.machineId,
    this.dessinId,
    this.nbRobes,
    required this.totalPoints,
    required this.tarif1000,
    required this.montant,
    this.note,
    required this.createdAt,
  });

  factory Production.fromMap(Map<String, dynamic> m) => Production(
        id: m['id'] as String,
        dateProd: DateTime.parse(m['date_prod'] as String),
        equipe: EquipeX.parse(m['equipe'] as String?),
        ouvrierId: m['ouvrier_id'] as String,
        typeId: m['type_id'] as String?,
        machineId: m['machine_id'] as String?,
        dessinId: m['dessin_id'] as String?,
        nbRobes: m['nb_robes'] == null ? null : _toI(m['nb_robes']),
        totalPoints: _toI(m['total_points']),
        tarif1000: _toD(m['tarif_1000']),
        montant: _toD(m['montant']),
        note: m['note'] as String?,
        createdAt: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
      );

  static Map<String, dynamic> toRow({
    required String dateKey,
    required Equipe equipe,
    required String ouvrierId,
    required String typeId,
    String? machineId,
    String? dessinId,
    int? nbRobes,
    required int totalPoints,
    required double tarif1000,
    String? note,
  }) =>
      {
        'date_prod': dateKey,
        'equipe': equipe.name,
        'ouvrier_id': ouvrierId,
        'type_id': typeId,
        'machine_id': machineId,
        'dessin_id': dessinId,
        'nb_robes': (nbRobes == null || nbRobes <= 0) ? null : nbRobes,
        'points_par_robe': null,
        'total_points': totalPoints,
        'tarif_1000': tarif1000,
        'note': _nullIfEmpty(note),
      };
}
