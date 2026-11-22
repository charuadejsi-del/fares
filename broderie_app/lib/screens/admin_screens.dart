import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../charts.dart';
import '../data/app_data.dart';
import '../data/commerce.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../data/stock.dart';
import '../pdf/documents.dart' show oublierLogo;
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'refs_screens.dart' show FormDialog;
import '../i18n.dart';
import '../pin.dart';

// ======================================================================= vue d'ensemble (admin)

class VueEnsembleScreen extends StatefulWidget {
  final void Function(int index)? onAller;
  const VueEnsembleScreen({super.key, this.onAller});

  @override
  State<VueEnsembleScreen> createState() => _VueEnsembleScreenState();
}

class _VueEnsembleScreenState extends State<VueEnsembleScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  bool _loading = true;
  String? _error;
  List<Production> _prod = [];
  List<Mouvement> _mvts = [];
  List<Piece> _pieces = [];
  List<Vente> _ventes = [];
  List<Versement> _encaisse = [];
  List<Vente> _ventes12 = [];
  List<Map<String, dynamic>> _lignes = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = rangeFor(_periode, _custom);
    try {
      final res = await Future.wait<Object>([
        data.fetchProduction(r.start, r.end),
        data.fetchMouvements(r.start, r.end),
        data.fetchPieces(r.start, r.end),
        stock.ventes(from: r.start, to: r.end),
        stock.versements(from: r.start, to: r.end),
      ]);
      await Future.wait<void>([data.refreshSoldes(), stock.load(), commerce.load()]);
      final now = DateTime.now();
      final debut12 = DateTime(now.year, now.month - 11, 1);
      final res2 = await Future.wait<Object>([
        stock.ventes(from: debut12, to: dayOnly(now), limit: 5000),
        stock.lignesVendues(r.start, r.end),
      ]);
      _ventes12 = (res2[0] as List<Vente>).where((v) => !v.annulee).toList();
      _lignes = res2[1] as List<Map<String, dynamic>>;
      if (mounted) {
        setState(() {
          _prod = res[0] as List<Production>;
          _mvts = res[1] as List<Mouvement>;
          _pieces = res[2] as List<Piece>;
          _ventes = (res[3] as List<Vente>).where((v) => !v.annulee).toList();
          _encaisse = res[4] as List<Versement>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pts = _prod.fold<int>(0, (s, p) => s + p.totalPoints);
    final mtBroderie = _prod.fold<double>(0, (s, p) => s + p.montant);
    double mv(TypeMvt t) => _mvts.where((m) => m.type == t).fold<double>(0, (s, m) => s + m.montant);
    final gainsAutres = _pieces.fold<double>(0, (s, p) => s + p.montant) + mv(TypeMvt.salaire) + mv(TypeMvt.prime);
    final ca = _ventes.fold<double>(0, (s, v) => s + v.totalTtc);
    final encaisse = _encaisse.fold<double>(0, (s, x) => s + x.montant);
    final piecesVendues = _ventes.fold<int>(0, (s, v) => s + v.nbArticles);
    final cout = mtBroderie + gainsAutres;

    Widget module(String titre, IconData icon, Gradient g, int? index, List<(String, String)> lignes) => AppCard(
          onTap: index == null || widget.onAller == null ? null : () => widget.onAller!(index),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(titre, style: context.tt.titleMedium)),
              if (index != null) Icon(Icons.chevron_right_rounded, color: context.pal.muted),
            ]),
            const SizedBox(height: 14),
            for (final l in lignes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(l.$1, style: TextStyle(color: context.pal.muted))),
                  Text(l.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        AppCard(
          gradient: AppColors.heroGradient,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(session.atelier?.nom ?? 'Atelier'.tr, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Bonjour {0} · vue d\'ensemble de l\'atelier'.trf([session.membre?.nom ?? '']), style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 40),
          ]),
        ),
        const SizedBox(height: 14),
        PeriodChips(
          periode: _periode,
          custom: _custom,
          onChanged: (p, c) {
            setState(() {
              _periode = p;
              _custom = c;
            });
            _load();
          },
        ),
        const SizedBox(height: 10),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null) ErrorBanner(_error!, onRetry: _load),
        const SizedBox(height: 6),
        AutoGrid(minItemWidth: 170, children: [
          StatTile(label: 'Ventes (CA)'.tr, value: fmtDA(ca), icon: Icons.trending_up_rounded, color: AppColors.violet),
          StatTile(label: 'Encaissé'.tr, value: fmtDA(encaisse), icon: Icons.payments_rounded, color: AppColors.green),
          StatTile(label: 'Clients doivent'.tr, value: fmtDA(stock.totalCreances), icon: Icons.storefront_rounded, color: AppColors.rose),
          StatTile(label: 'À payer aux ouvriers'.tr, value: fmtDA(data.totalResteAPayer), icon: Icons.groups_rounded, color: const Color(0xFFF97316)),
        ]),
        const SizedBox(height: 14),
        AutoGrid(minItemWidth: 300, children: [
          module('Broderie'.tr, Icons.blur_on_rounded, AppColors.heroGradient, 1, [
            ('Points brodés'.tr, fmtInt(pts)),
            ('Relevés'.tr, '${_prod.length}'),
            ('Coût broderie'.tr, fmtDA(mtBroderie)),
          ]),
          module('Paie & avances'.tr, Icons.account_balance_wallet_rounded, const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]), 2, [
            ('Avances données'.tr, fmtDA(mv(TypeMvt.avance))),
            ('Paiements faits'.tr, fmtDA(mv(TypeMvt.paiement))),
            ('Pièces + salaires'.tr, fmtDA(gainsAutres)),
            ('Reste à payer (total)'.tr, fmtDA(data.totalResteAPayer)),
          ]),
          module('Stock'.tr, Icons.inventory_2_rounded, AppColors.goldGradient, 3, [
            ('Pièces en stock'.tr, fmtInt(stock.totalPieces)),
            ('Valeur du stock'.tr, fmtDA(stock.valeurStock)),
            ('Produits en alerte'.tr, '${stock.nbAlertes}'),
          ]),
          module('Ventes'.tr, Icons.receipt_long_rounded, const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF38BDF8)]), 3, [
            ('Ventes'.tr, '${_ventes.length}'),
            ('Pièces vendues'.tr, fmtInt(piecesVendues)),
            ('Chiffre d\'affaires'.tr, fmtDA(ca)),
            ('Créances clients'.tr, fmtDA(stock.totalCreances)),
          ]),
        ]),
        const SizedBox(height: 14),
        _AnalyseVentes(ventes12: _ventes12, lignes: _lignes, ventesPeriode: _ventes),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('Résultat simplifié de la période'.tr, subtitle: 'Ventes − coût de la main-d\'œuvre enregistrée'.tr),
            _ligne(context, 'Chiffre d\'affaires'.tr, ca),
            _ligne(context, '− Main-d\'œuvre (broderie, pièces, salaires, primes)'.tr, -cout),
            const Divider(height: 20),
            _ligne(context, 'Marge brute'.tr, ca - cout, bold: true),
            const SizedBox(height: 6),
            Text('Indicatif : n\'inclut ni le tissu ni les autres charges.'.tr, style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          ]),
        ),
        if (stock.nbAlertes > 0) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Stock en alerte'.tr, subtitle: '{0} produit(s)'.trf([stock.nbAlertes])),
              for (final p in stock.produits.where((p) => p.actif && p.enAlerte).take(10))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Icon(Icons.warning_amber_rounded, color: p.rupture ? AppColors.rose : const Color(0xFFF97316), size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${p.reference} · ${p.libelle}', overflow: TextOverflow.ellipsis)),
                    Text('${fmtInt(p.stock)} pcs', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _ligne(BuildContext context, String t, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(t, style: TextStyle(fontWeight: bold ? FontWeight.w900 : null))),
          Text('${v < 0 ? '−' : ''}${fmtDA(v.abs())}',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: bold ? 18 : null, color: v < 0 ? AppColors.rose : (bold ? AppColors.green : null))),
        ]),
      );
}

