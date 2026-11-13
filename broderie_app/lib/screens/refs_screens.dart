import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../utils.dart';
import '../widgets.dart';

/// Écran générique de liste (ouvriers, dessins, machines).
class _RefList<T> extends StatefulWidget {
  final String addLabel;
  final String emptyText;
  final IconData icon;
  final List<T> Function() items;
  final String Function(T) title;
  final String Function(T) subtitle;
  final bool Function(T) actif;
  final String Function(T) id;
  final Future<bool?> Function(BuildContext, T?) openForm;
  final String table;

  const _RefList({
    super.key,
    required this.addLabel,
    required this.emptyText,
    required this.icon,
    required this.items,
    required this.title,
    required this.subtitle,
    required this.actif,
    required this.id,
    required this.openForm,
    required this.table,
  });

  @override
  State<_RefList<T>> createState() => _RefListState<T>();
}

class _RefListState<T> extends State<_RefList<T>> {
  bool _showInactive = false;
  String _search = '';

  Future<void> _delete(T item) async {
    final ok = await confirmDialog(context, 'Supprimer', 'Supprimer « ${widget.title(item)} » définitivement ?');
    if (!ok) return;
    try {
      await data.deleteRef(widget.table, widget.id(item));
      if (mounted) showSnack(context, 'Supprimé');
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _open([T? item]) async {
    final ok = await widget.openForm(context, item);
    if (ok == true && mounted) showSnack(context, 'Enregistré');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: data,
      builder: (context, _) {
        final all = widget.items();
        final q = _search.toLowerCase();
        final list = all
            .where((x) => _showInactive || widget.actif(x))
            .where((x) => q.isEmpty || widget.title(x).toLowerCase().contains(q))
            .toList();
        final nbInactive = all.where((x) => !widget.actif(x)).length;
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _open(),
            icon: const Icon(Icons.add),
            label: Text(widget.addLabel),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Rechercher', prefixIcon: Icon(Icons.search)),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (nbInactive > 0)
                  FilterChip(
                    label: Text('Afficher les inactifs ($nbInactive)'),
                    selected: _showInactive,
                    onSelected: (v) => setState(() => _showInactive = v),
                  ),
              ]),
              const SizedBox(height: 12),
              if (list.isEmpty)
                EmptyState(all.isEmpty ? widget.emptyText : 'Aucun résultat.', icon: widget.icon)
              else
                Card(
                  child: Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      ListTile(
                        leading: CircleAvatar(child: Icon(widget.icon, size: 20)),
                        title: Text(widget.title(list[i]),
                            style: widget.actif(list[i]) ? null : const TextStyle(decoration: TextDecoration.lineThrough)),
                        subtitle: Text(widget.subtitle(list[i])),
                        onTap: () => _open(list[i]),
                        trailing: PopupMenuButton<String>(
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Modifier')),
                            PopupMenuItem(value: 'del', child: Text('Supprimer')),
                          ],
                          onSelected: (v) => v == 'edit' ? _open(list[i]) : _delete(list[i]),
                        ),
                      ),
                      if (i < list.length - 1) const Divider(height: 1),
                    ],
                  ]),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Ouvriers

class OuvriersScreen extends StatelessWidget {
  const OuvriersScreen({super.key});

  @override
  Widget build(BuildContext context) => _RefList<Ouvrier>(
        table: 'broderie_ouvriers',
        addLabel: 'Ajouter un ouvrier',
        emptyText: 'Aucun ouvrier.\nAjoutez les ouvriers de l\'atelier.',
        icon: Icons.person_outline,
        items: () => data.ouvriers,
        title: (o) => o.nom,
        subtitle: (o) => [
          o.tarif1000 > 0 ? '${fmtDA(o.tarif1000)} / 1000 pts' : 'Tarif non défini',
          if (o.telephone != null) o.telephone!,
          if (!o.actif) 'Inactif',
        ].join(' · '),
        actif: (o) => o.actif,
        id: (o) => o.id,
        openForm: (c, o) => showDialog<bool>(context: c, builder: (_) => _OuvrierForm(o)),
      );
}

class _OuvrierForm extends StatefulWidget {
  final Ouvrier? o;
  const _OuvrierForm(this.o);

