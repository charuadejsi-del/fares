import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../i18n.dart';
import '../pdf/documents.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'production_screen.dart' show openProductionForm, deleteProductionWithConfirm;
import 'refs_screens.dart' show FormDialog;

enum _Filtre { encours, termines, livres, tous }

/// État d'un paquet : en broderie, terminé (toutes les pièces brodées) ou livré à la couture.
String _etat(Lot l) {
  if (l.livre) return 'Livré'.tr;
  return data.avancement(l.id).pieces >= l.nbPieces ? 'Terminé'.tr : 'En broderie'.tr;
}

Color _couleurEtat(Lot l) {
  if (l.livre) return AppColors.sky;
  return data.avancement(l.id).pieces >= l.nbPieces ? AppColors.green : AppColors.gold;
}

int _duree(Lot l) {
  final a = data.avancement(l.id);
  if (a.debut == null) return 0;
  final fin = l.dateLivraison ?? DateTime.now();
  return dayOnly(fin).difference(dayOnly(a.debut!)).inDays + 1;
}

// ====================================================================== liste des paquets

class LotsScreen extends StatefulWidget {
  const LotsScreen({super.key});

  @override
  State<LotsScreen> createState() => _LotsScreenState();
}

class _LotsScreenState extends State<LotsScreen> {
  _Filtre _filtre = _Filtre.encours;
  String _q = '';

  bool _garde(Lot l) {
    final fini = data.avancement(l.id).pieces >= l.nbPieces;
    final ok = switch (_filtre) {
      _Filtre.encours => !l.livre && !fini,
      _Filtre.termines => !l.livre && fini,
      _Filtre.livres => l.livre,
      _Filtre.tous => true,
    };
    if (!ok) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return l.numero.toLowerCase().contains(q) || (data.dessin(l.dessinId)?.nom.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final liste = data.lots.where(_garde).toList();
          final enCours = data.lots.where((l) => !l.livre).toList();
          final aBroder = enCours.fold<int>(0, (s, l) => s + (l.nbPieces - data.avancement(l.id).pieces).clamp(0, l.nbPieces));
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => ouvrirLotForm(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouveau paquet'.tr),
            ),
            body: RefreshIndicator(
              onRefresh: data.loadLots,
              child: ListView(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 96),
                children: [
                  AutoGrid(minItemWidth: 180, children: [
                    StatTile(label: 'Paquets en cours'.tr, value: '${enCours.length}', icon: Icons.inventory_2_rounded, color: AppColors.gold),
                    StatTile(label: 'Pièces à broder'.tr, value: fmtInt(aBroder), icon: Icons.checkroom_rounded, color: AppColors.violet),
                    StatTile(
                      label: 'Prêts à livrer'.tr,
                      value: '${enCours.where((l) => data.avancement(l.id).pieces >= l.nbPieces).length}',
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.green,
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    for (final f in _Filtre.values)
                      ChoiceChip(
                        label: Text(switch (f) {
                          _Filtre.encours => 'En broderie'.tr,
                          _Filtre.termines => 'Terminés'.tr,
                          _Filtre.livres => 'Livrés'.tr,
                          _Filtre.tous => 'Tous'.tr,
                        }),
                        selected: _filtre == f,
                        onSelected: (_) => setState(() => _filtre = f),
                      ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        decoration: InputDecoration(isDense: true, hintText: 'N° ou rechma…'.tr, prefixIcon: const Icon(Icons.search)),
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: EmptyState(
                        data.lots.isEmpty
                            ? 'Aucun paquet.\nAjoutez le paquet reçu de la coupe (ex. n° 53 · 128 pièces).'.tr
                            : 'Aucun paquet pour ce filtre.'.tr,
                        icon: Icons.inventory_2_outlined,
                      ),
                    )
                  else
                    AutoGrid(minItemWidth: 340, children: [for (final l in liste) _CarteLot(l)]),
                ],
              ),
            ),
          );
        },
      );
}

class _CarteLot extends StatelessWidget {
  final Lot l;
  const _CarteLot(this.l);

