import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../i18n.dart';

double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);
String? _s(dynamic v) => (v == null || v.toString().trim().isEmpty) ? null : v.toString().trim();

/// Les espaces de l'application.
enum Espace { broderie, paie, stock }

extension EspaceX on Espace {
  String get label => switch (this) {
        Espace.broderie => 'Broderie'.tr,
        Espace.paie => 'Paie & avances'.tr,
        Espace.stock => 'Stock & ventes'.tr,
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
        actif: (m['actif'] ?? true) as bool,
      );

  bool peut(Espace e) =>
      admin ||
      switch (e) {
        Espace.broderie => broderie,
        Espace.paie => paie,
        Espace.stock => stock,
      };

  String get droitsTexte {
    if (admin) return 'Administrateur · accès complet';
    final l = [if (broderie) 'Broderie', if (paie) 'Paie & avances', if (stock) 'Stock & ventes'];
    return l.isEmpty ? 'Aucun accès' : l.join(' · ');
  }

  /// Identifiant affiché (sans le domaine technique).
  String get identifiantCourt => (identifiant ?? '').replaceAll('@$domaineEmployes', '');
}

const domaineEmployes = 'atelier-broderie.app';

/// Transforme un identifiant d'employé en adresse de connexion.
String emailDeConnexion(String saisie) {
  final s = saisie.trim().toLowerCase();
  return s.contains('@') ? s : '$s@$domaineEmployes';
}

/// Session : compte connecté, son atelier et ses droits.
class AtelierSession extends ChangeNotifier {
  AtelierSession._();
  static final AtelierSession instance = AtelierSession._();

  SupabaseClient get _db => Supabase.instance.client;

  Membre? membre;
  Atelier? atelier;
  bool loaded = false;

  bool get admin => membre?.admin ?? false;
  bool peut(Espace e) => membre?.peut(e) ?? false;
  String? get atelierId => membre?.atelierId;

  Future<void> load() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    var row = await _db.from('atelier_membres').select().eq('user_id', uid).maybeSingle();
    if (row == null) {
      // Nouveau compte : il crée son atelier et en devient l'administrateur
      await _db.rpc('atelier_initialiser');
      row = await _db.from('atelier_membres').select().eq('user_id', uid).maybeSingle();
    }
    membre = row == null ? null : Membre.fromMap(row);
    if (membre != null && membre!.actif) {
      final a = await _db.from('ateliers').select().eq('id', membre!.atelierId).maybeSingle();
      atelier = a == null ? Atelier(id: membre!.atelierId, nom: 'Mon atelier') : Atelier.fromMap(a);
    }
    loaded = true;
    notifyListeners();
  }

  void clear() {
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
