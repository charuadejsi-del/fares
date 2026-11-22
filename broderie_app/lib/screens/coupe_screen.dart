import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_data.dart';
import '../data/couture.dart';
import '../data/models.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'lots_screen.dart' show LotDetailScreen;
import 'couture_screen.dart' show CarteEnvoi, ouvrirEnvoi;
import 'refs_screens.dart' show FormDialog;

/// Couleur d'une étape du circuit.
Color couleurEtape(String e) => switch (e) {
      'coupe' => AppColors.rose,
      'broderie' => AppColors.violet,
      'applique' || 'akkach' || 'dentelle' => AppColors.teal,
      'couture' => AppColors.sky,
      'finition' => AppColors.gold,
      'stock' => AppColors.green,
      _ => Colors.grey,
    };

IconData iconeEtape(String e) => switch (e) {
      'coupe' => Icons.content_cut_rounded,
      'broderie' => Icons.blur_on_rounded,
      'applique' || 'akkach' || 'dentelle' => Icons.auto_awesome_rounded,
      'couture' => Icons.design_services_rounded,
      'finition' => Icons.iron_rounded,
      'stock' => Icons.inventory_rounded,
      _ => Icons.circle,
    };

class PuceEtape extends StatelessWidget {
  final String etape;
  const PuceEtape(this.etape, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = couleurEtape(etape);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(iconeEtape(etape), size: 14, color: c),
        const SizedBox(width: 5),
        Text(etapeNom(etape), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Parcours d'un paquet : étapes passées, actuelle et à venir.
class FrisesParcours extends StatelessWidget {
  final Lot l;
  const FrisesParcours(this.l, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = l.circuit, i = c.indexOf(l.etape);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, runSpacing: 6, children: [
      for (var k = 0; k < c.length; k++) ...[
        if (k > 0) Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right, size: 16, color: muted),
        Opacity(
          opacity: k > i ? .45 : 1,
          child: k == i
              ? PuceEtape(c[k])
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (k < i) Icon(Icons.check_circle_rounded, size: 14, color: AppColors.green),
                  if (k < i) const SizedBox(width: 3),
                  Text(etapeNom(c[k]), style: TextStyle(fontSize: 12, color: muted)),
                ]),
        ),
      ],
    ]);
  }
}

// ====================================================================== module Coupe

class CoupeModule extends StatefulWidget {
  const CoupeModule({super.key});

  @override
  State<CoupeModule> createState() => _CoupeModuleState();
}

class _CoupeModuleState extends State<CoupeModule> {
  String? _etape; // null = en cours (hors stock)
  String _q = '';

  bool _garde(Lot l) {
    if (_etape == null ? l.etape == 'stock' : (_etape != '*' && l.etape != _etape)) return false;
    if (_q.isEmpty) return true;
    final q = _q.toLowerCase();
    return l.numero.toLowerCase().contains(q) || (l.modele?.toLowerCase().contains(q) ?? false) || (l.couleur?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final liste = data.lots.where(_garde).toList();
          final actifs = data.lots.where((l) => l.etape != 'stock').toList();
          int nb(String e) => actifs.where((l) => l.etape == e).length;
          final pieces = actifs.fold<int>(0, (s, l) => s + l.nbPieces);
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => ouvrirFicheCoupe(context),
              icon: const Icon(Icons.add_rounded),
              label: Text('Nouvelle fiche de coupe'.tr),
            ),
            body: RefreshIndicator(
              onRefresh: data.loadLots,
              child: ListView(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 96),
                children: [
                  AutoGrid(minItemWidth: 170, children: [
                    StatTile(label: 'Paquets dans l\'atelier'.tr, value: '${actifs.length}', icon: Icons.inventory_2_rounded, color: AppColors.gold, sub: '{0} pièces'.trf([fmtInt(pieces)])),
                    StatTile(label: 'En coupe'.tr, value: '${nb('coupe')}', icon: iconeEtape('coupe'), color: couleurEtape('coupe')),
                    StatTile(label: 'En broderie'.tr, value: '${nb('broderie')}', icon: iconeEtape('broderie'), color: couleurEtape('broderie')),
                    StatTile(
                      label: 'Appliqué · akkach · dentelle'.tr,
                      value: '${nb('applique') + nb('akkach') + nb('dentelle')}',
                      icon: iconeEtape('applique'),
                      color: couleurEtape('applique'),
                    ),
                    StatTile(label: 'En couture'.tr, value: '${nb('couture')}', icon: iconeEtape('couture'), color: couleurEtape('couture')),
                    StatTile(label: 'En finition'.tr, value: '${nb('finition')}', icon: iconeEtape('finition'), color: couleurEtape('finition')),
                  ]),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    ChoiceChip(label: Text('En cours'.tr), selected: _etape == null, onSelected: (_) => setState(() => _etape = null)),
                    for (final e in etapesAtelier)
                      ChoiceChip(
                        avatar: Icon(iconeEtape(e), size: 16, color: couleurEtape(e)),
                        label: Text(e == 'stock' ? etapeNom(e) : '${etapeNom(e)} (${nb(e)})'),
                        selected: _etape == e,
                        onSelected: (_) => setState(() => _etape = e),
                      ),
                    ChoiceChip(label: Text('Tous'.tr), selected: _etape == '*', onSelected: (_) => setState(() => _etape = '*')),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        decoration: InputDecoration(isDense: true, hintText: 'N°, modèle, couleur…'.tr, prefixIcon: const Icon(Icons.search)),
                        onChanged: (v) => setState(() => _q = v.trim()),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (liste.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 30),
                      child: EmptyState(
                        data.lots.isEmpty ? 'Aucun paquet.\nCréez la première fiche de coupe (ex. n° 58 · 127 pièces).'.tr : 'Aucun paquet pour ce filtre.'.tr,
                        icon: Icons.content_cut_rounded,
                      ),
                    )
                  else
                    AutoGrid(minItemWidth: 340, children: [for (final l in liste) _CartePaquet(l)]),
                ],
              ),
            ),
          );
        },
      );
}

