import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/stock.dart';
import '../../pdf/documents.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import '../refs_screens.dart' show FormDialog;
import 'scan_screen.dart';

Color stockColor(Produit p) => p.rupture ? AppColors.rose : (p.enAlerte ? const Color(0xFFF97316) : AppColors.green);

/// Liste des produits et du stock.
class ProduitsScreen extends StatefulWidget {
  const ProduitsScreen({super.key});

  @override
  State<ProduitsScreen> createState() => _ProduitsScreenState();
}

class _ProduitsScreenState extends State<ProduitsScreen> {
  String _q = '';
  String? _cat;
  bool _alertes = false;
  bool _inactifs = false;

  Future<void> _scanStock() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanScreen(
          titre: 'Scanner pour le stock',
          aide: 'Scannez une étiquette pour ajouter ou retirer des pièces',
          onCode: (ctx, code) => traiterCodeStock(ctx, code),
        ),
      ));

  Future<void> _etiquettesTous(List<Produit> list) async {
    if (list.isEmpty) return;
    await showDialog<void>(context: context, builder: (_) => EtiquettesDialog(produits: list, quantiteParStock: false));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final all = stock.produits;
          final cats = all.map((p) => p.categorie).whereType<String>().toSet().toList()..sort();
          final q = _q.toLowerCase();
          final list = all
              .where((p) => _inactifs || p.actif)
              .where((p) => _cat == null || p.categorie == _cat)
              .where((p) => !_alertes || p.enAlerte)
              .where((p) =>
                  q.isEmpty ||
                  p.reference.toLowerCase().contains(q) ||
                  p.designation.toLowerCase().contains(q) ||
                  (p.couleur ?? '').toLowerCase().contains(q) ||
                  (p.taille ?? '').toLowerCase().contains(q))
              .toList();
          return Scaffold(
            floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              FloatingActionButton.extended(
                heroTag: 'fab-scan-stock',
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                onPressed: _scanStock,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner'),
              ),
              const SizedBox(height: 10),
              FloatingActionButton.extended(
                heroTag: 'fab-new-prod',
                onPressed: () => ouvrirProduitForm(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouveau produit'),
              ),
            ]),
            body: RefreshIndicator(
              onRefresh: stock.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
                children: [
                  AutoGrid(minItemWidth: 170, children: [
                    StatTile(label: 'Pièces en stock', value: fmtInt(stock.totalPieces), icon: Icons.inventory_2_rounded, color: AppColors.violet),
                    StatTile(label: 'Valeur (prix gros)', value: fmtDA(stock.valeurStock), icon: Icons.savings_rounded, color: AppColors.green),
                    StatTile(label: 'Références', value: '${all.where((p) => p.actif).length}', icon: Icons.qr_code_2_rounded, color: AppColors.sky),
                    StatTile(label: 'En alerte', value: '${stock.nbAlertes}', icon: Icons.warning_amber_rounded, color: AppColors.rose),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    SizedBox(
                      width: 300,
                      child: TextField(
                        decoration: const InputDecoration(hintText: 'Référence, nom, couleur…', prefixIcon: Icon(Icons.search)),
                        onChanged: (v) => setState(() => _q = v),
                      ),
                    ),
                    FilterChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 18),
                      label: Text('En alerte (${stock.nbAlertes})'),
                      selected: _alertes,
                      onSelected: (v) => setState(() => _alertes = v),
                    ),
                    if (all.any((p) => !p.actif))
                      FilterChip(label: const Text('Inactifs'), selected: _inactifs, onSelected: (v) => setState(() => _inactifs = v)),
                    OutlinedButton.icon(
                      onPressed: list.isEmpty ? null : () => _etiquettesTous(list),
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Étiquettes'),
                    ),
                  ]),
                  if (cats.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(label: const Text('Toutes'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
                        ),
                        for (final c in cats)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(label: Text(c), selected: _cat == c, onSelected: (_) => setState(() => _cat = c)),
                          ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (!stock.loaded)
                    const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
                  else if (list.isEmpty)
                    EmptyState(all.isEmpty ? 'Aucun produit.\nAjoutez vos robes avec leur référence : un QR code est créé automatiquement.' : 'Aucun résultat.',
                        icon: Icons.checkroom_outlined)
                  else
                    AutoGrid(minItemWidth: 330, children: [for (final p in list) _ProduitCard(p)]),
                ],
              ),
            ),
          );
        },
      );
}

class _ProduitCard extends StatelessWidget {
  final Produit p;
  const _ProduitCard(this.p);

