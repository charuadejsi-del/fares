import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n.dart';
import '../utils.dart';
import 'app_data.dart';
import 'models.dart';

int _i(dynamic v) => v == null ? 0 : (v as num).toInt();
double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
DateTime _date(dynamic v) => DateTime.parse(v as String);
String? _vide(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// Atelier de couture externe.
class Couturier {
  final String id;
  final String nom;
  final String? telephone, adresse, note;
  final bool actif;
  const Couturier({required this.id, required this.nom, this.telephone, this.adresse, this.note, this.actif = true});

  factory Couturier.fromMap(Map<String, dynamic> m) => Couturier(
        id: m['id'] as String,
        nom: m['nom'] as String,
        telephone: m['telephone'] as String?,
        adresse: m['adresse'] as String?,
        note: m['note'] as String?,
        actif: (m['actif'] ?? true) as bool,
      );
}

class TarifCouture {
  final String id;
  final String modele;
  final double prix;
  const TarifCouture(this.id, this.modele, this.prix);
}

class RetourCouture {
  final String id, envoiId;
  final DateTime date;
  final int bonnes, retouche, abimees;
  final String? note;
  const RetourCouture({required this.id, required this.envoiId, required this.date, this.bonnes = 0, this.retouche = 0, this.abimees = 0, this.note});

  /// Pièces réellement revenues (les pièces à retoucher repartent chez l'atelier).
  int get rendues => bonnes + abimees;

  factory RetourCouture.fromMap(Map<String, dynamic> m) => RetourCouture(
        id: m['id'] as String,
        envoiId: m['envoi_id'] as String,
        date: _date(m['date_retour']),
        bonnes: _i(m['bonnes']),
        retouche: _i(m['retouche']),
        abimees: _i(m['abimees']),
        note: m['note'] as String?,
      );
}

/// Envoi d'une partie (ou de la totalité) d'un paquet chez un atelier de couture.
class EnvoiCouture {
  final String id, lotId, couturierId;
  final int pieces;
  final double prix;
  final DateTime date;
  final String? note;
  final List<RetourCouture> retours;
  EnvoiCouture({required this.id, required this.lotId, required this.couturierId, required this.pieces, required this.prix, required this.date, this.note, List<RetourCouture>? retours})
      : retours = retours ?? [];

  int get bonnes => retours.fold(0, (s, r) => s + r.bonnes);
  int get abimees => retours.fold(0, (s, r) => s + r.abimees);
  int get retouche => retours.fold(0, (s, r) => s + r.retouche);
  int get rendues => bonnes + abimees;
  int get restant => (pieces - rendues).clamp(0, pieces);
  bool get termine => restant == 0;

  /// Payé uniquement sur les pièces bonnes.
  double get montant => bonnes * prix;
  DateTime? get dernierRetour => retours.isEmpty ? null : retours.map((r) => r.date).reduce((a, b) => a.isAfter(b) ? a : b);
  int get jours => dayOnly(termine ? (dernierRetour ?? DateTime.now()) : DateTime.now()).difference(dayOnly(date)).inDays;

  factory EnvoiCouture.fromMap(Map<String, dynamic> m) => EnvoiCouture(
        id: m['id'] as String,
        lotId: m['lot_id'] as String,
        couturierId: m['couturier_id'] as String,
        pieces: _i(m['pieces']),
        prix: _d(m['prix']),
        date: _date(m['date_envoi']),
        note: m['note'] as String?,
      );
}

class PaiementCouture {
  final String id, couturierId;
  final DateTime date;
  final double montant;
  final String? note;
  const PaiementCouture({required this.id, required this.couturierId, required this.date, required this.montant, this.note});

  factory PaiementCouture.fromMap(Map<String, dynamic> m) => PaiementCouture(
        id: m['id'] as String,
        couturierId: m['couturier_id'] as String,
        date: _date(m['date_paie']),
        montant: _d(m['montant']),
        note: m['note'] as String?,
      );
}

/// Couture externe : ateliers, tarifs par modèle, envois, retours et paiements.
class Couture extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  List<Couturier> ateliers = [];
  List<TarifCouture> tarifs = [];
  List<EnvoiCouture> envois = [];
  List<PaiementCouture> paiements = [];
  bool loaded = false;

  Couturier? atelier(String? id) {
    for (final a in ateliers) {
      if (a.id == id) return a;
    }
    return null;
  }

  String nom(String? id) => atelier(id)?.nom ?? '—';

  double? prixModele(String? modele) {
    if (modele == null) return null;
    for (final t in tarifs) {
      if (t.modele.toLowerCase() == modele.trim().toLowerCase()) return t.prix;
    }
    return null;
  }

  List<EnvoiCouture> envoisDuLot(String lotId) => envois.where((e) => e.lotId == lotId).toList();
  List<EnvoiCouture> envoisDe(String couturierId) => envois.where((e) => e.couturierId == couturierId).toList();
  List<PaiementCouture> paiementsDe(String couturierId) => paiements.where((p) => p.couturierId == couturierId).toList();

  int envoyees(String lotId) => envoisDuLot(lotId).fold(0, (s, e) => s + e.pieces);
  int aEnvoyer(Lot l) => (l.nbPieces - envoyees(l.id)).clamp(0, l.nbPieces);
  int chezAtelier(String couturierId) => envoisDe(couturierId).fold(0, (s, e) => s + e.restant);
  double du(String couturierId) => envoisDe(couturierId).fold(0.0, (s, e) => s + e.montant);
  double paye(String couturierId) => paiementsDe(couturierId).fold(0.0, (s, p) => s + p.montant);
  double solde(String couturierId) => du(couturierId) - paye(couturierId);

  bool _complet = true;

  /// [complet] : tarifs et paiements (réservés au comptable et à l'administrateur).
  Future<void> load({bool? complet}) async {
    if (complet != null) _complet = complet;
    try {
      final vide = Future.value(<Map<String, dynamic>>[]);
      final res = await Future.wait([
        _db.from('couture_ateliers').select().order('nom'),
        _complet ? _db.from('couture_tarifs').select().order('modele') : vide,
        _db.from('couture_envois').select().order('date_envoi', ascending: false).order('created_at', ascending: false).limit(3000),
        _db.from('couture_retours').select().order('date_retour').order('created_at').limit(6000),
        _complet ? _db.from('couture_paiements').select().order('date_paie', ascending: false).limit(3000) : vide,
      ]);
      ateliers = res[0].map(Couturier.fromMap).toList();
      tarifs = [for (final m in res[1]) TarifCouture(m['id'] as String, m['modele'] as String, _d(m['prix']))];
      envois = res[2].map(EnvoiCouture.fromMap).toList();
      final parEnvoi = <String, EnvoiCouture>{for (final e in envois) e.id: e};
      for (final m in res[3]) {
        final r = RetourCouture.fromMap(m);
        parEnvoi[r.envoiId]?.retours.add(r);
      }
      paiements = res[4].map(PaiementCouture.fromMap).toList();
      loaded = true;
    } catch (e) {
      debugPrint('couture.load: $e');
    }
    notifyListeners();
  }

  void reset() {
    ateliers = [];
    tarifs = [];
    envois = [];
    paiements = [];
    loaded = false;
  }

  Future<void> saveAtelier({String? id, required String nom, String? telephone, String? adresse, String? note, bool actif = true}) async {
    final row = {'nom': nom.trim(), 'telephone': _vide(telephone), 'adresse': _vide(adresse), 'note': _vide(note), 'actif': actif};
    id == null ? await _db.from('couture_ateliers').insert(row) : await _db.from('couture_ateliers').update(row).eq('id', id);
    await load();
  }

  Future<void> deleteAtelier(String id) async {
    await _db.from('couture_ateliers').delete().eq('id', id);
    await load();
  }

  Future<void> saveTarif(String modele, double prix) async {
    await _db.from('couture_tarifs').upsert({'modele': modele.trim(), 'prix': prix}, onConflict: 'atelier_id,modele');
    await load();
  }

  Future<void> deleteTarif(String id) async {
    await _db.from('couture_tarifs').delete().eq('id', id);
    await load();
  }

  /// Envoie [pieces] pièces du paquet [l] chez l'atelier [couturierId].
  Future<void> envoyer(Lot l, {required String couturierId, required int pieces, required double prix, required DateTime date, String? note}) async {
    await _db.from('couture_envois').insert({
      'lot_id': l.id,
      'couturier_id': couturierId,
      'pieces': pieces,
      'prix': prix,
      'date_envoi': dateKey(date),
      'note': _vide(note),
    });
    if (l.modele != null && prixModele(l.modele) == null && prix > 0) {
      await _db.from('couture_tarifs').upsert({'modele': l.modele!.trim(), 'prix': prix}, onConflict: 'atelier_id,modele');
    }
    await load();
  }

  Future<void> deleteEnvoi(String id) async {
    await _db.from('couture_envois').delete().eq('id', id);
    await load();
  }

  /// Enregistre un retour. Quand toutes les pièces du paquet sont revenues,
  /// le paquet passe automatiquement à l'étape suivante (finition).
  /// Renvoie l'étape vers laquelle le paquet est parti, le cas échéant.
  Future<String?> retour(EnvoiCouture e, {required DateTime date, int bonnes = 0, int retouche = 0, int abimees = 0, String? note}) async {
    await _db.from('couture_retours').insert({
      'envoi_id': e.id,
      'date_retour': dateKey(date),
      'bonnes': bonnes,
      'retouche': retouche,
      'abimees': abimees,
      'note': _vide(note),
    });
    await load();
    final l = data.lot(e.lotId);
    if (l == null || l.etape != 'couture') return null;
    final env = envoisDuLot(l.id);
    final revenues = env.fold<int>(0, (s, x) => s + x.rendues);
    if (aEnvoyer(l) == 0 && env.every((x) => x.termine) && revenues > 0) {
      final vers = l.suivante ?? 'finition';
      await data.deplacerLot(l, vers, date, note: 'Retour de la couture complet'.tr);
      return vers;
    }
    return null;
  }

  Future<void> deleteRetour(String id) async {
    await _db.from('couture_retours').delete().eq('id', id);
    await load();
  }

  Future<void> payer(String couturierId, {required double montant, required DateTime date, String? note}) async {
    await _db.from('couture_paiements').insert({'couturier_id': couturierId, 'montant': montant, 'date_paie': dateKey(date), 'note': _vide(note)});
    await load();
  }

  Future<void> deletePaiement(String id) async {
    await _db.from('couture_paiements').delete().eq('id', id);
    await load();
  }
}

final couture = Couture();
