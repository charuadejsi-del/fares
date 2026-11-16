import 'package:flutter/material.dart';

import '../../data/commerce.dart';
import '../../data/stock.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import '../refs_screens.dart' show FormDialog;
import '../../i18n.dart';

/// Espace « Achats » : matières, achats, fournisseurs.
class AchatsModule extends StatefulWidget {
  const AchatsModule({super.key});

  @override
  State<AchatsModule> createState() => _AchatsModuleState();
}

class _AchatsModuleState extends State<AchatsModule> {
  int _vue = 0;

  final _historique = <int>[];

  bool _peut() => mounted && PageActive.of(context) && _historique.isNotEmpty;

  bool _revenir() {
    if (!_peut()) return false;
    setState(() => _vue = _historique.removeLast());
    Retours.signaler();
    return true;
  }

  @override
  void initState() {
    super.initState();
    Retours.inscrire(_peut, _revenir);
    if (!commerce.loaded) commerce.load().catchError((_) {});
  }

  @override
  void dispose() {
    Retours.desinscrire(_peut, _revenir);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, icon: Icon(Icons.layers_rounded), label: Text('Matières'.tr)),
              ButtonSegment(value: 1, icon: Icon(Icons.shopping_basket_rounded), label: Text('Achats'.tr)),
              ButtonSegment(value: 2, icon: Icon(Icons.local_shipping_rounded), label: Text('Fournisseurs'.tr)),
            ],
            selected: {_vue},
            onSelectionChanged: (s) {
              if (s.first == _vue) return;
              _historique.add(_vue);
              setState(() => _vue = s.first);
              Retours.signaler();
            },
          ),
        ),
        Expanded(
          child: switch (_vue) {
            0 => const _MatieresView(),
            1 => const _AchatsView(),
            _ => const _FournisseursView(),
          },
        ),
      ]);
}

String fmtQte(double q, String unite) => '${fmtNum(q)} $unite';

// ======================================================================= matières

class _MatieresView extends StatefulWidget {
  const _MatieresView();

  @override
  State<_MatieresView> createState() => _MatieresViewState();
}

class _MatieresViewState extends State<_MatieresView> {
  String _q = '';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: commerce,
        builder: (context, _) {
          final q = _q.toLowerCase();
          final list = commerce.matieres.where((m) => q.isEmpty || m.nom.toLowerCase().contains(q) || (m.categorie ?? '').toLowerCase().contains(q)).toList();
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-mat',
              onPressed: () => showDialog<String>(context: context, builder: (_) => const MatiereForm()),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvelle matière'.tr),
            ),
            body: RefreshIndicator(
              onRefresh: commerce.load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
                AutoGrid(minItemWidth: 170, children: [
                  StatTile(label: 'Valeur des matières'.tr, value: fmtDA(commerce.valeurMatieres), icon: Icons.savings_rounded, color: AppColors.green),
                  StatTile(label: 'Matières'.tr, value: '${commerce.matieres.length}', icon: Icons.layers_rounded, color: AppColors.violet),
                  StatTile(label: 'En alerte'.tr, value: '${commerce.nbAlertesMatieres}', icon: Icons.warning_amber_rounded, color: AppColors.rose),
                ]),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(hintText: 'Tissu, fil, perles…'.tr, prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _q = v),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  EmptyState('Aucune matière.\nAjoutez vos tissus, fils, perles… puis enregistrez vos achats.'.tr, icon: Icons.layers_outlined)
                else
                  AutoGrid(minItemWidth: 320, children: [
                    for (final m in list)
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MatiereDetailScreen(matiereId: m.id))),
                        child: Row(children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.forName(m.nom).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.layers_rounded, color: AppColors.forName(m.nom)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                              Text([if (m.categorie != null) m.categorie!, 'coût moyen ${fmtDA(m.coutMoyen)} / ${m.unite}'].join(' · '),
                                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                          Text(fmtQte(m.stock, m.unite),
                              style: TextStyle(fontWeight: FontWeight.w900, color: m.enAlerte ? AppColors.rose : AppColors.green)),
                        ]),
                      ),
                  ]),
              ]),
            ),
          );
        },
      );
}