  @override
  Widget build(BuildContext context) {
    final c = stockColor(p);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProduitDetailScreen(produitId: p.id))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: BarcodeWidget(barcode: Barcode.qrCode(), data: p.reference, width: 54, height: 54, drawText: false),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.reference, style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary, letterSpacing: 0.5)),
            Text(p.designation, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            Text([if (p.variante.isNotEmpty) p.variante, if (p.prixGros > 0) '${fmtDA(p.prixGros)} gros', if (!p.actif) 'Inactif'].join(' · '),
                style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text(fmtInt(p.stock), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: c)),
            Text(p.rupture ? 'rupture' : 'en stock', style: TextStyle(fontSize: 10.5, color: c, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}

// ======================================================================= scan → stock

Future<void> traiterCodeStock(BuildContext context, String code) async {
  final p = stock.parReference(code);
  if (p == null) {
    final creer = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Référence inconnue'),
        content: Text('Aucun produit avec la référence « $code ».\nVoulez-vous le créer ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Créer')),
        ],
      ),
    );
    if (creer == true && context.mounted) await ouvrirProduitForm(context, reference: code);
    return;
  }
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => MouvementStockSheet(produit: p),
  );
}

/// Ajouter / retirer des pièces d'un produit.
class MouvementStockSheet extends StatefulWidget {
  final Produit produit;
  final bool sortie;
  const MouvementStockSheet({super.key, required this.produit, this.sortie = false});

  @override
  State<MouvementStockSheet> createState() => _MouvementStockSheetState();
}

class _MouvementStockSheetState extends State<MouvementStockSheet> {
  late TypeStock _type = widget.sortie ? TypeStock.sortie : TypeStock.entree;
  final _qte = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool _busy = false;

  int get _n => int.tryParse(_qte.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _qte.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qte.dispose();
    _note.dispose();
    super.dispose();
  }

  void _add(int d) {
    HapticFeedback.selectionClick();
    final v = (_n + d).clamp(0, 999999);
    _qte.text = '$v';
  }

  int get _signe => switch (_type) {
        TypeStock.entree || TypeStock.retour => 1,
        TypeStock.sortie => -1,
        _ => 1,
      };

  Future<void> _save() async {
    if (_type == TypeStock.ajustement) {
      // inventaire : on donne la quantité réelle comptée
      final diff = _n - widget.produit.stock;
      if (diff == 0) {
        Navigator.pop(context, true);
        return;
      }
      setState(() => _busy = true);
      try {
        await stock.mouvement(widget.produit.id, TypeStock.ajustement, diff, note: _note.text.isEmpty ? 'Inventaire' : _note.text);
        if (mounted) {
          showSnack(context, 'Stock corrigé : ${fmtInt(_n)} pièces');
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          showSnack(context, errorMessage(e), error: true);
        }
      }
      return;
    }
    if (_n <= 0) return;
    setState(() => _busy = true);
    try {
      await stock.mouvement(widget.produit.id, _type, _signe * _n, note: _note.text);
      HapticFeedback.mediumImpact();
      if (mounted) {
        showSnack(context, '${_signe > 0 ? '+' : '−'}${fmtInt(_n)} · ${widget.produit.reference} → ${fmtInt(widget.produit.stock + _signe * _n)} en stock');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produit;
    final apres = _type == TypeStock.ajustement ? _n : p.stock + _signe * _n;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: BarcodeWidget(barcode: Barcode.qrCode(), data: p.reference, width: 46, height: 46, drawText: false),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.reference, style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary)),
                Text(p.libelle, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('En stock : ${fmtInt(p.stock)}', style: TextStyle(color: stockColor(p), fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          SegmentedButton<TypeStock>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TypeStock.entree, icon: Icon(Icons.add_box_rounded), label: Text('Entrée')),
              ButtonSegment(value: TypeStock.sortie, icon: Icon(Icons.indeterminate_check_box_rounded), label: Text('Sortie')),
              ButtonSegment(value: TypeStock.retour, icon: Icon(Icons.undo_rounded), label: Text('Retour')),
              ButtonSegment(value: TypeStock.ajustement, icon: Icon(Icons.fact_check_rounded), label: Text('Inventaire')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() {
              _type = s.first;
              if (_type == TypeStock.ajustement) _qte.text = '${p.stock}';
            }),
          ),
          const SizedBox(height: 16),
          Text(_type == TypeStock.ajustement ? 'Quantité réelle comptée' : 'Quantité', textAlign: TextAlign.center, style: context.tt.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            IconButton.filledTonal(iconSize: 30, onPressed: () => _add(-1), icon: const Icon(Icons.remove_rounded)),
            Expanded(
              child: TextField(
                controller: _qte,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: context.cs.primary),
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(vertical: 10)),
              ),
            ),
            IconButton.filledTonal(iconSize: 30, onPressed: () => _add(1), icon: const Icon(Icons.add_rounded)),
          ]),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final n in [5, 10, 20, 50, 100]) OutlinedButton(onPressed: () => _add(n), child: Text('+$n')),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _note, decoration: const InputDecoration(hintText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
          const SizedBox(height: 12),
          Text('Après : ${fmtInt(apres)} pièces en stock',
              textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: apres < 0 ? AppColors.rose : AppColors.green)),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _busy || (_type != TypeStock.ajustement && _n <= 0) ? null : _save,
              icon: _busy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_type == TypeStock.ajustement ? 'Corriger le stock' : '${_type.label} de ${fmtInt(_n)} pièce${_n > 1 ? 's' : ''}'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================================================================= formulaire produit

