import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/gestion.dart';
import '../data/session.dart';
import '../pdf/documents.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

// ====================================================================== clôture de la paie

class CloturePaieScreen extends StatefulWidget {
  const CloturePaieScreen({super.key});

  @override
  State<CloturePaieScreen> createState() => _CloturePaieScreenState();
}

class _CloturePaieScreenState extends State<CloturePaieScreen> {
  late DateTime _mois;
  bool _loading = true;
  bool _busy = false;
  String? _err;
  Cloture? _cloture;
  List<LignePaie> _base = [];
  Set<String> _sansSalaire = {};
  final Set<String> _ajouterSalaire = {};
  final Set<String> _payer = {};

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    // Par défaut : le mois précédent (on clôture en début de mois suivant)
    _mois = n.day <= 20 ? DateTime(n.year, n.month - 1) : DateTime(n.year, n.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final c = await gestion.cloture(_mois);
      if (c == null) {
        final (lignes, sans) = await gestion.preparer(_mois);
        _base = lignes;
        _sansSalaire = sans;
        _ajouterSalaire
          ..clear()
          ..addAll(sans);
        _payer.clear();
      }
      _cloture = c;
    } catch (e) {
      _err = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Lignes avec les salaires ajoutés et les paiements choisis.
  List<LignePaie> get _lignes => [
        for (final l in _base)
          () {
            final o = data.ouvrier(l.ouvrierId);
            final sal = _ajouterSalaire.contains(l.ouvrierId) ? (o?.salaireMensuel ?? 0) : 0.0;
            final x = l.copyWith(salaires: l.salaires + sal);
            return x.copyWith(paye: _payer.contains(l.ouvrierId) && x.net > 0 ? x.net : 0);
          }(),
      ];

  void _changerMois(int delta) {
    setState(() => _mois = DateTime(_mois.year, _mois.month + delta));
    _load();
  }

  Future<void> _pdf(List<LignePaie> lignes, {bool partage = false}) async {
    final a = session.atelier;
    if (a == null) return;
    try {
      final bytes = await buildCloturePaie(atelier: a, mois: _mois, lignes: lignes);
      final nom = 'Paie_${_mois.year}-${_mois.month.toString().padLeft(2, '0')}.pdf';
      partage ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _cloturer() async {
    final lignes = _lignes;
    final nbSal = _ajouterSalaire.length, nbPay = lignes.where((l) => l.paye > 0).length;
    final ok = await confirmDialog(
      context,
      'Clôturer ${fmtMonthYear(_mois)} ?',
      [
        '${lignes.length} ouvrier(s).',
        if (nbSal > 0) '$nbSal salaire(s) mensuel(s) seront ajoutés.',
        if (nbPay > 0) '$nbPay paiement(s) seront enregistrés (${fmtDA(lignes.fold<double>(0, (s, l) => s + l.paye))}).',
        'Ensuite, plus aucune saisie de production, pièce, avance ou paiement ne sera possible sur ce mois, '
            'sauf si l\'administrateur le réouvre.',
      ].join('\n\n'),
      action: 'Clôturer',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      final salaires = {
        for (final id in _ajouterSalaire)
          if ((data.ouvrier(id)?.salaireMensuel ?? 0) > 0) id: data.ouvrier(id)!.salaireMensuel,
      };
      final c = await gestion.cloturer(_mois, lignes, salairesAjoutes: salaires);
      if (!mounted) return;
      setState(() => _cloture = c);
      showSnack(context, 'Mois clôturé. Impression des fiches de paie…');
      await _pdf(c.lignes);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reouvrir() async {
    final c = _cloture;
    if (c == null) return;
    final ok = await confirmDialog(
      context,
      'Réouvrir ${fmtMonthYear(_mois)} ?',
      'Le mois redevient modifiable. Les salaires et paiements enregistrés à la clôture restent en place '
          '(vous pouvez les supprimer depuis la fiche de l\'ouvrier si besoin).',
      action: 'Réouvrir',
    );
    if (!ok) return;
    try {
      await gestion.reouvrir(c);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dernier = _mois.year == now.year && _mois.month == now.month;
    final c = _cloture;
    final lignes = c?.lignes ?? _lignes;
    double tot(double Function(LignePaie) f) => lignes.fold<double>(0, (s, l) => s + f(l));

    return Scaffold(
      appBar: AppBar(title: const Text('Clôture de la paie')),
      bottomNavigationBar: c != null || _loading || _err != null || lignes.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : _cloturer,
                  icon: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_rounded),
                  label: Text('Clôturer ${fmtMonthYear(_mois)} et imprimer les fiches'),
                ),
              ),
            ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(children: [
              IconButton(onPressed: _loading ? null : () => _changerMois(-1), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(
                child: Column(children: [
                  Text(fmtMonthYear(_mois), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  if (!_loading && _err == null)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c != null ? Icons.lock_rounded : Icons.lock_open_rounded, size: 14, color: c != null ? AppColors.green : AppColors.gold),
                      const SizedBox(width: 4),
                      Text(c != null ? 'Clôturé le ${fmtDate(c.creeLe)}' : 'Ouvert',
                          style: TextStyle(fontSize: 12, color: c != null ? AppColors.green : AppColors.gold, fontWeight: FontWeight.w700)),
                    ]),
                ]),
              ),
              IconButton(onPressed: _loading || dernier ? null : () => _changerMois(1), icon: const Icon(Icons.chevron_right_rounded)),
            ]),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (_err != null)
            ErrorBanner(_err!, onRetry: _load)
          else if (lignes.isEmpty)
            const EmptyState('Aucun ouvrier à payer : aucune activité ni solde sur ce mois.', icon: Icons.groups_outlined)
          else ...[
            AutoGrid(minItemWidth: 170, children: [
              StatTile(label: 'Gains du mois', value: fmtDA(tot((l) => l.gains)), icon: Icons.trending_up_rounded, color: AppColors.gold),
              StatTile(label: 'Avances & retenues', value: fmtDA(tot((l) => l.avances + l.retenues)), icon: Icons.north_east_rounded, color: AppColors.rose),
              StatTile(label: 'Net à payer', value: fmtDA(tot((l) => l.net)), icon: Icons.account_balance_wallet_rounded, color: AppColors.green),
              if (tot((l) => l.paye) > 0)
                StatTile(label: 'Réglé à la clôture', value: fmtDA(tot((l) => l.paye)), icon: Icons.payments_rounded, color: AppColors.sky),
            ]),
            const SizedBox(height: 12),
            if (c != null)
              AppCard(
                padding: const EdgeInsets.all(12),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  FilledButton.icon(onPressed: () => _pdf(c.lignes), icon: const Icon(Icons.print_rounded), label: const Text('Imprimer état + fiches')),
                  OutlinedButton.icon(onPressed: () => _pdf(c.lignes, partage: true), icon: const Icon(Icons.share_rounded), label: const Text('Partager')),
                  if (session.admin)
                    TextButton.icon(onPressed: _reouvrir, icon: const Icon(Icons.lock_open_rounded), label: const Text('Réouvrir le mois')),
                ]),
              )
            else
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: CheckboxListTile(
                  value: lignes.where((l) => l.net > 0).every((l) => _payer.contains(l.ouvrierId)),
                  onChanged: (v) => setState(() {
                    _payer.clear();
                    if (v == true) _payer.addAll(lignes.where((l) => l.net > 0).map((l) => l.ouvrierId));
                  }),
                  title: const Text('Payer tout le monde maintenant', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Enregistre un paiement du net pour chaque ouvrier (fiches marquées « PAYÉE »)'),
                ),
              ),
            const SizedBox(height: 12),
            for (final l in lignes) _ligne(context, l, modifiable: c == null),
          ],
        ],
      ),
    );
  }

  Widget _ligne(BuildContext context, LignePaie l, {required bool modifiable}) {
    final o = data.ouvrier(l.ouvrierId);
    final details = [
      if (l.anterieur != 0) 'Report ${fmtDA(l.anterieur)}',
      'Gains ${fmtDA(l.gains)}',
      if (l.deductions != 0) 'Déductions ${fmtDA(l.deductions)}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            NameAvatar(l.nom),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text([if (l.departement.isNotEmpty) l.departement, details].join(' · '),
                    style: TextStyle(fontSize: 12, color: context.cs.onSurfaceVariant)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtDA(l.net), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: l.net >= 0 ? AppColors.green : AppColors.rose)),
              Text(l.net >= 0 ? 'net à payer' : 'avance à reporter', style: TextStyle(fontSize: 11, color: context.cs.onSurfaceVariant)),
              if (l.paye > 0) Text('réglé ${fmtDA(l.paye)}', style: const TextStyle(fontSize: 11, color: AppColors.sky, fontWeight: FontWeight.w700)),
            ]),
          ]),
          if (modifiable) ...[
            const SizedBox(height: 4),
            Wrap(spacing: 8, children: [
              if (_sansSalaire.contains(l.ouvrierId))
                FilterChip(
                  selected: _ajouterSalaire.contains(l.ouvrierId),
                  onSelected: (v) => setState(() => v ? _ajouterSalaire.add(l.ouvrierId) : _ajouterSalaire.remove(l.ouvrierId)),
                  label: Text('Ajouter le salaire ${fmtDA(o?.salaireMensuel ?? 0)}'),
                ),
              if (l.net > 0)
                FilterChip(
                  selected: _payer.contains(l.ouvrierId),
                  onSelected: (v) => setState(() => v ? _payer.add(l.ouvrierId) : _payer.remove(l.ouvrierId)),
                  label: const Text('Payer maintenant'),
                ),
            ]),
          ] else
            const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

