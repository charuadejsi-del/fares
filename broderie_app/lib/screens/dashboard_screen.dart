import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../charts.dart';
import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'ouvrier_detail_screen.dart';

class Agg {
  int saisies = 0;
  int robes = 0;
  int points = 0;
  double montant = 0;
  void add(Production p) {
    saisies++;
    robes += p.nbRobes ?? 0;
    points += p.totalPoints;
    montant += p.montant;
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Periode _periode = Periode.mois;
  DateTimeRange? _custom;
  String? _ouvrierId;
  List<Production> _rows = [];
  List<Mouvement> _mvts = [];
  List<Piece> _pieces = [];
  int? _prevPoints;
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
      setState(() {});
    }
  }

  /// Période précédente de même durée (pour la comparaison).
  DateTimeRange? _previous(DateTimeRange r) {
    switch (_periode) {
      case Periode.tout:
        return null;
      case Periode.mois:
        final s = DateTime(r.start.year, r.start.month - 1, 1);
        final e = DateTime(s.year, s.month, r.end.day).isAfter(DateTime(s.year, s.month + 1, 0))
            ? DateTime(s.year, s.month + 1, 0)
            : DateTime(s.year, s.month, r.end.day);
        return DateTimeRange(start: s, end: e);
      default:
        final len = r.end.difference(r.start).inDays + 1;
        return DateTimeRange(start: r.start.subtract(Duration(days: len)), end: r.start.subtract(const Duration(days: 1)));
    }
  }

  Future<void> _load() async {
    _seenVersion = data.productionVersion;
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = rangeFor(_periode, _custom);
    final prev = _previous(r);
    try {
      final res = await Future.wait([
        data.fetchProduction(r.start, r.end, ouvrierId: _ouvrierId),
        if (prev != null) data.fetchProduction(prev.start, prev.end, ouvrierId: _ouvrierId),
      ]);
      final money = await Future.wait<Object>([
        data.fetchMouvements(r.start, r.end, ouvrierId: _ouvrierId),
        data.fetchPieces(r.start, r.end, ouvrierId: _ouvrierId),
      ]);
      if (mounted) {
        setState(() {
          _rows = res[0];
          _prevPoints = prev == null ? null : res[1].fold<int>(0, (s, p) => s + p.totalPoints);
          _mvts = money[0] as List<Mouvement>;
          _pieces = money[1] as List<Piece>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _csv() {
    String q(Object? v) => '"${(v ?? '').toString().replaceAll('"', '""')}"';
    final b = StringBuffer('Date;Equipe;Ouvrier;Type;Machine;Points;Tarif DA/1000;Montant DA;Dessin;Robes;Remarque\n');
    for (final p in _rows) {
      b.writeln([
        dateKey(p.dateProd),
        p.equipe.label,
        data.ouvrierNom(p.ouvrierId),
        data.typeNom(p.typeId),
        data.machineNom(p.machineId),
        p.totalPoints,
        p.tarif1000.toStringAsFixed(2).replaceAll('.', ','),
        p.montant.toStringAsFixed(2).replaceAll('.', ','),
        p.dessinId == null ? '' : data.dessinNom(p.dessinId!),
        p.nbRobes ?? '',
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
    final range = rangeFor(_periode, _custom);
    final total = Agg();
    final parOuvrier = <String, Agg>{};
    final parDessin = <String, Agg>{};
    final parType = <String, Agg>{};
    final parEquipe = {Equipe.jour: Agg(), Equipe.nuit: Agg()};
    final jours = <String>{};
    for (final p in _rows) {
      total.add(p);
      parOuvrier.putIfAbsent(p.ouvrierId, Agg.new).add(p);
      if (p.dessinId != null) parDessin.putIfAbsent(p.dessinId!, Agg.new).add(p);
      parType.putIfAbsent(p.typeId ?? '', Agg.new).add(p);
      parEquipe[p.equipe]!.add(p);
      jours.add(dateKey(p.dateProd));
    }
    final typesList = parType.entries.toList()..sort((a, b) => b.value.points.compareTo(a.value.points));
    final ouv = parOuvrier.entries.toList()..sort((a, b) => b.value.points.compareTo(a.value.points));
    final des = parDessin.entries.toList()..sort((a, b) => b.value.points.compareTo(a.value.points));
    final moyEquipe = total.saisies == 0 ? 0 : total.points / total.saisies;

    final hero = _HeroCard(total: total, prevPoints: _prevPoints, periode: _periode);

    final stats = AutoGrid(minItemWidth: 165, children: [
      StatTile(label: 'À payer', value: fmtDA(total.montant), icon: Icons.payments_rounded, color: AppColors.green),
      StatTile(label: 'Équipe de jour', value: '${fmtCompact(parEquipe[Equipe.jour]!.points)} pts', icon: Icons.wb_sunny_rounded,
          color: AppColors.gold, sub: fmtDA(parEquipe[Equipe.jour]!.montant)),
      StatTile(label: 'Équipe de nuit', value: '${fmtCompact(parEquipe[Equipe.nuit]!.points)} pts', icon: Icons.nightlight_round,
          color: AppColors.sky, sub: fmtDA(parEquipe[Equipe.nuit]!.montant)),
      StatTile(label: 'Moyenne par équipe', value: '${fmtCompact(moyEquipe)} pts', icon: Icons.speed_rounded, color: AppColors.rose,
          sub: '${total.saisies} relevés'),
    ]);

    final chart = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Production', subtitle: 'Points brodés sur la période'),
        PointsBarChart(rows: _rows, range: range),
      ]),
    );

    final donut = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Répartition', subtitle: 'Part des points par ouvrier'),
        if (ouv.isEmpty)
          const EmptyState('Aucune production sur cette période.', icon: Icons.pie_chart_outline)
        else
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 16,
            children: [
              ShareDonut(
                parts: [for (final e in ouv.take(8)) MapEntry(data.ouvrierNom(e.key), e.value.points)],
                centerValue: fmtCompact(total.points),
                centerLabel: 'points',
              ),
              SizedBox(
                width: 220,
                child: DonutLegend(parts: [for (final e in ouv.take(8)) MapEntry(data.ouvrierNom(e.key), e.value.points)]),
              ),
            ],
          ),
      ]),
    );

    final classement = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Classement des ouvriers', subtitle: 'Touchez un ouvrier pour sa fiche'),
        if (ouv.isEmpty)
          const EmptyState('Aucun ouvrier n\'a produit sur cette période.', icon: Icons.emoji_events_outlined)
        else
          for (var i = 0; i < ouv.length; i++)
            _RankRow(
              rank: i + 1,
              ouvrierId: ouv[i].key,
              agg: ouv[i].value,
              ratio: ouv.first.value.points == 0 ? 0 : ouv[i].value.points / ouv.first.value.points,
            ),
      ]),
    );

    final typesCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Par type de broderie', subtitle: 'Points et montant'),
        if (typesList.isEmpty)
          const EmptyState('—', icon: Icons.gesture_rounded)
        else
          for (final e in typesList)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _typeColor(e.key), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(data.typeNom(e.key.isEmpty ? null : e.key), style: const TextStyle(fontWeight: FontWeight.w700))),
                  Text(fmtDA(e.value.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Bar(total.points == 0 ? 0 : e.value.points / total.points, color: _typeColor(e.key)),
                const SizedBox(height: 4),
                Text('${fmtInt(e.value.points)} pts · ${e.value.saisies} relevés',
                    style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
              ]),
            ),
      ]),
    );

    final dessins = des.isEmpty
        ? const SizedBox.shrink()
        : AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Dessins'),
        if (des.isEmpty)
          const EmptyState('—', icon: Icons.local_florist_outlined)
        else
          for (final e in des.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                DessinThumb(data.dessin(e.key), size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data.dessinNom(e.key), style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    Text('${fmtInt(data.dessin(e.key)?.points ?? 0)} pts / robe',
                        style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${fmtCompact(e.value.points)} pts', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (e.value.robes > 0)
                    Text('${fmtInt(e.value.robes)} robes', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                ]),
              ]),
            ),
      ]),
    );

    double sumMvt(TypeMvt t) => _mvts.where((m) => m.type == t).fold<double>(0, (s, m) => s + m.montant);
    final gainsAutres = _pieces.fold<double>(0, (s, p) => s + p.montant) + sumMvt(TypeMvt.salaire) + sumMvt(TypeMvt.prime);
    final paieCard = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionTitle('Paie et avances', subtitle: 'Tous départements'),
        AutoGrid(minItemWidth: 150, children: [
          _MiniStat('Reste à payer (total)', fmtDA(data.totalResteAPayer), AppColors.green, Icons.account_balance_wallet_rounded),
          _MiniStat('Avances (période)', fmtDA(sumMvt(TypeMvt.avance)), AppColors.rose, Icons.north_east_rounded),
          _MiniStat('Payé (période)', fmtDA(sumMvt(TypeMvt.paiement)), AppColors.sky, Icons.payments_rounded),
          _MiniStat('Autres gains (pièces, salaires)', fmtDA(gainsAutres), AppColors.teal, Icons.checkroom_rounded),
        ]),
        if (data.totalAvancesNonCouvertes > 0) ...[
          const SizedBox(height: 10),
          Text('Avances non encore couvertes par le travail : ${fmtDA(data.totalAvancesNonCouvertes)}',
              style: TextStyle(color: AppColors.rose, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ],
      ]),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 960;
        return ListView(
          padding: EdgeInsets.fromLTRB(wide ? 28 : 16, 8, wide ? 28 : 16, 32),
          children: [
            PeriodChips(
              periode: _periode,
              custom: _custom,
              onChanged: (p, cr) {
                setState(() {
                  _periode = p;
                  _custom = cr;
                });
                _load();
              },
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              OuvrierFilter(
                value: _ouvrierId,
                onChanged: (id) {
                  setState(() => _ouvrierId = id);
                  _load();
                },
              ),
              OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.file_download_outlined), label: const Text('Exporter CSV')),
            ]),
            const SizedBox(height: 14),
            AnimatedOpacity(
              opacity: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const LinearProgressIndicator(minHeight: 2),
            ),
            const SizedBox(height: 6),
            if (_error != null) ErrorBanner(_error!, onRetry: _load),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: hero),
                const SizedBox(width: 16),
                Expanded(flex: 6, child: stats),
              ])
            else ...[
              hero,
              const SizedBox(height: 12),
              stats,
            ],
            const SizedBox(height: 16),
            paieCard,
            const SizedBox(height: 16),
            chart,
            const SizedBox(height: 16),
            if (wide)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(children: [classement, const SizedBox(height: 16), typesCard])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [donut, const SizedBox(height: 16), dessins])),
              ])
            else ...[
              classement,
              const SizedBox(height: 16),
              typesCard,
              const SizedBox(height: 16),
              donut,
              const SizedBox(height: 16),
              dessins,
            ],
          ],
        );
      }),
    );
  }
}

