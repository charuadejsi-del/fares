import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'gestion_screens.dart';
import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'ouvrier_detail_screen.dart';
import 'paie_forms.dart';
import '../i18n.dart';

/// Barre de recherche + filtre « inactifs ».
class _ListHeader extends StatelessWidget {
  final ValueChanged<String> onSearch;
  final int nbInactive;
  final bool showInactive;
  final ValueChanged<bool> onShowInactive;
  const _ListHeader({required this.onSearch, required this.nbInactive, required this.showInactive, required this.onShowInactive});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(
          width: 300,
          child: TextField(
            decoration: InputDecoration(hintText: 'Rechercher'.tr, prefixIcon: Icon(Icons.search)),
            onChanged: onSearch,
          ),
        ),
        if (nbInactive > 0)
          FilterChip(
            label: Text('Inactifs ({0})'.trf([nbInactive])),
            selected: showInactive,
            onSelected: onShowInactive,
          ),
      ]);
}

Future<void> _deleteRef(BuildContext context, String table, String id, String nom) async {
  final ok = await confirmDialog(context, 'Supprimer'.tr, 'Supprimer « {0} » définitivement ?'.trf([nom]));
  if (!ok) return;
  try {
    await data.deleteRef(table, id);
    if (context.mounted) showSnack(context, 'Supprimé'.tr);
  } catch (e) {
    if (context.mounted) showSnack(context, errorMessage(e), error: true);
  }
}

// ======================================================================= Ouvriers

class OuvriersScreen extends StatefulWidget {
  const OuvriersScreen({super.key});

  @override
  State<OuvriersScreen> createState() => _OuvriersScreenState();
}

class _OuvriersScreenState extends State<OuvriersScreen> {
  String _q = '';
  bool _inactive = false;
  String? _dept;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final all = data.ouvriers;
          final depts = all.map((o) => o.departement).toSet().toList()..sort();
          final list = all
              .where((o) => _inactive || o.actif)
              .where((o) => _dept == null || o.departement == _dept)
              .where((o) => _q.isEmpty || o.nom.toLowerCase().contains(_q.toLowerCase()))
              .toList();
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-ouv',
              onPressed: () => showDialog<bool>(context: context, builder: (_) => OuvrierForm(null, departement: _dept)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('Ajouter un ouvrier'.tr),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                AutoGrid(minItemWidth: 200, children: [
                  StatTile(
                    label: 'Reste à payer (tous)'.tr,
                    value: fmtDA(data.totalResteAPayer),
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.green,
                  ),
                  StatTile(
                    label: 'Avances non couvertes'.tr,
                    value: fmtDA(data.totalAvancesNonCouvertes),
                    icon: Icons.north_east_rounded,
                    color: AppColors.rose,
                  ),
                ]),
                const SizedBox(height: 12),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.lock_clock_rounded, color: AppColors.ink),
                    ),
                    title: Text('Clôture de la paie du mois'.tr, style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('Salaires, avances, net à payer · toutes les fiches de paie en un clic'.tr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CloturePaieScreen())),
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, color: context.cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Ici : les ouvriers de l\'atelier, sans compte ni accès au logiciel. Brodeurs sur les machines → mode « Points ». Autres ouvriers → « Mois » (salaire fixe) ou « Pièce ».'.tr),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _ListHeader(
                  onSearch: (v) => setState(() => _q = v),
                  nbInactive: all.where((o) => !o.actif).length,
                  showInactive: _inactive,
                  onShowInactive: (v) => setState(() => _inactive = v),
                ),
                if (depts.length > 1) ...[
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(label: Text('Tous ({0})'.trf([all.length])), selected: _dept == null, onSelected: (_) => setState(() => _dept = null)),
                      ),
                      for (final d in depts)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('$d (${all.where((o) => o.departement == d).length})'),
                            selected: _dept == d,
                            onSelected: (_) => setState(() => _dept = d),
                          ),
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyState(all.isEmpty ? 'Aucun ouvrier.\nAjoutez les ouvriers de l\'atelier.'.tr : 'Aucun résultat.'.tr,
                      icon: Icons.people_outline)
                else
                  AutoGrid(minItemWidth: 320, children: [
                    for (final o in list) _OuvrierCard(o),
                  ]),
              ],
            ),
          );
        },
      );
}

