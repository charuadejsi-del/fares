import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../utils.dart';
import '../widgets.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _Agg {
  int saisies = 0;
  int robes = 0;
  int points = 0;
  double montant = 0;
  void add(Production p) {
    saisies++;
    robes += p.nbRobes;
    points += p.totalPoints;
    montant += p.montant;
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  String? _ouvrierId;
  List<Production> _rows = [];
  bool _loading = true;
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
      setState(() {}); // noms mis à jour
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
      final rows = await data.fetchProduction(r.start, r.end, ouvrierId: _ouvrierId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _csv() {
    String q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final b = StringBuffer('Date;Ouvrier;Dessin;Machine;Robes;Points par robe;Total points;Tarif DA/1000;Montant DA;Remarque\n');
    for (final p in _rows) {
      b.writeln([
        dateKey(p.dateProd),
        data.ouvrierNom(p.ouvrierId),
        data.dessinNom(p.dessinId),
        data.machineNom(p.machineId),
        p.nbRobes,
        p.pointsParRobe,
        p.totalPoints,
        p.tarif1000.toStringAsFixed(2).replaceAll('.', ','),
        p.montant.toStringAsFixed(2).replaceAll('.', ','),
        p.note,
      ].map(q).join(';'));
    }
    return b.toString();
  }

  Future<void> _export() async {
    if (_rows.isEmpty) {
      showSnack(context, 'Rien à exporter sur cette période.');
      return;
    }
    final csv = _csv();
    try {
      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ?? await getApplicationDocumentsDirectory();
      } else {
        dir = (await getDownloadsDirectory()) ?? await getApplicationDocumentsDirectory();
      }
      final f = File('${dir.path}${Platform.pathSeparator}production_${dateKey(DateTime.now())}_${DateTime.now().millisecondsSinceEpoch}.csv');
      // BOM UTF-8 pour qu'Excel affiche correctement les accents
      await f.writeAsString('﻿$csv');
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) showSnack(context, 'Exporté : ${f.path} (copié aussi dans le presse-papiers)');
    } catch (e) {
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) showSnack(context, 'Fichier impossible à écrire — données copiées dans le presse-papiers.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _Agg();
    final parOuvrier = <String, _Agg>{};
    final parDessin = <String, _Agg>{};
    for (final p in _rows) {
      total.add(p);
      parOuvrier.putIfAbsent(p.ouvrierId, _Agg.new).add(p);
      parDessin.putIfAbsent(p.dessinId, _Agg.new).add(p);
    }
    final ouv = parOuvrier.entries.toList()..sort((a, b) => b.value.points.compareTo(a.value.points));
    final des = parDessin.entries.toList()..sort((a, b) => b.value.points.compareTo(a.value.points));
    final maxPts = (ouv.isEmpty || ouv.first.value.points <= 0) ? 1 : ouv.first.value.points;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilterBar(
            periode: _periode,
            custom: _custom,
            ouvrierId: _ouvrierId,
            onPeriode: (p, c) {
              setState(() {
                _periode = p;
                _custom = c;
              });
              _load();
            },
            onOuvrier: (id) {
              setState(() => _ouvrierId = id);
              _load();
            },
            trailing: [
              OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.file_download_outlined), label: const Text('Exporter CSV')),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_error!), trailing: TextButton(onPressed: _load, child: const Text('Réessayer'))),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: [
            KpiCard(label: 'Total points', value: fmtInt(total.points), icon: Icons.blur_on),
            KpiCard(label: 'Total robes', value: fmtInt(total.robes), icon: Icons.checkroom),
            KpiCard(label: 'À payer', value: fmtDA(total.montant), icon: Icons.payments_outlined),
            KpiCard(label: 'Saisies', value: fmtInt(total.saisies), icon: Icons.receipt_long_outlined),
          ]),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Par ouvrier',
            child: ouv.isEmpty
                ? const EmptyState('Aucune production sur cette période.')
                : Column(children: [
                    for (final e in ouv)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Row(children: [
                            Expanded(child: Text(data.ouvrierNom(e.key), style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${fmtInt(e.value.points)} pts'),
                          ]),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: e.value.points / maxPts, minHeight: 6, borderRadius: BorderRadius.circular(3)),
                          const SizedBox(height: 4),
                          Text(
                            '${fmtInt(e.value.robes)} robes · ${e.value.saisies} saisies · ${fmtDA(e.value.montant)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ]),
                      ),
                    const Divider(),
                    Row(children: [
                      const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
                      Text('${fmtInt(total.robes)} robes · ${fmtInt(total.points)} pts · ${fmtDA(total.montant)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                  ]),
          ),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Par dessin',
            child: des.isEmpty
                ? const EmptyState('—')
                : SimpleTable(
                    headers: const ['Dessin', 'Points / robe', 'Robes', 'Total points'],
                    numericCols: const {1, 2, 3},
                    rows: [
                      for (final e in des)
                        [
                          data.dessinNom(e.key),
                          fmtInt(data.dessin(e.key)?.points ?? 0),
                          fmtInt(e.value.robes),
                          fmtInt(e.value.points),
                        ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
