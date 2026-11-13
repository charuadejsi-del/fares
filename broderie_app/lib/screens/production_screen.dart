import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'quick_entry_screen.dart';

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
        label: const Text('Nouveau relevé'),
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
                      '${fmtCompact(byDay[d]!.fold<int>(0, (s, p) => s + p.totalPoints))} pts · ${fmtDA(byDay[d]!.fold<double>(0, (s, p) => s + p.montant))}',
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
  if (data.ouvriers.where((o) => o.actif).isEmpty) {
    showSnack(context, 'Ajoutez d\'abord au moins un ouvrier.', error: true);
    return;
  }
  final saved = await showDialog<bool>(context: context, builder: (_) => ProductionForm(existing: p));
  if (saved == true && context.mounted) showSnack(context, p == null ? 'Saisie enregistrée' : 'Saisie modifiée');
}

Future<void> deleteProductionWithConfirm(BuildContext context, Production p) async {
  final ok = await confirmDialog(context, 'Supprimer la saisie',
      '${data.ouvrierNom(p.ouvrierId)} — ${data.typeNom(p.typeId)} — ${fmtInt(p.totalPoints)} points (${p.equipe.label}, ${fmtDate(p.dateProd)}) ?');
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
      '${p.equipe == Equipe.jour ? '☀' : '☾'} ${p.equipe.label}',
      if (!showOuvrier) fmtDate(p.dateProd),
      if (p.machineId != null && data.machineNom(p.machineId).isNotEmpty) data.machineNom(p.machineId),
      if (p.dessinId != null) data.dessinNom(p.dessinId!),
      if (p.nbRobes != null) '${fmtInt(p.nbRobes!)} robes',
      if (p.note != null) p.note!,
    ].join(' · ');
    final nuit = p.equipe == Equipe.nuit;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => openProductionForm(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(children: [
          showOuvrier
              ? NameAvatar(data.ouvrierNom(p.ouvrierId), size: 44)
              : Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (nuit ? AppColors.sky : AppColors.gold).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(nuit ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: nuit ? AppColors.sky : AppColors.gold),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (showOuvrier)
                  Flexible(
                    child: Text(data.ouvrierNom(p.ouvrierId),
                        style: const TextStyle(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  ),
                if (showOuvrier) const SizedBox(width: 6),
                TypeBadge(p.typeId),
              ]),
              const SizedBox(height: 3),
              Text(details, style: context.tt.bodySmall?.copyWith(color: context.pal.muted), overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(fmtDA(p.montant), style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('${fmtInt(p.totalPoints)} pts', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
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

/// Formulaire d'ajout / modification d'un relevé de compteur.
class ProductionForm extends StatefulWidget {
  final Production? existing;
  const ProductionForm({super.key, this.existing});

  @override
  State<ProductionForm> createState() => _ProductionFormState();
}

class _ProductionFormState extends State<ProductionForm> {
  final _form = GlobalKey<FormState>();
  late DateTime _date;
  late Equipe _equipe;
  String? _ouvrierId;
  String? _typeId;
  String? _machineId;
  String? _dessinId;
  final _points = TextEditingController();
  final _robes = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  Production? get _ex => widget.existing;

  @override
  void initState() {
    super.initState();
    final e = _ex;
    final (eq, d) = defaultShift();
    _date = e?.dateProd ?? d;
    _equipe = e?.equipe ?? eq;
    _ouvrierId = e?.ouvrierId;
    _typeId = data.type(e?.typeId) == null ? null : e?.typeId;
    _machineId = data.machine(e?.machineId) == null ? null : e?.machineId;
    _dessinId = data.dessin(e?.dessinId) == null ? null : e?.dessinId;
    if (e != null) _points.text = ThousandsFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: '${e.totalPoints}')).text;
    if (e?.nbRobes != null) _robes.text = '${e!.nbRobes}';
    _note.text = e?.note ?? '';
    _points.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _points.dispose();
    _robes.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Tarif : on garde celui de la saisie si le type n'a pas changé.
  double get _tarif {
    final e = _ex;
    if (e != null && e.typeId == _typeId) return e.tarif1000;
    return data.type(_typeId)?.tarif1000 ?? 0;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveProduction(
        Production.toRow(
          dateKey: dateKey(_date),
          equipe: _equipe,
          ouvrierId: _ouvrierId!,
          typeId: _typeId!,
          machineId: _machineId,
          dessinId: _dessinId,
          nbRobes: parseInt(_robes.text),
          totalPoints: parseInt(_points.text)!,
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
    final ouvriers = data.ouvriers.where((o) => o.actif || o.id == _ex?.ouvrierId).toList();
    final types = data.types.where((t) => t.actif || t.id == _ex?.typeId).toList();
    final machines = data.machines.where((m) => m.actif || m.id == _ex?.machineId).toList();
    final pts = parseInt(_points.text) ?? 0;

    return AlertDialog(
      title: Text(_ex == null ? 'Nouveau relevé' : 'Modifier le relevé'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.event)),
                      child: Text(fmtDate(_date)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SegmentedButton<Equipe>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: Equipe.jour, icon: Icon(Icons.wb_sunny_rounded), label: Text('Jour')),
                    ButtonSegment(value: Equipe.nuit, icon: Icon(Icons.nightlight_round), label: Text('Nuit')),
                  ],
                  selected: {_equipe},
                  onSelectionChanged: (s) => setState(() => _equipe = s.first),
                ),
              ]),
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
                value: _typeId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type de broderie', prefixIcon: Icon(Icons.gesture_rounded)),
                items: [
                  for (final t in types) DropdownMenuItem(value: t.id, child: Text('${t.nom} — ${fmtDA(t.tarif1000)} / 1000 pts')),
                ],
                onChanged: (v) => setState(() => _typeId = v),
                validator: (v) => v == null ? 'Choisissez le type' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _points,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                decoration: const InputDecoration(labelText: 'Points du compteur', prefixIcon: Icon(Icons.blur_on_rounded), suffixText: 'pts'),
                validator: (v) {
                  final n = parseInt(v ?? '');
                  return (n == null || n <= 0) ? 'Nombre de points supérieur à 0' : null;
                },
              ),
              const SizedBox(height: 12),
              if (machines.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  value: _machineId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Machine', prefixIcon: Icon(Icons.precision_manufacturing_outlined)),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('—')),
                    for (final m in machines) DropdownMenuItem<String?>(value: m.id, child: Text('${m.nom} · ${m.nbTetes} têtes')),
                  ],
                  onChanged: (v) => setState(() => _machineId = v),
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String?>(
                value: _dessinId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Dessin (facultatif)', prefixIcon: Icon(Icons.local_florist_outlined)),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('—')),
                  for (final d in data.dessins.where((d) => d.actif || d.id == _ex?.dessinId))
                    DropdownMenuItem<String?>(value: d.id, child: Text(d.nom)),
                ],
                onChanged: (v) => setState(() => _dessinId = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _robes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Nombre de robes (facultatif)', prefixIcon: Icon(Icons.checkroom_rounded)),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text('${fmtInt(pts)} pts × ${fmtDA(_tarif)} / 1000', style: const TextStyle(color: Colors.white70)),
                  Text(fmtDA(pts * _tarif / 1000),
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
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

/// Pastille colorée du type de broderie.
class TypeBadge extends StatelessWidget {
  final String? typeId;
  const TypeBadge(this.typeId, {super.key});

  @override
  Widget build(BuildContext context) {
    final i = data.types.indexWhere((t) => t.id == typeId);
    final c = i < 0 ? context.pal.muted : AppColors.series[i % AppColors.series.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(data.typeNom(typeId), style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}
