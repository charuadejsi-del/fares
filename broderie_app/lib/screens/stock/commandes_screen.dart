import 'package:flutter/material.dart';

import '../../data/commerce.dart';
import '../../data/session.dart';
import '../../data/stock.dart';
import '../../pdf/documents.dart';
import '../../theme.dart';
import '../../utils.dart';
import '../../widgets.dart';
import 'clients_screen.dart';
import 'modeles_screen.dart' show choisirArticles;
import 'scan_screen.dart';
import 'ventes_screen.dart';
import '../../i18n.dart';

Color commandeColor(Commande c) {
  if (c.venteId != null) return AppColors.green;
  return switch (c.statut) {
    StatutDoc.enCours => c.enRetard ? AppColors.rose : AppColors.sky,
    StatutDoc.prete => AppColors.gold,
    StatutDoc.acceptee || StatutDoc.livree => AppColors.green,
    StatutDoc.refusee || StatutDoc.annulee => const Color(0xFF9AA0B4),
  };
}

// ======================================================================= liste

class CommandesScreen extends StatefulWidget {
  const CommandesScreen({super.key});

  @override
  State<CommandesScreen> createState() => _CommandesScreenState();
}

class _CommandesScreenState extends State<CommandesScreen> {
  bool? _devis; // null = tous
  bool _ouverts = true;
  List<Commande> _list = [];
  bool _loading = true;
  String? _error;
  int _seen = -1;
  String _q = '';

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
    setState(() => _loading = true);
    try {
      final l = await commerce.commandes();
      if (mounted) setState(() {
        _list = l;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  void _nouveau(bool devis) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommandeEditorScreen(devis: devis)));

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _list
        .where((c) => _devis == null || c.devis == _devis)
        .where((c) => !_ouverts || c.modifiable)
        .where((c) => q.isEmpty || c.numero.toLowerCase().contains(q) || (c.clientNom ?? '').toLowerCase().contains(q))
        .toList();
    final cmdOuvertes = _list.where((c) => !c.devis && c.modifiable).toList();
    final devisOuverts = _list.where((c) => c.devis && c.modifiable).toList();
    final retard = _list.where((c) => c.enRetard).length;

    return Scaffold(
      floatingActionButton: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
        FloatingActionButton.extended(
          heroTag: 'fab-devis',
          backgroundColor: AppColors.gold,
          foregroundColor: Colors.black,
          onPressed: () => _nouveau(true),
          icon: const Icon(Icons.request_quote_rounded),
          label: Text('Nouveau devis'.tr),
        ),
        const SizedBox(height: 10),
        FloatingActionButton.extended(
          heroTag: 'fab-cmd',
          onPressed: () => _nouveau(false),
          icon: const Icon(Icons.assignment_add),
          label: Text('Nouvelle commande'.tr),
        ),
      ]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 160), children: [
          AutoGrid(minItemWidth: 165, children: [
            StatTile(label: 'Commandes en cours'.tr, value: '${cmdOuvertes.length}', icon: Icons.assignment_rounded, color: AppColors.sky,
                sub: fmtDA(cmdOuvertes.fold<double>(0, (s, c) => s + c.total))),
            StatTile(label: 'Pièces réservées'.tr, value: fmtInt(stock.totalReserve), icon: Icons.lock_clock_rounded, color: AppColors.violet),
            StatTile(label: 'Devis en attente'.tr, value: '${devisOuverts.length}', icon: Icons.request_quote_rounded, color: AppColors.gold),
            StatTile(label: 'En retard'.tr, value: '$retard', icon: Icons.alarm_rounded, color: AppColors.rose),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SegmentedButton<bool?>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: null, label: Text('Tous'.tr)),
                ButtonSegment(value: false, label: Text('Commandes'.tr)),
                ButtonSegment(value: true, label: Text('Devis'.tr)),
              ],
              selected: {_devis},
              onSelectionChanged: (s) => setState(() => _devis = s.first),
            ),
            FilterChip(label: Text('En cours seulement'.tr), selected: _ouverts, onSelected: (v) => setState(() => _ouverts = v)),
            SizedBox(
              width: 260,
              child: TextField(
                decoration: InputDecoration(hintText: 'N° ou client'.tr, prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ErrorBanner(_error!, onRetry: _load),
          if (!_loading && list.isEmpty)
            EmptyState('Aucun devis ni commande.\nCréez un devis pour un client, puis transformez-le en commande ou en vente.'.tr,
                icon: Icons.assignment_outlined),
          if (list.isNotEmpty)
            AppCard(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Column(children: [
                for (var i = 0; i < list.length; i++) ...[
                  _CommandeTile(list[i]),
                  if (i < list.length - 1) const Divider(height: 1),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _CommandeTile extends StatelessWidget {
  final Commande c;
  const _CommandeTile(this.c);

  @override
  Widget build(BuildContext context) {
    final col = commandeColor(c);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CommandeDetailScreen(commandeId: c.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: col.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(c.devis ? Icons.request_quote_rounded : Icons.assignment_rounded, color: col, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c.numero} · ${c.clientNom ?? 'Sans client'.tr}', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
              Text(
                [
                  fmtDate(c.date),
                  '{0} pièces'.trf([fmtInt(c.nbArticles)]),
                  c.statutTexte,
                  if (c.echeance != null && c.modifiable) '${c.devis ? 'valable' : 'livraison'} ${fmtDate(c.echeance!)}',
                ].join(' · '),
                style: context.tt.bodySmall?.copyWith(color: c.enRetard ? AppColors.rose : context.pal.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          Text(fmtDA(c.total), style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

// ======================================================================= création / modification

class CommandeEditorScreen extends StatefulWidget {
  final bool devis;
  final Commande? existant;
  final List<CommandeLigne> lignesExistantes;
  final String? clientId;
  const CommandeEditorScreen({super.key, required this.devis, this.existant, this.lignesExistantes = const [], this.clientId});

  @override
  State<CommandeEditorScreen> createState() => _CommandeEditorScreenState();
}

class _CommandeEditorScreenState extends State<CommandeEditorScreen> {
  late String? _clientId = widget.existant?.clientId ?? widget.clientId;
  late DateTime _date = widget.existant?.date ?? dayOnly(DateTime.now());
  late DateTime? _echeance = widget.existant?.echeance ?? (widget.devis ? dayOnly(DateTime.now()).add(const Duration(days: 15)) : null);
  final List<LignePanier> _panier = [];
  late final _remise = TextEditingController(text: (widget.existant?.remise ?? 0) > 0 ? fmtNum(widget.existant!.remise).replaceAll(RegExp(r'\s'), '') : '');
  late final _note = TextEditingController(text: widget.existant?.note ?? '');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final l in widget.lignesExistantes) {
      final p = stock.produit(l.produitId);
      if (p != null) _panier.add(LignePanier(p, quantite: l.quantite, prix: l.prixUnitaire));
    }
    _remise.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _remise.dispose();
    _note.dispose();
    super.dispose();
  }

  double get _brut => _panier.fold<double>(0, (s, l) => s + l.montant);
  double get _total => (_brut - (parseNum(_remise.text) ?? 0)).clamp(0, double.infinity).toDouble();

  void _ajouter(Produit p, [int n = 1]) => setState(() {
        final i = _panier.indexWhere((l) => l.produit.id == p.id);
        if (i >= 0) {
          _panier[i].quantite += n;
        } else {
          _panier.add(LignePanier(p, quantite: n, prix: stock.prixPour(p, _clientId)));
        }
      });

  Future<void> _save() async {
    if (_panier.isEmpty) {
      showSnack(context, 'Ajoutez au moins un article'.tr, error: true);
      return;
    }
    if (!widget.devis && _clientId == null) {
      showSnack(context, 'Choisissez le client de la commande'.tr, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      String id;
      if (widget.existant == null) {
        id = await commerce.creerCommande(
          devis: widget.devis,
          clientId: _clientId,
          date: _date,
          echeance: _echeance,
          lignes: _panier,
          remise: parseNum(_remise.text) ?? 0,
          note: _note.text,
        );
      } else {
        id = widget.existant!.id;
        await commerce.modifierCommande(id,
            clientId: _clientId, date: _date, echeance: _echeance, lignes: _panier, remise: parseNum(_remise.text) ?? 0, note: _note.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CommandeDetailScreen(commandeId: id)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Future<DateTime?> _pick(DateTime init) => showDatePicker(context: context, initialDate: init, firstDate: DateTime(2020), lastDate: DateTime(2100));

  @override
  Widget build(BuildContext context) {
    final clients = stock.clients.where((c) => c.actif || c.id == _clientId).toList()..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    final titre = widget.existant != null ? 'Modifier {0}'.trf([widget.existant!.numero]) : (widget.devis ? 'Nouveau devis'.tr : 'Nouvelle commande'.tr);
    return Scaffold(
      appBar: AppBar(title: Text(titre)),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<String?>(
              value: _clientId,
              isExpanded: true,
              decoration: InputDecoration(labelText: 'Client'.tr, prefixIcon: Icon(Icons.storefront_outlined)),
              items: [
                if (widget.devis) DropdownMenuItem<String?>(value: null, child: Text('Sans client (prospect)'.tr)),
                for (final c in clients) DropdownMenuItem<String?>(value: c.id, child: Text(c.nom, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() {
                _clientId = v;
                for (final l in _panier) {
                  l.prix = stock.prixPour(l.produit, v);
                }
              }),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () async {
                  final id = await ouvrirClientForm(context);
                  if (id != null) setState(() => _clientId = id);
                },
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: Text('Nouveau client'.tr),
              ),
            ),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await _pick(_date);
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(decoration: InputDecoration(labelText: 'Date'.tr, prefixIcon: Icon(Icons.event)), child: Text(fmtDate(_date))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await _pick(_echeance ?? _date);
                    if (d != null) setState(() => _echeance = d);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: widget.devis ? 'Valable jusqu\'au'.tr : 'Livraison prévue'.tr,
                      prefixIcon: const Icon(Icons.event_available_outlined),
                    ),
                    child: Text(_echeance == null ? '—' : fmtDate(_echeance!)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('Articles'.tr, trailing: Wrap(spacing: 6, children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ScanScreen(
                    titre: 'Scanner les articles'.tr,
                    aide: 'Chaque scan ajoute 1 pièce'.tr,
                    onCode: (ctx, code) async {
                      final p = stock.parReference(code);
                      if (p == null) {
                        showSnack(ctx, 'Référence inconnue : {0}'.trf([code]), error: true);
                      } else {
                        _ajouter(p);
                        showSnack(ctx, '+1 ${p.reference}');
                        await Future.delayed(const Duration(milliseconds: 700));
                      }
                    },
                  ),
                )),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text('Scanner'.tr),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final r = await choisirArticles(context);
                  if (r == null) return;
                  for (final (p, n) in r) {
                    _ajouter(p, n);
                  }
                },
                icon: const Icon(Icons.search_rounded),
                label: Text('Chercher'.tr),
              ),
            ])),
            if (_panier.isEmpty)
              EmptyState('Ajoutez les articles.'.tr, icon: Icons.shopping_cart_outlined)
            else
              for (final l in _panier) LigneEditor(ligne: l, onChanged: () => setState(() {}), onRemove: () => setState(() => _panier.remove(l))),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: Text('Total articles'.tr)), Text(fmtDA(_brut), style: const TextStyle(fontWeight: FontWeight.w700))]),
            const SizedBox(height: 8),
            TextField(
              controller: _remise,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Remise'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.discount_outlined)),
            ),
            const SizedBox(height: 8),
            TextField(controller: _note, decoration: InputDecoration(labelText: 'Remarque / conditions'.tr, prefixIcon: Icon(Icons.notes))),
            const Divider(height: 22),
            Row(children: [
              Expanded(child: Text(widget.devis ? 'TOTAL DU DEVIS (HT)'.tr : 'TOTAL (HT)'.tr, style: const TextStyle(fontWeight: FontWeight.w900))),
              Text(fmtDA(_total), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: context.cs.primary)),
            ]),
            if (!widget.devis)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Les articles seront réservés dans le stock jusqu\'à la livraison.'.tr,
                    style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton.icon(
                onPressed: _busy || _panier.isEmpty ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(widget.existant != null ? 'Enregistrer'.tr : (widget.devis ? 'Créer le devis'.tr : 'Créer la commande'.tr)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ======================================================================= détail

class CommandeDetailScreen extends StatefulWidget {
  final String commandeId;
  const CommandeDetailScreen({super.key, required this.commandeId});

  @override
  State<CommandeDetailScreen> createState() => _CommandeDetailScreenState();
}

class _CommandeDetailScreenState extends State<CommandeDetailScreen> {
  Commande? _c;
  List<CommandeLigne> _lignes = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
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
      final r = await Future.wait<Object>([commerce.commande(widget.commandeId), commerce.commandeLignes(widget.commandeId)]);
      if (mounted) setState(() {
        _c = r[0] as Commande;
        _lignes = r[1] as List<CommandeLigne>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pdf({bool share = false}) async {
    final c = _c!;
    setState(() => _busy = true);
    try {
      final bytes = await buildDocumentCommercial(
        atelier: session.atelier!,
        titre: c.devis ? 'DEVIS'.tr : 'BON DE COMMANDE'.tr,
        infos: [
          ['N°'.tr, c.numero],
          ['Date'.tr, fmtDate(c.date)],
          if (c.echeance != null) [c.devis ? 'Valable jusqu\'au'.tr : 'Livraison'.tr, fmtDate(c.echeance!)],
        ],
        titreClient: 'Client'.tr,
        client: stock.client(c.clientId),
        lignes: [
          for (final l in _lignes)
            (
              reference: stock.produit(l.produitId)?.reference ?? '',
              designation: stock.produit(l.produitId)?.libelle ?? '(produit supprimé)'.tr,
              quantite: l.quantite,
              prix: l.prixUnitaire,
              montant: l.montant,
            ),
        ],
        totaux: [
          if (c.remise > 0) ...[('Total articles'.tr, c.totalBrut, false), ('Remise'.tr, -c.remise, false)],
          (c.devis ? 'TOTAL DU DEVIS'.tr : 'TOTAL DE LA COMMANDE'.tr, c.total, true),
        ],
        montantLettres: c.total,
        phraseLettres: c.devis ? 'Arrêté le présent devis à la somme de :'.tr : 'Arrêté le présent bon de commande à la somme de :'.tr,
        note: c.note,
        signatures: c.devis ? ['Bon pour accord (client)'.tr, 'Cachet et signature'] : ['Le client'.tr, 'Cachet et signature'],
        annule: c.statut == StatutDoc.annulee || c.statut == StatutDoc.refusee,
      );
      final nom = '${c.numero}.pdf';
      share ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _facturer() async {
    final c = _c!;
    if (c.clientId == null) {
      showSnack(context, 'Choisissez d\'abord un client (Modifier)'.tr, error: true);
      return;
    }
    final verse = TextEditingController();
    var mode = 'especes';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(c.devis ? 'Facturer le devis'.tr : 'Livrer et facturer'.tr),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Une facture et un bon de livraison seront créés, et le stock sera déduit.\nTotal : {0}{1}'.trf([fmtDA(c.total), (session.atelier?.tva ?? 0) > 0 ? ' HT (+ TVA)'.tr : ''])),
            const SizedBox(height: 12),
            TextField(
              controller: verse,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Versement maintenant'.tr,
                suffixText: 'DA'.tr,
                suffixIcon: TextButton(onPressed: () => verse.text = c.total.toStringAsFixed(0), child: Text('Tout'.tr)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in modesPaiement.entries)
                ChoiceChip(label: Text(m.value.tr), selected: mode == m.key, onSelected: (_) => setD(() => mode = m.key)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Facturer'.tr)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      String venteId;
      try {
        venteId = await commerce.commandeVersVente(c.id, versement: parseNum(verse.text) ?? 0, mode: mode);
      } catch (e) {
        final m = errorMessage(e);
        if (!m.contains('Stock insuffisant') || !mounted) rethrow;
        final force = await confirmDialog(context, 'Stock insuffisant'.tr, '{0}\n\nFacturer quand même ? (le stock deviendra négatif)'.trf([m]), action: 'Facturer quand même'.tr);
        if (!force) {
          setState(() => _busy = false);
          return;
        }
        venteId = await commerce.commandeVersVente(c.id, versement: parseNum(verse.text) ?? 0, mode: mode, autoriserNegatif: true);
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => VenteDetailScreen(venteId: venteId, nouvelle: true)));
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Future<void> _action(Future<void> Function() f, String ok) async {
    setState(() => _busy = true);
    try {
      await f();
      if (mounted) showSnack(context, ok);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) {
      return Scaffold(appBar: AppBar(), body: _loading ? const Center(child: CircularProgressIndicator()) : EmptyState(_error ?? 'Introuvable.'.tr));
    }
    final col = commandeColor(c);
    return Scaffold(
      appBar: AppBar(title: Text(c.numero), actions: [
        if (c.modifiable)
          IconButton(
            tooltip: 'Modifier'.tr,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CommandeEditorScreen(devis: c.devis, existant: c, lignesExistantes: _lignes))),
          ),
        PopupMenuButton<String>(
          itemBuilder: (_) => [
            if (c.modifiable) PopupMenuItem(value: 'annuler', child: Text(c.devis ? 'Refuser le devis'.tr : 'Annuler la commande'.tr)),
            if (c.venteId == null) PopupMenuItem(value: 'suppr', child: Text('Supprimer'.tr)),
          ],
          onSelected: (v) async {
            if (v == 'annuler') {
              if (await confirmDialog(context, c.devis ? 'Refuser'.tr : 'Annuler'.tr, '{0} : confirmer ?'.trf([c.numero]), action: 'Confirmer'.tr)) {
                await _action(() => commerce.statutCommande(c.id, c.devis ? StatutDoc.refusee : StatutDoc.annulee), 'Mis à jour'.tr);
              }
            } else if (v == 'suppr') {
              if (await confirmDialog(context, 'Supprimer'.tr, 'Supprimer définitivement {0} ?'.trf([c.numero]))) {
                try {
                  await commerce.supprimerCommande(c.id);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) showSnack(context, errorMessage(e), error: true);
                }
              }
            }
          },
        ),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        AppCard(
          gradient: c.modifiable ? (c.devis ? AppColors.goldGradient : AppColors.heroGradient) : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.devis ? 'Devis {0}'.trf([c.numero]) : 'Commande {0}'.trf([c.numero]), style: TextStyle(color: c.modifiable ? Colors.white70 : null)),
                  Text(c.clientNom ?? 'Sans client'.tr, style: TextStyle(color: c.modifiable ? Colors.white : null, fontSize: 20, fontWeight: FontWeight.w900)),
                  Text(
                    '${fmtDate(c.date)}${c.echeance != null ? ' · ${c.devis ? 'valable jusqu\'au'.tr : 'livraison'} ${fmtDate(c.echeance!)}' : ''}',
                    style: TextStyle(color: c.modifiable ? Colors.white70 : null),
                  ),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c.modifiable ? Colors.white : col.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(30)),
                child: Text(c.statutTexte, style: TextStyle(color: col, fontWeight: FontWeight.w900)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(fmtDA(c.total), style: TextStyle(color: c.modifiable ? Colors.white : null, fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(
                style: c.modifiable ? FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.violetDeep) : null,
                onPressed: _busy ? null : () => _pdf(),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(c.devis ? 'Devis PDF'.tr : 'Bon de commande PDF'.tr),
              ),
              IconButton.filledTonal(tooltip: 'Partager'.tr, onPressed: _busy ? null : () => _pdf(share: true), icon: const Icon(Icons.share_rounded)),
              if (c.venteId != null)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VenteDetailScreen(venteId: c.venteId!))),
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: Text('Voir la facture'.tr),
                ),
            ]),
          ]),
        ),
        if (c.modifiable) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Étapes suivantes'.tr),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (c.devis)
                  FilledButton.icon(
                    onPressed: _busy || c.clientId == null
                        ? null
                        : () => _action(() async {
                              final id = await commerce.devisVersCommande(c.id);
                              if (mounted) {
                                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => CommandeDetailScreen(commandeId: id)));
                              }
                            }, 'Commande créée, articles réservés'.tr),
                    icon: const Icon(Icons.assignment_turned_in_rounded),
                    label: Text('Accepté → commande'.tr),
                  ),
                if (!c.devis && c.statut == StatutDoc.enCours)
                  FilledButton.tonalIcon(
                    onPressed: _busy ? null : () => _action(() => commerce.statutCommande(c.id, StatutDoc.prete), 'Commande prête'.tr),
                    icon: const Icon(Icons.inventory_rounded),
                    label: Text('Marquer prête'.tr),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                  onPressed: _busy ? null : _facturer,
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: Text(c.devis ? 'Facturer directement'.tr : 'Livrer et facturer'.tr),
                ),
              ]),
              if (c.devis && c.clientId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Ajoutez un client (Modifier) pour transformer ce devis.'.tr, style: TextStyle(color: context.pal.muted, fontSize: 12.5)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle('Articles'.tr, subtitle: '{0} pièces'.trf([fmtInt(c.nbArticles)])),
            for (final l in _lignes)
              Builder(builder: (context) {
                final p = stock.produit(l.produitId);
                final manque = !c.devis && c.modifiable && p != null && p.stock < l.quantite;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p?.reference ?? '?', style: TextStyle(fontWeight: FontWeight.w900, color: context.cs.primary)),
                        Text(p?.libelle ?? '(produit supprimé)'.tr, overflow: TextOverflow.ellipsis),
                        if (manque) Text('Stock : {0} — insuffisant'.trf([fmtInt(p!.stock)]), style: const TextStyle(color: AppColors.rose, fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    Text('{0} × {1}'.trf([fmtInt(l.quantite), fmtDA(l.prixUnitaire)]), style: TextStyle(color: context.pal.muted)),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: Text(fmtDA(l.montant), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
                  ]),
                );
              }),
            const Divider(height: 22),
            if (c.remise > 0) ...[
              Row(children: [Expanded(child: Text('Total articles'.tr)), Text(fmtDA(c.totalBrut))]),
              Row(children: [Expanded(child: Text('Remise'.tr)), Text('−${fmtDA(c.remise)}')]),
            ],
            Row(children: [
              Expanded(child: Text('Total'.tr, style: TextStyle(fontWeight: FontWeight.w900))),
              Text(fmtDA(c.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ]),
            if (c.note != null) ...[const SizedBox(height: 10), Text('Remarque : {0}'.trf([c.note]))],
          ]),
        ),
      ]),
    );
  }
}
