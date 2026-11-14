import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_data.dart';
import '../data/models.dart';
import '../data/session.dart';
import '../data/stock.dart';
import '../utils.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin_screens.dart';
import 'refs_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Apparence', subtitle: 'Thème de l\'application'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Clair')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Sombre')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => ThemeController.instance.set(s.first),
                ),
              ),
            ]),
          ),
          if (session.admin) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.manage_accounts_rounded, color: AppColors.gold),
                  title: const Text('Comptes et accès au logiciel', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Pour ceux qui utilisent l\'application (pas les ouvriers)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployesScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business_rounded),
                  title: const Text('Entreprise (en-tête des factures)', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(session.atelier?.nom ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SocieteScreen())),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            const _TypesCard(),
          ],
          if (session.peut(Espace.broderie)) ...[
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(children: [
                ListTile(
                  leading: const Icon(Icons.precision_manufacturing_outlined),
                  title: const Text('Machines'),
                  subtitle: Text('${data.machines.length} machine(s)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MachinesScreen())),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: Text(session.membre?.nom.isNotEmpty == true ? session.membre!.nom : 'Compte'),
                subtitle: Text('${session.membre?.identifiantCourt ?? email}\n${session.membre?.droitsTexte ?? ''}'),
                isThreeLine: true,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: context.cs.error),
                title: Text('Se déconnecter', style: TextStyle(color: context.cs.error)),
                onTap: () async {
                  data.clear();
                  stock.clear();
                  session.clear();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Atelier Broderie · v5.0', style: TextStyle(color: context.pal.muted, fontSize: 12))),
        ],
      ),
    );
  }
}

/// Types de broderie et leurs tarifs (DA pour 1000 points).
class _TypesCard extends StatelessWidget {
  const _TypesCard();

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) => AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionTitle(
              'Types de broderie et tarifs',
              subtitle: 'Prix pour 1000 points du compteur',
              trailing: IconButton.filledTonal(
                tooltip: 'Ajouter un type',
                onPressed: () => showDialog<bool>(context: context, builder: (_) => const _TypeForm(null)),
                icon: const Icon(Icons.add),
              ),
            ),
            for (var i = 0; i < data.types.length; i++)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => showDialog<bool>(context: context, builder: (_) => _TypeForm(data.types[i])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: AppColors.series[i % AppColors.series.length], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data.types[i].nom + (data.types[i].actif ? '' : ' (inactif)'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('300 000 pts = ${fmtDA(300 * data.types[i].tarif1000)}',
                            style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
                      ]),
                    ),
                    Text('${fmtDA(data.types[i].tarif1000)} / 1000', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 6),
                    Icon(Icons.edit_outlined, size: 18, color: context.pal.muted),
                  ]),
                ),
              ),
            const SizedBox(height: 6),
            Text('Changer un tarif ne modifie pas les relevés déjà enregistrés.',
                style: context.tt.bodySmall?.copyWith(color: context.pal.muted)),
          ]),
        ),
      );
}

class _TypeForm extends StatefulWidget {
  final TypeTravail? t;
  const _TypeForm(this.t);

  @override
  State<_TypeForm> createState() => _TypeFormState();
}

class _TypeFormState extends State<_TypeForm> {
  final _form = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.t?.nom);
  late final _tarif = TextEditingController(text: widget.t == null ? '' : _fmt(widget.t!.tarif1000));
  late bool _actif = widget.t?.actif ?? true;
  bool _busy = false;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _nom.dispose();
    _tarif.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await data.saveRef(
        'broderie_types',
        TypeTravail.toRow(
          nom: _nom.text,
          tarif1000: parseNum(_tarif.text)!,
          ordre: widget.t?.ordre ?? data.types.length,
          actif: _actif,
        ),
        id: widget.t?.id,
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
        title: widget.t == null ? 'Nouveau type de broderie' : 'Modifier le type',
        formKey: _form,
        busy: _busy,
        onSave: _save,
        children: [
          TextFormField(
            controller: _nom,
            decoration: const InputDecoration(labelText: 'Nom (ex. Passé plat, Cordon)', prefixIcon: Icon(Icons.gesture_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatoire' : null,
          ),
          TextFormField(
            controller: _tarif,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Prix pour 1000 points (DA)',
              prefixIcon: Icon(Icons.payments_outlined),
              helperText: 'Ex. 10 → 300 000 points = 3 000 DA',
            ),
            validator: (v) {
              final n = parseNum(v ?? '');
              return (n == null || n < 0) ? 'Nombre invalide' : null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actif'),
            value: _actif,
            onChanged: (v) => setState(() => _actif = v),
          ),
        ],
      );
}