// ====================================================================== journal des actions

const _champs = {
  'nom': 'Nom',
  'montant': 'Montant',
  'quantite': 'Quantité',
  'prix_unitaire': 'Prix unitaire',
  'prix_gros': 'Prix de gros',
  'prix_detail': 'Prix détail',
  'cout_revient': 'Coût de revient',
  'date_mvt': 'Date',
  'date_prod': 'Date',
  'date_vente': 'Date',
  'date_travail': 'Date',
  'type': 'Type',
  'note': 'Note',
  'actif': 'Actif',
  'statut': 'Statut',
  'remise': 'Remise',
  'total_ttc': 'Total TTC',
  'nb_robes': 'Nombre de robes',
  'points_par_robe': 'Points par robe',
  'tarif_1000': 'Tarif / 1000 points',
  'salaire_mensuel': 'Salaire mensuel',
  'prix_piece': 'Prix à la pièce',
  'mode_paie': 'Mode de paie',
  'telephone': 'Téléphone',
  'role': 'Rôle',
  'perm_broderie': 'Accès broderie',
  'perm_paie': 'Accès paie',
  'perm_stock': 'Accès stock',
  'seuil_alerte': 'Seuil d\'alerte',
  'couleur': 'Couleur',
  'taille': 'Taille',
  'designation': 'Désignation',
  'reference': 'Référence',
};

