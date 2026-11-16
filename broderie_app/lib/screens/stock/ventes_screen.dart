import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/session.dart';
import '../../data/stock.dart';
import '../../pdf/documents.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import '../../data/commerce.dart';
import 'avoirs_screen.dart';
import 'clients_screen.dart';
import 'produits_screen.dart' show stockColor;
import 'modeles_screen.dart' show choisirArticles;
import 'scan_screen.dart';
import '../../i18n.dart';

Color venteColor(Vente v) {
  if (v.annulee) return const Color(0xFF9AA0B4);
  if (v.reste <= 0.005) return AppColors.green;
  if (v.verse > 0) return const Color(0xFFF97316);
  return AppColors.rose;
}

// ======================================================================= liste des ventes

class VentesScreen extends StatefulWidget {
  const VentesScreen({super.key});

  @override
  State<VentesScreen> createState() => _VentesScreenState();
}

class _VentesScreenState extends State<VentesScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  List<Vente> _ventes = [];
  List<Versement> _versements = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  bool _impayees = false;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = rangeFor(_periode, _custom);
    try {
      final res = await Future.wait<Object>([
        stock.ventes(from: r.start, to: r.end),
        stock.versements(from: r.start, to: r.end),
      ]);
      if (mounted) {
        setState(() {
          _ventes = res[0] as List<Vente>;
          _versements = res[1] as List<Versement>;
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
    final valides = _ventes.where((v) => !v.annulee).toList();
    final ca = valides.fold<double>(0, (s, v) => s + v.totalTtc);
    final encaisse = _versements.fold<double>(0, (s, x) => s + x.montant);
    final reste = valides.fold<double>(0, (s, v) => s + (v.reste > 0 ? v.reste : 0));
    final pieces = valides.fold<int>(0, (s, v) => s + v.nbArticles);
    final q = _q.toLowerCase();
    final list = _ventes
        .where((v) => !_impayees || (!v.annulee && v.reste > 0.005))
        .where((v) => q.isEmpty || v.numero.toLowerCase().contains(q) || (v.clientNom ?? '').toLowerCase().contains(q) || v.numeroBl.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-vente',
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NouvelleVenteScreen())),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: Text('Nouvelle vente'.tr),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
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
            AutoGrid(minItemWidth: 165, children: [
              StatTile(label: 'Chiffre d\'affaires'.tr, value: fmtDA(ca), icon: Icons.trending_up_rounded, color: AppColors.violet, sub: '${valides.length} ventes'),
              StatTile(label: 'Encaissé'.tr, value: fmtDA(encaisse), icon: Icons.payments_rounded, color: AppColors.green),
              StatTile(label: 'Reste à encaisser'.tr, value: fmtDA(reste), icon: Icons.hourglass_bottom_rounded, color: AppColors.rose),
              StatTile(label: 'Pièces vendues'.tr, value: fmtInt(pieces), icon: Icons.checkroom_rounded, color: AppColors.gold),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(
                width: 300,
                child: TextField(
                  decoration: InputDecoration(hintText: 'N° facture, BL, client…'.tr, prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => _q = v),
                ),
              ),
              FilterChip(label: Text('Non payées'.tr), selected: _impayees, onSelected: (v) => setState(() => _impayees = v)),
            ]),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ErrorBanner(_error!, onRetry: _load),
            if (!_loading && list.isEmpty) EmptyState('Aucune vente sur cette période.'.tr, icon: Icons.receipt_long_outlined),
            if (list.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    VenteTile(list[i]),
                    if (i < list.length - 1) const Divider(height: 1),
                  ],
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class VenteTile extends StatelessWidget {
  final Vente v;
  final bool showClient;
  const VenteTile(this.v, {super.key, this.showClient = true});

  @override
  Widget build(BuildContext context) {
    final c = venteColor(v);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VenteDetailScreen(venteId: v.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(v.annulee ? Icons.block_rounded : Icons.receipt_long_rounded, color: c, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(showClient ? '${v.numero} · ${v.clientNom ?? 'Client de passage'.tr}' : v.numero,
                  style: TextStyle(fontWeight: FontWeight.w800, decoration: v.annulee ? TextDecoration.lineThrough : null),
                  overflow: TextOverflow.ellipsis),
              Text('{0} · {1} pièces · {2}'.trf([fmtDate(v.date), fmtInt(v.nbArticles), v.statutTexte]),
                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtDA(v.totalTtc), style: const TextStyle(fontWeight: FontWeight.w900)),
            if (!v.annulee && v.reste > 0.005) Text('reste ${fmtDA(v.reste)}', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
  }
}

// ======================================================================= nouvelle vente

class NouvelleVenteScreen extends StatefulWidget {
  final String? clientId;
  const NouvelleVenteScreen({super.key, this.clientId});

  @override
  State<NouvelleVenteScreen> createState() => _NouvelleVenteScreenState();
}

class _NouvelleVenteScreenState extends State<NouvelleVenteScreen> {
  late String? _clientId = widget.clientId;
  DateTime _date = dayOnly(DateTime.now());
  final List<LignePanier> _panier = [];
  final _remise = TextEditingController();
  final _versement = TextEditingController();
  final _adresse = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'especes';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_remise, _versement]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_remise, _versement, _adresse, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  double get _brut => _panier.fold<double>(0, (s, l) => s + l.montant);
  double get _remiseV => parseNum(_remise.text) ?? 0;
  double get _ht => (_brut - _remiseV).clamp(0, double.infinity).toDouble();
  double get _tvaTaux => session.atelier?.tva ?? 0;
  double get _tva => (_ht * _tvaTaux / 100 * 100).roundToDouble() / 100;
  double get _ttc => _ht + _tva;
  int get _qte => _panier.fold<int>(0, (s, l) => s + l.quantite);

  void _ajouter(Produit p, [int n = 1]) {
    HapticFeedback.selectionClick();
    setState(() {
      final i = _panier.indexWhere((l) => l.produit.id == p.id);
      if (i >= 0) {
        _panier[i].quantite += n;
      } else {
        _panier.add(LignePanier(p, quantite: n, prix: stock.prixPour(p, _clientId)));
      }
    });
  }

  Future<void> _scanner() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ScanScreen(
          titre: 'Scanner les articles'.tr,
          aide: 'Chaque scan ajoute 1 pièce au panier'.tr,
          onCode: (ctx, code) async {
            final p = stock.parReference(code);
            if (p == null) {
              showSnack(ctx, 'Référence inconnue : {0}'.trf([code]), error: true);
              return;
            }
            _ajouter(p);
            final q = _panier.firstWhere((l) => l.produit.id == p.id).quantite;
            showSnack(ctx, '+1 {0} · {1} (×{2})'.trf([p.reference, p.designation, q]));
            await Future.delayed(const Duration(milliseconds: 700));
          },
        ),
      ));

  Future<void> _chercher() async {
    final r = await choisirArticles(context);
    if (r == null) return;
    for (final (p, n) in r) {
      _ajouter(p, n);
    }
  }

  Future<void> _valider() async {
    if (_panier.isEmpty) {
      showSnack(context, 'Ajoutez au moins un article'.tr, error: true);
      return;
    }
    final manque = _panier.where((l) => l.quantite > l.produit.stock).toList();
    var negatif = false;
    if (manque.isNotEmpty) {
      negatif = await confirmDialog(
        context,
        'Stock insuffisant'.tr,
        manque.map((l) => '{0} : demandé {1}, disponible {2}'.trf([l.produit.reference, l.quantite, l.produit.stock])).join('\n') +
            '\n\nVendre quand même ? (le stock deviendra négatif)'.tr,
        action: 'Vendre quand même'.tr,
      );
      if (!negatif) return;
    }
    final verse = parseNum(_versement.text) ?? 0;
    if (verse > 0 && _clientId == null) {
      showSnack(context, 'Choisissez le client pour enregistrer un versement'.tr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await stock.creerVenteAvecOption(
        clientId: _clientId,
        date: _date,
        lignes: _panier,
        remise: _remiseV,
        versement: verse,
        mode: _mode,
        adresse: _adresse.text,
        note: _note.text,
        autoriserNegatif: negatif,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => VenteDetailScreen(venteId: id, nouvelle: true)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clients = stock.clients.where((c) => c.actif || c.id == _clientId).toList()..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    final client = stock.client(_clientId);
    final wide = MediaQuery.sizeOf(context).width >= 960;

    final panier = AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Articles'.tr, subtitle: '{0} pièce{1}'.trf([fmtInt(_qte), _qte > 1 ? 's' : '']), trailing: Wrap(spacing: 6, children: [
          FilledButton.tonalIcon(onPressed: _scanner, icon: const Icon(Icons.qr_code_scanner_rounded), label: Text('Scanner'.tr)),
          OutlinedButton.icon(onPressed: _chercher, icon: const Icon(Icons.search_rounded), label: Text('Chercher'.tr)),
        ])),
        if (_panier.isEmpty)
          EmptyState('Scannez les étiquettes QR ou cherchez les produits.'.tr, icon: Icons.shopping_cart_outlined)
        else
          for (final l in _panier) LigneEditor(
            ligne: l,
            onChanged: () => setState(() {}),
            onRemove: () => setState(() => _panier.remove(l)),
          ),
      ]),
    );

    final resume = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Client'.tr),
        DropdownButtonFormField<String?>(
          value: _clientId,
          isExpanded: true,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_outlined)),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('Client de passage'.tr)),
            for (final c in clients) DropdownMenuItem<String?>(value: c.id, child: Text(c.nom, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() {
            _clientId = v;
            for (final l in _panier) {
              l.prix = stock.prixPour(l.produit, v);
            }
          }),
        ),
        Row(children: [
          TextButton.icon(
            onPressed: () async {
              final id = await ouvrirClientForm(context);
              if (id != null) setState(() => _clientId = id);
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text('Nouveau client'.tr),
          ),
          const Spacer(),
          if (client != null && client.solde.abs() > 0.005)
            Text('Ancien solde : {0}'.trf([soldeClientTexte(client.solde)]), style: TextStyle(color: soldeClientColor(client.solde), fontWeight: FontWeight.w700, fontSize: 12.5)),
        ]),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(decoration: InputDecoration(labelText: 'Date'.tr, prefixIcon: Icon(Icons.event)), child: Text(fmtDate(_date))),
        ),
        const SizedBox(height: 16),
        _tot('Total articles'.tr, _brut),
        const SizedBox(height: 6),
        TextField(
          controller: _remise,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Remise'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.discount_outlined)),
        ),
        const SizedBox(height: 8),
        if (_tvaTaux > 0) ...[
          _tot('Total HT'.tr, _ht),
          _tot('TVA {0} %'.trf([fmtNum(_tvaTaux)]), _tva),
        ],
        const Divider(height: 20),
        Row(children: [
          Expanded(child: Text(_tvaTaux > 0 ? 'TOTAL TTC'.tr : 'TOTAL'.tr, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          Text(fmtDA(_ttc), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: context.cs.primary)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _versement,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Versement maintenant'.tr,
            suffixText: 'DA'.tr,
            prefixIcon: const Icon(Icons.payments_rounded),
            suffixIcon: TextButton(onPressed: () => _versement.text = _ttc.toStringAsFixed(_ttc == _ttc.roundToDouble() ? 0 : 2), child: Text('Tout'.tr)),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in modesPaiement.entries)
            ChoiceChip(label: Text(m.value.tr), selected: _mode == m.key, onSelected: (_) => setState(() => _mode = m.key)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Reste à payer sur cette vente'.tr)),
          Text(fmtDA((_ttc - (parseNum(_versement.text) ?? 0)).clamp(0, double.infinity)),
              style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.rose)),
        ]),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Livraison et remarque'.tr),
            subtitle: Text('Adresse de livraison, remarque'.tr, style: TextStyle(color: context.pal.muted, fontSize: 12)),
            children: [
              TextField(controller: _adresse, decoration: InputDecoration(labelText: 'Adresse de livraison'.tr, prefixIcon: Icon(Icons.place_outlined))),
              const SizedBox(height: 8),
              TextField(controller: _note, decoration: InputDecoration(labelText: 'Remarque'.tr, prefixIcon: Icon(Icons.notes))),
              const SizedBox(height: 8),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: _busy || _panier.isEmpty ? null : _valider,
            icon: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded),
            label: Text(_panier.isEmpty ? 'Ajoutez des articles'.tr : 'Valider la vente · {0}'.trf([fmtDA(_ttc)])),
          ),
        ),
      ]),
    );

    return Scaffold(
      appBar: AppBar(title: Text('Nouvelle vente en gros'.tr)),
      body: wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: ListView(padding: const EdgeInsets.all(16), children: [panier])),
              Expanded(flex: 2, child: ListView(padding: const EdgeInsets.fromLTRB(0, 16, 16, 16), children: [resume])),
            ])
          : ListView(padding: const EdgeInsets.all(16), children: [panier, const SizedBox(height: 12), resume]),
    );
  }

  Widget _tot(String l, double v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [Expanded(child: Text(l)), Text(fmtDA(v), style: const TextStyle(fontWeight: FontWeight.w700))]),
      );
}