class MatiereForm extends StatefulWidget {
  final Matiere? m;
  const MatiereForm({super.key, this.m});

  @override
  State<MatiereForm> createState() => _MatiereFormState();
}

class _MatiereFormState extends State<MatiereForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.m?.nom);
  late final _cat = TextEditingController(text: widget.m?.categorie);
  late final _seuil = TextEditingController(text: widget.m == null ? '' : fmtNum(widget.m!.seuilAlerte).replaceAll(RegExp(r'\s'), ''));
  late String _unite = widget.m?.unite ?? 'm';
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await commerce.saveMatiere({
        'nom': _nom.text.trim(),
        'categorie': _cat.text.trim().isEmpty ? null : _cat.text.trim(),
        'unite': _unite,
        'seuil_alerte': parseNum(_seuil.text) ?? 0,
      }, id: widget.m?.id);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.m == null ? 'Nouvelle matière'.tr : 'Modifier la matière'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: widget.m == null,
            decoration: InputDecoration(labelText: 'Nom (ex. Tissu satin noir)'.tr, prefixIcon: Icon(Icons.layers_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(controller: _cat, decoration: InputDecoration(labelText: 'Catégorie (Tissu, Fil, Perles…)'.tr, prefixIcon: Icon(Icons.category_outlined))),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final u in unitesMatieres) ChoiceChip(label: Text(u), selected: _unite == u, onSelected: (_) => setState(() => _unite = u)),
          ]),
          TextFormField(
            controller: _seuil,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Alerte si stock ≤'.tr, suffixText: _unite, prefixIcon: const Icon(Icons.warning_amber_rounded)),
          ),
        ],
      );
}

class MatiereDetailScreen extends StatefulWidget {
  final String matiereId;
  const MatiereDetailScreen({super.key, required this.matiereId});

  @override
  State<MatiereDetailScreen> createState() => _MatiereDetailScreenState();
}

