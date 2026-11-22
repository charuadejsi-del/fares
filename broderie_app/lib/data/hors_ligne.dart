import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fonctionnement hors ligne de Warchati, au niveau des requêtes réseau :
/// - lectures : la dernière réponse du serveur est gardée sur l'appareil et resservie sans internet ;
/// - écritures : sans internet elles sont mises en file d'attente puis envoyées dans l'ordre au retour du réseau
///   (le dernier enregistrement gagne ; les refus du serveur sont listés) ;
/// - horloge fiable : heure du serveur + temps écoulé ; un recul de l'horloge de l'appareil est détecté ;
/// - durée maximale sans internet selon l'abonnement (essai 3 j, mensuel 15 j, annuel 8 mois).
class HorsLigne extends ChangeNotifier {
  HorsLigne._();
  static final HorsLigne instance = HorsLigne._();

  /// Tables dont l'identifiant (uuid) peut être fabriqué par l'application (création hors ligne).
  static const _tablesUuid = {
    'broderie_dessins', 'broderie_lots', 'broderie_machines', 'broderie_mouvements', 'broderie_ouvriers', 'broderie_pieces',
    'broderie_production', 'broderie_production_lots', 'broderie_types', 'couture_ateliers', 'couture_envois', 'couture_paiements',
    'couture_retours', 'couture_tarifs', 'lot_mouvements', 'paie_clotures', 'stock_achat_lignes', 'stock_achats', 'stock_avoir_lignes',
    'stock_avoirs', 'stock_clients', 'stock_commande_lignes', 'stock_commandes', 'stock_fournisseurs', 'stock_matiere_mvts',
    'stock_matieres', 'stock_modeles_info', 'stock_mouvements', 'stock_nomenclature', 'stock_paiements_fournisseurs',
    'stock_prix_clients', 'stock_produits', 'stock_vente_lignes', 'stock_ventes', 'stock_versements', 'travail_taches',
  };

  /// Fonctions serveur qui ne modifient rien : leur réponse peut être resservie hors ligne.
  static const _rpcLecture = {'est_proprietaire', 'pin_etat', 'atelier_actif', 'vitrine_catalogue', 'vitrine_catalogue_code'};

  /// Durée maximale sans connexion selon le type d'abonnement.
  static const limites = {'essai': Duration(days: 3), 'mensuel': Duration(days: 15), 'annuel': Duration(days: 240)};

  Directory? _dir;
  bool enLigne = true;
  List<Map<String, dynamic>> file = [];
  List<Map<String, dynamic>> rejets = [];
  int version = 0; // augmente quand la file a été envoyée au serveur

  // horloge fiable
  DateTime? _serveur; // heure du serveur au dernier contact
  DateTime? _appareil; // heure de l'appareil au même moment
  DateTime? _dernierVu; // plus grande heure d'appareil observée
  DateTime? derniereSynchro;
  bool horlogeModifiee = false;
  String _abonnement = 'illimite';
  DateTime? _fin;
  bool _envoi = false;
  Timer? _minuteur;

  static final _cle = utf8.encode('warchati-horloge-v1-7f3a9c');

  // ------------------------------------------------------------------ initialisation et persistance

  Future<void> init() async {
    try {
      final base = await getApplicationSupportDirectory();
      _dir = Directory('${base.path}/hors_ligne');
      await Directory('${_dir!.path}/cache').create(recursive: true);
      file = _lireListe('file.json');
      rejets = _lireListe('rejets.json');
      _lireHorloge();
    } catch (e) {
      debugPrint('hors_ligne.init: $e');
    }
    _verifierHorloge();
    _minuteur = Timer.periodic(const Duration(minutes: 1), (_) {
      _verifierHorloge();
      if (file.isNotEmpty) vider();
    });
  }

  List<Map<String, dynamic>> _lireListe(String nom) {
    final f = File('${_dir!.path}/$nom');
    if (!f.existsSync()) return [];
    try {
      return [for (final e in jsonDecode(f.readAsStringSync()) as List) Map<String, dynamic>.from(e as Map)];
    } catch (_) {
      return [];
    }
  }

