import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Historique de production, regroupé par jour.
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  Periode _periode = Periode.semaine;
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
      final rows = await data.fetchProduction(r.start, r.end, ouvrierId: _ouvrierId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <DateTime, List<Production>>{};
    for (final p in _rows) {
      byDay.putIfAbsent(dayOnly(p.dateProd), () => []).add(p);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-hist',
        onPressed: () => openProductionForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Saisie détaillée'),
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
            OuvrierFilter(
              value: _ouvrierId,
              onChanged: (id) {
                setState(() => _ouvrierId = id);
                _load();
              },
            ),
            const SizedBox(height: 10),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ErrorBanner(_error!, onRetry: _load),
            if (!_loading && _rows.isEmpty && _error == null)
              const EmptyState('Aucune saisie sur cette période.', icon: Icons.history_rounded),
            for (final d in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8, left: 4, right: 4),
                child: Row(children: [
                  Expanded(
                    child: Text(_capitalize(fmtDateLong(d)),
                        style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.cs.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${fmtInt(byDay[d]!.fold<int>(0, (s, p) => s + p.nbRobes))} robes · ${fmtCompact(byDay[d]!.fold<int>(0, (s, p) => s + p.totalPoints))} pts',
                      style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ]),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(children: [
                  for (final p in byDay[d]!) ...[
                    ProductionTile(p),
                    if (p != byDay[d]!.last) const Divider(height: 1, indent: 64),
                  ],
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Ouvre le formulaire détaillé (ajout ou modification).
Future<void> openProductionForm(BuildContext context, [Production? p]) async {
  if (data.ouvriers.where((o) => o.actif).isEmpty || data.dessins.where((d) => d.actif).isEmpty) {
    showSnack(context, 'Ajoutez d\'abord au moins un ouvrier et un dessin.', error: true);
    return;
  }
  final saved = await showDialog<bool>(context: context, builder: (_) => ProductionForm(existing: p));
  if (saved == true && context.mounted) showSnack(context, p == null ? 'Saisie enregistrée' : 'Saisie modifiée');
}

Future<void> deleteProductionWithConfirm(BuildContext context, Production p) async {
  final ok = await confirmDialog(context, 'Supprimer la saisie',
      '${data.ouvrierNom(p.ouvrierId)} — ${data.dessinNom(p.dessinId)} — ${p.nbRobes} robes du ${fmtDate(p.dateProd)} ?');
  if (!ok) return;
  try {
    await data.deleteProduction(p.id);
    if (context.mounted) showSnack(context, 'Saisie supprimée');
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e), error: true);
  }
}

/// Ligne d'une saisie de production.
class ProductionTile extends StatelessWidget {
  final Production p;
  final bool showOuvrier;
  const ProductionTile(this.p, {super.key, this.showOuvrier = true});

  @override
  Widget build(BuildContext context) {
    final details = [
      '${fmtInt(p.nbRobes)} robes × ${fmtInt(p.pointsParRobe)}',
      if (!showOuvrier) fmtDate(p.dateProd),
      if (p.machineId != null && data.machineNom(p.machineId).isNotEmpty) data.machineNom(p.machineId),
      if (p.note != null) p.note!,
    ].join(' · ');
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openProductionForm(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(children: [
          DessinThumb(data.dessin(p.dessinId), size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                showOuvrier ? '${data.ouvrierNom(p.ouvrierId)} — ${data.dessinNom(p.dessinId)}' : data.dessinNom(p.dessinId),
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(details, style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtInt(p.totalPoints), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(p.montant > 0 ? fmtDA(p.montant) : 'pts', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          ]),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.pal.muted),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Modifier')),
              PopupMenuItem(value: 'del', child: Text('Supprimer')),
            ],
            onSelected: (v) => v == 'edit' ? openProductionForm(context, p) : deleteProductionWithConfirm(context, p),
          ),
        ]),
      ),
    );
  }
}

/// Formulaire d'ajout / modification d'une saisie de production.
class ProductionForm extends StatefulWidget {
  final Production? existing;
  const ProductionForm({super.key, this.existing});

  @override
  State<ProductionForm> createState() => _ProductionFormState();
}

class _ProductionFormState extends State<ProductionForm> {
  final _form = GlobalKey<FormState>();
  late DateTime _date;
  String? _ouvrierId;
  String? _dessinId;
  String? _machineId;
  final _robes = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  Production? get _ex => widget.existing;

  @override
  void initState() {
    super.initState();
    final e = _ex;
    _date = e?.dateProd ?? dayOnly(DateTime.now());
    _ouvrierId = e?.ouvrierId;
    _dessinId = e?.dessinId;
    _machineId = data.machine(e?.machineId) == null ? null : e?.machineId;
    if (e != null) _robes.text = e.nbRobes.toString();
    _note.text = e?.note ?? '';
    _robes.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _robes.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Points par robe : on garde la valeur figée de la saisie si le dessin n'a pas changé.
  int get _ppr {
    final e = _ex;
    if (e != null && e.dessinId == _dessinId) return e.pointsParRobe;
    return data.dessin(_dessinId)?.points ?? 0;
  }

  double get _tarif {
    final e = _ex;
    if (e != null && e.ouvrierId == _ouvrierId) return e.tarif1000;
    return data.ouvrier(_ouvrierId)?.tarif1000 ?? 0;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveProduction(
        Production.toRow(
          dateKey: dateKey(_date),
          ouvrierId: _ouvrierId!,
          dessinId: _dessinId!,
          machineId: _machineId,
          nbRobes: parseInt(_robes.text)!,
          pointsParRobe: _ppr,
          tarif1000: _tarif,
          note: _note.text,
        ),
        id: _ex?.id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ouvriers / dessins actifs + celui de la saisie modifiée s'il a été désactivé
    final ouvriers = data.ouvriers.where((o) => o.actif || o.id == _ex?.ouvrierId).toList();
    final dessins = data.dessins.where((d) => d.actif || d.id == _ex?.dessinId).toList();
    final machines = data.machines.where((m) => m.actif || m.id == _ex?.machineId).toList();
    final robes = parseInt(_robes.text) ?? 0;
    final total = robes * _ppr;
    final montant = total * _tarif / 1000;
    final t = Theme.of(context);

    return AlertDialog(
      title: Text(_ex == null ? 'Nouvelle saisie' : 'Modifier la saisie'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
                  child: Text(fmtDate(_date)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _ouvrierId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ouvrier', prefixIcon: Icon(Icons.person_outline)),
                items: [for (final o in ouvriers) DropdownMenuItem(value: o.id, child: Text(o.nom))],
                onChanged: (v) => setState(() => _ouvrierId = v),
                validator: (v) => v == null ? 'Choisissez un ouvrier' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _dessinId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dessin', prefixIcon: Icon(Icons.draw_outlined)),
                items: [
                  for (final d in dessins)
                    DropdownMenuItem(value: d.id, child: Text('${d.nom} — ${fmtInt(d.points)} pts', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _dessinId = v),
                validator: (v) => v == null ? 'Choisissez un dessin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _robes,
                keyboardType: TextInputType.number,
                autofocus: _ex == null,
                decoration: const InputDecoration(labelText: 'Nombre de robes / pièces', prefixIcon: Icon(Icons.checkroom)),
                validator: (v) {
                  final n = parseInt(v ?? '');
                  if (n == null || n <= 0) return 'Nombre entier supérieur à 0';
                  if (n > 100000) return 'Nombre trop grand';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: _machineId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Machine (facultatif)', prefixIcon: Icon(Icons.settings_input_component_outlined)),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final m in machines) DropdownMenuItem<String?>(value: m.id, child: Text(m.nom)),
                ],
                onChanged: (v) => setState(() => _machineId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: (_dessinId == null || robes <= 0)
                    ? Text('Choisissez un dessin et un nombre de robes.', style: TextStyle(color: t.colorScheme.onPrimaryContainer))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${fmtInt(robes)} robes × ${fmtInt(_ppr)} points', style: TextStyle(color: t.colorScheme.onPrimaryContainer)),
                        Text('${fmtInt(total)} points',
                            style: t.textTheme.headlineSmall?.copyWith(color: t.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                        if (_tarif > 0) Text(fmtDA(montant), style: TextStyle(color: t.colorScheme.onPrimaryContainer)),
                      ]),
              ),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
