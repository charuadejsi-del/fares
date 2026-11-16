import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../charts.dart';
import '../data/app_data.dart';
import '../data/models.dart';
import '../pdf/fiche_paie.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'paie_forms.dart';
import 'production_screen.dart';
import 'refs_screens.dart';

class OuvrierDetailScreen extends StatefulWidget {
  final String ouvrierId;
  const OuvrierDetailScreen({super.key, required this.ouvrierId});

  @override
  State<OuvrierDetailScreen> createState() => _OuvrierDetailScreenState();
}

class _OuvrierDetailScreenState extends State<OuvrierDetailScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  List<Production> _prod = [];
  List<Piece> _pieces = [];
  List<Mouvement> _mvts = [];
  Bilan _bilan = const Bilan();
  bool _loading = true;
  bool _pdfBusy = false;
  String? _error;
  int _seenVersion = -1;

  @override
  void initState() {
    super.initState();
    data.addListener(_onData);
    _load();
  }

  @override
  void dispose() {
    data.removeListener(_onData);
    super.dispose();
  }

  void _onData() {
    if (data.productionVersion != _seenVersion) {
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  DateTimeRange get _range {
    final r = rangeFor(_periode, _custom);
    return _periode == Periode.tout ? DateTimeRange(start: DateTime(2000), end: dayOnly(DateTime.now())) : r;
  }

  Future<void> _load() async {
    _seenVersion = data.productionVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = _range;
    final id = widget.ouvrierId;
    try {
      final res = await Future.wait<Object>([
        data.fetchProduction(r.start, r.end, ouvrierId: id),
        data.fetchPieces(r.start, r.end, ouvrierId: id),
        data.fetchMouvements(r.start, r.end, ouvrierId: id),
        data.bilan(id, r.start, r.end),
      ]);
      if (mounted) {
        setState(() {
          _prod = res[0] as List<Production>;
          _pieces = res[1] as List<Piece>;
          _mvts = res[2] as List<Mouvement>;
          _bilan = res[3] as Bilan;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fichePaie({bool share = false}) async {
    final o = data.ouvrier(widget.ouvrierId);
    if (o == null) return;
    setState(() => _pdfBusy = true);
    try {
      final r = _range;
      final dates = [..._prod.map((p) => p.dateProd), ..._pieces.map((p) => p.date), ..._mvts.map((m) => m.date)];
      final start = _periode == Periode.tout && dates.isNotEmpty ? dates.reduce((a, b) => a.isBefore(b) ? a : b) : r.start;
      final bytes = await buildFichePaie(
        ouvrier: o,
        periode: DateTimeRangeLite(start, r.end),
        rows: _prod,
        pieces: _pieces,
        mouvements: _mvts,
        bilan: _bilan,
      );
      final name = 'fiche_paie_${o.nom.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${dateKey(start)}_${dateKey(r.end)}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Impossible de créer le PDF : ${errorMessage(e)}', error: true);
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  List<JournalItem> _journal(Ouvrier o) {
    final items = <JournalItem>[
      for (final p in _prod)
        JournalItem(
          date: p.dateProd,
          tri: p.createdAt,
          titre: 'Broderie · ${data.typeNom(p.typeId)}',
          detail: '${p.equipe.label} · ${fmtInt(p.totalPoints)} pts',
          montant: p.montant,
          icon: p.equipe == Equipe.jour ? Icons.wb_sunny_rounded : Icons.nightlight_round,
          color: AppColors.violet,
          onEdit: () => openProductionForm(context, p),
          onDelete: () => data.deleteProduction(p.id),
        ),
      for (final p in _pieces)
        JournalItem(
          date: p.date,
          tri: p.date,
          titre: p.libelle,
          detail: '${fmtNum(p.quantite)} × ${fmtDA(p.prixUnitaire)}',
          montant: p.montant,
          icon: Icons.checkroom_rounded,
          color: AppColors.teal,
          onEdit: () => openPieceForm(context, o, existing: p),
          onDelete: () => data.deletePiece(p.id),
        ),
      for (final m in _mvts)
        JournalItem(
          date: m.date,
          tri: m.date,
          titre: m.type.label,
          detail: m.note ?? (m.type.signe > 0 ? 'Ajouté à la paie' : 'Déduit de la paie'),
          montant: m.type.signe * m.montant,
          icon: mvtIcon(m.type),
          color: mvtColor(m.type),
          onEdit: () => openMouvementForm(context, o, m.type, existing: m),
          onDelete: () => data.deleteMouvement(m.id),
        ),
    ];
    items.sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.tri.compareTo(a.tri);
    });
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final o = data.ouvrier(widget.ouvrierId);
    if (o == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState('Ouvrier introuvable.'));
    }
    final r = _range;
    final pts = _prod.fold<int>(0, (s, p) => s + p.totalPoints);
    final nbJour = _prod.where((p) => p.equipe == Equipe.jour).length;
    final nbNuit = _prod.length - nbJour;
    final journal = _journal(o);
    final showBroderie = o.enBroderie || _prod.isNotEmpty;
    final showTravail = !o.brodeur || _pieces.isNotEmpty;
    final qtePieces = _pieces.fold<double>(0, (s, p) => s + p.quantite);
    final montantPieces = _pieces.fold<double>(0, (s, p) => s + p.montant);
    final joursTravail = {for (final p in _pieces) dateKey(p.date)}.length;
    final parTache = <String, double>{};
    for (final p in _pieces) {
      parTache[p.libelle.trim()] = (parTache[p.libelle.trim()] ?? 0) + p.quantite;
    }
    final tachesTri = parTache.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      floatingActionButton: o.brodeur
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openPieceForm(context, o),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Ajouter du travail'),
            ),
      appBar: AppBar(
        title: Text(o.nom),
        actions: [
          IconButton(
            tooltip: 'Modifier',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => showDialog<bool>(context: context, builder: (_) => OuvrierForm(o)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 960;
          final header = AppCard(
            gradient: AppColors.heroGradient,
            child: Row(children: [
              NameAvatar(o.nom, size: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(o.nom, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      o.departement,
                      switch (o.modePaie) {
                        ModePaie.points => 'Payé aux points',
                        ModePaie.mois => 'Salaire ${fmtDA(o.salaireMensuel)} / mois',
                        ModePaie.piece => '${fmtDA(o.prixPiece)} / pièce',
                      },
                      if (o.telephone != null) o.telephone!,
                    ].join('  ·  '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ]),
              ),
            ]),
          );

          final bilanCard = AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Bilan de la période',
                  subtitle: _periode == Periode.tout ? 'Depuis le début' : 'Du ${fmtDate(r.start)} au ${fmtDate(r.end)}'),
              _bl(context, 'Solde reporté (avant la période)', _bilan.anterieur, muted: true),
              if (_bilan.broderie != 0 || o.brodeur) _bl(context, '+ Broderie (points)', _bilan.broderie),
              if (_bilan.pieces != 0 || o.modePaie == ModePaie.piece)
                _bl(context, o.modePaie == ModePaie.mois ? '+ Travail en extra' : '+ Travaux à la pièce', _bilan.pieces),
              if (_bilan.salaires != 0 || o.modePaie == ModePaie.mois) _bl(context, '+ Salaires', _bilan.salaires),
              if (_bilan.primes != 0) _bl(context, '+ Primes', _bilan.primes),
              _bl(context, '− Avances', -_bilan.avances),
              if (_bilan.retenues != 0) _bl(context, '− Retenues', -_bilan.retenues),
              _bl(context, '− Déjà payé', -_bilan.paiements),
              const Divider(height: 22),
              Row(children: [
                Expanded(
                  child: Text(_bilan.reste < -0.005 ? 'Avance non couverte' : 'Reste à payer',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Text(fmtDA(_bilan.reste.abs()),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: soldeColor(_bilan.reste))),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _pdfBusy ? null : () => _fichePaie(),
                    icon: _pdfBusy
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.print_rounded),
                    label: const Text('Fiche de paie PDF'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Partager le PDF',
                  onPressed: _pdfBusy ? null : () => _fichePaie(share: true),
                  icon: const Icon(Icons.share_rounded),
                ),
              ]),
            ]),
          );

          final Widget broderie = !showBroderie
              ? const SizedBox.shrink()
              : Column(children: [
                  AutoGrid(minItemWidth: 160, children: [
                    StatTile(label: 'Points brodés', value: fmtInt(pts), icon: Icons.blur_on_rounded, color: AppColors.violet),
                    StatTile(label: 'Équipes de jour', value: '$nbJour', icon: Icons.wb_sunny_rounded, color: AppColors.gold),
                    StatTile(label: 'Équipes de nuit', value: '$nbNuit', icon: Icons.nightlight_round, color: AppColors.sky),
                  ]),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const SectionTitle('Évolution', subtitle: 'Points brodés'),
                      PointsBarChart(rows: _prod, range: rangeFor(_periode, _custom), height: 190),
                    ]),
                  ),
                ]);

          final Widget travail = !showTravail
              ? const SizedBox.shrink()
              : Column(children: [
                  AutoGrid(minItemWidth: 160, children: [
                    StatTile(
                        label: 'Pièces réalisées',
                        value: qtePieces == qtePieces.roundToDouble() ? qtePieces.toStringAsFixed(0) : qtePieces.toStringAsFixed(1),
                        icon: Icons.checkroom_rounded,
                        color: AppColors.violet),
                    StatTile(
                        label: o.modePaie == ModePaie.mois ? 'Payé en extra' : 'Gagné aux pièces',
                        value: fmtDA(montantPieces),
                        icon: Icons.payments_rounded,
                        color: AppColors.green),
                    StatTile(label: 'Jours travaillés', value: '$joursTravail', icon: Icons.event_available_rounded, color: AppColors.gold),
                  ]),
                  if (tachesTri.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const SectionTitle('Travail par tâche'),
                        for (final e in tachesTri)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Row(children: [
                                Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text('${e.value == e.value.roundToDouble() ? e.value.toStringAsFixed(0) : e.value.toStringAsFixed(1)} pcs',
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(minHeight: 5, value: e.value / tachesTri.first.value),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                  ],
                ]);

          final journalCard = AppCard(
            padding: const EdgeInsets.fromLTRB(16, 18, 6, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SectionTitle('Journal', subtitle: '${journal.length} opération${journal.length > 1 ? 's' : ''}'),
              ),
              if (journal.isEmpty)
                const EmptyState('Rien sur cette période.', icon: Icons.receipt_long_outlined)
              else
                for (final it in journal) JournalTile(it),
            ]),
          );

          final period = PeriodChips(
            periode: _periode,
            custom: _custom,
            choices: const [Periode.semaine, Periode.mois, Periode.moisDernier, Periode.tout, Periode.personnalisee],
            onChanged: (p, cr) {
              setState(() {
                _periode = p;
                _custom = cr;
              });
              _load();
            },
          );

          return ListView(
            padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 4, wide ? 28 : 16, 96),
            children: [
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: header),
                  const SizedBox(width: 16),
                  Expanded(child: SoldeCard(o)),
                ])
              else ...[
                header,
                const SizedBox(height: 12),
                SoldeCard(o),
              ],
              const SizedBox(height: 16),
              period,
              const SizedBox(height: 8),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              if (_error != null) ErrorBanner(_error!, onRetry: _load),
              const SizedBox(height: 8),
              if (wide)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(children: [
                      bilanCard,
                      const SizedBox(height: 16),
                      travail,
                      if (showTravail && showBroderie) const SizedBox(height: 16),
                      broderie,
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: journalCard),
                ])
              else ...[
                bilanCard,
                const SizedBox(height: 16),
                travail,
                if (showTravail) const SizedBox(height: 16),
                broderie,
                if (showBroderie) const SizedBox(height: 16),
                journalCard,
              ],
            ],
          );
        }),
      ),
    );
  }

  Widget _bl(BuildContext context, String label, double v, {bool muted = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: muted ? context.pal.muted : null))),
          Text(
            '${v < 0 ? '−' : ''}${fmtDA(v.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: muted ? context.pal.muted : (v < 0 ? AppColors.rose : (v > 0 ? AppColors.green : null)),
            ),
          ),
        ]),
      );
}