class _CartePaquet extends StatelessWidget {
  final Lot l;
  const _CartePaquet(this.l);

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final infos = [
      if (l.modele != null) l.modele!,
      if (l.couleur != null) l.couleur!,
      if (l.dateCoupe != null) 'Coupé le {0}'.trf([fmtDate(l.dateCoupe!)]),
    ];
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: l.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${l.numero}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('{0} pièces'.trf([fmtInt(l.nbPieces)]), style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
          const Spacer(),
          PuceEtape(l.etape),
        ]),
        if (infos.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(infos.join(' · '), style: TextStyle(color: muted, fontSize: 13)),
        ],
        const SizedBox(height: 10),
        FrisesParcours(l),
      ]),
    );
  }
}

// ====================================================================== fiche de coupe

Future<String?> ouvrirFicheCoupe(BuildContext context, [Lot? l]) => showDialog<String>(context: context, builder: (_) => _FicheCoupe(existing: l));

class _FicheCoupe extends StatefulWidget {
  final Lot? existing;
  const _FicheCoupe({this.existing});

  @override
  State<_FicheCoupe> createState() => _FicheCoupeState();
}

class _FicheCoupeState extends State<_FicheCoupe> {
  final _form = GlobalKey<FormState>();
  late final _numero = TextEditingController(text: widget.existing?.numero ?? '');
  late final _pieces = TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.nbPieces}');
  late final _modele = TextEditingController(text: widget.existing?.modele ?? '');
  late final _couleur = TextEditingController(text: widget.existing?.couleur ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  late DateTime _date = widget.existing?.dateCoupe ?? DateTime.now();
  late final Set<String> _deco = {...?widget.existing?.parcours.where(decorations.contains)};
  late bool _couture = widget.existing?.parcours.contains('couture') ?? true;
  bool _envoyer = true;
  bool _busy = false;

  bool get _nouveau => widget.existing == null;

  @override
  void dispose() {
    for (final c in [_numero, _pieces, _modele, _couleur, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _parcours => [for (final d in decorations) if (_deco.contains(d)) d, if (_couture) 'couture', 'finition'];

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final num = _numero.text.trim().replaceFirst('#', '');
    if (data.lots.any((l) => l.numero == num && l.id != widget.existing?.id && l.etape != 'stock')) {
      showSnack(context, 'Le paquet {0} existe déjà dans l\'atelier.'.trf(['#$num']), error: true);
      return;
    }
    final parcours = _parcours;
    final ex = widget.existing;
    if (ex != null && ex.etape != 'coupe' && ex.etape != 'stock' && !parcours.contains(ex.etape)) {
      showSnack(context, 'Le paquet est actuellement en {0} : gardez cette étape dans le parcours.'.trf([etapeNom(ex.etape)]), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final row = {
        'numero': num,
        'nb_pieces': parseInt(_pieces.text)!,
        'modele': _modele.text.trim().isEmpty ? null : _modele.text.trim(),
        'couleur': _couleur.text.trim().isEmpty ? null : _couleur.text.trim(),
        'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
        'date_coupe': dateKey(_date),
        'parcours': parcours,
        if (_nouveau) 'etape': 'coupe',
      };
      final id = await data.saveLot(row, id: ex?.id);
      if (_nouveau && _envoyer) {
        final l = data.lot(id);
        if (l != null) await data.deplacerLot(l, parcours.first, _date);
      }
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
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return FormDialog(
      title: _nouveau ? 'Nouvelle fiche de coupe'.tr : 'Modifier la fiche de coupe'.tr,
      formKey: _form,
      busy: _busy,
      onSave: _save,
      children: [
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _numero,
              autofocus: _nouveau,
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
              validator: (v) => (parseInt(v ?? '') ?? 0) <= 0 ? 'Obligatoire'.tr : null,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _modele, decoration: InputDecoration(labelText: 'Modèle (facultatif)'.tr))),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _couleur, decoration: InputDecoration(labelText: 'Tissu / couleur (facultatif)'.tr))),
        ]),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_rounded),
          title: Text('Date de coupe'.tr),
          subtitle: Text(fmtDate(_date)),
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));
            if (d != null) setState(() => _date = d);
          },
        ),
        const SizedBox(height: 4),
        Text('Décorations (dans l\'ordre)'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final d in decorations)
            FilterChip(
              avatar: Icon(iconeEtape(d), size: 16, color: couleurEtape(d)),
              label: Text(etapeNom(d)),
              selected: _deco.contains(d),
              onSelected: (v) => setState(() => v ? _deco.add(d) : _deco.remove(d)),
            ),
        ]),
        if (_deco.isEmpty) ...[
          const SizedBox(height: 4),
          Text('Aucune décoration : tissu qui part directement à la couture.'.tr, style: TextStyle(fontSize: 12, color: muted)),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _couture,
          onChanged: (v) => setState(() => _couture = v),
          title: Text('Couture (atelier externe)'.tr),
        ),
        const SizedBox(height: 4),
        Text('Parcours'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FrisesParcours(Lot(id: '', numero: '', nbPieces: 0, createdAt: DateTime.now(), etape: 'coupe', parcours: _parcours)),
        if (_nouveau)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _envoyer,
            onChanged: (v) => setState(() => _envoyer = v),
            title: Text('Envoyer tout de suite à : {0}'.trf([etapeNom(_parcours.first)])),
            subtitle: Text('Désactivez si la coupe n\'est pas terminée.'.tr),
          ),
        const SizedBox(height: 8),
        TextFormField(controller: _note, maxLines: 2, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
      ],
    );
  }
}