  @override
  State<_OuvrierForm> createState() => _OuvrierFormState();
}

class _OuvrierFormState extends State<_OuvrierForm> {
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
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _FormDialog(
        title: widget.o == null ? 'Nouvel ouvrier' : 'Modifier l\'ouvrier',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nom et prénom'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _tel,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Téléphone (facultatif)'),
          ),
          TextFormField(
            controller: _tarif,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Tarif (DA pour 1000 points)', helperText: 'Laisser vide si non payé aux points'),
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

// ---------------------------------------------------------------- Dessins

class DessinsScreen extends StatelessWidget {
  const DessinsScreen({super.key});

  @override
  Widget build(BuildContext context) => _RefList<Dessin>(
        table: 'broderie_dessins',
        addLabel: 'Ajouter un dessin',
        emptyText: 'Aucun dessin.\nAjoutez vos dessins avec leur nombre de points.',
        icon: Icons.draw_outlined,
        items: () => data.dessins,
        title: (d) => d.nom,
        subtitle: (d) => [
          '${fmtInt(d.points)} points / robe',
          if (d.client != null) d.client!,
          if (d.note != null) d.note!,
          if (!d.actif) 'Inactif',
        ].join(' · '),
        actif: (d) => d.actif,
        id: (d) => d.id,
        openForm: (c, d) => showDialog<bool>(context: c, builder: (_) => _DessinForm(d)),
      );
}

class _DessinForm extends StatefulWidget {
  final Dessin? d;
  const _DessinForm(this.d);

  @override
  State<_DessinForm> createState() => _DessinFormState();
}

class _DessinFormState extends State<_DessinForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.d?.nom);
  late final _pts = TextEditingController(text: widget.d?.points.toString());
  late final _client = TextEditingController(text: widget.d?.client);
  late final _note = TextEditingController(text: widget.d?.note);
  late bool _actif = widget.d?.actif ?? true;
  bool _busy = false;

  @override
  void dispose() {
    _nom.dispose();
    _pts.dispose();
    _client.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveRef(
        'broderie_dessins',
        Dessin.toRow(nom: _nom.text, points: parseInt(_pts.text)!, client: _client.text, note: _note.text, actif: _actif),
        id: widget.d?.id,
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
  Widget build(BuildContext context) => _FormDialog(
        title: widget.d == null ? 'Nouveau dessin' : 'Modifier le dessin',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nom / référence du dessin'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _pts,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Nombre de points (par robe)',
              helperText: widget.d == null ? null : 'Modifier ce nombre ne change pas les saisies déjà enregistrées',
            ),
            validator: (v) {
              final n = parseInt(v ?? '');
              return (n == null || n <= 0) ? 'Nombre entier supérieur à 0' : null;
            },
          ),
          TextFormField(controller: _client, decoration: const InputDecoration(labelText: 'Client (facultatif)')),
          TextFormField(controller: _note, decoration: const InputDecoration(labelText: 'Remarque (facultatif)')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
        ],
      );
}

// ---------------------------------------------------------------- Machines

class MachinesScreen extends StatelessWidget {
  const MachinesScreen({super.key});

  @override
  Widget build(BuildContext context) => _RefList<Machine>(
        table: 'broderie_machines',
        addLabel: 'Ajouter une machine',
        emptyText: 'Aucune machine (facultatif).\nAjoutez vos machines pour savoir laquelle a brodé.',
        icon: Icons.settings_input_component_outlined,
        items: () => data.machines,
        title: (m) => m.nom,
        subtitle: (m) => ['${m.nbTetes} tête${m.nbTetes > 1 ? 's' : ''}', if (!m.actif) 'Inactive'].join(' · '),
        actif: (m) => m.actif,
        id: (m) => m.id,
        openForm: (c, m) => showDialog<bool>(context: c, builder: (_) => _MachineForm(m)),
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
  Widget build(BuildContext context) => _FormDialog(
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

// ---------------------------------------------------------------- Dialogue commun

class _FormDialog extends StatelessWidget {
  final String title;
  final GlobalKey<FormState> formKey;
  final bool busy;
  final VoidCallback onSave;
  final List<Widget> children;

  const _FormDialog({required this.title, required this.formKey, required this.busy, required this.onSave, required this.children});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 12), child: c),
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