  void _ecrireListe(String nom, List<Map<String, dynamic>> l) {
    if (_dir == null) return;
    try {
      File('${_dir!.path}/$nom').writeAsStringSync(jsonEncode(l));
    } catch (_) {}
  }

  void _lireHorloge() {
    final f = File('${_dir!.path}/horloge.json');
    if (!f.existsSync()) return;
    try {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final data = m['d'] as String;
      if (Hmac(sha256, _cle).convert(utf8.encode(data)).toString() != m['s']) {
        horlogeModifiee = true; // fichier modifié à la main
        return;
      }
      final d = jsonDecode(data) as Map<String, dynamic>;
      DateTime? t(String k) => d[k] == null ? null : DateTime.parse(d[k] as String);
      _serveur = t('serveur');
      _appareil = t('appareil');
      _dernierVu = t('vu');
      derniereSynchro = t('synchro');
      horlogeModifiee = d['modifiee'] == true;
      _abonnement = (d['abonnement'] ?? 'illimite') as String;
      _fin = t('fin');
    } catch (_) {}
  }

  void _ecrireHorloge() {
    if (_dir == null) return;
    final data = jsonEncode({
      'serveur': _serveur?.toIso8601String(),
      'appareil': _appareil?.toIso8601String(),
      'vu': _dernierVu?.toIso8601String(),
      'synchro': derniereSynchro?.toIso8601String(),
      'modifiee': horlogeModifiee,
      'abonnement': _abonnement,
      'fin': _fin?.toIso8601String(),
    });
    try {
      File('${_dir!.path}/horloge.json').writeAsStringSync(jsonEncode({'d': data, 's': Hmac(sha256, _cle).convert(utf8.encode(data)).toString()}));
    } catch (_) {}
  }

  // ------------------------------------------------------------------ horloge et limites

  /// Heure fiable : heure du serveur + temps écoulé sur l'appareil depuis le dernier contact.
  DateTime get maintenant {
    final now = DateTime.now();
    if (_serveur == null || _appareil == null) return now;
    final ecoule = now.difference(_appareil!);
    return _serveur!.add(ecoule.isNegative ? Duration.zero : ecoule);
  }

  void _verifierHorloge() {
    final now = DateTime.now();
    if (_dernierVu != null && now.isBefore(_dernierVu!.subtract(const Duration(minutes: 10)))) {
      if (!horlogeModifiee) {
        horlogeModifiee = true;
        notifyListeners();
      }
    }
    if (_dernierVu == null || now.isAfter(_dernierVu!)) _dernierVu = now;
    _ecrireHorloge();
  }

  void _noterServeur(String? dateHttp) {
    if (dateHttp == null) return;
    try {
      final s = HttpDate.parse(dateHttp);
      final now = DateTime.now();
      _serveur = s;
      _appareil = now;
      _dernierVu = now;
      derniereSynchro = s;
      if (horlogeModifiee) {
        horlogeModifiee = false;
        notifyListeners();
      }
      _ecrireHorloge();
    } catch (_) {}
  }

  /// Abonnement de l'atelier (appelé au chargement de la session).
  void configurer(String abonnement, DateTime? fin) {
    _abonnement = abonnement;
    _fin = fin;
    _ecrireHorloge();
    notifyListeners();
  }

  Duration? get limite => limites[_abonnement];

  /// Temps restant avant de devoir se connecter (null : pas de limite).
  Duration? get resteHorsLigne {
    final l = limite;
    if (l == null || derniereSynchro == null) return null;
    return derniereSynchro!.add(l).difference(maintenant);
  }

  /// Raison pour laquelle les écritures sont bloquées hors ligne (null : autorisées).
  String? get blocage {
    if (horlogeModifiee) return 'Horloge de l\'appareil modifiée : connectez-vous à internet pour continuer.';
    if (enLigne) return null;
    final r = resteHorsLigne;
    if (r != null && r.isNegative) return 'Trop longtemps sans internet : connectez-vous une fois pour continuer.';
    if (_fin != null && _abonnement != 'illimite') {
      final j = DateTime(_fin!.year, _fin!.month, _fin!.day).add(const Duration(days: 1));
      if (!maintenant.isBefore(j)) return 'Abonnement terminé : connectez-vous pour le renouveler.';
    }
    return null;
  }

