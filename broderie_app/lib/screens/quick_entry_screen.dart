import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

/// Équipe et date par défaut selon l'heure : 8 h–20 h = jour,
/// après 20 h = nuit du jour, avant 8 h = nuit de la veille.
(Equipe, DateTime) defaultShift() {
  final now = DateTime.now();
  final today = dayOnly(now);
  if (now.hour >= 8 && now.hour < 20) return (Equipe.jour, today);
  if (now.hour >= 20) return (Equipe.nuit, today);
  return (Equipe.nuit, today.subtract(const Duration(days: 1)));
}

/// Saisie rapide : ouvrier → type de broderie → points du compteur.
class QuickEntryScreen extends StatefulWidget {
  final VoidCallback? onGoToRefs;
  const QuickEntryScreen({super.key, this.onGoToRefs});

  @override
  State<QuickEntryScreen> createState() => _QuickEntryScreenState();
}

class _QuickEntryScreenState extends State<QuickEntryScreen> {
  String? _ouvrierId;
  String? _typeId;
  String? _machineId;
  String? _dessinId;
  late Equipe _equipe;
  late DateTime _date;
  final _points = TextEditingController();
  final _robes = TextEditingController();
  final _note = TextEditingController();
  final _pointsFocus = FocusNode();
  bool _busy = false;

  int _todayPts = 0;
  double _todayDA = 0;
  int _seenVersion = -1;

  int get _step => _ouvrierId == null ? 0 : (_typeId == null ? 1 : 2);
  int get _pts => parseInt(_points.text) ?? 0;

  @override
  void initState() {
    super.initState();
    final (e, d) = defaultShift();
    _equipe = e;
    _date = d;
    final actives = data.machines.where((m) => m.actif).toList();
    if (actives.length == 1) _machineId = actives.first.id;
    _points.addListener(() => setState(() {}));
    data.addListener(_onData);
    _loadToday();
  }