Future<String?> ouvrirProduitForm(BuildContext context, {Produit? produit, String? reference}) =>
    showDialog<String>(context: context, builder: (_) => ProduitForm(produit: produit, reference: reference));

class ProduitForm extends StatefulWidget {
  final Produit? produit;
  final String? reference;
  const ProduitForm({super.key, this.produit, this.reference});

  @override
  State<ProduitForm> createState() => _ProduitFormState();
}

class _ProduitFormState extends State<ProduitForm> {
  final _form = GlobalKey<FormState>();
  late final _ref = TextEditingController(text: widget.produit?.reference ?? widget.reference ?? '');
  late final _des = TextEditingController(text: widget.produit?.designation ?? 'Robe');
  late final _cat = TextEditingController(text: widget.produit?.categorie ?? '');
  late final _taille = TextEditingController(text: widget.produit?.taille ?? '');
  late final _couleur = TextEditingController(text: widget.produit?.couleur ?? '');
  late final _gros = TextEditingController(text: _f(widget.produit?.prixGros));
  late final _detail = TextEditingController(text: _f(widget.produit?.prixDetail));
  late final _cout = TextEditingController(text: _f(widget.produit?.coutRevient));
  late final _seuil = TextEditingController(text: widget.produit == null ? '5' : '${widget.produit!.seuilAlerte}');
  final _initial = TextEditingController();
  late bool _actif = widget.produit?.actif ?? true;
  bool _busy = false;

  static String _f(double? v) => v == null || v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void initState() {
    super.initState();
    if (widget.produit == null && _ref.text.isEmpty) _genererRef();
  }

  Future<void> _genererRef() async {
    try {
      final r = await stock.prochaineReference();
      if (mounted && _ref.text.isEmpty) setState(() => _ref.text = r);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_ref, _des, _cat, _taille, _couleur, _gros, _detail, _cout, _seuil, _initial]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ref = _ref.text.trim().toUpperCase();
    final doublon = stock.parReference(ref);
    if (doublon != null && doublon.id != widget.produit?.id) {
      showSnack(context, 'La référence $ref existe déjà', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await stock.saveProduit(
        Produit.toRow(
          reference: ref,
          designation: _des.text,
          categorie: _cat.text,
          taille: _taille.text,
          couleur: _couleur.text,
          prixGros: parseNum(_gros.text) ?? 0,
          prixDetail: parseNum(_detail.text) ?? 0,
          coutRevient: parseNum(_cout.text) ?? 0,
          seuilAlerte: parseInt(_seuil.text) ?? 0,
          actif: _actif,
        ),
        id: widget.produit?.id,
        stockInitial: parseInt(_initial.text) ?? 0,
      );
      if (mounted) {
        showSnack(context, 'Produit $ref enregistré');
        Navigator.pop(context, id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        final m = errorMessage(e);
        showSnack(context, m.contains('duplicate') || m.contains('unique') ? 'Cette référence existe déjà' : m, error: true);
      }
    }
  }

  Widget _row(List<Widget> c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (var i = 0; i < c.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: c[i])],
      ]);