Color _typeColor(String typeId) {
  final i = data.types.indexWhere((t) => t.id == typeId);
  return i < 0 ? const Color(0xFF9AA0B4) : AppColors.series[i % AppColors.series.length];
}

class _HeroCard extends StatelessWidget {
  final Agg total;
  final int? prevPoints;
  final Periode periode;
  const _HeroCard({required this.total, required this.prevPoints, required this.periode});

  @override
  Widget build(BuildContext context) {
    double? evol;
    if (prevPoints != null && prevPoints! > 0) evol = (total.points - prevPoints!) * 100 / prevPoints!;
    const white = Colors.white;
    return AppCard(
      gradient: AppColors.heroGradient,
      padding: const EdgeInsets.all(22),
      child: Stack(children: [
        Positioned(
          right: -10,
          top: -14,
          child: Icon(Icons.blur_on_rounded, size: 130, color: white.withValues(alpha: 0.10)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)),
              child: Text(periode.label, style: const TextStyle(color: white, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            const Spacer(),
            if (evol != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(evol >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: white, size: 16),
                  const SizedBox(width: 4),
                  Text('${evol >= 0 ? '+' : ''}${evol.toStringAsFixed(0)} %',
                      style: const TextStyle(color: white, fontWeight: FontWeight.w700, fontSize: 12)),
                ]),
              ),
          ]),
          const SizedBox(height: 18),
          const Text('Points brodés', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(fmtInt(total.points),
                style: const TextStyle(color: white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 18, runSpacing: 6, children: [
            _heroInfo(Icons.payments_rounded, fmtDA(total.montant)),
            _heroInfo(Icons.receipt_long_rounded, '${total.saisies} relevés'),
            if (prevPoints != null) _heroInfo(Icons.history_rounded, 'Avant : ${fmtCompact(prevPoints!)} pts'),
          ]),
        ]),
      ]),
    );
  }

  Widget _heroInfo(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: Colors.white70),
        const SizedBox(width: 5),
        Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]);
}

class _RankRow extends StatelessWidget {
  final int rank;
  final String ouvrierId;
  final Agg agg;
  final double ratio;
  const _RankRow({required this.rank, required this.ouvrierId, required this.agg, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final nom = data.ouvrierNom(ouvrierId);
    final medal = switch (rank) { 1 => AppColors.gold, 2 => const Color(0xFFB8C2CC), 3 => const Color(0xFFCD7F32), _ => null };
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: data.ouvrier(ouvrierId) == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: ouvrierId))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 22)
                : Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: context.pal.muted, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          NameAvatar(nom, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                Text(fmtInt(agg.points), style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(' pts', style: TextStyle(color: context.pal.muted, fontSize: 12)),
              ]),
              const SizedBox(height: 6),
              Bar(ratio, color: AppColors.forName(nom)),
              const SizedBox(height: 4),
              Text('${agg.saisies} équipe${agg.saisies > 1 ? 's' : ''} · ${fmtDA(agg.montant)}',
                  style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _MiniStat(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
              ),
              Text(label, style: context.tt.bodySmall?.copyWith(color: context.pal.muted), maxLines: 2),
            ]),
          ),
        ]),
      );
}