  @override
  void dispose() {
    data.removeListener(_onData);
    _points.dispose();
    _robes.dispose();
    _note.dispose();
    _pointsFocus.dispose();
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
          _todayDA = rows.fold<double>(0, (s, p) => s + p.montant);
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final o = data.ouvrier(_ouvrierId);
    final t = data.type(_typeId);
    if (o == null || t == null || _pts <= 0) return;
    setState(() => _busy = true);
    try {
      await data.saveProduction(Production.toRow(
        dateKey: dateKey(_date),
        equipe: _equipe,
        ouvrierId: o.id,
        typeId: t.id,
        machineId: _machineId,
        dessinId: _dessinId,
        nbRobes: parseInt(_robes.text),
        totalPoints: _pts,
        tarif1000: t.tarif1000,
        note: _note.text,
      ));
      HapticFeedback.mediumImpact();
      if (mounted) {
        showSnack(context, '✓ ${o.nom} · ${t.nom} : ${fmtInt(_pts)} points = ${fmtDA(_pts * t.tarif1000 / 1000)}');
        setState(() {
          _points.clear();
          _robes.clear();
          _note.clear();
          _dessinId = null;
          _ouvrierId = null;
          _typeId = null;
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
    final types = data.types.where((t) => t.actif).toList();

    if (ouvriers.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [
        EmptyState(
          'Pour commencer, ajoutez vos ouvriers.',
          icon: Icons.rocket_launch_outlined,
          action: widget.onGoToRefs == null
              ? null
              : FilledButton.icon(onPressed: widget.onGoToRefs, icon: const Icon(Icons.person_add_alt_1), label: const Text('Ajouter un ouvrier')),
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, c) {
      final pad = c.maxWidth >= 900 ? 28.0 : 16.0;
      return ListView(
        padding: EdgeInsets.fromLTRB(pad, 8, pad, 32),
        children: [
          _TodayBanner(points: _todayPts, montant: _todayDA),
          const SizedBox(height: 16),
          _Steps(step: _step),
          const SizedBox(height: 16),

          // ---------------- 1. Ouvrier
          if (_step == 0) ...[
            const SectionTitle('Qui a travaillé ?', subtitle: 'Choisissez l\'ouvrier'),
            AutoGrid(minItemWidth: 150, children: [
              for (final o in ouvriers)
                AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => setState(() {
                    _ouvrierId = o.id;
                    if (types.length == 1) _typeId = types.first.id;
                  }),
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
              onChange: () => setState(() => _ouvrierId = null),
            ),

          // ---------------- 2. Type de broderie
          if (_step == 1) ...[
            const SizedBox(height: 16),
            const SectionTitle('Type de broderie', subtitle: 'Le prix dépend du type'),
            AutoGrid(minItemWidth: 200, children: [
              for (var i = 0; i < types.length; i++)
                _TypeCard(
                  type: types[i],
                  color: AppColors.series[i % AppColors.series.length],
                  onTap: () {
                    setState(() => _typeId = types[i].id);
                    Future.delayed(const Duration(milliseconds: 120), () {
                      if (mounted) _pointsFocus.requestFocus();
                    });
                  },
                ),
            ]),
          ] else if (_step == 2) ...[
            const SizedBox(height: 10),
            _Selected(
              label: 'Type de broderie',
              title: data.typeNom(_typeId),
              subtitle: '${fmtDA(data.type(_typeId)?.tarif1000 ?? 0)} pour 1000 points',
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.gesture_rounded, color: Colors.white),
              ),
              onChange: () => setState(() => _typeId = null),
            ),
          ],

          // ---------------- 3. Compteur
          if (_step == 2) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SegmentedButton<Equipe>(
                    segments: [
                      for (final e in Equipe.values)
                        ButtonSegment(
                          value: e,
                          icon: Icon(e == Equipe.jour ? Icons.wb_sunny_rounded : Icons.nightlight_round),
                          label: Text('${e.label} · ${e.horaire}'),
                        ),
                    ],
                    selected: {_equipe},
                    onSelectionChanged: (s) => setState(() => _equipe = s.first),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_date == dayOnly(DateTime.now()) ? 'Aujourd\'hui' : fmtDate(_date)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ]),
                if (data.machines.where((m) => m.actif).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final m in data.machines.where((m) => m.actif))
                      ChoiceChip(
                        avatar: const Icon(Icons.precision_manufacturing_outlined, size: 18),
                        label: Text('${m.nom} · ${m.nbTetes} têtes'),
                        selected: _machineId == m.id,
                        onSelected: (s) => setState(() => _machineId = s ? m.id : null),
                      ),
                  ]),
                ],
                const SizedBox(height: 18),
                Text('Points du compteur', style: context.tt.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _points,
                  focusNode: _pointsFocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [ThousandsFormatter()],
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: context.cs.primary, letterSpacing: 1),
                  decoration: const InputDecoration(hintText: '0', suffixText: 'pts', contentPadding: EdgeInsets.symmetric(vertical: 18)),
                  onSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 14),
                _CalcBox(points: _pts, tarif: data.type(_typeId)?.tarif1000 ?? 0),
                const SizedBox(height: 6),
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('Détails facultatifs', style: TextStyle(color: context.pal.muted, fontSize: 14)),
                    subtitle: Text('Dessin, nombre de robes, remarque', style: TextStyle(color: context.pal.muted, fontSize: 12)),
                    children: [
                      DropdownButtonFormField<String?>(
                        value: _dessinId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Dessin', prefixIcon: Icon(Icons.local_florist_outlined)),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('—')),
                          for (final d in data.dessins.where((d) => d.actif)) DropdownMenuItem<String?>(value: d.id, child: Text(d.nom)),
                        ],
                        onChanged: (v) => setState(() => _dessinId = v),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _robes,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Nombre de robes', prefixIcon: Icon(Icons.checkroom_rounded)),
                      ),
                      const SizedBox(height: 10),
                      TextField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque', prefixIcon: Icon(Icons.notes))),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: FilledButton.icon(
                onPressed: (_busy || _pts <= 0) ? null : _save,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded),
                label: Text(_pts <= 0
                    ? 'Tapez les points du compteur'
                    : 'Enregistrer · ${fmtDA(_pts * (data.type(_typeId)?.tarif1000 ?? 0) / 1000)}'),
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// Regroupe les chiffres par milliers pendant la frappe : 300000 → 300 000.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final trimmed = digits.length > 12 ? digits.substring(0, 12) : digits;
    final s = int.parse(trimmed).toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    final out = b.toString();
    return TextEditingValue(text: out, selection: TextSelection.collapsed(offset: out.length));
  }
}

class _CalcBox extends StatelessWidget {
  final int points;
  final double tarif;
  const _CalcBox({required this.points, required this.tarif});

  @override
  Widget build(BuildContext context) {
    final montant = points * tarif / 1000;
    return AppCard(
      gradient: AppColors.heroGradient,
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text('${fmtInt(points)} pts × ${fmtDA(tarif)} / 1000', style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(fmtDA(montant), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        ),
        const Text('à payer pour ce relevé', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final TypeTravail type;
  final Color color;
  final VoidCallback onTap;
  const _TypeCard({required this.type, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(18),
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.3)!]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.gesture_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 2),
              Text('${fmtDA(type.tarif1000)} / 1000 pts', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              Text('300 000 pts = ${fmtDA(300 * type.tarif1000)}', style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: context.pal.muted),
        ]),
      );
}

class _TodayBanner extends StatelessWidget {
  final int points;
  final double montant;
  const _TodayBanner({required this.points, required this.montant});

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
            Text(fmtDA(montant), style: const TextStyle(color: Colors.white70)),
          ]),
        ]),
      );
}

class _Steps extends StatelessWidget {
  final int step;
  const _Steps({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Ouvrier', 'Type', 'Compteur'];
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
