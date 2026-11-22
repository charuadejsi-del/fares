import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n.dart';
import '../utils.dart' show masquerMontants;

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String? _s(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

/// Les espaces de l'application.
enum Espace { broderie, paie, stock, coupe, applique, finition }

extension EspaceX on Espace {
  String get label => switch (this) {
        Espace.broderie => 'Broderie'.tr,
        Espace.paie => 'Paie & avances'.tr,
        Espace.stock => 'Stock & ventes'.tr,
        Espace.coupe => 'Coupe'.tr,
        Espace.applique => 'Appliqué'.tr,
        Espace.finition => 'Finition'.tr,
      };
}

/// Informations de l'entreprise (en-tête des factures).
class Atelier {
  final String id;
  final String nom;
  final String? activite;
  final String? adresse;
  final String? telephone;
  final String? email;
  final String? rc;
  final String? nif;
  final String? nis;
  final String? art;
  final String? rib;
  final double tva;
  final String? mentions;
  final String? logoPath;
  final String? qrLien;
  final String? qrLibelle;
  final bool vitrineActive;
  final bool vitrinePrix;
  final String? vitrineUrl;
  final String? vitrineSlogan;
  final String? logoPublic;
  final String? whatsapp;

  /// Délai normal (jours) passé dans chaque atelier avant d'être signalé en retard.
  final Map<String, int> delais;

  /// Plateforme Warchati : code de connexion, abonnement.
  final String? code;
  final String abonnement;
  final DateTime? abonnementFin;
  final bool suspendu;

  bool get illimite => abonnement == 'illimite' || abonnementFin == null;
  int? get joursRestants => illimite ? null : DateTime(abonnementFin!.year, abonnementFin!.month, abonnementFin!.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
  /// Abonnement valide : sinon l'atelier est en lecture seule.
  bool get actif => !suspendu && (illimite || joursRestants! >= 0);

  static const delaisParDefaut = {'coupe': 3, 'broderie': 10, 'applique': 5, 'akkach': 5, 'couture': 15, 'finition': 5};

  const Atelier({
    required this.id,
    required this.nom,
    this.activite,
    this.adresse,
    this.telephone,
    this.email,
    this.rc,
    this.nif,
    this.nis,
    this.art,
    this.rib,
    this.tva = 0,
    this.mentions,
    this.logoPath,
    this.qrLien,
    this.qrLibelle,
    this.vitrineActive = true,
    this.vitrinePrix = false,
    this.vitrineUrl,
    this.vitrineSlogan,
    this.logoPublic,
    this.whatsapp,
    this.delais = delaisParDefaut,
    this.code,
    this.abonnement = 'illimite',
    this.abonnementFin,
    this.suspendu = false,
  });

  factory Atelier.fromMap(Map<String, dynamic> m) => Atelier(
        id: m['id'] as String,
        nom: (m['nom'] ?? 'Mon atelier') as String,
        activite: _s(m['activite']),
        adresse: _s(m['adresse']),
        telephone: _s(m['telephone']),
        email: _s(m['email']),
        rc: _s(m['rc']),
        nif: _s(m['nif']),
        nis: _s(m['nis']),
        art: _s(m['art']),
        rib: _s(m['rib']),
        tva: _d(m['tva']),
        mentions: _s(m['mentions']),
        logoPath: _s(m['logo_path']),
        qrLien: _s(m['qr_lien']),
        qrLibelle: _s(m['qr_libelle']),
        vitrineActive: (m['vitrine_active'] ?? true) as bool,
        vitrinePrix: (m['vitrine_prix'] ?? false) as bool,
        vitrineUrl: _s(m['vitrine_url']),
        vitrineSlogan: _s(m['vitrine_slogan']),
        logoPublic: _s(m['logo_public']),
        whatsapp: _s(m['whatsapp']),
        code: _s(m['code']),
        abonnement: (m['abonnement'] ?? 'illimite') as String,
        abonnementFin: m['abonnement_fin'] == null ? null : DateTime.parse(m['abonnement_fin'] as String),
        suspendu: (m['suspendu'] ?? false) as bool,
        delais: {
          ...delaisParDefaut,
          for (final e in ((m['delais'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt(),
        },
      );
}

/// Un compte de l'atelier (administrateur ou employé).
class Membre {
  final String userId;
  final String atelierId;
  final String nom;
  final String? identifiant;
  final bool admin;
  final bool broderie;
  final bool paie;
  final bool stock;
  final bool coupe;
  final bool applique;
  final bool finition;
  final bool actif;

  const Membre({
    required this.userId,
    required this.atelierId,
    required this.nom,
    this.identifiant,
    this.admin = false,
    this.broderie = false,
    this.paie = false,
    this.stock = false,
    this.coupe = false,
    this.applique = false,
    this.finition = false,
    this.actif = true,
  });

  factory Membre.fromMap(Map<String, dynamic> m) => Membre(
        userId: m['user_id'] as String,
        atelierId: m['atelier_id'] as String,
        nom: (m['nom'] ?? '') as String,
        identifiant: _s(m['identifiant']),
        admin: m['role'] == 'admin',
        broderie: (m['perm_broderie'] ?? false) as bool,
        paie: (m['perm_paie'] ?? false) as bool,
        stock: (m['perm_stock'] ?? false) as bool,
        coupe: (m['perm_coupe'] ?? false) as bool,
        applique: (m['perm_applique'] ?? false) as bool,
        finition: (m['perm_finition'] ?? false) as bool,
        actif: (m['actif'] ?? true) as bool,
      );

  bool peut(Espace e) =>
      admin ||
      switch (e) {
        Espace.broderie => broderie,
        Espace.paie => paie,
        Espace.stock => stock,
        Espace.coupe => coupe,
        Espace.applique => applique,
        Espace.finition => finition,
      };

  /// Seuls l'administrateur et le comptable (paie) voient les prix et montants.
  bool get voitPrix => admin || paie;

  String get droitsTexte {
    if (admin) return 'Administrateur · accès complet';
    final l = [
      if (coupe) 'Coupe'.tr,
      if (broderie) 'Broderie'.tr,
      if (applique) 'Appliqué'.tr,
      if (finition) 'Finition'.tr,
      if (paie) 'Comptabilité'.tr,
      if (stock) 'Stock & ventes'.tr,
    ];
    return l.isEmpty ? 'Aucun accès' : l.join(' · ');
  }

  /// Identifiant affiché (sans le domaine technique).
  String get identifiantCourt => (identifiant ?? '').replaceAll('@$domaineEmployes', '');
}

const domaineEmployes = 'atelier-broderie.app';

/// Transforme un identifiant d'employé (et le code de son atelier) en adresse de connexion.
String emailDeConnexion(String saisie, [String? codeAtelier]) {
  final s = saisie.trim().toLowerCase();
  if (s.contains('@')) return s;
  final c = (codeAtelier ?? '').trim().toLowerCase();
  return c.isEmpty ? '$s@$domaineEmployes' : '$s.$c@$domaineEmployes';
}

/// Session : compte connecté, son atelier et ses droits.
class AtelierSession extends ChangeNotifier {
  AtelierSession._();
  static final AtelierSession instance = AtelierSession._();

  SupabaseClient get _db => Supabase.instance.client;

  Membre? membre;
  Atelier? atelier;
  bool loaded = false;

  /// Propriétaire de la plateforme Warchati (gère les ateliers clients et les abonnements).
  bool proprietaire = false;

  /// Compte connecté sans atelier : il doit l'activer avec un code.
  bool sansAtelier = false;

  bool get admin => membre?.admin ?? false;
  bool peut(Espace e) => membre?.peut(e) ?? false;
  bool get voitPrix => membre?.voitPrix ?? false;

  /// Responsable d'au moins un atelier de production.
  bool get production => admin || [Espace.coupe, Espace.broderie, Espace.applique, Espace.finition, Espace.paie].any(peut);
  String? get atelierId => membre?.atelierId;

  Future<void> load() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final row = await _db.from('atelier_membres').select().eq('user_id', uid).maybeSingle();
    sansAtelier = row == null;
    membre = row == null ? null : Membre.fromMap(row);
    if (membre != null && membre!.actif) {
      final a = await _db.from('ateliers').select().eq('id', membre!.atelierId).maybeSingle();
      atelier = a == null ? Atelier(id: membre!.atelierId, nom: 'Mon atelier') : Atelier.fromMap(a);
    }
    masquerMontants = !voitPrix;
    try {
      proprietaire = membre != null && (await _db.rpc('est_proprietaire')) == true;
    } catch (_) {
      proprietaire = false;
    }
    loaded = true;
    notifyListeners();
  }

  /// Crée l'atelier du compte connecté avec un code d'activation fourni par Warchati.
  Future<void> activer({required String nom, required String code, required String activation}) async {
    await _db.rpc('atelier_activer', params: {'p_nom': nom, 'p_code': code, 'p_activation': activation});
    await load();
  }

  void clear() {
    proprietaire = false;
    sansAtelier = false;
    membre = null;
    atelier = null;
    loaded = false;
  }

  Future<void> saveAtelier(Map<String, dynamic> row) async {
    await _db.from('ateliers').update(row).eq('id', atelierId!);
    final a = await _db.from('ateliers').select().eq('id', atelierId!).single();
    atelier = Atelier.fromMap(a);
    notifyListeners();
  }

  // ---------------- Employés (via la fonction serveur)

  Future<List<Membre>> membres() async {
    final rows = await _db.from('atelier_membres').select().eq('atelier_id', atelierId!).order('created_at');
    return rows.map(Membre.fromMap).toList();
  }

  Future<void> employe(Map<String, dynamic> body) async {
    try {
      final res = await _db.functions.invoke('atelier-employes', body: body);
      final data = res.data;
      if (data is Map && data['error'] != null) throw Exception(data['error']);
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['error'] != null) throw Exception(d['error']);
      throw Exception(e.reasonPhrase ?? 'Erreur du serveur (${e.status})');
    }
  }
}

final session = AtelierSession.instance;
