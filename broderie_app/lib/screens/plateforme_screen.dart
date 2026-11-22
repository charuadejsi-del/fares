import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

SupabaseClient get _db => Supabase.instance.client;

String _abonnementNom(String a) => switch (a) {
      'essai' => 'Essai'.tr,
      'mensuel' => 'Mensuel'.tr,
      'annuel' => 'Annuel'.tr,
      'illimite' => 'Illimité'.tr,
      _ => a,
    };

/// Espace du propriétaire de Warchati : ateliers clients, abonnements, codes d'activation.
/// Aucune donnée interne des clients n'est visible ici.
class PlateformeScreen extends StatelessWidget {
  const PlateformeScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(icon: const Icon(Icons.storefront_rounded), text: 'Ateliers clients'.tr),
              Tab(icon: const Icon(Icons.vpn_key_rounded), text: 'Codes d\'activation'.tr),
            ]),
          ),
          const Expanded(child: TabBarView(children: [_Ateliers(), _Codes()])),
        ]),
      );
}

// ====================================================================== ateliers

class _Ateliers extends StatefulWidget {
  const _Ateliers();

  @override
  State<_Ateliers> createState() => _AteliersState();
}

class _AteliersState extends State<_Ateliers> {
  late Future<List<Map<String, dynamic>>> _f = _charger();

  Future<List<Map<String, dynamic>>> _charger() async => List<Map<String, dynamic>>.from(await _db.rpc('proprio_ateliers') as List);

  void _recharger() => setState(() => _f = _charger());