  @override
  Widget build(BuildContext context) {
    final a = data.avancement(l.id);
    final d = data.dessin(l.dessinId);
    final p = (a.pieces / l.nbPieces).clamp(0.0, 1.0);
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => LotDetailScreen(lotId: l.id))),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DessinThumb(d, size: 52, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('#${l.numero}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Text(d?.nom ?? 'Sans rechma'.tr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.pal.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _couleurEtat(l).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
            child: Text(_etat(l), style: TextStyle(color: _couleurEtat(l), fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Text('{0} / {1} pièces'.trf([a.pieces, l.nbPieces]), style: const TextStyle(fontWeight: FontWeight.w800)),
          const Spacer(),
          Text('${(p * 100).round()} %', style: TextStyle(fontWeight: FontWeight.w800, color: _couleurEtat(l))),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(minHeight: 8, value: p, color: _couleurEtat(l)),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (a.ouvriers.isNotEmpty) a.ouvriers.map(data.ouvrierNom).join(', '),
            if (a.debut != null) 'début {0}'.trf([fmtShort(a.debut!)]),
            if (a.fin != null) 'terminé {0}'.trf([fmtShort(a.fin!)]),
            if (_duree(l) > 0) '{0} jour(s)'.trf([_duree(l)]),
            if (l.livre) 'livré le {0}'.trf([fmtDate(l.dateLivraison!)]),
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: context.pal.muted),
        ),
      ]),
    );
  }
}

// ====================================================================== formulaire

Future<String?> ouvrirLotForm(BuildContext context, [Lot? l]) =>
    showDialog<String>(context: context, builder: (_) => _LotForm(existing: l));

class _LotForm extends StatefulWidget {
  final Lot? existing;
  const _LotForm({this.existing});

  @override
  State<_LotForm> createState() => _LotFormState();
}

class _LotFormState extends State<_LotForm> {
  final _form = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.existing?.numero ?? '');
  late final _pieces = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.nbPieces}');
  late final _fil = TextEditingController(text: widget.existing?.fil ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late String? _dessinId = data.dessin(widget.existing?.dessinId) == null ? null : widget.existing?.dessinId;
  late String? _machineId = data.machine(widget.existing?.machineId) == null
      ? (data.machines.where((m) => m.actif).length == 1 ? data.machines.firstWhere((m) => m.actif).id : null)
      : widget.existing?.machineId;
  bool _busy = false;

  @override
  void dispose() {
    _numero.dispose();
    _pieces.dispose();
    _fil.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final num = _numero.text.trim().replaceFirst('#', '');
    if (data.lots.any((l) => l.numero == num && l.id != widget.existing?.id && !l.livre)) {
      showSnack(context, 'Le paquet {0} existe déjà (non livré).'.trf(['#$num']), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final id = await data.saveLot(
        Lot.toRow(numero: num, nbPieces: parseInt(_pieces.text)!, dessinId: _dessinId, machineId: _machineId, fil: _fil.text, note: _note.text),
        id: widget.existing?.id,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final machines = data.machines.where((m) => m.actif || m.id == _machineId).toList();
    return FormDialog(
      title: widget.existing == null ? 'Nouveau paquet'.tr : 'Modifier le paquet'.tr,
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _numero,
              autofocus: widget.existing == null,
              decoration: InputDecoration(labelText: 'N° du paquet'.tr, prefixText: '#', prefixIcon: const Icon(Icons.tag_rounded)),
              validator: (v) => (v == null || v.trim().replaceFirst('#', '').isEmpty) ? 'Obligatoire'.tr : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _pieces,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Nombre de pièces'.tr, prefixIcon: const Icon(Icons.checkroom_rounded)),
              validator: (v) => ((parseInt(v ?? '') ?? 0) <= 0) ? 'Supérieur à 0'.tr : null,
            ),
          ),
        ]),
        DropdownButtonFormField<String?>(
          value: _dessinId,
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Rechma (dessin)'.tr, prefixIcon: const Icon(Icons.local_florist_outlined)),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('—')),
            for (final d in data.dessins.where((d) => d.actif || d.id == _dessinId))
              DropdownMenuItem<String?>(value: d.id, child: Text('{0} · {1} points'.trf([d.nom, fmtInt(d.points)]))),
          ],
          onChanged: (v) => setState(() => _dessinId = v),
        ),
        if (machines.isNotEmpty)
          DropdownButtonFormField<String?>(
            value: _machineId,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Machine'.tr, prefixIcon: const Icon(Icons.precision_manufacturing_outlined)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('—')),
              for (final m in machines) DropdownMenuItem<String?>(value: m.id, child: Text('{0} · {1} têtes'.trf([m.nom, m.nbTetes]))),
            ],
            onChanged: (v) => setState(() => _machineId = v),
          ),
        TextFormField(
          controller: _fil,
          decoration: InputDecoration(labelText: 'Fil utilisé (facultatif)'.tr, prefixIcon: const Icon(Icons.gesture_rounded)),
        ),
        TextFormField(
          controller: _note,
          decoration: InputDecoration(labelText: 'Remarque (facultatif)'.tr, prefixIcon: const Icon(Icons.notes)),
        ),
      ],
    );
  }
}

