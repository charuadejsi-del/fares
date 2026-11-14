import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../data/stock.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'refs_screens.dart' show FormDialog;

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
      await Future.wait<void>([data.refreshSoldes(), stock.load()]);
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
                Text(session.atelier?.nom ?? 'Atelier', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Bonjour ${session.membre?.nom ?? ''} · vue d\'ensemble de l\'atelier', style: const TextStyle(color: Colors.white70)),
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
          StatTile(label: 'Ventes (CA)', value: fmtDA(ca), icon: Icons.trending_up_rounded, color: AppColors.violet),
          StatTile(label: 'Encaissé', value: fmtDA(encaisse), icon: Icons.payments_rounded, color: AppColors.green),
          StatTile(label: 'Clients doivent', value: fmtDA(stock.totalCreances), icon: Icons.storefront_rounded, color: AppColors.rose),
          StatTile(label: 'À payer aux ouvriers', value: fmtDA(data.totalResteAPayer), icon: Icons.groups_rounded, color: const Color(0xFFF97316)),
        ]),
        const SizedBox(height: 14),
        AutoGrid(minItemWidth: 300, children: [
          module('Broderie', Icons.blur_on_rounded, AppColors.heroGradient, 1, [
            ('Points brodés', fmtInt(pts)),
            ('Relevés', '${_prod.length}'),
            ('Coût broderie', fmtDA(mtBroderie)),
          ]),
          module('Paie & avances', Icons.account_balance_wallet_rounded, const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]), 2, [
            ('Avances données', fmtDA(mv(TypeMvt.avance))),
            ('Paiements faits', fmtDA(mv(TypeMvt.paiement))),
            ('Pièces + salaires', fmtDA(gainsAutres)),
            ('Reste à payer (total)', fmtDA(data.totalResteAPayer)),
          ]),
          module('Stock', Icons.inventory_2_rounded, AppColors.goldGradient, 3, [
            ('Pièces en stock', fmtInt(stock.totalPieces)),
            ('Valeur du stock', fmtDA(stock.valeurStock)),
            ('Produits en alerte', '${stock.nbAlertes}'),
          ]),
          module('Ventes', Icons.receipt_long_rounded, const LinearGradient(colors: [Color(0xFF0369A1), Color(0xFF38BDF8)]), 3, [
            ('Ventes', '${_ventes.length}'),
            ('Pièces vendues', fmtInt(piecesVendues)),
            ('Chiffre d\'affaires', fmtDA(ca)),
            ('Créances clients', fmtDA(stock.totalCreances)),
          ]),
        ]),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Résultat simplifié de la période', subtitle: 'Ventes − coût de la main-d\'œuvre enregistrée'),
            _ligne(context, 'Chiffre d\'affaires', ca),
            _ligne(context, '− Main-d\'œuvre (broderie, pièces, salaires, primes)', -cout),
            const Divider(height: 20),
            _ligne(context, 'Marge brute', ca - cout, bold: true),
            const SizedBox(height: 6),
            Text('Indicatif : n\'inclut ni le tissu ni les autres charges.', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          ]),
        ),
        if (stock.nbAlertes > 0) ...[
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Stock en alerte', subtitle: '${stock.nbAlertes} produit(s)'),
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

  Future<void> _supprimer(Membre m) async {
    if (!await confirmDialog(context, 'Supprimer le compte',
        'Supprimer le compte de ${m.nom} ? Il ne pourra plus se connecter. Ses saisies restent enregistrées.')) {
      return;
    }
    try {
      await session.employe({'action': 'supprimer', 'user_id': m.userId});
      if (mounted) showSnack(context, 'Compte supprimé');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Employés et accès')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-emp',
          onPressed: () => _form(),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Nouvel employé'),
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
            AppCard(
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: context.cs.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Chaque employé se connecte avec son identifiant et son mot de passe. '
                      'Il ne voit que les espaces que vous cochez : Broderie, Paie & avances, Stock & ventes.'),
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
                            Text('(vous)', style: TextStyle(color: context.pal.muted)),
                          ],
                        ]),
                        Text('Identifiant : ${m.identifiantCourt}', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                        const SizedBox(height: 4),
                        Text(m.actif ? m.droitsTexte : 'Compte désactivé',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: m.actif ? (m.admin ? AppColors.gold : context.cs.primary) : AppColors.rose)),
                      ]),
                    ),
                    if (m.userId != session.membre?.userId)
                      PopupMenuButton<String>(
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Modifier / mot de passe')),
                          PopupMenuItem(value: 'del', child: Text('Supprimer le compte')),
                        ],
                        onSelected: (v) => v == 'edit' ? _form(m) : _supprimer(m),
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
    if (!_admin && !_broderie && !_paie && !_stock) {
      showSnack(context, 'Cochez au moins un espace', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final droits = {
        'role': _admin ? 'admin' : 'employe',
        'perm_broderie': _broderie,
        'perm_paie': _paie,
        'perm_stock': _stock,
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
        showSnack(context, widget.membre == null ? 'Compte créé : ${_id.text.trim().toLowerCase()}' : 'Compte mis à jour');
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
        title: widget.membre == null ? 'Nouvel employé' : 'Modifier ${widget.membre!.nom}',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom et prénom', prefixIcon: Icon(Icons.badge_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _id,
            enabled: widget.membre == null,
            decoration: const InputDecoration(
              labelText: 'Identifiant de connexion',
              helperText: 'ex. karim.stock (lettres, chiffres, point)',
              prefixIcon: Icon(Icons.alternate_email_rounded),
            ),
            validator: (v) {
              if (widget.membre != null) return null;
              final s = (v ?? '').trim().toLowerCase();
              return RegExp(r'^[a-z0-9._@-]{3,60}$').hasMatch(s) ? null : '3 caractères min. : lettres, chiffres, point, tiret';
            },
          ),
          TextFormField(
            controller: _mdp,
            obscureText: !_voir,
            decoration: InputDecoration(
              labelText: widget.membre == null ? 'Mot de passe' : 'Nouveau mot de passe (laisser vide pour garder)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(icon: Icon(_voir ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _voir = !_voir)),
            ),
            validator: (v) {
              final s = v ?? '';
              if (widget.membre == null && s.length < 6) return '6 caractères minimum';
              if (widget.membre != null && s.isNotEmpty && s.length < 6) return '6 caractères minimum';
              return null;
            },
          ),
          const Divider(),
          Text('Accès', style: context.tt.titleSmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.gold),
            title: const Text('Administrateur', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Voit et contrôle tout, gère les employés'),
            value: _admin,
            onChanged: _soi ? null : (v) => setState(() => _admin = v),
          ),
          _espace('Broderie', 'Saisie des points, historique, dessins', Icons.blur_on_rounded, _broderie, (v) => setState(() => _broderie = v)),
          _espace('Paie & avances', 'Ouvriers, avances, paiements, fiches de paie', Icons.account_balance_wallet_rounded, _paie, (v) => setState(() => _paie = v)),
          _espace('Stock & ventes', 'Produits, QR, scan, ventes, clients, factures', Icons.inventory_2_rounded, _stock, (v) => setState(() => _stock = v)),
          if (widget.membre != null && !_soi)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Compte actif'),
              subtitle: const Text('Désactivé : il ne peut plus se connecter'),
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
      });
      if (mounted) showSnack(context, 'Informations enregistrées');
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
        appBar: AppBar(title: const Text('Entreprise (factures)')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            AppCard(
              child: Column(children: [
                const SectionTitle('Identité', subtitle: 'Apparaît en haut des factures et bons de livraison'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _nom,
                    decoration: const InputDecoration(labelText: 'Nom de l\'entreprise', prefixIcon: Icon(Icons.business_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
                  ),
                ),
                _f(_act, 'Activité', Icons.work_outline),
                _f(_adr, 'Adresse', Icons.place_outlined),
                _f(_tel, 'Téléphone', Icons.phone_outlined, k: TextInputType.phone),
                _f(_mail, 'Email', Icons.mail_outline, k: TextInputType.emailAddress),
              ]),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(children: [
                const SectionTitle('Identifiants fiscaux', subtitle: 'Facultatifs'),
                _f(_rc, 'Registre de commerce (RC)', Icons.badge_outlined),
                _f(_nif, 'NIF', Icons.badge_outlined),
                _f(_nis, 'NIS', Icons.badge_outlined),
                _f(_art, 'Article d\'imposition (ART)', Icons.badge_outlined),
                _f(_rib, 'RIB / compte bancaire', Icons.account_balance_outlined),
                _f(_tva, 'TVA (%)', Icons.percent_rounded, k: const TextInputType.numberWithOptions(decimal: true),
                    helper: '0 si non assujetti. S\'applique aux nouvelles ventes.'),
                _f(_ment, 'Mention en bas des documents', Icons.notes, helper: 'ex. Merci pour votre confiance'),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_rounded),
                label: const Text('Enregistrer'),
              ),
            ),
          ]),
        ),
      );
}