const _periodes = [('Aujourd\'hui', 0), ('7 jours', 7), ('30 jours', 30), ('Tout', -1)];

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final List<ActionJournal> _items = [];
  List<String> _utilisateurs = [];
  String? _utilisateur;
  String? _espace;
  String? _action;
  int _jours = 7;
  bool _loading = true;
  bool _fin = false;
  String? _err;

  static final _espaces = {for (final v in tablesJournal.values) v.$2}.toList();

  @override
  void initState() {
    super.initState();
    gestion.utilisateursJournal().then((u) {
      if (mounted) setState(() => _utilisateurs = u);
    }).catchError((_) {});
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _err = null;
      if (reset) {
        _items.clear();
        _fin = false;
      }
    });
    try {
      final now = DateTime.now();
      final page = await gestion.journal(
        offset: _items.length,
        utilisateur: _utilisateur,
        action: _action,
        tables: _espace == null ? null : [for (final e in tablesJournal.entries) if (e.value.$2 == _espace) e.key],
        depuis: _jours < 0 ? null : DateTime(now.year, now.month, now.day).subtract(Duration(days: _jours)),
      );
      _items.addAll(page);
      _fin = page.length < 60;
    } catch (e) {
      _err = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _filtre(VoidCallback f) {
    setState(f);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    DateTime? jour;
    for (final a in _items) {
      final d = DateTime(a.date.year, a.date.month, a.date.day);
      if (jour != d) {
        jour = d;
        rows.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(fmtDateLong(d), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold, letterSpacing: 0.5)),
        ));
      }
      rows.add(_tuile(context, a));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Journal des actions'), actions: [
        IconButton(tooltip: 'Actualiser', onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final p in _periodes)
                  ChoiceChip(label: Text(p.$1), selected: _jours == p.$2, onSelected: (_) => _filtre(() => _jours = p.$2)),
                const SizedBox(width: 6),
                DropdownButton<String?>(
                  value: _utilisateur,
                  hint: const Text('Tous les utilisateurs'),
                  underline: const SizedBox.shrink(),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les utilisateurs')),
                    for (final u in _utilisateurs) DropdownMenuItem(value: u, child: Text(u)),
                  ],
                  onChanged: (v) => _filtre(() => _utilisateur = v),
                ),
              ]),
              const Divider(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('Tout'), selected: _espace == null, onSelected: (_) => _filtre(() => _espace = null)),
                for (final e in _espaces) ChoiceChip(label: Text(e), selected: _espace == e, onSelected: (_) => _filtre(() => _espace = e)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in const [(null, 'Toutes les actions'), ('ajout', 'Ajouts'), ('modification', 'Modifications'), ('suppression', 'Suppressions')])
                  ChoiceChip(
                    label: Text(a.$2),
                    selected: _action == a.$1,
                    selectedColor: a.$1 == 'suppression' ? AppColors.rose.withValues(alpha: 0.25) : null,
                    onSelected: (_) => _filtre(() => _action = a.$1),
                  ),
              ]),
            ]),
          ),
          if (_err != null) ...[const SizedBox(height: 12), ErrorBanner(_err!, onRetry: () => _load(reset: true))],
          if (!_loading && _err == null && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 30),
              child: EmptyState('Aucune action enregistrée pour ces filtres.', icon: Icons.history_rounded),
            ),
          ...rows,
          if (_loading)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (!_fin && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.expand_more_rounded), label: const Text('Voir plus')),
            ),
        ],
      ),
    );
  }

  Widget _tuile(BuildContext context, ActionJournal a) {
    final (couleur, icone, verbe) = switch (a.action) {
      'ajout' => (AppColors.green, Icons.add_rounded, 'a ajouté'),
      'modification' => (AppColors.sky, Icons.edit_rounded, 'a modifié'),
      _ => (AppColors.rose, Icons.delete_rounded, 'a supprimé'),
    };
    final quoi = tablesJournal[a.table]?.$1 ?? a.table;
    final heure = '${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}';
    final champs = a.changements?.keys.map((k) => _champs[k] ?? k.replaceAll('_', ' ')).take(4).join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: a.changements == null ? null : () => _details(context, a, quoi),
          leading: CircleAvatar(backgroundColor: couleur.withValues(alpha: 0.15), child: Icon(icone, color: couleur, size: 20)),
          title: Text.rich(TextSpan(children: [
            TextSpan(text: a.userNom ?? '—', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' $verbe '),
            TextSpan(text: quoi.toLowerCase(), style: TextStyle(fontWeight: FontWeight.w700, color: couleur)),
          ])),
          subtitle: Text(
            [
              if ((a.libelle ?? '').isNotEmpty) a.libelle!,
              if (a.montant != null) fmtDA(a.montant!),
              if (champs != null && champs.isNotEmpty) 'champs : $champs',
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(heure, style: TextStyle(fontWeight: FontWeight.w700, color: context.cs.onSurfaceVariant)),
        ),
      ),
    );
  }

  void _details(BuildContext context, ActionJournal a, String quoi) {
    String v(Object? x) => switch (x) {
          null => '—',
          true => 'Oui',
          false => 'Non',
          _ => '$x',
        };
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$quoi modifié'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('${a.userNom ?? '—'} · ${fmtDate(a.date)} à ${a.date.hour.toString().padLeft(2, '0')}:${a.date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: context.cs.onSurfaceVariant)),
              const SizedBox(height: 12),
              for (final e in a.changements!.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_champs[e.key] ?? e.key.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Flexible(child: Text(v((e.value as List)[0]), style: const TextStyle(color: AppColors.rose, decoration: TextDecoration.lineThrough))),
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 16)),
                      Flexible(child: Text(v(e.value[1]), style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w700))),
                    ]),
                  ]),
                ),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