// ====================================================================== fiche d'un paquet

class LotDetailScreen extends StatefulWidget {
  final String lotId;
  const LotDetailScreen({super.key, required this.lotId});

  @override
  State<LotDetailScreen> createState() => _LotDetailScreenState();
}

class _LotDetailScreenState extends State<LotDetailScreen> {
  List<JourneeLot> _prod = [];
  bool _loading = true;
  int _seen = -1;

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
    if (data.productionVersion != _seen) {
      _load();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    _seen = data.productionVersion;
    try {
      final p = await data.fetchProductionLot(widget.lotId);
      if (mounted) setState(() => _prod = p);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Par brodeur : (nom, équipes, jours, pièces).
  List<(String, String, int, int)> _parOuvrier() {
    final m = <String, (Set<String>, Set<String>, int)>{};
    for (final j in _prod) {
      final a = m[j.p.ouvrierId] ?? (<String>{}, <String>{}, 0);
      a.$1.add(j.p.equipe.label);
      a.$2.add(dateKey(j.p.dateProd));
      m[j.p.ouvrierId] = (a.$1, a.$2, a.$3 + j.pieces);
    }
    final l = [for (final e in m.entries) (data.ouvrierNom(e.key), e.value.$1.join(' / '), e.value.$2.length, e.value.$3)];
    l.sort((a, b) => b.$4.compareTo(a.$4));
    return l;
  }

  Future<void> _fiche(Lot l, {bool partage = false}) async {
    final a = session.atelier;
    if (a == null) return;
    try {
      final d = data.dessin(l.dessinId);
      final bytes = await buildFicheLot(
        atelier: a,
        numero: l.numero,
        nbPieces: l.nbPieces,
        dessinNom: d?.nom,
        dessinPoints: d?.points ?? 0,
        dessinPhoto: await data.photoBytes(d?.photoPath),
        machineNom: data.machine(l.machineId)?.nom,
        fil: l.fil,
        note: l.note,
        debut: data.avancement(l.id).debut,
        livraison: l.dateLivraison,
        parOuvrier: _parOuvrier(),
        jours: [for (final j in _prod) (j.p.dateProd, j.p.equipe.label, data.ouvrierNom(j.p.ouvrierId), j.pieces)],
      );
      final nom = 'Paquet_${l.numero}.pdf';
      partage ? await partager(bytes, nom) : await imprimer(bytes, nom);
    } catch (e) {
      if (mounted) showSnack(context, 'Impossible de créer le PDF : {0}'.trf([errorMessage(e)]), error: true);
    }
  }

  Future<void> _livrer(Lot l) async {
    final a = data.avancement(l.id);
    if (a.pieces < l.nbPieces) {
      final ok = await confirmDialog(
        context,
        'Paquet incomplet'.tr,
        'Seulement {0} pièces sur {1} sont brodées. Livrer quand même ?'.trf([a.pieces, l.nbPieces]),
        action: 'Livrer quand même'.tr,
      );
      if (!ok || !mounted) return;
    }
    final d = await showDatePicker(
      context: context,
      helpText: 'Date de livraison à la couture'.tr,
      initialDate: DateTime.now(),
      firstDate: a.debut ?? DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (d == null || !mounted) return;
    try {
      await data.livrerLot(l.id, d);
      if (!mounted) return;
      showSnack(context, 'Paquet livré. Impression de la fiche…'.tr);
      final nouveau = data.lot(l.id);
      if (nouveau != null) await _fiche(nouveau);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _supprimer(Lot l) async {
    final ok = await confirmDialog(context, 'Supprimer le paquet {0} ?'.trf(['#${l.numero}']),
        'Les saisies de points sont conservées (et restent payées), elles ne seront plus liées au paquet.'.tr,
        action: 'Supprimer'.tr);
    if (!ok) return;
    try {
      await data.deleteLot(l.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = data.lot(widget.lotId);
    if (l == null) return Scaffold(appBar: AppBar(), body: EmptyState('Paquet introuvable.'.tr));
    final a = data.avancement(l.id);
    final d = data.dessin(l.dessinId);
    final reste = (l.nbPieces - a.pieces).clamp(0, l.nbPieces);
    final jours = _duree(l);
    final parJour = jours == 0 ? 0.0 : a.pieces / jours;
    final restantJours = parJour <= 0 || reste == 0 ? null : (reste / parJour).ceil();
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    final tete = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          DessinThumb(d, size: 84, radius: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Paquet {0}'.trf(['#${l.numero}']), style: context.tt.headlineSmall),
              Text(d == null ? 'Sans rechma'.tr : '{0} · {1} points'.trf([d.nom, fmtInt(d.points)]), style: TextStyle(color: context.pal.muted)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _couleurEtat(l).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(_etat(l), style: TextStyle(color: _couleurEtat(l), fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Text('{0} / {1} pièces'.trf([a.pieces, l.nbPieces]), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const Spacer(),
          if (reste > 0) Text('Reste {0}'.trf([reste]), style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.gold)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(minHeight: 10, value: (a.pieces / l.nbPieces).clamp(0.0, 1.0), color: _couleurEtat(l)),
        ),
        const SizedBox(height: 14),
        AutoGrid(minItemWidth: 150, children: [
          StatTile(label: 'Points brodés'.tr, value: fmtInt(a.points), icon: Icons.blur_on_rounded, color: AppColors.violet),
          StatTile(label: 'Début'.tr, value: a.debut == null ? '—' : fmtDate(a.debut!), icon: Icons.play_circle_outline_rounded, color: AppColors.sky),
          StatTile(label: 'Durée en broderie'.tr, value: jours == 0 ? '—' : '{0} j'.trf([jours]), icon: Icons.timer_outlined, color: AppColors.gold),
          StatTile(
            label: l.livre ? 'Livré le'.tr : (a.fin != null ? 'Terminé le'.tr : 'Fin estimée'.tr),
            value: l.livre
                ? fmtDate(l.dateLivraison!)
                : (a.fin != null ? fmtDate(a.fin!) : (restantJours == null ? '—' : '~{0} j'.trf([restantJours]))),
            icon: l.livre ? Icons.local_shipping_rounded : Icons.flag_outlined,
            color: AppColors.green,
          ),
        ]),
        if (data.machine(l.machineId) != null || (l.fil ?? '').isNotEmpty || (l.note ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            [
              if (data.machine(l.machineId) != null) '{0} : {1}'.trf(['Machine'.tr, data.machine(l.machineId)!.nom]),
              if ((l.fil ?? '').isNotEmpty) '{0} : {1}'.trf(['Fil'.tr, l.fil]),
              if ((l.note ?? '').isNotEmpty) l.note!,
            ].join(' · '),
            style: TextStyle(color: context.pal.muted),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (!l.livre)
            FilledButton.icon(
              onPressed: () => openProductionForm(context, null, l.id),
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter une journée'.tr),
            ),
          if (!l.livre)
            FilledButton.tonalIcon(
              onPressed: () => _livrer(l),
              icon: const Icon(Icons.local_shipping_rounded),
              label: Text('Livrer à la couture'.tr),
            ),
          OutlinedButton.icon(onPressed: () => _fiche(l), icon: const Icon(Icons.print_rounded), label: Text('Fiche PDF'.tr)),
          OutlinedButton.icon(onPressed: () => _fiche(l, partage: true), icon: const Icon(Icons.share_rounded), label: Text('Partager'.tr)),
          if (l.livre)
            TextButton.icon(
              onPressed: () async {
                await data.livrerLot(l.id, null);
                if (context.mounted) showSnack(context, 'Livraison annulée'.tr);
              },
              icon: const Icon(Icons.undo_rounded),
              label: Text('Annuler la livraison'.tr),
            ),
        ]),
      ]),
    );

    final parOuvrier = _parOuvrier();
    final brodeurs = AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionTitle('Brodeurs'.tr),
        if (parOuvrier.isEmpty) Text('Aucune journée saisie.'.tr, style: TextStyle(color: context.pal.muted)),
        for (final o in parOuvrier)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: NameAvatar(o.$1, size: 38),
            title: Text(o.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('{0} · {1} jour(s)'.trf([o.$2, o.$3])),
            trailing: Text('{0} pcs'.trf([o.$4]), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
      ]),
    );

    final journees = AppCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.only(right: 8), child: SectionTitle('Journées'.tr, subtitle: '{0} saisie(s)'.trf([_prod.length]))),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_prod.isEmpty)
          EmptyState('Aucune journée. Touchez « Ajouter une journée ».'.tr, icon: Icons.event_note_outlined)
        else
          for (final j in _prod.reversed)
            Builder(builder: (context) {
              final p = j.p;
              final debut = identical(j, _prod.first);
              final fin = data.avancement(l.id).fin != null && identical(j, _prod.lastWhere((x) => x.p.dateProd == data.avancement(l.id).fin));
              final partiel = p.nbRobes != null && p.nbRobes! > j.pieces;
              return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(p.equipe == Equipe.nuit ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded, color: AppColors.gold),
              title: Text('{0} · {1}'.trf([fmtDate(p.dateProd), data.ouvrierNom(p.ouvrierId)]), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                '{0} points'.trf([fmtInt(j.points)]),
                if (partiel) 'saisie partagée avec un autre paquet'.tr,
                if (debut) 'début du paquet'.tr,
                if (fin) 'paquet terminé ✓'.tr,
              ].join(' · ')),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('{0} pcs'.trf([j.pieces]), style: const TextStyle(fontWeight: FontWeight.w900)),
                PopupMenuButton<String>(
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text('Modifier'.tr)),
                    PopupMenuItem(value: 'del', child: Text('Supprimer'.tr)),
                  ],
                  onSelected: (v) => v == 'edit' ? openProductionForm(context, p) : deleteProductionWithConfirm(context, p),
                ),
              ]),
              );
            }),
      ]),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Paquet {0}'.trf(['#${l.numero}'])),
        actions: [
          IconButton(tooltip: 'Modifier'.tr, onPressed: () => ouvrirLotForm(context, l), icon: const Icon(Icons.edit_rounded)),
          IconButton(tooltip: 'Supprimer'.tr, onPressed: () => _supprimer(l), icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 8, wide ? 24 : 16, 32),
        children: [
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: Column(children: [tete, const SizedBox(height: 16), brodeurs])),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: journees),
            ])
          else ...[
            tete,
            const SizedBox(height: 14),
            brodeurs,
            const SizedBox(height: 14),
            journees,
          ],
        ],
      ),
    );
  }
}