// ======================================================================= employés

class EmployesScreen extends StatefulWidget {
  const EmployesScreen({super.key});

  @override
  State<EmployesScreen> createState() => _EmployesScreenState();
}

class _EmployesScreenState extends State<EmployesScreen> {
  List<Membre> _membres = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final m = await session.membres();
      if (mounted) setState(() {
        _membres = m;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _form([Membre? m]) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => EmployeForm(membre: m));
    if (ok == true) _load();
  }

  Future<void> _reinitialiserPin(Membre m) async {
    if (!await confirmDialog(context, 'Réinitialiser le code PIN'.tr,
        '{0} devra créer un nouveau code PIN à sa prochaine ouverture du logiciel.'.trf([m.nom]),
        action: 'Réinitialiser'.tr)) {
      return;
    }
    try {
      await verrou.reinitialiser(m.userId);
      if (mounted) showSnack(context, 'Code PIN réinitialisé'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _supprimer(Membre m) async {
    if (!await confirmDialog(context, 'Supprimer le compte'.tr,
        'Supprimer le compte de {0} ? Il ne pourra plus se connecter. Ses saisies restent enregistrées.'.trf([m.nom]))) {
      return;
    }
    try {
      await session.employe({'action': 'supprimer', 'user_id': m.userId});
      if (mounted) showSnack(context, 'Compte supprimé'.tr);
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Employés et accès'.tr)),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-emp',
          onPressed: () => _form(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: Text('Nouvel employé'.tr),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            AppCard(
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: context.cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Comptes de connexion au logiciel (gérant, magasinier, caissier…). Chacun ne voit que les espaces cochés.\nLes ouvriers sans accès (brodeurs, ouvriers au mois) s\'ajoutent dans l\'onglet « Ouvriers ».'.tr),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ErrorBanner(_error!, onRetry: _load),
            for (final m in _membres)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => _form(m),
                  child: Row(children: [
                    Opacity(opacity: m.actif ? 1 : 0.4, child: NameAvatar(m.nom.isEmpty ? '?' : m.nom, size: 46)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(child: Text(m.nom.isEmpty ? m.identifiantCourt : m.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
                          if (m.userId == session.membre?.userId) ...[
                            const SizedBox(width: 6),
                            Text('(vous)'.tr, style: TextStyle(color: context.pal.muted)),
                          ],
                        ]),
                        Text('Identifiant : {0}'.trf([m.identifiantCourt]), style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                        const SizedBox(height: 4),
                        Text(m.actif ? m.droitsTexte : 'Compte désactivé'.tr,
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: m.actif ? (m.admin ? AppColors.gold : context.cs.primary) : AppColors.rose)),
                      ]),
                    ),
                    if (m.userId != session.membre?.userId)
                      PopupMenuButton<String>(
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'edit', child: Text('Modifier / mot de passe'.tr)),
                          PopupMenuItem(value: 'pin', child: Text('Réinitialiser le code PIN'.tr)),
                          PopupMenuItem(value: 'del', child: Text('Supprimer le compte'.tr)),
                        ],
                        onSelected: (v) => switch (v) {
                          'edit' => _form(m),
                          'pin' => _reinitialiserPin(m),
                          _ => _supprimer(m),
                        },
                      ),
                  ]),
                ),
              ),
          ]),
        ),
      );
}

