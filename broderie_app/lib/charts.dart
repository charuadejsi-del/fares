import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'data/models.dart';
import 'theme.dart';
import 'utils.dart';
import 'i18n.dart';

class _Bucket {
  final DateTime start;
  final String label;
  final String tooltip;
  int points = 0;
  double montant = 0;
  _Bucket(this.start, this.label, this.tooltip);
}

/// Histogramme des points brodés par jour (ou par mois sur les longues périodes).
class PointsBarChart extends StatelessWidget {
  final List<Production> rows;
  final DateTimeRange range;
  final double height;
  const PointsBarChart({super.key, required this.rows, required this.range, this.height = 220});

  List<_Bucket> _buckets() {
    var start = range.start;
    final end = range.end;
    // Période « tout » : commencer à la première saisie
    if (rows.isNotEmpty) {
      final first = rows.map((p) => p.dateProd).reduce((a, b) => a.isBefore(b) ? a : b);
      if (first.isAfter(start)) start = dayOnly(first);
    }
    final days = end.difference(start).inDays + 1;
    final byMonth = days > 45;
    final list = <_Bucket>[];
    final index = <String, _Bucket>{};
    if (byMonth) {
      var m = DateTime(start.year, start.month, 1);
      while (!m.isAfter(end)) {
        final b = _Bucket(m, fmtShortMonth(m), fmtMonthYear(m));
        list.add(b);
        index['${m.year}-${m.month}'] = b;
        m = DateTime(m.year, m.month + 1, 1);
      }
      for (final p in rows) {
        final b = index['${p.dateProd.year}-${p.dateProd.month}'];
        if (b != null) {
          b.points += p.totalPoints;
          b.montant += p.montant;
        }
      }
    } else {
      for (var i = 0; i < days; i++) {
        final d = DateTime(start.year, start.month, start.day + i);
        final b = _Bucket(d, days <= 8 ? fmtWeekday(d) : '${d.day}', fmtDate(d));
        list.add(b);
        index[dateKey(d)] = b;
      }
      for (final p in rows) {
        final b = index[dateKey(p.dateProd)];
        if (b != null) {
          b.points += p.totalPoints;
          b.montant += p.montant;
        }
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = _buckets();
    if (buckets.isEmpty) return SizedBox(height: height);
    final maxY = buckets.fold<int>(0, (m, b) => b.points > m ? b.points : m);
    final top = maxY == 0 ? 1000.0 : maxY * 1.18;
    final step = (buckets.length / 10).ceil().clamp(1, 1000);
    final barW = (260 / buckets.length).clamp(4.0, 26.0);
    final muted = context.pal.muted;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: top,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: top / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1, dashArray: [4, 4]),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: top / 4,
                getTitlesWidget: (v, meta) => v == 0 || v >= top
                    ? const SizedBox.shrink()
                    : Text(fmtCompact(v), style: TextStyle(fontSize: 10, color: muted)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: 1,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= buckets.length || i % step != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(buckets[i].label, style: TextStyle(fontSize: 10, color: muted)),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => context.isDark ? const Color(0xFF2B2F3E) : const Color(0xFF1F1A2E),
              getTooltipItem: (group, gi, rod, ri) {
                final b = buckets[group.x];
                return BarTooltipItem(
                  '${b.tooltip}\n',
                  const TextStyle(color: Colors.white70, fontSize: 11),
                  children: [
                    TextSpan(
                      text: '{0} pts · {1}'.trf([fmtInt(b.points), fmtDA(b.montant)]),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: buckets[i].points.toDouble(),
                  width: barW,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  gradient: const LinearGradient(
                    colors: [AppColors.violetDeep, AppColors.violet, Color(0xFFC4B5FD)],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: context.pal.surface2),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

/// Donut de répartition (ex. points par ouvrier).
class ShareDonut extends StatelessWidget {
  final List<MapEntry<String, int>> parts; // libellé -> valeur
  final String centerValue;
  final String centerLabel;
  final double size;
  const ShareDonut({super.key, required this.parts, required this.centerValue, required this.centerLabel, this.size = 190});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (s, e) => s + e.value);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            centerSpaceRadius: size * 0.31,
            sectionsSpace: 3,
            startDegreeOffset: -90,
            sections: total == 0
                ? [PieChartSectionData(value: 1, color: context.pal.surface2, radius: size * 0.14, showTitle: false)]
                : [
                    for (var i = 0; i < parts.length; i++)
                      PieChartSectionData(
                        value: parts[i].value.toDouble(),
                        color: AppColors.series[i % AppColors.series.length],
                        radius: size * 0.14,
                        showTitle: false,
                      ),
                  ],
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(centerValue, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(centerLabel, style: context.tt.labelSmall?.copyWith(color: context.pal.muted)),
        ]),
      ]),
    );
  }
}

/// Légende du donut.
class DonutLegend extends StatelessWidget {
  final List<MapEntry<String, int>> parts;
  const DonutLegend({super.key, required this.parts});

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (s, e) => s + e.value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 0; i < parts.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: AppColors.series[i % AppColors.series.length], shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(parts[i].key, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(total == 0 ? '0 %' : '${(parts[i].value * 100 / total).toStringAsFixed(0)} %',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
    ]);
  }
}

/// Histogramme simple (une valeur par libellé), ex. chiffre d'affaires par mois.
class SimpleBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double height;
  final Color color;
  const SimpleBarChart({super.key, required this.labels, required this.values, this.height = 220, this.color = AppColors.violet});

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(0, (m, v) => v > m ? v : m);
    final top = maxV == 0 ? 1000.0 : maxV * 1.18;
    final muted = context.pal.muted;
    return SizedBox(
      height: height,
      child: BarChart(BarChartData(
        maxY: top,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: top / 4,
          getDrawingHorizontalLine: (_) => FlLine(color: context.pal.line, strokeWidth: 1, dashArray: [4, 4]),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              interval: top / 4,
              getTitlesWidget: (v, meta) => v == 0 || v >= top ? const SizedBox.shrink() : Text(fmtCompact(v), style: TextStyle(fontSize: 10, color: muted)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[i], style: TextStyle(fontSize: 10, color: muted)));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1F1A2E),
            getTooltipItem: (g, gi, rod, ri) => BarTooltipItem(
              '${labels[g.x]}\n',
              const TextStyle(color: Colors.white70, fontSize: 11),
              children: [TextSpan(text: fmtDA(values[g.x]), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))],
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: values[i],
                width: (300 / values.length).clamp(6.0, 28.0),
                color: color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: top, color: context.pal.surface2),
              ),
            ]),
        ],
      )),
    );
  }
}