class _OuvrierCard extends StatelessWidget {
  final Ouvrier o;
  const _OuvrierCard(this.o);

  @override
  Widget build(BuildContext context) {
    final solde = data.solde(o.id).solde;
    final c = soldeColor(solde);
    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Opacity(opacity: o.actif ? 1 : 0.45, child: NameAvatar(o.nom, size: 50)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _pill(context, o.departement.tr, AppColors.forName(o.departement)),
                _pill(context, _modeText(o), context.pal.muted),
                if (!o.actif) _pill(context, 'Inactif'.tr, AppColors.rose),
              ]),
            ]),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: context.pal.muted),
            itemBuilder: (_) => [
              if (!o.brodeur) PopupMenuItem(value: 'travail', child: Text('Ajouter du travail'.tr)),
              PopupMenuItem(value: 'avance', child: Text('Donner une avance'.tr)),
              PopupMenuItem(value: 'payer', child: Text('Payer'.tr)),
              PopupMenuItem(value: 'edit', child: Text('Modifier'.tr)),
              PopupMenuItem(value: 'del', child: Text('Supprimer'.tr)),
            ],
            onSelected: (v) {
              switch (v) {
                case 'travail':
                  openPieceForm(context, o);
                case 'avance':
                  openMouvementForm(context, o, TypeMvt.avance);
                case 'payer':
                  openMouvementForm(context, o, TypeMvt.paiement, montant: solde > 0 ? solde : null);
                case 'edit':
                  showDialog<bool>(context: context, builder: (_) => OuvrierForm(o));
                default:
                  _deleteRef(context, 'broderie_ouvriers', o.id, o.nom);
              }
            },
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(solde < -0.005 ? Icons.north_east_rounded : Icons.account_balance_wallet_rounded, size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(child: Text(solde < -0.005 ? 'Avance non couverte'.tr : 'Reste à payer'.tr, style: TextStyle(color: c, fontWeight: FontWeight.w600))),
            Text(fmtDA(solde.abs()), style: TextStyle(color: c, fontWeight: FontWeight.w900)),
          ]),
        ),
      ]),
    );
  }

  static String _modeText(Ouvrier o) => switch (o.modePaie) {
        ModePaie.points => 'Points broderie'.tr,
        ModePaie.mois => 'Mois · {0}'.trf([fmtDA(o.salaireMensuel)]),
        ModePaie.piece => 'Pièce · {0}'.trf([fmtDA(o.prixPiece)]),
      };

  static Widget _pill(BuildContext context, String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class OuvrierForm extends StatefulWidget {
  final Ouvrier? o;
  final String? departement;
  const OuvrierForm(this.o, {super.key, this.departement});

  @override
  State<OuvrierForm> createState() => _OuvrierFormState();
}

class _OuvrierFormState extends State<OuvrierForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.o?.nom);
  late final _tel = TextEditingController(text: widget.o?.telephone);
  late final _dept = TextEditingController(text: widget.o?.departement ?? widget.departement ?? 'Broderie');
  late ModePaie _mode = widget.o?.modePaie ?? ((widget.departement ?? 'Broderie') == 'Broderie' ? ModePaie.points : ModePaie.mois);
  late final _salaire = TextEditingController(text: _fmt(widget.o?.salaireMensuel ?? 0));
  late final _prix = TextEditingController(text: _fmt(widget.o?.prixPiece ?? 0));
  late bool _actif = widget.o?.actif ?? true;
  bool _busy = false;

  static String _fmt(double v) => v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString());

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _dept.dispose();
    _salaire.dispose();
    _prix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveRef(
        'broderie_ouvriers',
        Ouvrier.toRow(
          nom: _nom.text,
          telephone: _tel.text,
          tarif1000: widget.o?.tarif1000 ?? 0,
          actif: _actif,
          departement: _dept.text,
          modePaie: _mode,
          salaireMensuel: parseNum(_salaire.text) ?? 0,
          prixPiece: parseNum(_prix.text) ?? 0,
        ),
        id: widget.o?.id,
      );
      if (mounted) {
        showSnack(context, 'Ouvrier enregistré'.tr);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.o == null ? 'Nouvel ouvrier'.tr : 'Modifier l\'ouvrier'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: widget.o == null,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: 'Nom et prénom'.tr, prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: 'Téléphone (facultatif)'.tr, prefixIcon: Icon(Icons.phone_outlined)),
          ),
          TextFormField(
            controller: _dept,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Département / poste'.tr, prefixIcon: Icon(Icons.apartment_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in data.departements)
              ChoiceChip(
                label: Text(d.tr),
                selected: _dept.text.trim() == d,
                onSelected: (_) => setState(() {
                  _dept.text = d;
                  if (widget.o == null && d != 'Broderie' && _mode == ModePaie.points) _mode = ModePaie.mois;
                }),
              ),
          ]),
          Text('Mode de paie'.tr, style: context.tt.labelLarge),
          SegmentedButton<ModePaie>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: ModePaie.points, icon: Icon(Icons.blur_on_rounded), label: Text('Points'.tr)),
              ButtonSegment(value: ModePaie.mois, icon: Icon(Icons.calendar_month_rounded), label: Text('Mois'.tr)),
              ButtonSegment(value: ModePaie.piece, icon: Icon(Icons.checkroom_rounded), label: Text('Pièce'.tr)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          if (_mode == ModePaie.points)
            Text('Payé selon les points du compteur et le type de broderie (Réglages → tarifs).'.tr,
                style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          if (_mode == ModePaie.mois)
            TextFormField(
              controller: _salaire,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Salaire mensuel'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.payments_outlined)),
              validator: (v) {
                final n = parseNum(v ?? '');
                return (n == null || n <= 0) ? 'Indiquez le salaire'.tr : null;
              },
            ),
          if (_mode != ModePaie.points && _dept.text.trim().toLowerCase() == 'broderie')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Département Broderie : vous pourrez saisir ses points (production suivie), sans montant ajouté à sa paie.'.tr,
                  style: TextStyle(fontSize: 12, color: context.cs.primary)),
            ),
          if (_mode == ModePaie.piece)
            TextFormField(
              controller: _prix,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Prix par pièce (par défaut)'.tr, suffixText: 'DA'.tr, prefixIcon: Icon(Icons.sell_outlined)),
              validator: (v) {
                final n = parseNum(v ?? '');
                return (n == null || n <= 0) ? 'Indiquez le prix'.tr : null;
              },
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Actif'.tr),
            subtitle: Text('Un ouvrier inactif n\'apparaît plus dans les saisies'.tr),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
        ],
      );
}