class EmployeForm extends StatefulWidget {
  final Membre? membre;
  const EmployeForm({super.key, this.membre});

  @override
  State<EmployeForm> createState() => _EmployeFormState();
}

class _EmployeFormState extends State<EmployeForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.membre?.nom);
  late final _id = TextEditingController(text: widget.membre?.identifiantCourt);
  final _mdp = TextEditingController();
  late bool _admin = widget.membre?.admin ?? false;
  late bool _broderie = widget.membre?.broderie ?? false;
  late bool _paie = widget.membre?.paie ?? false;
  late bool _stock = widget.membre?.stock ?? false;
  late bool _coupe = widget.membre?.coupe ?? false;
  late bool _applique = widget.membre?.applique ?? false;
  late bool _finition = widget.membre?.finition ?? false;
  late bool _actif = widget.membre?.actif ?? true;
  bool _busy = false;
  bool _voir = false;

  bool get _soi => widget.membre?.userId == session.membre?.userId;

  @override
  void dispose() {
    _nom.dispose();
    _id.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (!_admin && !_broderie && !_paie && !_stock && !_coupe && !_applique && !_finition) {
      showSnack(context, 'Cochez au moins un espace'.tr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final droits = {
        'role': _admin ? 'admin' : 'employe',
        'perm_broderie': _broderie,
        'perm_paie': _paie,
        'perm_stock': _stock,
        'perm_coupe': _coupe,
        'perm_applique': _applique,
        'perm_finition': _finition,
      };
      if (widget.membre == null) {
        await session.employe({
          'action': 'creer',
          'nom': _nom.text.trim(),
          'identifiant': _id.text.trim().toLowerCase(),
          'mot_de_passe': _mdp.text,
          ...droits,
        });
      } else {
        await session.employe({
          'action': 'modifier',
          'user_id': widget.membre!.userId,
          'nom': _nom.text.trim(),
          if (_mdp.text.isNotEmpty) 'mot_de_passe': _mdp.text,
          if (!_soi) ...droits,
          if (!_soi) 'actif': _actif,
        });
      }
      if (mounted) {
        showSnack(context, widget.membre == null ? 'Compte créé : {0}'.trf([_id.text.trim().toLowerCase()]) : 'Compte mis à jour'.tr);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Widget _espace(String titre, String sous, IconData i, bool v, ValueChanged<bool>? f) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _admin || v,
        onChanged: _admin || _soi ? null : (x) => f?.call(x ?? false),
        secondary: Icon(i),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sous),
      );

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.membre == null ? 'Nouvel employé'.tr : 'Modifier {0}'.trf([widget.membre!.nom]),
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nom et prénom'.tr, prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(
            controller: _id,
            enabled: widget.membre == null,
            decoration: InputDecoration(
              labelText: 'Identifiant de connexion'.tr,
              helperText: 'ex. karim.stock (lettres, chiffres, point)'.tr,
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) {
              if (widget.membre != null) return null;
              final s = (v ?? '').trim().toLowerCase();
              return RegExp(r'^[a-z0-9._@-]{3,60}$').hasMatch(s) ? null : '3 caractères min. : lettres, chiffres, point, tiret'.tr;
            },
          ),
          TextFormField(
            controller: _mdp,
            obscureText: !_voir,
            decoration: InputDecoration(
              labelText: widget.membre == null ? 'Mot de passe'.tr : 'Nouveau mot de passe (laisser vide pour garder)'.tr,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_voir ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _voir = !_voir)),
            ),
            validator: (v) {
              final s = v ?? '';
              if (widget.membre == null && s.length < 6) return '6 caractères minimum'.tr;
              if (widget.membre != null && s.isNotEmpty && s.length < 6) return '6 caractères minimum'.tr;
              return null;
            },
          ),
          const Divider(),
          Text('Accès'.tr, style: context.tt.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold),
            title: Text('Administrateur'.tr, style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('Voit et contrôle tout, gère les employés'.tr),
            value: _admin,
            onChanged: _soi ? null : (v) => setState(() => _admin = v),
          ),
          _espace('Coupe'.tr, 'Fiches de coupe, suivi des paquets, ouvriers et travail du jour (sans prix)'.tr, Icons.content_cut_rounded, _coupe, (v) => setState(() => _coupe = v)),
          _espace('Broderie'.tr, 'Saisie des points, paquets, dessins (sans prix)'.tr, Icons.blur_on_rounded, _broderie, (v) => setState(() => _broderie = v)),
          _espace('Appliqué'.tr, 'Paquets reçus, ouvriers et travail du jour (sans prix)'.tr, Icons.auto_awesome_rounded, _applique, (v) => setState(() => _applique = v)),
          _espace('Finition'.tr, 'Repassage, presse à chaud, emballage, entrée au stock (sans prix)'.tr, Icons.iron_rounded, _finition, (v) => setState(() => _finition = v)),
          _espace('Comptabilité'.tr, 'Prix et montants, salaires, avances, paiements, couture externe'.tr, Icons.account_balance_wallet_rounded, _paie, (v) => setState(() => _paie = v)),
          _espace('Stock & ventes'.tr, 'Produits, QR, scan, ventes, clients, factures'.tr, Icons.inventory_2_rounded, _stock, (v) => setState(() => _stock = v)),
          if (widget.membre != null && !_soi)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Compte actif'.tr),
              subtitle: Text('Désactivé : il ne peut plus se connecter'.tr),
              value: _actif,
              onChanged: (v) => setState(() => _actif = v),
            ),
        ],
      );
}