class LigneEditor extends StatefulWidget {
  final LignePanier ligne;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const LigneEditor({super.key, required this.ligne, required this.onChanged, required this.onRemove});

  @override
  State<LigneEditor> createState() => LigneEditorState();
}

class LigneEditorState extends State<LigneEditor> {
  late final _q = TextEditingController(text: '${widget.ligne.quantite}');
  late final _p = TextEditingController(text: _f(widget.ligne.prix));

  static String _f(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void didUpdateWidget(covariant LigneEditor old) {
    super.didUpdateWidget(old);
    if (int.tryParse(_q.text) != widget.ligne.quantite) _q.text = '${widget.ligne.quantite}';
    if ((parseNum(_p.text) ?? -1) != widget.ligne.prix) _p.text = _f(widget.ligne.prix);
  }

  @override
  void dispose() {
    _q.dispose();
    _p.dispose();
    super.dispose();
  }

  void _setQ(int v) {
    widget.ligne.quantite = v.clamp(1, 999999);
    _q.text = '${widget.ligne.quantite}';
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.ligne;
    final manque = l.quantite > l.produit.disponible;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${l.produit.reference} · ${l.produit.libelle}', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text('Disponible : {0}{1}{2}'.trf([fmtInt(l.produit.disponible), l.produit.reserve > 0 ? ' ({0} réservées)'.trf([fmtInt(l.produit.reserve)]) : '', manque ? '  ⚠ insuffisant'.tr : '']),
                  style: TextStyle(fontSize: 12, color: manque ? AppColors.rose : stockColor(l.produit), fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(tooltip: 'Retirer'.tr, onPressed: widget.onRemove, icon: Icon(Icons.delete_outline, color: context.pal.muted)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          IconButton.filledTonal(onPressed: () => _setQ(l.quantite - 1), icon: const Icon(Icons.remove_rounded)),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _q,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
              onChanged: (v) {
                final n = int.tryParse(v);
                if (n != null && n > 0) {
                  l.quantite = n;
                  widget.onChanged();
                }
              },
            ),
          ),
          IconButton.filledTonal(onPressed: () => _setQ(l.quantite + 1), icon: const Icon(Icons.add_rounded)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _p,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Prix unitaire'.tr, suffixText: 'DA'.tr),
              onChanged: (v) {
                l.prix = parseNum(v) ?? 0;
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(fmtDA(l.montant), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
        const Divider(height: 18),
      ]),
    );
  }
}

class ChoixProduitDialog extends StatefulWidget {
  const ChoixProduitDialog({super.key});