// ======================================================================= Dessins

class DessinsScreen extends StatefulWidget {
  const DessinsScreen({super.key});

  @override
  State<DessinsScreen> createState() => _DessinsScreenState();
}

class _DessinsScreenState extends State<DessinsScreen> {
  String _q = '';
  bool _inactive = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final all = data.dessins;
          final list = all
              .where((d) => _inactive || d.actif)
              .where((d) => _q.isEmpty || d.nom.toLowerCase().contains(_q.toLowerCase()) || (d.client ?? '').toLowerCase().contains(_q.toLowerCase()))
              .toList();
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-des',
              onPressed: () => showDialog<bool>(context: context, builder: (_) => const DessinForm(null)),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text('Ajouter un dessin'.tr),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _ListHeader(
                  onSearch: (v) => setState(() => _q = v),
                  nbInactive: all.where((d) => !d.actif).length,
                  showInactive: _inactive,
                  onShowInactive: (v) => setState(() => _inactive = v),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyState(all.isEmpty ? 'Aucun dessin.\nAjoutez vos dessins avec leur photo et leur nombre de points.'.tr : 'Aucun résultat.'.tr,
                      icon: Icons.local_florist_outlined)
                else
                  AutoGrid(minItemWidth: 170, children: [
                    for (final d in list)
                      AppCard(
                        padding: const EdgeInsets.all(10),
                        onTap: () => showDialog<bool>(context: context, builder: (_) => DessinForm(d)),
                        child: Opacity(
                          opacity: d.actif ? 1 : 0.5,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            AspectRatio(
                              aspectRatio: 1.1,
                              child: LayoutBuilder(builder: (_, bc) => DessinThumb(d, size: bc.maxWidth, radius: 14)),
                            ),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                child: Text(d.nom, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                              InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _deleteRef(context, 'broderie_dessins', d.id, d.nom),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(Icons.delete_outline, size: 18, color: context.pal.muted),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.cs.primary.withValues(alpha: 0.13),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('${fmtInt(d.points)} pts',
                                    style: TextStyle(color: context.cs.primary, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                              const SizedBox(width: 6),
                              if (d.client != null)
                                Expanded(
                                  child: Text(d.client!, overflow: TextOverflow.ellipsis,
                                      style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                                ),
                            ]),
                          ]),
                        ),
                      ),
                  ]),
              ],
            ),
          );
        },
      );
}