class _MatiereDetailScreenState extends State<MatiereDetailScreen> {
  List<MatiereMvt> _mvts = [];
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    commerce.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    commerce.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (commerce.version != _seen) _load();
  }

  Future<void> _load() async {
    _seen = commerce.version;
    try {
      final m = await commerce.mouvementsMatiere(widget.matiereId);
      if (mounted) setState(() => _mvts = m);
    } catch (_) {}
  }

  Future<void> _mouvement(Matiere m, {required bool inventaire}) async {
    final c = TextEditingController(text: inventaire ? fmtNum(m.stock).replaceAll(RegExp(r'\s'), '') : '');
    final note = TextEditingController();
    final v = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inventaire ? 'Inventaire · {0}'.trf([m.nom]) : 'Consommation · {0}'.trf([m.nom])),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: inventaire ? 'Quantité réelle comptée'.tr : 'Quantité utilisée'.tr, suffixText: m.unite),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: InputDecoration(labelText: 'Remarque'.tr)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Valider'.tr)),
        ],
      ),
    );
    if (v != true) return;
    final q = parseNum(c.text);
    if (q == null) return;
    try {
      if (inventaire) {
        final diff = q - m.stock;
        if (diff.abs() > 0.0005) await commerce.mouvementMatiere(m.id, 'ajustement', diff, note: note.text.isEmpty ? 'Inventaire'.tr : note.text);
      } else if (q > 0) {
        await commerce.mouvementMatiere(m.id, 'consommation', -q, note: note.text);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: commerce,
        builder: (context, _) {
          final m = commerce.matiere(widget.matiereId);
          if (m == null) return Scaffold(appBar: AppBar(), body: EmptyState('Matière introuvable.'.tr));
          return Scaffold(
            appBar: AppBar(title: Text(m.nom), actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog<String>(context: context, builder: (_) => MatiereForm(m: m))),
              PopupMenuButton<String>(
                itemBuilder: (_) => [PopupMenuItem(value: 'del', child: Text('Supprimer'.tr))],
                onSelected: (_) async {
                  if (!await confirmDialog(context, 'Supprimer'.tr, 'Supprimer {0} ?'.trf([m.nom]))) return;
                  try {
                    await commerce.deleteMatiere(m.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (context.mounted) showSnack(context, 'Impossible : cette matière a des achats ou est utilisée.'.tr, error: true);
                  }
                },
              ),
            ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AutoGrid(minItemWidth: 160, children: [
                StatTile(label: 'En stock'.tr, value: fmtQte(m.stock, m.unite), icon: Icons.inventory_2_rounded, color: m.enAlerte ? AppColors.rose : AppColors.green),
                StatTile(label: 'Coût moyen'.tr, value: '${fmtDA(m.coutMoyen)} / ${m.unite}', icon: Icons.price_change_rounded, color: AppColors.violet),
                StatTile(label: 'Valeur'.tr, value: fmtDA(m.valeur), icon: Icons.savings_rounded, color: AppColors.gold),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchatEditorScreen(matiereInitiale: m))),
                  icon: const Icon(Icons.shopping_basket_rounded),
                  label: Text('Acheter'.tr),
                ),
                OutlinedButton.icon(onPressed: () => _mouvement(m, inventaire: false), icon: const Icon(Icons.content_cut_rounded), label: Text('Consommation'.tr)),
                OutlinedButton.icon(onPressed: () => _mouvement(m, inventaire: true), icon: const Icon(Icons.fact_check_rounded), label: Text('Inventaire'.tr)),
              ]),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle('Historique'.tr),
                  if (_mvts.isEmpty) EmptyState('Aucun mouvement.'.tr, icon: Icons.history_rounded),
                  for (final x in _mvts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Icon(x.quantite > 0 ? Icons.south_west_rounded : Icons.north_east_rounded, size: 20, color: x.quantite > 0 ? AppColors.green : AppColors.rose),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(x.typeTexte, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${fmtDate(x.date)}${x.note != null ? ' · ${x.note}' : ''}', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                          ]),
                        ),
                        Text('${x.quantite > 0 ? '+' : ''}${fmtNum(x.quantite)} ${m.unite}',
                            style: TextStyle(fontWeight: FontWeight.w900, color: x.quantite > 0 ? AppColors.green : AppColors.rose)),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      );
}

// ======================================================================= achats

class _AchatsView extends StatefulWidget {
  const _AchatsView();

  @override
  State<_AchatsView> createState() => _AchatsViewState();
}

class _AchatsViewState extends State<_AchatsView> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  List<Achat> _achats = [];
  bool _loading = true;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    commerce.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    commerce.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (commerce.version != _seen) _load();
  }

  Future<void> _load() async {
    _seen = commerce.version;
    final r = rangeFor(_periode, _custom);
    try {
      final a = await commerce.achats(from: r.start, to: r.end);
      if (mounted) setState(() => _achats = a);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final total = _achats.fold<double>(0, (s, a) => s + a.total);
    final reste = _achats.fold<double>(0, (s, a) => s + (a.reste > 0 ? a.reste : 0));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-achat',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchatEditorScreen())),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text('Nouvel achat'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
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
          const SizedBox(height: 12),
          AutoGrid(minItemWidth: 170, children: [
            StatTile(label: 'Achats de la période'.tr, value: fmtDA(total), icon: Icons.shopping_basket_rounded, color: AppColors.violet),
            StatTile(label: 'Reste à payer (période)'.tr, value: fmtDA(reste), icon: Icons.hourglass_bottom_rounded, color: AppColors.rose),
            StatTile(label: 'Dettes fournisseurs (total)'.tr, value: fmtDA(commerce.totalDettes), icon: Icons.account_balance_rounded, color: const Color(0xFFF97316)),
          ]),
          const SizedBox(height: 12),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (!_loading && _achats.isEmpty) EmptyState('Aucun achat sur cette période.'.tr, icon: Icons.shopping_basket_outlined),
          if (_achats.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              child: Column(children: [
                for (var i = 0; i < _achats.length; i++) ...[
                  AchatTile(_achats[i]),
                  if (i < _achats.length - 1) const Divider(height: 1),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class AchatTile extends StatelessWidget {
  final Achat a;
  const AchatTile(this.a, {super.key});

  @override
  Widget build(BuildContext context) {
    final paye = a.reste <= 0.005;
    return InkWell(
      onTap: () => showDialog<void>(context: context, builder: (_) => _AchatDetailDialog(achat: a)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: (paye ? AppColors.green : AppColors.rose).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.shopping_basket_rounded, color: paye ? AppColors.green : AppColors.rose, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a.numero} · ${a.fournisseurNom ?? 'Sans fournisseur'.tr}', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text('${fmtDate(a.date)} · ${paye ? 'Payé'.tr : 'Reste {0}'.trf([fmtDA(a.reste)])}', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
            ]),
          ),
          Text(fmtDA(a.total), style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _AchatDetailDialog extends StatefulWidget {
  final Achat achat;
  const _AchatDetailDialog({required this.achat});

  @override
  State<_AchatDetailDialog> createState() => _AchatDetailDialogState();
}

class _AchatDetailDialogState extends State<_AchatDetailDialog> {
  List<AchatLigne> _l = [];

  @override
  void initState() {
    super.initState();
    commerce.achatLignes(widget.achat.id).then((l) {
      if (mounted) setState(() => _l = l);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achat;
    final f = commerce.fournisseur(a.fournisseurId);
    return AlertDialog(
      title: Text('Achat {0}'.trf([a.numero])),
      content: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${a.fournisseurNom ?? 'Sans fournisseur'.tr} · ${fmtDate(a.date)}'),
          const Divider(height: 20),
          for (final l in _l)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Expanded(child: Text(commerce.matiere(l.matiereId)?.nom ?? '?')),
                Text('{0} {1} × {2}'.trf([fmtNum(l.quantite), commerce.matiere(l.matiereId)?.unite ?? '', fmtDA(l.prixUnitaire)])),
              ]),
            ),
          const Divider(height: 20),
          Row(children: [Expanded(child: Text('Total'.tr)), Text(fmtDA(a.total), style: const TextStyle(fontWeight: FontWeight.w900))]),
          Row(children: [Expanded(child: Text('Payé'.tr)), Text(fmtDA(a.paye), style: const TextStyle(color: AppColors.green))]),
          Row(children: [
            Expanded(child: Text('Reste'.tr, style: TextStyle(fontWeight: FontWeight.w800))),
            Text(fmtDA(a.reste), style: TextStyle(fontWeight: FontWeight.w900, color: a.reste > 0.005 ? AppColors.rose : AppColors.green)),
          ]),
          if (a.note != null) ...[const SizedBox(height: 8), Text('Remarque : {0}'.trf([a.note]))],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'.tr)),
        if (f != null && a.reste > 0.005)
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await ouvrirPaiementFournisseur(context, f, achat: a);
            },
            icon: const Icon(Icons.payments_rounded),
            label: Text('Payer'.tr),
          ),
      ],
    );
  }
}

class AchatEditorScreen extends StatefulWidget {
  final Matiere? matiereInitiale;
  final String? fournisseurId;
  const AchatEditorScreen({super.key, this.matiereInitiale, this.fournisseurId});

  @override
  State<AchatEditorScreen> createState() => _AchatEditorScreenState();
}

class _AchatEditorScreenState extends State<AchatEditorScreen> {
  late String? _fournisseurId = widget.fournisseurId;
  DateTime _date = dayOnly(DateTime.now());
  final List<LigneAchat> _lignes = [];
  final _paiement = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'especes';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.matiereInitiale != null) _lignes.add(LigneAchat(widget.matiereInitiale!));
    _paiement.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _paiement.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _total => _lignes.fold<double>(0, (s, l) => s + l.montant);

  Future<void> _ajouter() async {
    final m = await showDialog<Matiere>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Choisir une matière'.tr),
        children: [
          for (final m in commerce.matieres.where((m) => m.actif))
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, m), child: Text('${m.nom} (${m.unite})')),
          SimpleDialogOption(
            onPressed: () async {
              final id = await showDialog<String>(context: ctx, builder: (_) => const MatiereForm());
              if (id != null && ctx.mounted) Navigator.pop(ctx, commerce.matiere(id));
            },
            child: Text('+ Nouvelle matière'.tr, style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (m != null) setState(() => _lignes.add(LigneAchat(m)));
  }

  Future<void> _save() async {
    if (_lignes.isEmpty) return;
    final pay = parseNum(_paiement.text) ?? 0;
    if (pay > 0 && _fournisseurId == null) {
      showSnack(context, 'Choisissez le fournisseur pour enregistrer un paiement'.tr, error: true);
      return;
    }
    if (_lignes.any((l) => l.quantite <= 0)) {
      showSnack(context, 'Quantité invalide'.tr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await commerce.creerAchat(fournisseurId: _fournisseurId, date: _date, lignes: _lignes, paiement: pay, mode: _mode, note: _note.text);
      if (mounted) {
        showSnack(context, 'Achat enregistré, stock des matières mis à jour'.tr);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Nouvel achat de matières'.tr)),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              DropdownButtonFormField<String?>(
                value: _fournisseurId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Fournisseur'.tr, prefixIcon: Icon(Icons.local_shipping_outlined)),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text('Sans fournisseur'.tr)),
                  for (final f in commerce.fournisseurs.where((f) => f.actif)) DropdownMenuItem<String?>(value: f.id, child: Text(f.nom)),
                ],
                onChanged: (v) => setState(() => _fournisseurId = v),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final id = await showDialog<String>(context: context, builder: (_) => const FournisseurForm());
                    if (id != null) setState(() => _fournisseurId = id);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Nouveau fournisseur'.tr),
                ),
              ),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(decoration: InputDecoration(labelText: 'Date'.tr, prefixIcon: Icon(Icons.event)), child: Text(fmtDate(_date))),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Matières achetées'.tr,
                  trailing: FilledButton.tonalIcon(onPressed: _ajouter, icon: const Icon(Icons.add_rounded), label: Text('Ajouter'.tr))),
              if (_lignes.isEmpty) EmptyState('Ajoutez les matières achetées.'.tr, icon: Icons.layers_outlined),
              for (final l in _lignes)
                Padding(
                  key: ObjectKey(l),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Expanded(child: Text(l.matiere.nom, style: const TextStyle(fontWeight: FontWeight.w800))),
                      IconButton(onPressed: () => setState(() => _lignes.remove(l)), icon: Icon(Icons.delete_outline, color: context.pal.muted)),
                    ]),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: fmtNum(l.quantite).replaceAll(RegExp(r'\s'), ''),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Quantité'.tr, suffixText: l.matiere.unite),
                          onChanged: (v) => setState(() => l.quantite = parseNum(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: l.prix == 0 ? '' : fmtNum(l.prix).replaceAll(RegExp(r'\s'), ''),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(labelText: 'Prix / {0}'.trf([l.matiere.unite]), suffixText: 'DA'.tr),
                          onChanged: (v) => setState(() => l.prix = parseNum(v) ?? 0),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 100, child: Text(fmtDA(l.montant), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
                    ]),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('TOTAL'.tr, style: TextStyle(fontWeight: FontWeight.w900))),
                Text(fmtDA(_total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: context.cs.primary)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _paiement,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Payé maintenant'.tr,
                  suffixText: 'DA'.tr,
                  suffixIcon: TextButton(onPressed: () => _paiement.text = _total.toStringAsFixed(0), child: Text('Tout'.tr)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in modesPaiement.entries) ChoiceChip(label: Text(m.value.tr), selected: _mode == m.key, onSelected: (_) => setState(() => _mode = m.key)),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _note, decoration: InputDecoration(labelText: 'Remarque (n° de facture fournisseur…)'.tr, prefixIcon: Icon(Icons.notes))),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _busy || _lignes.isEmpty ? null : _save,
                  icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                  label: Text('Enregistrer l\'achat · {0}'.trf([fmtDA(_total)])),
                ),
              ),
            ]),
          ),
        ]),
      );
}