// ====================================================================== détail d'un paquet

class PaquetDetailScreen extends StatefulWidget {
  final String lotId;
  const PaquetDetailScreen({super.key, required this.lotId});

  @override
  State<PaquetDetailScreen> createState() => _PaquetDetailScreenState();
}

class _PaquetDetailScreenState extends State<PaquetDetailScreen> {
  late Future<List<MouvementLot>> _mvts = data.fetchMouvementsLot(widget.lotId);

  void _recharger() => setState(() => _mvts = data.fetchMouvementsLot(widget.lotId));

  Future<void> _deplacer(Lot l, String vers) async {
    final note = TextEditingController();
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('{0} → {1}'.trf(['#${l.numero}', etapeNom(vers)])),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_rounded),
                title: Text('Date'.tr),
                subtitle: Text(fmtDate(date)),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));
                  if (d != null) set(() => date = d);
                },
              ),
              TextField(controller: note, decoration: InputDecoration(labelText: 'Note (facultatif)'.tr)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Confirmer'.tr)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await data.deplacerLot(l, vers, date, note: note.text);
      if (mounted) showSnack(context, 'Paquet envoyé : {0}'.trf([etapeNom(vers)]));
      _recharger();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _supprimer(Lot l) async {
    final ok = await confirmDialog(context, 'Supprimer le paquet {0} ?'.trf(['#${l.numero}']),
        'Les saisies de points sont conservées (et restent payées), elles ne seront plus liées au paquet.'.tr);
    if (!ok || !mounted) return;
    try {
      await data.deleteLot(l.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data, couture]),
        builder: (context, _) {
          final l = data.lot(widget.lotId);
          if (l == null) return Scaffold(appBar: AppBar(), body: EmptyState('Paquet introuvable.'.tr));
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          final suivante = l.suivante;
          final autres = l.circuit.where((e) => e != l.etape).toList();
          return Scaffold(
            appBar: AppBar(
              title: Text('Paquet {0}'.trf(['#${l.numero}'])),
              actions: [
                IconButton(tooltip: 'Modifier'.tr, icon: const Icon(Icons.edit_rounded), onPressed: () => ouvrirFicheCoupe(context, l)),
                PopupMenuButton<String>(
                  onSelected: (v) => v == '_del' ? _supprimer(l) : _deplacer(l, v),
                  itemBuilder: (_) => [
                    for (final e in autres) PopupMenuItem(value: e, child: Text('Corriger l\'étape : {0}'.trf([etapeNom(e)]))),
                    const PopupMenuDivider(),
                    PopupMenuItem(value: '_del', child: Text('Supprimer'.tr, style: const TextStyle(color: AppColors.rose))),
                  ],
                ),
              ],
            ),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('#${l.numero}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    Text('{0} pièces'.trf([fmtInt(l.nbPieces)]), style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 16)),
                    const Spacer(),
                    PuceEtape(l.etape),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 18, runSpacing: 6, children: [
                    if (l.modele != null) _info(Icons.style_rounded, 'Modèle'.tr, l.modele!),
                    if (l.couleur != null) _info(Icons.palette_rounded, 'Tissu / couleur'.tr, l.couleur!),
                    if (l.dateCoupe != null) _info(Icons.content_cut_rounded, 'Date de coupe'.tr, fmtDate(l.dateCoupe!)),
                    if (l.dessinId != null && data.dessin(l.dessinId) != null) _info(Icons.blur_on_rounded, 'Rechma'.tr, data.dessin(l.dessinId)!.nom),
                  ]),
                  if (l.note != null) ...[const SizedBox(height: 8), Text(l.note!, style: TextStyle(color: muted))],
                  const SizedBox(height: 14),
                  FrisesParcours(l),
                  const SizedBox(height: 14),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    if (suivante != null && !l.enBroderie)
                      FilledButton.icon(
                        onPressed: () => _deplacer(l, suivante),
                        icon: Icon(iconeEtape(suivante)),
                        label: Text('Envoyer à : {0}'.trf([etapeNom(suivante)])),
                      ),
                    if (l.etape == 'couture' && couture.aEnvoyer(l) > 0 && couture.ateliers.any((a) => a.actif))
                      FilledButton.tonalIcon(
                        onPressed: () => ouvrirEnvoi(context, l),
                        icon: const Icon(Icons.store_rounded),
                        label: Text('Envoyer chez un atelier de couture'.tr),
                      ),
                    if (l.passeBroderie && l.etape != 'coupe')
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LotDetailScreen(lotId: l.id))).then((_) => _recharger()),
                        icon: const Icon(Icons.blur_on_rounded),
                        label: Text('Suivi broderie'.tr),
                      ),
                  ]),
                  if (l.enBroderie) ...[
                    const SizedBox(height: 8),
                    Text('Le responsable broderie livre ce paquet depuis son espace : il passera alors à l\'étape suivante.'.tr,
                        style: TextStyle(fontSize: 12, color: muted)),
                  ],
                ]),
              ),
              if (couture.envoisDuLot(l.id).isNotEmpty) ...[
                const SizedBox(height: 16),
                SectionTitle('Couture'.tr),
                const SizedBox(height: 8),
                AutoGrid(minItemWidth: 340, children: [for (final e in couture.envoisDuLot(l.id)) CarteEnvoi(e)]),
              ],
              const SizedBox(height: 16),
              SectionTitle('Historique des mouvements'.tr),
              const SizedBox(height: 8),
              FutureBuilder<List<MouvementLot>>(
                future: _mvts,
                builder: (context, snap) {
                  if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  final m = snap.data!;
                  if (m.isEmpty) return EmptyState('Aucun mouvement pour l\'instant.'.tr, icon: Icons.timeline_rounded);
                  return AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      for (final x in m.reversed)
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: couleurEtape(x.vers).withValues(alpha: .15),
                            child: Icon(iconeEtape(x.vers), color: couleurEtape(x.vers), size: 20),
                          ),
                          title: Text('{0} → {1}'.trf([etapeNom(x.de), etapeNom(x.vers)])),
                          subtitle: Text([fmtDate(x.date), '{0} pièces'.trf([fmtInt(x.pieces)]), if (x.note != null) x.note!].join(' · ')),
                        ),
                    ]),
                  );
                },
              ),
            ]),
          );
        },
      );

  Widget _info(IconData i, String label, String v) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 16, color: AppColors.gold),
        const SizedBox(width: 6),
        Text('$label : ', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ]);
}