// ====================================================================== paquets d'une saisie

/// Une ligne « paquet + pièces » dans une saisie de broderie.
class LigneLot {
  String? lotId;
  final TextEditingController qte;
  LigneLot({this.lotId, int? pieces}) : qte = TextEditingController(text: pieces == null || pieces == 0 ? '' : '$pieces');
  int get pieces => parseInt(qte.text) ?? 0;
}

List<(String, int)> liensDe(List<LigneLot> lignes) => [
      for (final l in lignes)
        if (l.lotId != null && l.pieces > 0) (l.lotId!, l.pieces),
    ];

/// Éditeur des paquets brodés dans une même saisie (ex. fin du #53 puis début du #54).
class EditeurLots extends StatelessWidget {
  final List<LigneLot> lignes;
  final VoidCallback onChanged;

  /// Pièces déjà enregistrées par cette saisie, par paquet (modification d'une saisie).
  final Map<String, int> dejaSaisi;

  /// Appelé quand le premier paquet est choisi (pour remplir rechma et machine).
  final ValueChanged<Lot>? onPremierLot;

  const EditeurLots({super.key, required this.lignes, required this.onChanged, this.dejaSaisi = const {}, this.onPremierLot});

  int _reste(Lot l) => l.nbPieces - data.avancement(l.id).pieces + (dejaSaisi[l.id] ?? 0);