// ======================================================================= fournisseurs

class _FournisseursView extends StatelessWidget {
  const _FournisseursView();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: commerce,
        builder: (context, _) => Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'fab-fourn',
            onPressed: () => showDialog<String>(context: context, builder: (_) => const FournisseurForm()),
            icon: const Icon(Icons.add_business_rounded),
            label: Text('Nouveau fournisseur'.tr),
          ),
          body: RefreshIndicator(
            onRefresh: commerce.load,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
              StatTile(label: 'Je dois aux fournisseurs'.tr, value: fmtDA(commerce.totalDettes), icon: Icons.account_balance_rounded, color: AppColors.rose),
              const SizedBox(height: 12),
              if (commerce.fournisseurs.isEmpty) EmptyState('Aucun fournisseur.'.tr, icon: Icons.local_shipping_outlined),
              AutoGrid(minItemWidth: 320, children: [
                for (final f in commerce.fournisseurs)
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FournisseurDetailScreen(fournisseurId: f.id))),
                    child: Row(children: [
                      NameAvatar(f.nom, size: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('Achats {0}{1}'.trf([fmtDA(f.totalAchats), f.telephone != null ? ' · ${f.telephone}' : '']),
                              style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      Text(f.solde > 0.005 ? 'Je dois {0}'.trf([fmtDA(f.solde)]) : 'À jour'.tr,
                          style: TextStyle(fontWeight: FontWeight.w900, color: f.solde > 0.005 ? AppColors.rose : AppColors.green)),
                    ]),
                  ),
              ]),
            ]),
          ),
        ),
      );
}