  @override
  State<ChoixProduitDialog> createState() => ChoixProduitDialogState();
}

class ChoixProduitDialogState extends State<ChoixProduitDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = stock.produits
        .where((p) => p.actif)
        .where((p) => q.isEmpty || p.reference.toLowerCase().contains(q) || p.libelle.toLowerCase().contains(q))
        .take(100)
        .toList();
    return AlertDialog(
      title: Text('Choisir un produit'.tr),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: 'Référence ou nom'.tr, prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? EmptyState('Aucun produit.'.tr)
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final p = list[i];
                      return ListTile(
                        title: Text('${p.reference} · ${p.designation}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([if (p.variante.isNotEmpty) p.variante, fmtDA(p.prixGros)].join(' · ')),
                        trailing: Text(fmtInt(p.stock), style: TextStyle(fontWeight: FontWeight.w900, color: stockColor(p))),
                        onTap: () => Navigator.pop(context, p),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('Fermer'.tr))],
    );
  }
}

// ======================================================================= détail d'une vente

class VenteDetailScreen extends StatefulWidget {
  final String venteId;
  final bool nouvelle;
  const VenteDetailScreen({super.key, required this.venteId, this.nouvelle = false});

  @override
  State<VenteDetailScreen> createState() => _VenteDetailScreenState();
}

