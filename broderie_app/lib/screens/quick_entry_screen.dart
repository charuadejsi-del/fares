import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Saisie rapide en 3 touches : ouvrier → dessin → nombre de robes.
class QuickEntryScreen extends StatefulWidget {
  final VoidCallback? onGoToRefs;
  const QuickEntryScreen({super.key, this.onGoToRefs});

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  String? _ouvrierId;
  String? _dessinId;
  String? _machineId;
  int _robes = 0;
  DateTime _date = dayOnly(DateTime.now());
  bool _busy = false;
  final _note = TextEditingController();
  String _searchDessin = '';

  // Production du jour (bandeau du haut)
  int _todayPts = 0;
  int _todayRobes = 0;
  int _seenVersion = -1;

  int get _step => _ouvrierId == null ? 0 : (_dessinId == null ? 1 : 2);

  @override
  void initState() {
    super.initState();
    data.addListener(_onData);
    _loadToday();
  }

  @override
  void dispose() {
    data.removeListener(_onData);
    _note.dispose();
    super.dispose();
  }

  void _onData() {
    if (data.productionVersion != _seenVersion) _loadToday();
    if (mounted) setState(() {});
  }

  Future<void> _loadToday() async {
    _seenVersion = data.productionVersion;
    try {
      final t = dayOnly(DateTime.now());
      final rows = await data.fetchProduction(t, t);
      if (mounted) {
        setState(() {
          _todayPts = rows.fold<int>(0, (s, p) => s + p.totalPoints);
          _todayRobes = rows.fold<int>(0, (s, p) => s + p.nbRobes);
        });
      }
    } catch (_) {}
  }

  void _add(int n) {
    HapticFeedback.selectionClick();
    setState(() => _robes = (_robes + n).clamp(0, 99999));
  }