// ======================================================================= informations de l'entreprise

class SocieteScreen extends StatefulWidget {
  const SocieteScreen({super.key});

  @override
  State<SocieteScreen> createState() => _SocieteScreenState();
}

class _SocieteScreenState extends State<SocieteScreen> {
  final _form = GlobalKey<FormState>();
  late final Atelier a = session.atelier!;
  late final _nom = TextEditingController(text: a.nom);
  late final _act = TextEditingController(text: a.activite);
  late final _adr = TextEditingController(text: a.adresse);
  late final _tel = TextEditingController(text: a.telephone);
  late final _mail = TextEditingController(text: a.email);
  late final _rc = TextEditingController(text: a.rc);
  late final _nif = TextEditingController(text: a.nif);
  late final _nis = TextEditingController(text: a.nis);
  late final _art = TextEditingController(text: a.art);
  late final _rib = TextEditingController(text: a.rib);
  late final _tva = TextEditingController(text: fmtNum(a.tva));
  late final _ment = TextEditingController(text: a.mentions);
  late final _qrLien = TextEditingController(text: a.qrLien);
  late final _qrLib = TextEditingController(text: a.qrLibelle ?? 'Suivez-nous sur Facebook'.tr);
  late final _vUrl = TextEditingController(text: a.vitrineUrl);
  late final _vSlogan = TextEditingController(text: a.vitrineSlogan);
  late final _wa = TextEditingController(text: a.whatsapp);
  late bool _vActive = a.vitrineActive;
  late bool _vPrix = a.vitrinePrix;
  bool _busy = false;

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await session.saveAtelier({
        'nom': _nom.text.trim(),
        'activite': _n(_act),
        'adresse': _n(_adr),
        'telephone': _n(_tel),
        'email': _n(_mail),
        'rc': _n(_rc),
        'nif': _n(_nif),
        'nis': _n(_nis),
        'art': _n(_art),
        'rib': _n(_rib),
        'tva': parseNum(_tva.text) ?? 0,
        'mentions': _n(_ment),
        'qr_lien': _n(_qrLien),
        'qr_libelle': _n(_qrLien) == null ? null : _n(_qrLib),
        'vitrine_active': _vActive,
        'vitrine_prix': _vPrix,
        'vitrine_url': _n(_vUrl),
        'vitrine_slogan': _n(_vSlogan),
        'whatsapp': _n(_wa),
      });
      if (mounted) showSnack(context, 'Informations enregistrées'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _f(TextEditingController c, String l, IconData i, {TextInputType? k, String? helper}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(controller: c, keyboardType: k, decoration: InputDecoration(labelText: l, prefixIcon: Icon(i), helperText: helper)),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Entreprise (factures)'.tr)),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const LogoEditor(),
            const SizedBox(height: 12),
            AppCard(
              child: Column(children: [
                SectionTitle('Identité'.tr, subtitle: 'Apparaît en haut des factures et bons de livraison'.tr),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nom,
                    decoration: InputDecoration(labelText: 'Nom de l\'entreprise'.tr, prefixIcon: Icon(Icons.business_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
                  ),
                ),
                _f(_act, 'Activité'.tr, Icons.work_outline),
                _f(_adr, 'Adresse'.tr, Icons.place_outlined),
                _f(_tel, 'Téléphone'.tr, Icons.phone_outlined, k: TextInputType.phone),
                _f(_mail, 'Email'.tr, Icons.mail_outline, k: TextInputType.emailAddress),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(children: [
                SectionTitle('Identifiants fiscaux'.tr, subtitle: 'Facultatifs'.tr),
                _f(_rc, 'Registre de commerce (RC)'.tr, Icons.badge_outlined),
                _f(_nif, 'NIF'.tr, Icons.badge_outlined),
                _f(_nis, 'NIS'.tr, Icons.badge_outlined),
                _f(_art, 'Article d\'imposition (ART)'.tr, Icons.badge_outlined),
                _f(_rib, 'RIB / compte bancaire'.tr, Icons.account_balance_outlined),
                _f(_tva, 'TVA (%)'.tr, Icons.percent_rounded, k: const TextInputType.numberWithOptions(decimal: true),
                    helper: '0 si non assujetti. S\'applique aux nouvelles ventes.'.tr),
                _f(_ment, 'Mention en bas des documents'.tr, Icons.notes, helper: 'ex. Merci pour votre confiance'.tr),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle('Site vitrine de la collection'.tr,
                    subtitle: 'Vos modèles en stock et leurs photos sont publiés automatiquement. Les clients voient les couleurs et tailles, jamais les quantités.'.tr),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Site en ligne'.tr),
                  value: _vActive,
                  onChanged: (v) => setState(() => _vActive = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Afficher le prix de gros'.tr),
                  value: _vPrix,
                  onChanged: (v) => setState(() => _vPrix = v),
                ),
                _f(_vSlogan, 'Phrase d\'accueil du site'.tr, Icons.auto_awesome_outlined, helper: 'ex. L\'élégance algérienne, brodée à la main'.tr),
                _f(_wa, 'Numéro WhatsApp pour les commandes'.tr, Icons.chat_outlined, k: TextInputType.phone, helper: 'ex. 213559013738 (indicatif sans +)'.tr),
                _f(_vUrl, 'Adresse du site (après mise en ligne)'.tr, Icons.language_rounded, k: TextInputType.url),
                if ((_vUrl.text).trim().startsWith('http'))
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: BarcodeWidget(barcode: Barcode.qrCode(), data: _vUrl.text.trim(), width: 110, height: 110, drawText: false),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_vUrl.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _vUrl.text.trim()));
                              showSnack(context, 'Lien copié'.tr);
                            },
                            icon: const Icon(Icons.copy_rounded),
                            label: Text('Copier le lien'.tr),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _qrLien.text = _vUrl.text.trim()),
                            icon: const Icon(Icons.qr_code_2_rounded),
                            label: Text('Mettre ce QR sur les factures'.tr),
                          ),
                        ]),
                      ]),
                    ),
                  ]),
              ]),
            ),            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle('QR code sur les documents'.tr,
                    subtitle: 'Collez le lien de votre page Facebook (ou Instagram, site, WhatsApp) : un QR code est ajouté en bas à droite de chaque facture, BL, bon de commande, devis et avoir.'.tr),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(children: [
                      TextFormField(
                        controller: _qrLien,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'Lien (ex. https://facebook.com/mapage)', prefixIcon: Icon(Icons.link_rounded)),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return null;
                          return t.startsWith('http://') || t.startsWith('https://') ? null : 'Le lien doit commencer par https://';
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(controller: _qrLib, decoration: InputDecoration(labelText: 'Texte à côté du QR'.tr, prefixIcon: Icon(Icons.short_text_rounded))),
                    ]),
                  ),
                  if (_qrLien.text.trim().startsWith('http')) ...[
                    const SizedBox(width: 14),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: BarcodeWidget(barcode: Barcode.qrCode(), data: _qrLien.text.trim(), width: 110, height: 110, drawText: false),
                    ),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: Text('Enregistrer'.tr),
              ),
            ),
          ]),
        ),
      );
}