  @override
  Widget build(BuildContext context) {
    final cats = {...stock.produits.map((p) => p.categorie).whereType<String>(), 'Robes', 'Caftans', 'Djellabas', 'Ensembles'}.toList();
    return FormDialog(
      title: widget.produit == null ? 'Nouveau produit' : 'Modifier ${widget.produit!.reference}',
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        _row([
          TextFormField(
            controller: _ref,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Référence (= QR code)',
              prefixIcon: const Icon(Icons.qr_code_2_rounded),
              suffixIcon: widget.produit == null
                  ? IconButton(tooltip: 'Générer', icon: const Icon(Icons.autorenew_rounded), onPressed: () {
                      _ref.clear();
                      _genererRef();
                    })
                  : null,
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
        ]),
        TextFormField(
          controller: _des,
          decoration: const InputDecoration(labelText: 'Désignation (ex. Robe brodée soirée)', prefixIcon: Icon(Icons.checkroom_rounded)),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
        ),
        TextFormField(controller: _cat, decoration: const InputDecoration(labelText: 'Catégorie (facultatif)', prefixIcon: Icon(Icons.category_outlined))),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in cats) ActionChip(label: Text(c), onPressed: () => setState(() => _cat.text = c)),
        ]),
        _row([
          TextFormField(controller: _taille, decoration: const InputDecoration(labelText: 'Taille')),
          TextFormField(controller: _couleur, decoration: const InputDecoration(labelText: 'Couleur')),
        ]),
        _row([
          TextFormField(
            controller: _gros,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix de gros', suffixText: 'DA'),
          ),
          TextFormField(
            controller: _detail,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Prix détail', suffixText: 'DA'),
          ),
        ]),
        _row([
          TextFormField(
            controller: _cout,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Coût de revient', suffixText: 'DA'),
          ),
          TextFormField(
            controller: _seuil,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Alerte si stock ≤'),
          ),
        ]),
        if (widget.produit == null)
          TextFormField(
            controller: _initial,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Stock initial (facultatif)', prefixIcon: Icon(Icons.inventory_2_outlined)),
          ),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Actif'), value: _actif, onChanged: (v) => setState(() => _actif = v)),
      ],
    );
  }
}

// ======================================================================= étiquettes

class EtiquettesDialog extends StatefulWidget {
  final List<Produit> produits;
  final bool quantiteParStock;
  const EtiquettesDialog({super.key, required this.produits, this.quantiteParStock = true});

  @override
  State<EtiquettesDialog> createState() => _EtiquettesDialogState();
}

class _EtiquettesDialogState extends State<EtiquettesDialog> {
  late final Map<String, TextEditingController> _qte = {
    for (final p in widget.produits)
      p.id: TextEditingController(text: '${widget.quantiteParStock ? (p.stock > 0 ? p.stock : 1) : 1}'),
  };
  FormatEtiquette _format = FormatEtiquette.a4;
  bool _prix = true;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _qte.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _go({bool share = false}) async {
    final items = <(Produit, int)>[
      for (final p in widget.produits) (p, (int.tryParse(_qte[p.id]!.text) ?? 0).clamp(0, 1000)),
    ].where((e) => e.$2 > 0).toList();
    final total = items.fold<int>(0, (s, e) => s + e.$2);
    if (total == 0) return;
    if (total > 2000) {
      showSnack(context, 'Maximum 2000 étiquettes à la fois', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = await buildEtiquettes(items, format: _format, prix: _prix);
      final nom = 'etiquettes_${dateKey(DateTime.now())}.pdf';
      if (share) {
        await partager(bytes, nom);
      } else {
        await imprimer(bytes, nom);
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Imprimer les étiquettes QR'),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<FormatEtiquette>(
              value: _format,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Format'),
              items: [for (final f in FormatEtiquette.values) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (v) => setState(() => _format = v ?? _format),
            ),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Afficher le prix de gros'), value: _prix, onChanged: (v) => setState(() => _prix = v)),
            const Divider(),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final p in widget.produits)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text('${p.reference} · ${p.libelle}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _qte[p.id],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(suffixText: 'ét.'),
                        ),
                      ),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          IconButton(tooltip: 'Partager', onPressed: _busy ? null : () => _go(share: true), icon: const Icon(Icons.share_rounded)),
          FilledButton.icon(
            onPressed: _busy ? null : _go,
            icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.print_rounded),
            label: const Text('Imprimer'),
          ),
        ],
      );
}

// ======================================================================= fiche produit

class ProduitDetailScreen extends StatefulWidget {
  final String produitId;
  const ProduitDetailScreen({super.key, required this.produitId});

  @override
  State<ProduitDetailScreen> createState() => _ProduitDetailScreenState();
}