  Future<void> _editRobes() async {
    final c = TextEditingController(text: _robes == 0 ? '' : '$_robes');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de robes'),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onSubmitted: (s) => Navigator.pop(ctx, int.tryParse(s)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: const Text('OK')),
        ],
      ),
    );
    if (v != null) setState(() => _robes = v.clamp(0, 99999));
  }

  Future<void> _save() async {
    final o = data.ouvrier(_ouvrierId);
    final d = data.dessin(_dessinId);
    if (o == null || d == null || _robes <= 0) return;
    setState(() => _busy = true);
    try {
      await data.saveProduction(Production.toRow(
        dateKey: dateKey(_date),
        ouvrierId: o.id,
        dessinId: d.id,
        machineId: _machineId,
        nbRobes: _robes,
        pointsParRobe: d.points,
        tarif1000: o.tarif1000,
        note: _note.text,
      ));
      HapticFeedback.mediumImpact();
      if (mounted) {
        showSnack(context, '✓ ${o.nom} : ${fmtInt(_robes)} robes · ${fmtInt(_robes * d.points)} points');
        setState(() {
          _robes = 0;
          _note.clear();
        });
      }
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ouvriers = data.ouvriers.where((o) => o.actif).toList();
    final dessins = data.dessins
        .where((d) => d.actif)
        .where((d) => _searchDessin.isEmpty || d.nom.toLowerCase().contains(_searchDessin.toLowerCase()))
        .toList();

    if (ouvriers.isEmpty || data.dessins.where((d) => d.actif).isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        EmptyState(
          'Pour commencer, ajoutez au moins un ouvrier et un dessin (avec son nombre de points).',
          icon: Icons.rocket_launch_outlined,
          action: widget.onGoToRefs == null
              ? null
              : FilledButton.icon(onPressed: widget.onGoToRefs, icon: const Icon(Icons.person_add_alt_1), label: const Text('Ajouter')),
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth >= 900 ? 28.0 : 16.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
        children: [
          _TodayBanner(points: _todayPts, robes: _todayRobes),
          const SizedBox(height: 16),
          _Steps(step: _step),
          const SizedBox(height: 16),

          // ---------------- Étape 1 : ouvrier
          if (_step == 0) ...[
            const SectionTitle('Qui a brodé ?', subtitle: 'Choisissez l\'ouvrier'),
            AutoGrid(minItemWidth: 150, children: [
              for (final o in ouvriers)
                AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => setState(() => _ouvrierId = o.id),
                  child: Column(children: [
                    NameAvatar(o.nom, size: 56),
                    const SizedBox(height: 10),
                    Text(o.nom, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ] else
            _Selected(
              label: 'Ouvrier',
              title: data.ouvrierNom(_ouvrierId!),
              leading: NameAvatar(data.ouvrierNom(_ouvrierId!), size: 40),
              onChange: () => setState(() {
                _ouvrierId = null;
              }),
            ),

          // ---------------- Étape 2 : dessin
          if (_step == 1) ...[
            const SizedBox(height: 16),
            SectionTitle('Quel dessin ?', subtitle: 'Choisissez le dessin brodé',
                trailing: SizedBox(
                  width: 180,
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Rechercher', prefixIcon: Icon(Icons.search, size: 20)),
                    onChanged: (v) => setState(() => _searchDessin = v),
                  ),
                )),
            AutoGrid(minItemWidth: 160, children: [
              for (final d in dessins)
                AppCard(
                  padding: const EdgeInsets.all(10),
                  onTap: () => setState(() => _dessinId = d.id),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    AspectRatio(
                      aspectRatio: 1.25,
                      child: LayoutBuilder(builder: (_, bc) => DessinThumb(d, size: bc.maxWidth, radius: 14)),
                    ),
                    const SizedBox(height: 8),
                    Text(d.nom, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${fmtInt(d.points)} pts', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                  ]),
                ),
            ]),
          ] else if (_step == 2) ...[
            const SizedBox(height: 10),
            _Selected(
              label: 'Dessin',
              title: data.dessinNom(_dessinId!),
              subtitle: '${fmtInt(data.dessin(_dessinId)?.points ?? 0)} points / robe',
              leading: DessinThumb(data.dessin(_dessinId), size: 40, radius: 12),
              onChange: () => setState(() => _dessinId = null),
            ),
          ],

          // ---------------- Étape 3 : quantité
          if (_step == 2) ...[
            const SizedBox(height: 16),
            _CounterCard(
              robes: _robes,
              pointsParRobe: data.dessin(_dessinId)?.points ?? 0,
              tarif: data.ouvrier(_ouvrierId)?.tarif1000 ?? 0,
              onAdd: _add,
              onTapValue: _editRobes,
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ActionChip(
                avatar: const Icon(Icons.event_rounded, size: 18),
                label: Text(_date == dayOnly(DateTime.now()) ? 'Aujourd\'hui' : fmtDate(_date)),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (d != null) setState(() => _date = d);
                },
              ),
              for (final m in data.machines.where((m) => m.actif))
                ChoiceChip(
                  avatar: const Icon(Icons.precision_manufacturing_outlined, size: 18),
                  label: Text(m.nom),
                  selected: _machineId == m.id,
                  onSelected: (s) => setState(() => _machineId = s ? m.id : null),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(hintText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
            const SizedBox(height: 16),
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: (_busy || _robes <= 0) ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_robes <= 0 ? 'Indiquez le nombre de robes' : 'Enregistrer ${fmtInt(_robes)} robes'),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _TodayBanner extends StatelessWidget {
  final int points;
  final int robes;
  const _TodayBanner({required this.points, required this.robes});

  @override
  Widget build(BuildContext context) => AppCard(
        gradient: AppColors.heroGradient,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(children: [
          const Icon(Icons.today_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          const Expanded(
            child: Text("Aujourd'hui", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${fmtInt(points)} pts', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
            Text('${fmtInt(robes)} robes', style: const TextStyle(color: Colors.white70)),
          ]),
        ]),
      );
}

class _Steps extends StatelessWidget {
  final int step;
  const _Steps({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Ouvrier', 'Dessin', 'Quantité'];
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              decoration: BoxDecoration(
                color: i <= step ? context.cs.primary : context.pal.surface2,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Text('${i + 1}. ${labels[i]}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                  color: i <= step ? context.cs.onSurface : context.pal.muted,
                )),
          ]),
        ),
        if (i < 2) const SizedBox(width: 8),
      ],
    ]);
  }
}

class _Selected extends StatelessWidget {
  final String label;
  final String title;
  final String? subtitle;
  final Widget leading;
  final VoidCallback onChange;
  const _Selected({required this.label, required this.title, required this.leading, required this.onChange, this.subtitle});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: context.tt.labelSmall?.copyWith(color: context.pal.muted)),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis),
              if (subtitle != null) Text(subtitle!, style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
            ]),
          ),
          TextButton.icon(onPressed: onChange, icon: const Icon(Icons.swap_horiz_rounded, size: 18), label: const Text('Changer')),
        ]),
      );
}

class _CounterCard extends StatelessWidget {
  final int robes;
  final int pointsParRobe;
  final double tarif;
  final void Function(int) onAdd;
  final VoidCallback onTapValue;
  const _CounterCard({required this.robes, required this.pointsParRobe, required this.tarif, required this.onAdd, required this.onTapValue});

  @override
  Widget build(BuildContext context) {
    final total = robes * pointsParRobe;
    Widget round(IconData i, VoidCallback? f) => SizedBox(
          width: 64,
          height: 64,
          child: IconButton.filledTonal(onPressed: f, icon: Icon(i, size: 30)),
        );
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text('Combien de robes ?', style: context.tt.titleMedium),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          round(Icons.remove_rounded, robes > 0 ? () => onAdd(-1) : null),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTapValue,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Text('$robes',
                        key: ValueKey(robes),
                        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: context.cs.primary, height: 1)),
                  ),
                  Text('toucher pour taper', style: context.tt.labelSmall?.copyWith(color: context.pal.muted)),
                ]),
              ),
            ),
          ),
          round(Icons.add_rounded, () => onAdd(1)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final n in [5, 10, 20, 50])
            OutlinedButton(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onPressed: () => onAdd(n),
              child: Text('+$n', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
        ]),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: context.pal.surface2, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Text('${fmtInt(robes)} × ${fmtInt(pointsParRobe)} points', style: TextStyle(color: context.pal.muted)),
            const SizedBox(height: 2),
            Text('${fmtInt(total)} points', style: context.tt.headlineSmall?.copyWith(color: context.cs.primary)),
            if (tarif > 0) Text(fmtDA(total * tarif / 1000), style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}