class _VenteDetailScreenState extends State<VenteDetailScreen> {
  Vente? _v;
  List<VenteLigne> _lignes = [];
  List<Versement> _versements = [];
  List<Avoir> _avoirs = [];
  bool _loading = true;
  bool _pdf = false;
  String? _error;
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
      final r = await Future.wait<Object>([
        stock.vente(widget.venteId),
        stock.lignes(widget.venteId),
        stock.versements(venteId: widget.venteId),
        commerce.avoirs(venteId: widget.venteId),
      ]);
      if (mounted) {
        setState(() {
          _v = r[0] as Vente;
          _lignes = r[1] as List<VenteLigne>;
          _versements = r[2] as List<Versement>;
          _avoirs = r[3] as List<Avoir>;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _doc({required bool facture, bool share = false}) async {
    final v = _v;
    if (v == null) return;
    setState(() => _pdf = true);
    try {
      final c = stock.client(v.clientId);
      final bytes = facture
          ? await buildFacture(atelier: session.atelier!, vente: v, lignes: _lignes, client: c)
          : await buildBonLivraison(atelier: session.atelier!, vente: v, lignes: _lignes, client: c);
      final nom = '${facture ? v.numero : v.numeroBl}.pdf';
      share ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _pdf = false);
    }
  }

  Future<void> _annuler() async {
    final motif = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Annuler la vente'.tr),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Les articles reviennent dans le stock. Les versements déjà reçus restent au crédit du client.'.tr),
          const SizedBox(height: 12),
          TextField(controller: motif, decoration: InputDecoration(labelText: 'Motif (facultatif)'.tr)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Retour'.tr)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: Text('Annuler la vente'.tr),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await stock.annulerVente(widget.venteId, motif.text);
      if (mounted) showSnack(context, 'Vente annulée, stock remis à jour'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _v;
    if (v == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _loading ? const Center(child: CircularProgressIndicator()) : EmptyState(_error ?? 'Vente introuvable.'.tr),
      );
    }
    final c = stock.client(v.clientId);
    final col = venteColor(v);
    return Scaffold(
      appBar: AppBar(title: Text(v.numero), actions: [
        if (!v.annulee)
          PopupMenuButton<String>(
            itemBuilder: (_) => [PopupMenuItem(value: 'annuler', child: Text('Annuler la vente'.tr))],
            onSelected: (_) => _annuler(),
          ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          if (widget.nouvelle)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: AppColors.green),
                SizedBox(width: 10),
                Expanded(child: Text('Vente enregistrée. Le stock a été mis à jour automatiquement.'.tr, style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
            ),
          AppCard(
            gradient: v.annulee ? null : AppColors.heroGradient,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Facture {0} · BL {1}'.trf([v.numero, v.numeroBl]), style: TextStyle(color: v.annulee ? null : Colors.white70)),
                    Text(v.clientNom ?? 'Client de passage'.tr,
                        style: TextStyle(color: v.annulee ? null : Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    Text(fmtDateLong(v.date), style: TextStyle(color: v.annulee ? null : Colors.white70)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: v.annulee ? col.withValues(alpha: 0.15) : Colors.white, borderRadius: BorderRadius.circular(30)),
                  child: Text(v.statutTexte, style: TextStyle(color: col, fontWeight: FontWeight.w900)),
                ),
              ]),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  style: v.annulee ? null : FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.violetDeep),
                  onPressed: _pdf ? null : () => _doc(facture: true),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text('Facture'.tr),
                ),
                FilledButton.icon(
                  style: v.annulee ? null : FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.violetDeep),
                  onPressed: _pdf ? null : () => _doc(facture: false),
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: Text('Bon de livraison'.tr),
                ),
                IconButton.filledTonal(tooltip: 'Partager la facture'.tr, onPressed: _pdf ? null : () => _doc(facture: true, share: true), icon: const Icon(Icons.share_rounded)),
                if (!v.annulee && c != null && v.reste > 0.005)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                    onPressed: () => ouvrirVersementForm(context, c, vente: v),
                    icon: const Icon(Icons.payments_rounded),
                    label: Text('Encaisser'.tr),
                  ),
                if (!v.annulee && c != null)
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => AvoirEditorScreen(client: c, vente: v, lignesVente: _lignes))),
                    icon: const Icon(Icons.undo_rounded),
                    label: Text('Retour / avoir'.tr),
                  ),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Articles'.tr, subtitle: '{0} pièces'.trf([fmtInt(v.nbArticles)])),
              for (final l in _lignes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.reference, style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary)),
                        Text(l.designation, overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Text('{0} × {1}'.trf([fmtInt(l.quantite), fmtDA(l.prixUnitaire)]), style: TextStyle(color: context.pal.muted)),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: Text(fmtDA(l.montant), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                ),
              const Divider(height: 22),
              if (v.remise > 0) ...[_l('Total articles'.tr, v.totalBrut), _l('Remise'.tr, -v.remise)],
              if (v.tvaTaux > 0) ...[_l('Total HT'.tr, v.totalHt), _l('TVA {0} %'.trf([fmtNum(v.tvaTaux)]), v.totalTva)],
              _l(v.tvaTaux > 0 ? 'Total TTC'.tr : 'Total'.tr, v.totalTtc, bold: true),
              if (!v.annulee) ...[
                if (v.avoirs > 0) _l('Avoirs (retours)'.tr, -v.avoirs, color: AppColors.teal),
                _l('Versé'.tr, v.verse, color: AppColors.green),
                _l('Reste à payer'.tr, v.reste, bold: true, color: v.reste > 0.005 ? AppColors.rose : AppColors.green),
              ],
            ]),
          ),
          if (v.chauffeur != null || v.vehicule != null || v.adresseLivraison != null || v.note != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionTitle('Livraison et remarques'.tr),
                if (v.chauffeur != null) Text('Chauffeur : {0}'.trf([v.chauffeur])),
                if (v.vehicule != null) Text('Véhicule : {0}'.trf([v.vehicule])),
                if (v.adresseLivraison != null) Text('Adresse : {0}'.trf([v.adresseLivraison])),
                if (v.note != null) Text('Remarque : {0}'.trf([v.note])),
              ]),
            ),
          ],
          if (_avoirs.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle('Retours (avoirs)'.tr),
                for (final a in _avoirs) AvoirTile(a),
              ]),
            ),
          ],
          if (c != null) ...[
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SectionTitle('Versements sur cette facture'.tr),
                if (_versements.isEmpty)
                  EmptyState('Aucun versement.'.tr, icon: Icons.payments_outlined)
                else
                  for (final x in _versements) VersementTile(x, client: c, ventes: [v]),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _l(String t, double v, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(t, style: TextStyle(fontWeight: bold ? FontWeight.w900 : null))),
          Text(fmtDA(v), style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, fontSize: bold ? 17 : null, color: color)),
        ]),
      );
}
