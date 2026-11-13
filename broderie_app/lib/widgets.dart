import 'package:flutter/material.dart';

import 'data/app_data.dart';
import 'utils.dart';

/// Barre de filtre : période + ouvrier (optionnel).
class FilterBar extends StatelessWidget {
  final Periode periode;
  final DateTimeRange? custom;
  final String? ouvrierId;
  final void Function(Periode p, DateTimeRange? custom) onPeriode;
  final ValueChanged<String?>? onOuvrier;
  final List<Widget> trailing;

  const FilterBar({
    super.key,
    required this.periode,
    required this.custom,
    required this.onPeriode,
    this.ouvrierId,
    this.onOuvrier,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final r = rangeFor(periode, custom);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<Periode>(
            value: periode,
            decoration: const InputDecoration(labelText: 'Période'),
            items: [for (final p in Periode.values) DropdownMenuItem(value: p, child: Text(p.label))],
            onChanged: (p) async {
              if (p == null) return;
              if (p == Periode.personnalisee) {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  initialDateRange: custom ?? rangeFor(Periode.mois, null),
                );
                if (picked == null) return;
                onPeriode(p, picked);
              } else {
                onPeriode(p, custom);
              }
            },
          ),
        ),
        if (periode != Periode.tout)
          Text('${fmtDate(r.start)} → ${fmtDate(r.end)}', style: Theme.of(context).textTheme.bodySmall),
        if (onOuvrier != null)
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String?>(
              value: data.ouvrier(ouvrierId) == null ? null : ouvrierId,
              decoration: const InputDecoration(labelText: 'Ouvrier'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Tous les ouvriers')),
                for (final o in data.ouvriers) DropdownMenuItem<String?>(value: o.id, child: Text(o.nom)),
              ],
              onChanged: onOuvrier,
            ),
          ),
        ...trailing,
      ],
    );
  }
}

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const KpiCard({super.key, required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              backgroundColor: t.colorScheme.primaryContainer,
              foregroundColor: t.colorScheme.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  const SectionCard({super.key, required this.title, required this.child, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            ...actions,
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Icon(icon, size: 40, color: c),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: c)),
      ]),
    );
  }
}

/// Tableau simple et défilable horizontalement.
class SimpleTable extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final Set<int> numericCols;
  final List<String>? footer;
  const SimpleTable({super.key, required this.headers, required this.rows, this.numericCols = const {}, this.footer});

  @override
  Widget build(BuildContext context) {
    final bold = const TextStyle(fontWeight: FontWeight.w700);
    DataCell cell(String s, int i, {bool b = false}) => DataCell(
          Align(
            alignment: numericCols.contains(i) ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(s, style: b ? bold : null),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 36,
        dataRowMaxHeight: 44,
        columns: [
          for (var i = 0; i < headers.length; i++) DataColumn(label: Text(headers[i]), numeric: numericCols.contains(i)),
        ],
        rows: [
          for (final r in rows) DataRow(cells: [for (var i = 0; i < r.length; i++) cell(r[i], i)]),
          if (footer != null) DataRow(cells: [for (var i = 0; i < footer!.length; i++) cell(footer![i], i, b: true)]),
        ],
      ),
    );
  }
}
