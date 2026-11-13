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

  const Dessin({required this.id, required this.nom, required this.points, this.client, this.note, this.actif = true});

  factory Dessin.fromMap(Map<String, dynamic> m) => Dessin(
        id: m['id'] as String,
        nom: (m['nom'] ?? '') as String,
        points: _toI(m['points']),
        client: m['client'] as String?,
        note: m['note'] as String?,
        actif: (m['actif'] ?? true) as bool,
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

class Production {
  final String id;
  final DateTime dateProd;
  final String ouvrierId;
  final String dessinId;
  final String? machineId;
  final int nbRobes;
  final int pointsParRobe;
  final double tarif1000;
  final int totalPoints;
  final double montant;
  final String? note;
  final DateTime createdAt;

  const Production({
    required this.id,
    required this.dateProd,
    required this.ouvrierId,
    required this.dessinId,
    this.machineId,
    required this.nbRobes,
    required this.pointsParRobe,
    required this.tarif1000,
    required this.totalPoints,
    required this.montant,
    this.note,
    required this.createdAt,
  });

  factory Production.fromMap(Map<String, dynamic> m) => Production(
        id: m['id'] as String,
        dateProd: DateTime.parse(m['date_prod'] as String),
        ouvrierId: m['ouvrier_id'] as String,
        dessinId: m['dessin_id'] as String,
        machineId: m['machine_id'] as String?,
        nbRobes: _toI(m['nb_robes']),
        pointsParRobe: _toI(m['points_par_robe']),
        tarif1000: _toD(m['tarif_1000']),
        totalPoints: _toI(m['total_points']),
        montant: _toD(m['montant']),
        note: m['note'] as String?,
        createdAt: DateTime.tryParse((m['created_at'] ?? '') as String) ?? DateTime.now(),
      );

  static Map<String, dynamic> toRow({
    required String dateKey,
    required String ouvrierId,
    required String dessinId,
    String? machineId,
    required int nbRobes,
    required int pointsParRobe,
    required double tarif1000,
    String? note,
  }) =>
      {
        'date_prod': dateKey,
        'ouvrier_id': ouvrierId,
        'dessin_id': dessinId,
        'machine_id': machineId,
        'nb_robes': nbRobes,
        'points_par_robe': pointsParRobe,
        'tarif_1000': tarif1000,
        'note': _nullIfEmpty(note),
      };
}
