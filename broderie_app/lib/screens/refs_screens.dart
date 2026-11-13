import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'ouvrier_detail_screen.dart';

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
            decoration: const InputDecoration(hintText: 'Rechercher', prefixIcon: Icon(Icons.search)),
            onChanged: onSearch,
          ),
        ),
        if (nbInactive > 0)
          FilterChip(
            label: Text('Inactifs ($nbInactive)'),
            selected: showInactive,
            onSelected: onShowInactive,
          ),
      ]);
}

Future<void> _deleteRef(BuildContext context, String table, String id, String nom) async {
  final ok = await confirmDialog(context, 'Supprimer', 'Supprimer « $nom » définitivement ?');
  if (!ok) return;
  try {
    await data.deleteRef(table, id);
    if (context.mounted) showSnack(context, 'Supprimé');
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final all = data.ouvriers;
          final list = all
              .where((o) => _inactive || o.actif)
              .where((o) => _q.isEmpty || o.nom.toLowerCase().contains(_q.toLowerCase()))
              .toList();
          return Scaffold(
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-ouv',
              onPressed: () => showDialog<bool>(context: context, builder: (_) => const OuvrierForm(null)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Ajouter un ouvrier'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _ListHeader(
                  onSearch: (v) => setState(() => _q = v),
                  nbInactive: all.where((o) => !o.actif).length,
                  showInactive: _inactive,
                  onShowInactive: (v) => setState(() => _inactive = v),
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  EmptyState(all.isEmpty ? 'Aucun ouvrier.\nAjoutez les ouvriers de l\'atelier.' : 'Aucun résultat.',
                      icon: Icons.people_outline)
                else
                  AutoGrid(minItemWidth: 300, children: [
                    for (final o in list)
                      AppCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id))),
                        child: Row(children: [
                          Opacity(opacity: o.actif ? 1 : 0.45, child: NameAvatar(o.nom, size: 50)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16), overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  o.tarif1000 > 0 ? '${fmtDA(o.tarif1000)} / 1000 pts' : 'Tarif non défini',
                                  if (o.telephone != null) o.telephone!,
                                  if (!o.actif) 'Inactif',
                                ].join(' · '),
                                style: context.tt.bodySmall?.copyWith(color: context.pal.muted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ]),
                          ),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: context.pal.muted),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'fiche', child: Text('Fiche et paie')),
                              PopupMenuItem(value: 'edit', child: Text('Modifier')),
                              PopupMenuItem(value: 'del', child: Text('Supprimer')),
                            ],
                            onSelected: (v) {
                              if (v == 'fiche') {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id)));
                              } else if (v == 'edit') {
                                showDialog<bool>(context: context, builder: (_) => OuvrierForm(o));
                              } else {
                                _deleteRef(context, 'broderie_ouvriers', o.id, o.nom);
                              }
                            },
                          ),
                        ]),
                      ),
                  ]),
              ],
            ),
          );
        },
      );
}

class OuvrierForm extends StatefulWidget {
  final Ouvrier? o;
  const OuvrierForm(this.o, {super.key});

  @override
  State<OuvrierForm> createState() => _OuvrierFormState();
}

class _OuvrierFormState extends State<OuvrierForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.o?.nom);
  late final _tel = TextEditingController(text: widget.o?.telephone);
  late final _tarif = TextEditingController(text: (widget.o?.tarif1000 ?? 0) > 0 ? widget.o!.tarif1000.toString() : '');
  late bool _actif = widget.o?.actif ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _tarif.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveRef(
        'broderie_ouvriers',
        Ouvrier.toRow(nom: _nom.text, telephone: _tel.text, tarif1000: parseNum(_tarif.text) ?? 0, actif: _actif),
        id: widget.o?.id,
      );
      if (mounted) {
        showSnack(context, 'Ouvrier enregistré');
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
        title: widget.o == null ? 'Nouvel ouvrier' : 'Modifier l\'ouvrier',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom et prénom', prefixIcon: Icon(Icons.person_outline)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone (facultatif)', prefixIcon: Icon(Icons.phone_outlined)),
          ),
          TextFormField(
            controller: _tarif,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Tarif (DA pour 1000 points)',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText: 'Laisser vide si non payé aux points',
            ),
            validator: (v) => (v != null && v.trim().isNotEmpty && (parseNum(v) == null || parseNum(v)! < 0)) ? 'Nombre invalide' : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            subtitle: const Text('Un ouvrier inactif n\'apparaît plus dans les saisies'),
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
              label: const Text('Ajouter un dessin'),
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
                  EmptyState(all.isEmpty ? 'Aucun dessin.\nAjoutez vos dessins avec leur photo et leur nombre de points.' : 'Aucun résultat.',
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
      if (mounted) showSnack(context, 'Impossible d\'ouvrir la photo : ${errorMessage(e)}', error: true);
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
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choisir dans la galerie'),
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
        showSnack(context, 'Dessin enregistré');
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
        Text('Ajouter une photo du dessin', style: TextStyle(color: context.pal.muted)),
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
          TextButton.icon(onPressed: _busy ? null : _choosePhoto, icon: const Icon(Icons.swap_horiz, size: 18), label: const Text('Changer')),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _newPhoto = null;
                      _removePhoto = true;
                    }),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Retirer'),
          ),
        ]),
    ]);
  }

  @override
  Widget build(BuildContext context) => FormDialog(
        title: widget.d == null ? 'Nouveau dessin' : 'Modifier le dessin',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          _photoBox(),
          TextFormField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom / référence du dessin', prefixIcon: Icon(Icons.local_florist_outlined)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _pts,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nombre de points (par robe)',
              prefixIcon: const Icon(Icons.blur_on_rounded),
              helperText: widget.d == null ? null : 'Modifier ce nombre ne change pas les saisies déjà enregistrées',
            ),
            validator: (v) {
              final n = parseInt(v ?? '');
              return (n == null || n <= 0) ? 'Nombre entier supérieur à 0' : null;
            },
          ),
          TextFormField(controller: _client, decoration: const InputDecoration(labelText: 'Client (facultatif)', prefixIcon: Icon(Icons.storefront_outlined))),
          TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (facultatif)', prefixIcon: Icon(Icons.notes))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
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
        appBar: AppBar(title: const Text('Machines')),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'fab-mac',
          onPressed: () => showDialog<bool>(context: context, builder: (_) => const _MachineForm(null)),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une machine'),
        ),
        body: ListenableBuilder(
          listenable: data,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (data.machines.isEmpty)
                const EmptyState('Aucune machine (facultatif).\nAjoutez vos machines pour savoir laquelle a brodé.',
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
                            Text('${m.nbTetes} tête${m.nbTetes > 1 ? 's' : ''}${m.actif ? '' : ' · Inactive'}',
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
        title: widget.m == null ? 'Nouvelle machine' : 'Modifier la machine',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom (ex. Tajima 1)'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _tetes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Nombre de têtes'),
            validator: (v) {
              final n = parseInt(v ?? '');
              return (n == null || n <= 0) ? 'Nombre entier supérieur à 0' : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
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
          TextButton(onPressed: busy ? null : () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: busy ? null : onSave,
            child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Enregistrer'),
          ),
        ],
      );
}