class _ProduitDetailScreenState extends State<ProduitDetailScreen> {
  List<StockMvt> _mvts = [];
  bool _loading = true;
  int _seen = -1;

  @override
  void initState() {
    super.initState();
    stock.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    stock.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (stock.version != _seen) _load();
  }

  Future<void> _load() async {
    _seen = stock.version;
    try {
      final m = await stock.mouvements(produitId: widget.produitId);
      if (mounted) setState(() => _mvts = m);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _supprimer(Produit p) async {
    if (!await confirmDialog(context, 'Supprimer', 'Supprimer définitivement ${p.reference} ?')) return;
    try {
      await stock.deleteProduit(p.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Impossible : ce produit a déjà des mouvements ou des ventes. Rendez-le inactif.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: stock,
        builder: (context, _) {
          final p = stock.produit(widget.produitId);
          if (p == null) return Scaffold(appBar: AppBar(), body: const EmptyState('Produit introuvable.'));
          final c = stockColor(p);
          return Scaffold(
            appBar: AppBar(title: Text(p.reference), actions: [
              IconButton(tooltip: 'Modifier', icon: const Icon(Icons.edit_outlined), onPressed: () => ouvrirProduitForm(context, produit: p)),
              PopupMenuButton<String>(
                itemBuilder: (_) => const [PopupMenuItem(value: 'del', child: Text('Supprimer'))],
                onSelected: (_) => _supprimer(p),
              ),
            ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                child: Wrap(spacing: 20, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: BarcodeWidget(barcode: Barcode.qrCode(), data: p.reference, width: 150, height: 150, drawText: false),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.reference, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: context.cs.primary)),
                      Text(p.libelle, style: context.tt.titleMedium),
                      if (p.categorie != null) Text(p.categorie!, style: TextStyle(color: context.pal.muted)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        if (p.prixGros > 0) _chip(context, 'Gros ${fmtDA(p.prixGros)}', AppColors.violet),
                        if (p.prixDetail > 0) _chip(context, 'Détail ${fmtDA(p.prixDetail)}', AppColors.sky),
                        if (p.coutRevient > 0) _chip(context, 'Coût ${fmtDA(p.coutRevient)}', context.pal.muted),
                        _chip(context, 'Alerte ≤ ${p.seuilAlerte}', const Color(0xFFF97316)),
                      ]),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              AutoGrid(minItemWidth: 160, children: [
                StatTile(label: 'En stock', value: fmtInt(p.stock), icon: Icons.inventory_2_rounded, color: c),
                StatTile(label: 'Vendus', value: fmtInt(p.vendus), icon: Icons.shopping_bag_rounded, color: AppColors.gold),
                StatTile(label: 'Valeur du stock', value: fmtDA(p.valeurStock), icon: Icons.savings_rounded, color: AppColors.green),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                FilledButton.icon(
                  onPressed: () => showModalBottomSheet<bool>(
                      context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => MouvementStockSheet(produit: p)),
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text('Ajouter du stock'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showModalBottomSheet<bool>(
                      context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => MouvementStockSheet(produit: p, sortie: true)),
                  icon: const Icon(Icons.indeterminate_check_box_rounded),
                  label: const Text('Retirer / inventaire'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showDialog<void>(context: context, builder: (_) => EtiquettesDialog(produits: [p])),
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Imprimer étiquettes'),
                ),
              ]),
              const SizedBox(height: 16),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SectionTitle('Historique du stock'),
                  if (_loading)
                    const LinearProgressIndicator()
                  else if (_mvts.isEmpty)
                    const EmptyState('Aucun mouvement.', icon: Icons.history_rounded)
                  else
                    for (final m in _mvts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Icon(m.quantite > 0 ? Icons.south_west_rounded : Icons.north_east_rounded,
                              color: m.quantite > 0 ? AppColors.green : AppColors.rose, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(m.type.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('${fmtDate(m.date)} ${m.date.hour.toString().padLeft(2, '0')}:${m.date.minute.toString().padLeft(2, '0')}'
                                  '${m.note != null ? ' · ${m.note}' : ''}',
                                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                            ]),
                          ),
                          Text('${m.quantite > 0 ? '+' : ''}${fmtInt(m.quantite)}',
                              style: TextStyle(fontWeight: FontWeight.w900, color: m.quantite > 0 ? AppColors.green : AppColors.rose)),
                        ]),
                      ),
                ]),
              ),
            ]),
          );
        },
      );

  Widget _chip(BuildContext context, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
}
