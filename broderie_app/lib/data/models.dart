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

class Ouvrier {
  final String id;
  final String nom;
  final String? telephone;
  final double tarif1000;
  final bool actif;

  const Ouvrier({required this.id, required this.nom, this.telephone, this.tarif1000 = 0, this.actif = true});

  factory Ouvrier.fromMap(Map<String, dynamic> m) => Ouvrier(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        telephone: m['telephone'] as String?,
        tarif1000: _toD(m['tarif_1000']),
        actif: (m['actif'] ?? true) as bool,
      );

  static Map<String, dynamic> toRow({required String nom, String? telephone, double tarif1000 = 0, bool actif = true}) => {
        'nom': nom.trim(),
        'telephone': _nullIfEmpty(telephone),
        'tarif_1000': tarif1000,
        'actif': actif,
      };
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