// ======================================================================= analyse des ventes

class _AnalyseVentes extends StatelessWidget {
  final List<Vente> ventes12;
  final List<Map<String, dynamic>> lignes;
  final List<Vente> ventesPeriode;
  const _AnalyseVentes({required this.ventes12, required this.lignes, required this.ventesPeriode});

  static double _d(dynamic v) => v == null ? 0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final mois = [for (var i = 11; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
    final caMois = [
      for (final m in mois) ventes12.where((v) => v.date.year == m.year && v.date.month == m.month).fold<double>(0, (s, v) => s + v.totalTtc),
    ];
    final ceMois = caMois.last, moisPrec = caMois[caMois.length - 2];
    final evol = moisPrec > 0 ? (ceMois - moisPrec) * 100 / moisPrec : null;

    // top produits et marge (sur la période choisie)
    final parProduit = <String, (int, double)>{};
    var marge = 0.0;
    for (final l in lignes) {
      final pid = l['produit_id'] as String;
      final q = (l['quantite'] as num).toInt();
      final mt = _d(l['montant']);
      final prev = parProduit[pid] ?? (0, 0.0);
      parProduit[pid] = (prev.$1 + q, prev.$2 + mt);
      final p = stock.produit(pid);
      if (p != null) marge += mt - q * p.coutTotal;
    }
    final topProduits = parProduit.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));