  void _etat(bool v) {
    if (enLigne == v) return;
    enLigne = v;
    notifyListeners();
    if (v && file.isNotEmpty) vider();
  }

  // ------------------------------------------------------------------ cache des lectures

  String get _utilisateur => Supabase.instance.client.auth.currentUser?.id ?? 'anonyme';

  File? _fichierCache(String cle) =>
      _dir == null ? null : File('${_dir!.path}/cache/${sha1.convert(utf8.encode('$_utilisateur|$cle')).toString()}.json');

  void _sauverCache(String cle, String corps) {
    try {
      _fichierCache(cle)?.writeAsStringSync(corps);
    } catch (_) {}
  }

  String? _lireCache(String cle) {
    try {
      final f = _fichierCache(cle);
      return f != null && f.existsSync() ? f.readAsStringSync() : null;
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------ file d'attente

  void _ajouterFile(Map<String, dynamic> op) {
    file.add(op);
    _ecrireListe('file.json', file);
    notifyListeners();
  }

  void supprimerRejet(int i) {
    rejets.removeAt(i);
    _ecrireListe('rejets.json', rejets);
    notifyListeners();
  }

  void viderRejets() {
    rejets.clear();
    _ecrireListe('rejets.json', rejets);
    notifyListeners();
  }

  /// Envoie la file au serveur, dans l'ordre (le dernier enregistrement gagne).
  Future<void> vider() async {
    if (_envoi || file.isEmpty) return;
    _envoi = true;
    final client = http.Client();
    var envoye = false;
    try {
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession?.isExpired ?? false) {
        try {
          await auth.refreshSession();
        } catch (_) {}
      }
      while (file.isNotEmpty) {
        final op = file.first;
        final req = http.Request(op['methode'] as String, Uri.parse(op['url'] as String));
        req.headers.addAll(Map<String, String>.from(op['entetes'] as Map));
        final jeton = auth.currentSession?.accessToken;
        if (jeton != null) req.headers['Authorization'] = 'Bearer $jeton';
        if (op['corps'] != null) req.body = op['corps'] as String;
        http.Response r;
        try {
          r = await http.Response.fromStream(await client.send(req).timeout(const Duration(seconds: 20)));
        } catch (_) {
          _etat(false);
          break;
        }
        _noterServeur(r.headers['date']);
        _etat(true);
        if (r.statusCode >= 500) break;
        file.removeAt(0);
        envoye = true;
        if (r.statusCode >= 400) {
          String msg = r.body;
          try {
            msg = (jsonDecode(r.body) as Map)['message']?.toString() ?? r.body;
          } catch (_) {}
          rejets.add({...op, 'erreur': msg, 'le': DateTime.now().toIso8601String()});
          _ecrireListe('rejets.json', rejets);
        }
        _ecrireListe('file.json', file);
      }
    } finally {
      client.close();
      _envoi = false;
      if (envoye) version++;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ application de la file aux lectures

  static const _paramsIgnores = {'select', 'order', 'limit', 'offset', 'and', 'or', 'on_conflict', 'columns'};

  static Map<String, String> _filtres(Uri u) => {for (final e in u.queryParameters.entries) if (!_paramsIgnores.contains(e.key)) e.key: e.value};

  static bool _correspond(Map<String, dynamic> ligne, Map<String, String> filtres) {
    for (final e in filtres.entries) {
      if (!ligne.containsKey(e.key)) continue;
      final v = ligne[e.key];
      final i = e.value.indexOf('.');
      if (i < 0) continue;
      final op = e.value.substring(0, i), val = e.value.substring(i + 1);
      final s = v?.toString();
      int cmp() {
        final a = num.tryParse(s ?? ''), b = num.tryParse(val);
        if (a != null && b != null) return a.compareTo(b);
        return (s ?? '').compareTo(val);
      }

      final ok = switch (op) {
        'eq' => s == val,
        'neq' => s != val,
        'gt' => s != null && cmp() > 0,
        'gte' => s != null && cmp() >= 0,
        'lt' => s != null && cmp() < 0,
        'lte' => s != null && cmp() <= 0,
        'is' => val == 'null' ? v == null : (val == 'true' ? v == true : (val == 'false' ? v == false : true)),
        'in' => val.replaceAll(RegExp(r'^\(|\)$'), '').split(',').map((x) => x.replaceAll('"', '')).contains(s),
        _ => true,
      };
      if (!ok) return false;
    }
    return true;
  }

  static Map<String, dynamic> _completer(Map<String, dynamic> l) {
    final r = Map<String, dynamic>.from(l);
    r.putIfAbsent('created_at', () => DateTime.now().toUtc().toIso8601String());
    if (!r.containsKey('montant') && r['quantite'] != null && r['prix_unitaire'] != null) {
      r['montant'] = (num.tryParse('${r['quantite']}') ?? 0) * (num.tryParse('${r['prix_unitaire']}') ?? 0);
    }
    if (!r.containsKey('montant') && r['total_points'] != null && r['tarif_1000'] != null) {
      r['montant'] = (num.tryParse('${r['total_points']}') ?? 0) * (num.tryParse('${r['tarif_1000']}') ?? 0) / 1000;
    }
    return r;
  }

  /// Applique les écritures en attente à une réponse de lecture gardée en cache.
  String _appliquerFile(Uri u, String corps) {
    if (file.isEmpty) return corps;
    final table = u.pathSegments.last;
    if (!file.any((o) => o['table'] == table)) return corps;
    dynamic d;
    try {
      d = jsonDecode(corps);
    } catch (_) {
      return corps;
    }
    if (d is! List) return corps;
    final lignes = [for (final e in d) Map<String, dynamic>.from(e as Map)];
    final filtres = _filtres(u);
    final imbrique = (u.queryParameters['select'] ?? '').contains('(');
    for (final op in file.where((o) => o['table'] == table)) {
      final ou = Uri.parse(op['url'] as String);
      final cible = _filtres(ou);
      switch (op['methode']) {
        case 'POST':
          if (imbrique || op['corps'] == null) break;
          final b = jsonDecode(op['corps'] as String);
          for (final l in (b is List ? b : [b])) {
            final m = _completer(Map<String, dynamic>.from(l as Map));
            if (!_correspond(m, filtres)) continue;
            final i = lignes.indexWhere((x) => x['id'] != null && x['id'] == m['id']);
            i >= 0 ? lignes[i].addAll(m) : lignes.insert(0, m);
          }
        case 'PATCH':
          if (op['corps'] == null) break;
          final patch = Map<String, dynamic>.from(jsonDecode(op['corps'] as String) as Map);
          for (final l in lignes) {
            if (_correspond(l, cible)) l.addAll(patch);
          }
        case 'DELETE':
          lignes.removeWhere((l) => _correspond(l, cible));
      }
    }
    return jsonEncode(lignes);
  }
}

/// Client HTTP de Supabase avec cache, file d'attente et horloge fiable.
class ClientHorsLigne extends http.BaseClient {
  final http.Client _interne = http.Client();
  HorsLigne get _hl => HorsLigne.instance;

  static bool _reseau(Object e) => e is SocketException || e is TimeoutException || e is http.ClientException || e is HandshakeException;

  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    final s = [for (var i = 0; i < 16; i++) h(i)].join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  static http.StreamedResponse _reponse(http.BaseRequest req, int statut, String corps, {Map<String, String>? entetes}) {
    final bytes = utf8.encode(corps);
    return http.StreamedResponse(Stream.value(bytes), statut,
        contentLength: bytes.length,
        request: req,
        headers: {'content-type': 'application/json; charset=utf-8', ...?entetes});
  }

  static http.StreamedResponse _erreur(http.BaseRequest req, int statut, String message) =>
      _reponse(req, statut, jsonEncode({'message': message, 'code': 'HORS_LIGNE', 'details': null, 'hint': null}));

  Future<http.Response> _envoyer(http.BaseRequest original, List<int> corps, {Uri? url}) async {
    final r = http.Request(original.method, url ?? original.url)
      ..headers.addAll(original.headers)
      ..bodyBytes = corps
      ..followRedirects = original.followRedirects;
    final s = await _interne.send(r).timeout(Duration(seconds: _hl.enLigne ? 20 : 6));
    return http.Response.fromStream(s);
  }

  http.StreamedResponse _rejouer(http.BaseRequest req, http.Response r) =>
      http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode, contentLength: r.bodyBytes.length, request: req, headers: r.headers, reasonPhrase: r.reasonPhrase);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) async {
    final u = req.url;
    final corpsOrig = await req.finalize().toBytes();

    // authentification, fonctions, stockage : directement (internet nécessaire)
    if (!u.path.startsWith('/rest/v1/')) {
      try {
        final r = await _envoyer(req, corpsOrig);
        _hl._noterServeur(r.headers['date']);
        _hl._etat(true);
        return _rejouer(req, r);
      } catch (e) {
        if (_reseau(e)) _hl._etat(false);
        rethrow;
      }
    }

    final segs = u.pathSegments;
    final rpc = segs.length >= 4 && segs[2] == 'rpc' ? segs[3] : null;
    final lecture = req.method == 'GET' || req.method == 'HEAD' || (rpc != null && HorsLigne._rpcLecture.contains(rpc));
    final cle = '${req.method} $u ${utf8.decode(corpsOrig, allowMalformed: true)}';

    // ---------------------------------------------------------------- lectures
    if (lecture || rpc == 'pin_verifier') {
      if (_hl.file.isNotEmpty && _hl.enLigne) await _hl.vider();
      try {
        final r = await _envoyer(req, corpsOrig);
        _hl._noterServeur(r.headers['date']);
        _hl._etat(true);
        if (r.statusCode == 200 && rpc == null) _hl._sauverCache(cle, r.body);
        if (r.statusCode == 200 && rpc != null && rpc != 'pin_verifier') _hl._sauverCache(cle, r.body);
        if (rpc == 'pin_verifier' && r.statusCode == 200) _memoriserPin(corpsOrig, r.body);
        return _rejouer(req, r);
      } catch (e) {
        if (!_reseau(e)) rethrow;
        _hl._etat(false);
        if (rpc == 'pin_verifier') return _reponse(req, 200, _verifierPinLocal(corpsOrig));
        final c = _hl._lireCache(cle);
        final objet = (req.headers['Accept'] ?? req.headers['accept'] ?? '').contains('vnd.pgrst.object');
        if (c == null) {
          return objet || rpc != null
              ? _erreur(req, 406, 'Hors ligne : ces données n\'ont jamais été chargées sur cet appareil.')
              : _reponse(req, 200, '[]', entetes: {'content-range': '*/0'});
        }
        return _reponse(req, 200, rpc == null ? _hl._appliquerFile(u, c) : c);
      }
    }

    // ---------------------------------------------------------------- fonctions serveur qui modifient
    if (rpc != null) {
      try {
        final r = await _envoyer(req, corpsOrig);
        _hl._noterServeur(r.headers['date']);
        _hl._etat(true);
        return _rejouer(req, r);
      } catch (e) {
        if (!_reseau(e)) rethrow;
        _hl._etat(false);
        return _erreur(req, 503, 'Connexion internet nécessaire pour cette opération (numérotation des documents).');
      }
    }

    // ---------------------------------------------------------------- écritures sur une table
    final table = segs.last;
    var corps = corpsOrig;
    var url = u;
    final prefer = req.headers['Prefer'] ?? req.headers['prefer'] ?? '';
    if (req.method == 'POST' && HorsLigne._tablesUuid.contains(table) && !u.queryParameters.containsKey('on_conflict') && !prefer.contains('resolution')) {
      try {
        final d = jsonDecode(utf8.decode(corpsOrig));
        Map<String, dynamic> avecId(Object? l) {
          final m = Map<String, dynamic>.from(l as Map);
          m['id'] ??= _uuid();
          return m;
        }

        final nouveau = d is List ? [for (final l in d) avecId(l)] : avecId(d);
        corps = utf8.encode(jsonEncode(nouveau));
        // insertion en lot : la liste des colonnes doit inclure l'identifiant fabriqué ici
        final cols = u.queryParameters['columns'];
        if (cols != null && !cols.split(',').map((c) => c.replaceAll('"', '').trim()).contains('id')) {
          url = u.replace(queryParameters: {...u.queryParameters, 'columns': '$cols,"id"'});
        }
      } catch (_) {}
    }

    if (_hl.file.isNotEmpty && _hl.enLigne) await _hl.vider();
    if (_hl.file.isEmpty) {
      try {
        final r = await _envoyer(req, corps, url: url);
        _hl._noterServeur(r.headers['date']);
        _hl._etat(true);
        return _rejouer(req, r);
      } catch (e) {
        if (!_reseau(e)) rethrow;
        _hl._etat(false);
      }
    }
    // hors ligne : contrôle des limites puis mise en file d'attente
    final b = _hl.blocage;
    if (b != null) return _erreur(req, 403, b);
    final entetes = Map<String, String>.from(req.headers)..removeWhere((k, _) => k.toLowerCase() == 'authorization' || k.toLowerCase() == 'content-length');
    final texte = corps.isEmpty ? null : utf8.decode(corps);
    _hl._ajouterFile({'methode': req.method, 'url': url.toString(), 'table': table, 'entetes': entetes, 'corps': texte, 'le': DateTime.now().toIso8601String()});

    final representation = prefer.contains('return=representation');
    final objet = (req.headers['Accept'] ?? req.headers['accept'] ?? '').contains('vnd.pgrst.object');
    if (!representation) return _reponse(req, req.method == 'POST' ? 201 : 204, '');
    dynamic rep;
    if (texte == null) {
      rep = [];
    } else {
      final d = jsonDecode(texte);
      rep = d is List ? [for (final l in d) HorsLigne._completer(Map<String, dynamic>.from(l as Map))] : [HorsLigne._completer(Map<String, dynamic>.from(d as Map))];
    }
    if (objet) return _reponse(req, req.method == 'POST' ? 201 : 200, jsonEncode((rep as List).isEmpty ? {} : rep.first));
    return _reponse(req, req.method == 'POST' ? 201 : 200, jsonEncode(rep));
  }

  // ------------------------------------------------------------------ code PIN hors ligne

  String get _clePin => 'pin|${Supabase.instance.client.auth.currentUser?.id}';

  void _memoriserPin(List<int> corps, String reponse) {
    try {
      final pin = (jsonDecode(utf8.decode(corps)) as Map)['p_pin']?.toString();
      final ok = (jsonDecode(reponse) as Map)['ok'] == true;
      if (pin != null && ok) {
        _hl._sauverCache(_clePin, sha256.convert(utf8.encode('${Supabase.instance.client.auth.currentUser?.id}|$pin|warchati')).toString());
      }
    } catch (_) {}
  }

  String _verifierPinLocal(List<int> corps) {
    try {
      final pin = (jsonDecode(utf8.decode(corps)) as Map)['p_pin']?.toString();
      final attendu = _hl._lireCache(_clePin);
      if (attendu == null) return jsonEncode({'ok': false, 'defini': true, 'restants': 0});
      final h = sha256.convert(utf8.encode('${Supabase.instance.client.auth.currentUser?.id}|$pin|warchati')).toString();
      return jsonEncode(h == attendu ? {'ok': true} : {'ok': false, 'defini': true, 'restants': 5});
    } catch (_) {
      return jsonEncode({'ok': false, 'defini': true, 'restants': 0});
    }
  }
}
