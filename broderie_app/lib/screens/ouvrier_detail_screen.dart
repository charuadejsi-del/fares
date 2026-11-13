import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../charts.dart';
import '../data/app_data.dart';
import '../data/models.dart';
import '../pdf/fiche_paie.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
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
  List<Production> _rows = [];
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

  Future<void> _load() async {
    _seenVersion = data.productionVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = rangeFor(_periode, _custom);
    try {
      final rows = await data.fetchProduction(r.start, r.end, ouvrierId: widget.ouvrierId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fichePaie({bool share = false}) async {
    final o = data.ouvrier(widget.ouvrierId);
    if (o == null) return;
    if (_rows.isEmpty) {
      showSnack(context, 'Aucune production sur cette période.');
      return;
    }
    setState(() => _pdfBusy = true);
    try {
      final r = rangeFor(_periode, _custom);
      final first = _rows.map((p) => p.dateProd).reduce((a, b) => a.isBefore(b) ? a : b);
      final start = _periode == Periode.tout ? first : r.start;
      final bytes = await buildFichePaie(ouvrier: o, periode: DateTimeRangeLite(start, r.end), rows: _rows);
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

  @override
  Widget build(BuildContext context) {
    final o = data.ouvrier(widget.ouvrierId);
    if (o == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState('Ouvrier introuvable.'));
    }
    final range = rangeFor(_periode, _custom);
    var pts = 0, robes = 0;
    var mt = 0.0;
    final jours = <String>{};
    final parDessin = <String, List<int>>{};
    for (final p in _rows) {
      pts += p.totalPoints;
      robes += p.nbRobes;
      mt += p.montant;
      jours.add(dateKey(p.dateProd));
      final v = parDessin.putIfAbsent(p.dessinId, () => [0, 0]);
      v[0] += p.nbRobes;
      v[1] += p.totalPoints;
    }
    final des = parDessin.entries.toList()..sort((a, b) => b.value[1].compareTo(a.value[1]));

    return Scaffold(
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            AppCard(
              gradient: AppColors.heroGradient,
              child: Row(children: [
                NameAvatar(o.nom, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.nom, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        o.tarif1000 > 0 ? '${fmtDA(o.tarif1000)} / 1000 pts' : 'Tarif non défini',
                        if (o.telephone != null) o.telephone!,
                      ].join('  ·  '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                    if (!o.actif)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                        child: const Text('Inactif', style: TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            AutoGrid(minItemWidth: 160, children: [
              StatTile(label: 'Points brodés', value: fmtInt(pts), icon: Icons.blur_on_rounded, color: AppColors.violet),
              StatTile(label: 'Robes', value: fmtInt(robes), icon: Icons.checkroom_rounded, color: AppColors.gold),
              StatTile(label: 'À payer', value: fmtDA(mt), icon: Icons.payments_rounded, color: AppColors.green),
              StatTile(label: 'Jours travaillés', value: '${jours.length}', icon: Icons.event_available_rounded, color: AppColors.sky),
            ]),
            const SizedBox(height: 16),
            AppCard(
              gradient: AppColors.goldGradient,
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Fiche de paie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${fmtDA(mt)} · ${fmtInt(pts)} points', style: const TextStyle(color: Colors.white)),
                  ]),
                ),
                if (_pdfBusy)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else ...[
                  IconButton(
                    tooltip: 'Partager le PDF',
                    onPressed: () => _fichePaie(share: true),
                    icon: const Icon(Icons.share_rounded, color: Colors.white),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF8A5A0B)),
                    onPressed: () => _fichePaie(),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('PDF'),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Évolution', subtitle: 'Points brodés'),
                PointsBarChart(rows: _rows, range: range, height: 200),
              ]),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Par dessin'),
                if (des.isEmpty)
                  const EmptyState('—', icon: Icons.local_florist_outlined)
                else
                  for (final e in des)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        DessinThumb(data.dessin(e.key), size: 42),
                        const SizedBox(width: 12),
                        Expanded(child: Text(data.dessinNom(e.key), style: const TextStyle(fontWeight: FontWeight.w600))),
                        Text('${fmtInt(e.value[0])} robes · ${fmtCompact(e.value[1])} pts'),
                      ]),
                    ),
              ]),
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.fromLTRB(18, 18, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Historique des saisies'),
                if (_rows.isEmpty)
                  const EmptyState('Aucune saisie sur cette période.')
                else
                  for (final p in _rows) ProductionTile(p, showOuvrier: false),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