    final parClient = <String, double>{};
    for (final v in ventesPeriode) {
      if (v.clientId != null) parClient[v.clientId!] = (parClient[v.clientId!] ?? 0) + v.totalTtc;
    }
    final topClients = parClient.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final caPeriode = ventesPeriode.fold<double>(0, (s, v) => s + v.totalTtc);
    final coutsConnus = stock.produits.any((p) => p.coutTotal > 0);

    Widget top(String titre, IconData icon, List<(String, String, double)> rows) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(titre),
            if (rows.isEmpty) Text('—', style: TextStyle(color: context.pal.muted)),
            for (var i = 0; i < rows.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    SizedBox(width: 22, child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: context.pal.muted))),
                    Icon(icon, size: 18, color: AppColors.series[i % AppColors.series.length]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(rows[i].$1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w900)),
                  ]),
                  const SizedBox(height: 4),
                  Bar(rows.first.$3 == 0 ? 0 : rows[i].$3 / rows.first.$3, color: AppColors.series[i % AppColors.series.length]),
                ]),
              ),
          ]),
        );

    return Column(children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionTitle('Ventes des 12 derniers mois'.tr, subtitle: 'Chiffre d\'affaires par mois'.tr,
              trailing: evol == null
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: (evol >= 0 ? AppColors.green : AppColors.rose).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('{0}{1} % vs mois dernier'.trf([evol >= 0 ? '+' : '', evol.toStringAsFixed(0)]),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: evol >= 0 ? AppColors.green : AppColors.rose)),
                    )),
          SimpleBarChart(labels: [for (final m in mois) fmtShortMonth(m)], values: caMois),
        ]),
      ),
      const SizedBox(height: 14),
      AutoGrid(minItemWidth: 300, children: [
        top('Meilleurs clients (période)'.tr, Icons.storefront_rounded, [
          for (final e in topClients.take(5)) (stock.client(e.key)?.nom ?? '?', fmtDA(e.value), e.value),
        ]),
        top('Robes les plus vendues (période)'.tr, Icons.checkroom_rounded, [
          for (final e in topProduits.take(5))
            ('${stock.produit(e.key)?.reference ?? '?'} · ${stock.produit(e.key)?.designation ?? ''}', '{0} pcs · {1}'.trf([fmtInt(e.value.$1), fmtCompact(e.value.$2)]), e.value.$2),
        ]),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('Rentabilité des ventes (période)'.tr, subtitle: 'Prix de vente − coût de revient des robes'.tr),
            Row(children: [Expanded(child: Text('Chiffre d\'affaires'.tr)), Text(fmtDA(caPeriode), style: const TextStyle(fontWeight: FontWeight.w800))]),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text('Marge estimée'.tr, style: TextStyle(fontWeight: FontWeight.w900))),
              Text(fmtDA(marge), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: marge >= 0 ? AppColors.green : AppColors.rose)),
            ]),
            if (caPeriode > 0)
              Text('Taux de marge : {0} %'.trf([(marge * 100 / caPeriode).toStringAsFixed(0)]), style: TextStyle(color: context.pal.muted)),
            if (!coutsConnus)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Renseignez la composition (matières) et le coût de revient des robes pour une marge exacte.'.tr,
                    style: context.tt.bodySmall?.copyWith(color: const Color(0xFFF97316))),
              ),
          ]),
        ),
      ]),
    ]);
  }
}