class FournisseurForm extends StatefulWidget {
  final Fournisseur? f;
  const FournisseurForm({super.key, this.f});

  @override
  State<FournisseurForm> createState() => _FournisseurFormState();
}

class _FournisseurFormState extends State<FournisseurForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.f?.nom);
  late final _tel = TextEditingController(text: widget.f?.telephone);
  late final _adr = TextEditingController(text: widget.f?.adresse);
  late final _note = TextEditingController(text: widget.f?.note);
  bool _busy = false;

  String? _n(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await commerce.saveFournisseur({'nom': _nom.text.trim(), 'telephone': _n(_tel), 'adresse': _n(_adr), 'note': _n(_note)}, id: widget.f?.id);
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.f == null ? 'Nouveau fournisseur'.tr : 'Modifier le fournisseur'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: widget.f == null,
            decoration: InputDecoration(labelText: 'Nom'.tr, prefixIcon: Icon(Icons.local_shipping_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(controller: _tel, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: 'Téléphone'.tr, prefixIcon: Icon(Icons.phone_outlined))),
          TextFormField(controller: _adr, decoration: InputDecoration(labelText: 'Adresse'.tr, prefixIcon: Icon(Icons.place_outlined))),
          TextFormField(controller: _note, decoration: InputDecoration(labelText: 'Remarque'.tr, prefixIcon: Icon(Icons.notes))),
        ],
      );
}