  @override
  Widget build(BuildContext context) {
    final choisis = {for (final l in lignes) l.lotId};
    final total = lignes.fold<int>(0, (s, l) => s + l.pieces);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.inventory_2_rounded, color: AppColors.gold, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Paquets de cette journée'.tr, style: const TextStyle(fontWeight: FontWeight.w800))),
          if (total > 0) Text('{0} pcs'.trf([total]), style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        for (var i = 0; i < lignes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String?>(
                  value: data.lot(lignes[i].lotId) == null ? null : lignes[i].lotId,
                  isExpanded: true,
                  decoration: InputDecoration(isDense: true, labelText: 'Paquet'.tr),
                  items: [
                    for (final l in data.lots.where((l) => (!l.livre && !choisis.contains(l.id)) || l.id == lignes[i].lotId))
                      DropdownMenuItem<String?>(value: l.id, child: Text('{0} · reste {1}'.trf(['#${l.numero}', _reste(l)]))),
                  ],
                  onChanged: (v) {
                    lignes[i].lotId = v;
                    final l = data.lot(v);
                    if (l != null) {
                      if (lignes[i].qte.text.isEmpty) lignes[i].qte.text = '${_reste(l).clamp(0, l.nbPieces)}';
                      if (i == 0) onPremierLot?.call(l);
                    }
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: lignes[i].qte,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Pièces'.tr,
                    helperText: () {
                      final l = data.lot(lignes[i].lotId);
                      if (l == null) return null;
                      final r = _reste(l) - lignes[i].pieces;
                      return r <= 0 ? 'Paquet terminé ✓'.tr : 'Il restera {0}'.trf([r]);
                    }(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              IconButton(
                tooltip: 'Retirer'.tr,
                onPressed: () {
                  lignes.removeAt(i);
                  onChanged();
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ]),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: data.lots.any((l) => !l.livre && !choisis.contains(l.id))
                ? () {
                    lignes.add(LigneLot());
                    onChanged();
                  }
                : null,
            icon: const Icon(Icons.add_rounded),
            label: Text(lignes.isEmpty ? 'Ajouter un paquet'.tr : 'Ajouter un autre paquet'.tr),
          ),
        ),
      ]),
    );
  }
}