// ======================================================================= alertes

class Alerte {
  final IconData icon;
  final Color color;
  final String titre;
  final String detail;
  const Alerte(this.icon, this.color, this.titre, this.detail);
}

Future<List<Alerte>> calculerAlertes() async {
  final out = <Alerte>[];
  final today = dayOnly(DateTime.now());
  if (session.peut(Espace.stock)) {
    for (final p in stock.produits.where((p) => p.actif && p.rupture)) {
      out.add(Alerte(Icons.remove_shopping_cart_rounded, AppColors.rose, 'Rupture : {0}'.trf([p.reference]), '{0} · {1} en stock'.trf([p.libelle, fmtInt(p.stock)])));
    }
    for (final p in stock.produits.where((p) => p.actif && !p.rupture && p.enAlerte)) {
      out.add(Alerte(Icons.warning_amber_rounded, const Color(0xFFF97316), 'Stock bas : {0}'.trf([p.reference]), '{0} · {1} restantes (alerte ≤ {2})'.trf([p.libelle, fmtInt(p.stock), p.seuilAlerte])));
    }
    if (!commerce.loaded) {
      try {
        await commerce.load();
      } catch (_) {}
    }
    for (final m in commerce.matieres.where((m) => m.actif && m.enAlerte)) {
      out.add(Alerte(Icons.layers_rounded, const Color(0xFFF97316), 'Matière à racheter : {0}'.trf([m.nom]), '${fmtNum(m.stock)} ${m.unite} restants'));
    }
    try {
      final ventes = await stock.ventes(to: today.subtract(const Duration(days: 30)), limit: 500);
      for (final v in ventes.where((v) => !v.annulee && v.reste > 0.005)) {
        out.add(Alerte(Icons.hourglass_bottom_rounded, AppColors.rose, 'Impayé depuis plus de 30 jours : {0}'.trf([v.numero]),
            '{0} · reste {1} · vendu le {2}'.trf([v.clientNom ?? 'Client'.tr, fmtDA(v.reste), fmtDate(v.date)])));
      }
      final docs = await commerce.commandes();
      for (final c in docs.where((c) => c.enRetard)) {
        out.add(Alerte(c.devis ? Icons.request_quote_rounded : Icons.alarm_rounded, c.devis ? AppColors.gold : AppColors.rose,
            c.devis ? 'Devis expiré : {0}'.trf([c.numero]) : 'Commande en retard : {0}'.trf([c.numero]),
            '{0} · prévue le {1}'.trf([c.clientNom ?? '', fmtDate(c.echeance!)])));
      }
    } catch (_) {}
  }
  if (session.peut(Espace.paie)) {
    for (final o in data.ouvriers) {
      final s = data.solde(o.id).solde;
      if (s < -0.005) out.add(Alerte(Icons.north_east_rounded, AppColors.rose, 'Avance non couverte : {0}'.trf([o.nom]), 'A pris {0} de plus que son travail'.trf([fmtDA(-s)])));
    }
  }
  return out;
}