Future<void> ouvrirPaiementFournisseur(BuildContext context, Fournisseur f, {Achat? achat}) async {
  final mt = TextEditingController(text: achat != null ? achat.reste.toStringAsFixed(0) : (f.solde > 0 ? f.solde.toStringAsFixed(0) : ''));
  final note = TextEditingController();
  var mode = 'especes';
  var date = dayOnly(DateTime.now());
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text('Payer {0}'.trf([f.nom])),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(achat != null ? 'Achat {0} · reste {1}'.trf([achat.numero, fmtDA(achat.reste)]) : 'Je dois : {0}'.trf([fmtDA(f.solde)])),
          const SizedBox(height: 10),
          TextField(
            controller: mt,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Montant payé'.tr, suffixText: 'DA'.tr),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in modesPaiement.entries) ChoiceChip(label: Text(m.value.tr), selected: mode == m.key, onSelected: (_) => setD(() => mode = m.key)),
          ]),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (d != null) setD(() => date = d);
            },
            child: InputDecorator(decoration: InputDecoration(labelText: 'Date'.tr), child: Text(fmtDate(date))),
          ),
          const SizedBox(height: 8),
          TextField(controller: note, decoration: InputDecoration(labelText: 'Remarque'.tr)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
        ],
      ),
    ),
  );
  if (ok != true) return;
  final v = parseNum(mt.text);
  if (v == null || v <= 0) return;
  try {
    await commerce.savePaiementFournisseur(fournisseurId: f.id, achatId: achat?.id, date: date, montant: v, mode: mode, note: note.text);
    if (context.mounted) showSnack(context, 'Paiement enregistré'.tr);
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e), error: true);
  }
}