  Future<void> _action(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (mounted) showSnack(context, ok);
      _recharger();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, snap) {
          if (snap.hasError) return EmptyState(errorMessage(snap.error!), icon: Icons.error_outline);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final l = snap.data!;
          final actifs = l.where((a) => !(a['suspendu'] as bool) && (a['abonnement_fin'] == null || !DateTime.parse(a['abonnement_fin']).isBefore(dayOnly(DateTime.now())))).length;
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          return RefreshIndicator(
            onRefresh: () async => _recharger(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              AutoGrid(minItemWidth: 170, children: [
                StatTile(label: 'Ateliers clients'.tr, value: '${l.length}', icon: Icons.storefront_rounded, color: AppColors.gold),
                StatTile(label: 'Abonnements actifs'.tr, value: '$actifs', icon: Icons.verified_rounded, color: AppColors.green),
                StatTile(label: 'Expirés ou suspendus'.tr, value: '${l.length - actifs}', icon: Icons.block_rounded, color: AppColors.rose),
              ]),
              const SizedBox(height: 8),
              Text('Vous voyez seulement les informations d\'abonnement : jamais les données internes des ateliers.'.tr, style: TextStyle(fontSize: 12, color: muted)),
              const SizedBox(height: 12),
              for (final a in l) _carte(a, muted),
            ]),
          );
        },
      );

  Widget _carte(Map<String, dynamic> a, Color muted) {
    final id = a['id'] as String;
    final fin = a['abonnement_fin'] == null ? null : DateTime.parse(a['abonnement_fin'] as String);
    final illimite = a['abonnement'] == 'illimite' || fin == null;
    final jours = fin == null ? null : fin.difference(dayOnly(DateTime.now())).inDays;
    final suspendu = a['suspendu'] as bool;
    final couleur = suspendu || (jours != null && jours < 0) ? AppColors.rose : (jours != null && jours <= 7 ? AppColors.gold : AppColors.green);
    final etat = suspendu
        ? 'Suspendu'.tr
        : illimite
            ? 'Illimité'.tr
            : jours! < 0
                ? 'Expiré depuis {0} j'.trf([-jours])
                : 'Expire dans {0} j'.trf([jours]);
    final activite = a['derniere_activite'] == null ? null : DateTime.parse(a['derniere_activite'] as String).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(a['nom'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: couleur.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)),
              child: Text(etat, style: TextStyle(color: couleur, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (a['code'] != null) '{0} : {1}'.trf(['Code'.tr, a['code']]),
              _abonnementNom(a['abonnement'] as String),
              if (fin != null) '{0} {1}'.trf(['Fin :'.tr, fmtDate(fin)]),
              '{0} comptes'.trf([a['membres']]),
              if (a['telephone'] != null) a['telephone'] as String,
            ].join(' · '),
            style: TextStyle(color: muted),
          ),
          Text(activite == null ? 'Aucune activité'.tr : 'Dernière activité : {0}'.trf([fmtDate(activite)]), style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton.tonal(
              onPressed: () => _action(() => _db.rpc('proprio_prolonger', params: {'p_atelier': id, 'p_mois': 1, 'p_abonnement': 'mensuel'}), 'Prolongé d\'un mois'.tr),
              child: Text('+1 mois'.tr),
            ),
            FilledButton.tonal(
              onPressed: () => _action(() => _db.rpc('proprio_prolonger', params: {'p_atelier': id, 'p_mois': 12, 'p_abonnement': 'annuel'}), 'Prolongé d\'un an'.tr),
              child: Text('+1 an'.tr),
            ),
            if (!illimite)
              OutlinedButton(
                onPressed: () => _action(() => _db.rpc('proprio_illimite', params: {'p_atelier': id}), 'Abonnement illimité'.tr),
                child: Text('Illimité'.tr),
              ),
            OutlinedButton.icon(
              onPressed: () async {
                if (!suspendu && !await confirmDialog(context, 'Suspendre {0} ?'.trf([a['nom']]), 'L\'atelier passera en lecture seule jusqu\'à sa réactivation.'.tr, action: 'Suspendre'.tr)) {
                  return;
                }
                await _action(() => _db.rpc('proprio_suspendre', params: {'p_atelier': id, 'p_suspendu': !suspendu}), suspendu ? 'Atelier réactivé'.tr : 'Atelier suspendu'.tr);
              },
              icon: Icon(suspendu ? Icons.play_arrow_rounded : Icons.pause_rounded),
              label: Text(suspendu ? 'Réactiver'.tr : 'Suspendre'.tr),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ====================================================================== codes d'activation

class _Codes extends StatefulWidget {
  const _Codes();

  @override
  State<_Codes> createState() => _CodesState();
}

class _CodesState extends State<_Codes> {
  late Future<List<Map<String, dynamic>>> _f = _charger();

  Future<List<Map<String, dynamic>>> _charger() async => List<Map<String, dynamic>>.from(await _db.rpc('proprio_codes') as List);

  Future<void> _nouveau() async {
    var type = 'mensuel';
    final mois = TextEditingController(text: '1');
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Nouveau code d\'activation'.tr),
          content: SizedBox(
            width: 380,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'essai', label: Text('Essai'.tr)),
                  ButtonSegment(value: 'mensuel', label: Text('Mensuel'.tr)),
                  ButtonSegment(value: 'annuel', label: Text('Annuel'.tr)),
                ],
                selected: {type},
                onSelectionChanged: (v) => set(() {
                  type = v.first;
                  mois.text = type == 'annuel' ? '12' : '1';
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mois,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Durée (mois)'.tr),
              ),
              const SizedBox(height: 8),
              TextField(controller: note, decoration: InputDecoration(labelText: 'Client / note (facultatif)'.tr)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Créer'.tr)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final code = await _db.rpc('proprio_creer_code', params: {'p_abonnement': type, 'p_mois': (parseInt(mois.text) ?? 1).clamp(1, 60), 'p_note': note.text});
      await Clipboard.setData(ClipboardData(text: '$code'));
      if (mounted) showSnack(context, 'Code {0} créé et copié'.trf([code]));
      setState(() => _f = _charger());
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(onPressed: _nouveau, icon: const Icon(Icons.add_rounded), label: Text('Nouveau code'.tr)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return EmptyState(errorMessage(snap.error!), icon: Icons.error_outline);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final l = snap.data!;
            if (l.isEmpty) return EmptyState('Aucun code.\nCréez un code et envoyez-le à votre client.'.tr, icon: Icons.vpn_key_outlined);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final c in l)
                Card(
                  child: ListTile(
                    leading: Icon(c['atelier'] == null ? Icons.vpn_key_rounded : Icons.check_circle_rounded, color: c['atelier'] == null ? AppColors.gold : AppColors.green),
                    title: SelectableText(c['code'] as String, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                    subtitle: Text([
                      _abonnementNom(c['abonnement'] as String),
                      '{0} mois'.trf([c['duree_mois']]),
                      if (c['note'] != null) c['note'] as String,
                      c['atelier'] == null ? 'Non utilisé'.tr : 'Utilisé par {0}'.trf([c['atelier']]),
                    ].join(' · ')),
                    trailing: c['atelier'] != null
                        ? null
                        : Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                              tooltip: 'Copier'.tr,
                              icon: const Icon(Icons.copy_rounded),
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: c['code'] as String));
                                if (context.mounted) showSnack(context, 'Copié'.tr);
                              },
                            ),
                            IconButton(
                              tooltip: 'Supprimer'.tr,
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () async {
                                await _db.rpc('proprio_supprimer_code', params: {'p_code': c['code']});
                                setState(() => _f = _charger());
                              },
                            ),
                          ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