class AlertesScreen extends StatelessWidget {
  final List<Alerte> alertes;
  const AlertesScreen({super.key, required this.alertes});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Alertes ({0})'.trf([alertes.length]))),
        body: alertes.isEmpty
            ? EmptyState('Tout va bien : aucune alerte.'.tr, icon: Icons.verified_rounded)
            : ListView(padding: const EdgeInsets.all(16), children: [
                for (final a in alertes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: a.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(a.icon, color: a.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.titre, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(a.detail, style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
              ]),
      );
}

// ======================================================================= logo

class LogoEditor extends StatefulWidget {
  const LogoEditor({super.key});

  @override
  State<LogoEditor> createState() => _LogoEditorState();
}

class _LogoEditorState extends State<LogoEditor> {
  bool _busy = false;
  Uint8List? _apercu;

  Future<void> _choisir() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 90);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      setState(() {
        _busy = true;
        _apercu = bytes;
      });
      final ext = x.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final path = '${session.atelierId}/logo-${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Supabase.instance.client.storage
          .from('broderie-dessins')
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true));
      final ancien = session.atelier?.logoPath;
      String? public;
      try {
        public = await stock.envoyerPhotoVitrine(bytes, ext: ext, dossier: 'logo');
      } catch (_) {}
      await session.saveAtelier({'logo_path': path, if (public != null) 'logo_public': public});
      if (ancien != null) {
        try {
          await Supabase.instance.client.storage.from('broderie-dessins').remove([ancien]);
        } catch (_) {}
      }
      oublierLogo();
      if (mounted) showSnack(context, 'Logo enregistré : il apparaîtra sur les factures'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retirer() async {
    final ancien = session.atelier?.logoPath;
    setState(() => _busy = true);
    try {
      await session.saveAtelier({'logo_path': null, 'logo_public': null});
      if (ancien != null) await Supabase.instance.client.storage.from('broderie-dessins').remove([ancien]);
      oublierLogo();
      setState(() => _apercu = null);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = session.atelier?.logoPath;
    Widget img;
    if (_apercu != null) {
      img = Image.memory(_apercu!, fit: BoxFit.contain);
    } else if (path != null) {
      img = FutureBuilder<String?>(
        future: data.photoUrl(path),
        builder: (_, s) => s.data == null ? const SizedBox.shrink() : Image.network(s.data!, fit: BoxFit.contain),
      );
    } else {
      img = Icon(Icons.image_outlined, size: 40, color: context.pal.muted);
    }
    return AppCard(
      child: Row(children: [
        Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.pal.line)),
          child: img,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Logo de l\'entreprise'.tr, style: context.tt.titleMedium),
            Text('Affiché en haut des factures, bons de livraison, devis et avoirs.'.tr, style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _choisir,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_rounded),
                label: Text(path == null ? 'Ajouter'.tr : 'Changer'.tr),
              ),
              if (path != null) TextButton(onPressed: _busy ? null : _retirer, child: Text('Retirer'.tr)),
            ]),
          ]),
        ),
      ]),
    );
  }
}