class FournisseurDetailScreen extends StatefulWidget {
  final String fournisseurId;
  const FournisseurDetailScreen({super.key, required this.fournisseurId});

  @override
  State<FournisseurDetailScreen> createState() => _FournisseurDetailScreenState();
}

class _FournisseurDetailScreenState extends State<FournisseurDetailScreen> {
  List<Achat> _achats = [];
  List<PaiementFournisseur> _paiements = [];
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    commerce.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    commerce.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (commerce.version != _seen) _load();
  }

  Future<void> _load() async {
    _seen = commerce.version;
    try {
      final r = await Future.wait<Object>([
        commerce.achats(fournisseurId: widget.fournisseurId),
        commerce.paiementsFournisseur(fournisseurId: widget.fournisseurId),
      ]);
      if (mounted) setState(() {
        _achats = r[0] as List<Achat>;
        _paiements = r[1] as List<PaiementFournisseur>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: commerce,
        builder: (context, _) {
          final f = commerce.fournisseur(widget.fournisseurId);
          if (f == null) return Scaffold(appBar: AppBar(), body: EmptyState('Fournisseur introuvable.'.tr));
          return Scaffold(
            appBar: AppBar(title: Text(f.nom), actions: [
              IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog<String>(context: context, builder: (_) => FournisseurForm(f: f))),
            ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                gradient: f.solde > 0.005 ? const LinearGradient(colors: [Color(0xFFBE123C), Color(0xFFF43F5E)]) : const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(f.solde > 0.005 ? 'Je dois encore'.tr : 'Compte à jour'.tr, style: const TextStyle(color: Colors.white70)),
                  Text(fmtDA(f.solde.abs()), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  Text('Achats {0} · Payé {1}'.trf([fmtDA(f.totalAchats), fmtDA(f.totalPaye)]), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87),
                      onPressed: () => ouvrirPaiementFournisseur(context, f),
                      icon: const Icon(Icons.payments_rounded),
                      label: Text('Payer'.tr),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AchatEditorScreen(fournisseurId: f.id))),
                      icon: const Icon(Icons.add_shopping_cart_rounded),
                      label: Text('Nouvel achat'.tr),
                    ),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 16, 8, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(padding: EdgeInsets.only(left: 4), child: SectionTitle('Achats'.tr)),
                  if (_achats.isEmpty) EmptyState('Aucun achat.'.tr, icon: Icons.shopping_basket_outlined),
                  for (final a in _achats) AchatTile(a),
                ]),
              ),
              const SizedBox(height: 12),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionTitle('Paiements'.tr),
                  if (_paiements.isEmpty) EmptyState('Aucun paiement.'.tr, icon: Icons.payments_outlined),
                  for (final p in _paiements)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const Icon(Icons.payments_rounded, color: AppColors.green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${fmtDate(p.date)} · ${p.modeTexte}${p.note != null ? ' · ${p.note}' : ''}', overflow: TextOverflow.ellipsis)),
                        Text(fmtDA(p.montant), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.green)),
                        IconButton(
                          icon: Icon(Icons.delete_outline, size: 18, color: context.pal.muted),
                          onPressed: () async {
                            if (await confirmDialog(context, 'Supprimer'.tr, 'Supprimer ce paiement de {0} ?'.trf([fmtDA(p.montant)]))) {
                              await commerce.deletePaiementFournisseur(p.id);
                            }
                          },
                        ),
                      ]),
                    ),
                ]),
              ),
            ]),
          );
        },
      );
}