class DessinForm extends StatefulWidget {
  final Dessin? d;
  const DessinForm(this.d, {super.key});

  @override
  State<DessinForm> createState() => _DessinFormState();
}

class _DessinFormState extends State<DessinForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.d?.nom);
  late final _pts = TextEditingController(text: widget.d?.points.toString());
  late final _client = TextEditingController(text: widget.d?.client);
  late final _note = TextEditingController(text: widget.d?.note);
  late bool _actif = widget.d?.actif ?? true;
  bool _busy = false;

  Uint8List? _newPhoto;
  String _newExt = 'jpg';
  bool _removePhoto = false;

  @override
  void dispose() {
    _nom.dispose();
    _pts.dispose();
    _client.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1200, maxHeight: 1200, imageQuality: 82);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final name = x.name.toLowerCase();
      setState(() {
        _newPhoto = bytes;
        _newExt = name.contains('.') ? name.split('.').last : 'jpg';
        _removePhoto = false;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Impossible d\'ouvrir la photo : {0}'.trf([errorMessage(e)]), error: true);
    }
  }

  Future<void> _choosePhoto() async {
    final canCamera = Theme.of(context).platform == TargetPlatform.android || Theme.of(context).platform == TargetPlatform.iOS;
    if (!canCamera) return _pick(ImageSource.gallery);
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text('Prendre une photo'.tr),
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text('Choisir dans la galerie'.tr),
              onTap: () => Navigator.pop(c, ImageSource.gallery)),
        ]),
      ),
    );
    if (src != null) await _pick(src);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final id = await data.saveRef(
        'broderie_dessins',
        Dessin.toRow(nom: _nom.text, points: parseInt(_pts.text)!, client: _client.text, note: _note.text, actif: _actif),
        id: widget.d?.id,
      );
      final old = widget.d?.photoPath;
      if (_newPhoto != null) {
        final path = await data.uploadPhoto(id, _newPhoto!, _newExt);
        await data.setDessinPhoto(id, path);
        if (old != null) await data.removePhoto(old);
      } else if (_removePhoto && old != null) {
        await data.setDessinPhoto(id, null);
        await data.removePhoto(old);
      }
      if (mounted) {
        showSnack(context, 'Dessin enregistré'.tr);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  Widget _photoBox() {
    final hasOld = widget.d?.photoPath != null && !_removePhoto;
    Widget content;
    if (_newPhoto != null) {
      content = Image.memory(_newPhoto!, fit: BoxFit.cover);
    } else if (hasOld) {
      content = LayoutBuilder(builder: (_, c) => DessinThumb(widget.d, size: c.maxWidth, radius: 0));
    } else {
      content = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_a_photo_outlined, size: 36, color: context.cs.primary),
        const SizedBox(height: 8),
        Text('Ajouter une photo du dessin'.tr, style: TextStyle(color: context.pal.muted)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy ? null : _choosePhoto,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 170,
            color: context.pal.surface2,
            child: content,
          ),
        ),
      ),
      if (_newPhoto != null || hasOld)
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          TextButton.icon(onPressed: _busy ? null : _choosePhoto, icon: const Icon(Icons.swap_horiz, size: 18), label: Text('Changer'.tr)),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _newPhoto = null;
                      _removePhoto = true;
                    }),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: Text('Retirer'.tr),
          ),
        ]),
    ]);
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.d == null ? 'Nouveau dessin'.tr : 'Modifier le dessin'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          _photoBox(),
          TextFormField(
            controller: _nom,
            decoration: InputDecoration(labelText: 'Nom / référence du dessin'.tr, prefixIcon: Icon(Icons.local_florist_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(
            controller: _pts,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nombre de points (par robe)'.tr,
              prefixIcon: const Icon(Icons.blur_on_rounded),
              helperText: widget.d == null ? null : 'Modifier ce nombre ne change pas les saisies déjà enregistrées'.tr,
            ),
            validator: (v) {
              final n = parseInt(v ?? '');
              return (n == null || n <= 0) ? 'Nombre entier supérieur à 0'.tr : null;
            },
          ),
          TextFormField(controller: _client, decoration: InputDecoration(labelText: 'Client (facultatif)'.tr, prefixIcon: Icon(Icons.storefront_outlined))),
          TextFormField(controller: _note, decoration: InputDecoration(labelText: 'Remarque (facultatif)'.tr, prefixIcon: Icon(Icons.notes))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Actif'.tr),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
        ],
      );
}

// ======================================================================= Machines

class MachinesScreen extends StatelessWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Machines'.tr)),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-mac',
          onPressed: () => showDialog<bool>(context: context, builder: (_) => const _MachineForm(null)),
          icon: const Icon(Icons.add),
          label: Text('Ajouter une machine'.tr),
        ),
        body: ListenableBuilder(
          listenable: data,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (data.machines.isEmpty)
                EmptyState('Aucune machine (facultatif).\nAjoutez vos machines pour savoir laquelle a brodé.'.tr,
                    icon: Icons.precision_manufacturing_outlined)
              else
                for (final m in data.machines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => showDialog<bool>(context: context, builder: (_) => _MachineForm(m)),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.precision_manufacturing_rounded, color: AppColors.teal),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.nom, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('{0} tête{1}{2}'.trf([m.nbTetes, m.nbTetes > 1 ? 's' : '', m.actif ? '' : ' · Inactive'.tr]),
                                style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                          ]),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: context.pal.muted),
                          onPressed: () => _deleteRef(context, 'broderie_machines', m.id, m.nom),
                        ),
                      ]),
                    ),
                  ),
            ],
          ),
        ),
      );
}

class _MachineForm extends StatefulWidget {
  final Machine? m;
  const _MachineForm(this.m);

  @override
  State<_MachineForm> createState() => _MachineFormState();
}

class _MachineFormState extends State<_MachineForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.m?.nom);
  late final _tetes = TextEditingController(text: (widget.m?.nbTetes ?? 1).toString());
  late bool _actif = widget.m?.actif ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _nom.dispose();
    _tetes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveRef(
        'broderie_machines',
        Machine.toRow(nom: _nom.text, nbTetes: parseInt(_tetes.text)!, actif: _actif),
        id: widget.m?.id,
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
  Widget build(BuildContext context) => FormDialog(
        title: widget.m == null ? 'Nouvelle machine'.tr : 'Modifier la machine'.tr,
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Nom (ex. Tajima 1)'.tr),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire'.tr : null,
          ),
          TextFormField(
            controller: _tetes,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Nombre de têtes'.tr),
            validator: (v) {
              final n = parseInt(v ?? '');
              return (n == null || n <= 0) ? 'Nombre entier supérieur à 0'.tr : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Active'.tr),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
        ],
      );
}

// ======================================================================= Dialogue commun

class FormDialog extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final VoidCallback onSave;
  final List<Widget> children;

  const FormDialog({super.key, required this.title, required this.formKey, required this.busy, required this.onSave, required this.children});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: Text('Annuler'.tr)),
          FilledButton(
            onPressed: busy ? null : onSave,
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Enregistrer'.tr),
          ),
        ],
      );
}
