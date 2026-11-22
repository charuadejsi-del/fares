import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
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

/// Application du propriétaire de Warchati : séparée de tout atelier.
class ProprietaireShell extends StatelessWidget {
  const ProprietaireShell({super.key});

  Future<void> _motDePasse(BuildContext context) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Changer mon mot de passe'.tr),
        content: TextField(controller: c, obscureText: true, decoration: InputDecoration(labelText: 'Nouveau mot de passe (6 caractères minimum)'.tr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
        ],
      ),
    );
    if (ok != true || c.text.length < 6) return;
    try {
      await _db.auth.updateUser(UserAttributes(password: c.text));
      if (context.mounted) showSnack(context, 'Mot de passe modifié'.tr);
    } catch (e) {
      if (context.mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ورشتي · Warchati'),
          actions: [
            IconButton(
              tooltip: langue.ar ? 'Français' : 'العربية',
              icon: const Icon(Icons.translate_rounded),
              onPressed: () => langue.set(langue.ar ? 'fr' : 'ar'),
            ),
            IconButton(tooltip: 'Changer mon mot de passe'.tr, icon: const Icon(Icons.password_rounded), onPressed: () => _motDePasse(context)),
            IconButton(
              tooltip: 'Se déconnecter'.tr,
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                session.clear();
                await _db.auth.signOut();
              },
            ),
          ],
        ),
        body: const PlateformeScreen(),
      );
}

/// Espace du propriétaire de Warchati : ateliers clients, abonnements, codes d'activation.
/// Aucune donnée interne des clients n'est visible ici.
class PlateformeScreen extends StatelessWidget {
  const PlateformeScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [
              Tab(icon: const Icon(Icons.storefront_rounded), text: 'Ateliers clients'.tr),
              Tab(icon: const Icon(Icons.receipt_long_rounded), text: 'Paiements'.tr),
              Tab(icon: const Icon(Icons.workspace_premium_rounded), text: 'Packs'.tr),
              Tab(icon: const Icon(Icons.settings_rounded), text: 'Réglages'.tr),
            ]),
          ),
          const Expanded(child: TabBarView(children: [_Ateliers(), _Demandes(), _Packs(), _Reglages()])),
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
              if (a['vitrine'] == true) 'Vitrine'.tr,
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
                final c = TextEditingController(text: a['max_employes'] == null ? '' : '${a['max_employes']}');
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Employés maximum'.tr),
                    content: TextField(
                      controller: c,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(helperText: 'Vide = illimité'.tr),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
                    ],
                  ),
                );
                if (ok != true) return;
                await _action(() => _db.rpc('proprio_max_employes', params: {'p_atelier': id, 'p_max': parseInt(c.text)}), 'Enregistré'.tr);
              },
              icon: const Icon(Icons.groups_rounded),
              label: Text(a['max_employes'] == null ? 'Employés : illimité'.tr : 'Employés : {0} max'.trf([a['max_employes']])),
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

// ====================================================================== demandes de paiement

class _Demandes extends StatefulWidget {
  const _Demandes();

  @override
  State<_Demandes> createState() => _DemandesState();
}

class _DemandesState extends State<_Demandes> {
  late Future<List<Map<String, dynamic>>> _f = _charger();

  Future<List<Map<String, dynamic>>> _charger() async => List<Map<String, dynamic>>.from(await _db.rpc('proprio_demandes') as List);

  Future<void> _voirPreuve(String path) async {
    try {
      final bytes = await _db.storage.from('preuves').download(path);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Fermer'.tr)),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _valider(Map<String, dynamic> d) async {
    final ok = await confirmDialog(context, 'Activer {0} ?'.trf([d['atelier']]), 'Pack {0} : l\'abonnement sera prolongé de {1} mois.'.trf([d['pack'], d['duree_mois']]),
        action: 'Activer'.tr);
    if (!ok) return;
    try {
      final fin = await _db.rpc('proprio_valider_demande', params: {'p_id': d['id']});
      if (mounted) showSnack(context, 'Activé jusqu\'au {0}'.trf([fmtDate(DateTime.parse('$fin'))]));
      setState(() => _f = _charger());
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  Future<void> _refuser(Map<String, dynamic> d) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refuser le paiement'.tr),
        content: TextField(controller: c, decoration: InputDecoration(labelText: 'Motif (visible par le client)'.tr, hintText: 'Reçu illisible…'.tr)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Refuser'.tr)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _db.rpc('proprio_refuser_demande', params: {'p_id': d['id'], 'p_motif': c.text});
      setState(() => _f = _charger());
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
          final attente = l.where((d) => d['statut'] == 'attente').length;
          return RefreshIndicator(
            onRefresh: () async => setState(() => _f = _charger()),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              StatTile(label: 'Paiements à vérifier'.tr, value: '$attente', icon: Icons.hourglass_top_rounded, color: attente > 0 ? AppColors.gold : AppColors.green),
              const SizedBox(height: 12),
              if (l.isEmpty) EmptyState('Aucune demande de paiement.'.tr, icon: Icons.receipt_long_outlined),
              for (final d in l)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${d['atelier']} · ${d['pack']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                        Text(fmtDA((d['montant'] as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.gold)),
                      ]),
                      Text([
                        fmtDate(DateTime.parse(d['created_at'] as String).toLocal()),
                        '{0} mois'.trf([d['duree_mois']]),
                        switch (d['statut']) { 'validee' => 'Validée'.tr, 'refusee' => 'Refusée'.tr, _ => 'En attente'.tr },
                        if (d['motif'] != null) d['motif'] as String,
                      ].join(' · ')),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(onPressed: () => _voirPreuve(d['preuve_path'] as String), icon: const Icon(Icons.image_rounded), label: Text('Voir la preuve'.tr)),
                        if (d['statut'] == 'attente') ...[
                          FilledButton.icon(onPressed: () => _valider(d), icon: const Icon(Icons.check_rounded), label: Text('Activer'.tr)),
                          TextButton.icon(onPressed: () => _refuser(d), icon: const Icon(Icons.close_rounded), label: Text('Refuser'.tr)),
                        ],
                      ]),
                    ]),
                  ),
                ),
            ]),
          );
        },
      );
}

// ====================================================================== packs

class _Packs extends StatefulWidget {
  const _Packs();

  @override
  State<_Packs> createState() => _PacksState();
}

class _PacksState extends State<_Packs> {
  late Future<List<Map<String, dynamic>>> _f = _charger();

  Future<List<Map<String, dynamic>>> _charger() async => List<Map<String, dynamic>>.from(await _db.from('packs').select().order('ordre').order('prix'));

  Future<void> _editer([Map<String, dynamic>? p]) async {
    final nom = TextEditingController(text: p?['nom'] as String? ?? '');
    final duree = TextEditingController(text: '${p?['duree_mois'] ?? 1}');
    final prix = TextEditingController(text: p == null ? '' : (p['prix'] as num).toStringAsFixed(0));
    final max = TextEditingController(text: p?['max_employes'] == null ? '' : '${p!['max_employes']}');
    final desc = TextEditingController(text: p?['description'] as String? ?? '');
    var actif = (p?['actif'] as bool?) ?? true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(p == null ? 'Nouveau pack'.tr : 'Modifier le pack'.tr),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: nom, decoration: InputDecoration(labelText: 'Nom du pack'.tr, hintText: 'Mensuel, Annuel, Pro…'.tr)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: duree, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Durée (mois)'.tr))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: prix, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: InputDecoration(labelText: 'Prix (DA)'.tr))),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: max,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Employés maximum'.tr, helperText: 'Vide = illimité'.tr),
                ),
                const SizedBox(height: 8),
                TextField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: 'Description (facultatif)'.tr)),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: actif, onChanged: (v) => set(() => actif = v), title: Text('Visible par les ateliers'.tr)),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Annuler'.tr)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Enregistrer'.tr)),
          ],
        ),
      ),
    );
    if (ok != true || nom.text.trim().isEmpty || parseInt(prix.text) == null) return;
    try {
      await _db.rpc('proprio_save_pack', params: {
        'p_id': p?['id'],
        'p_nom': nom.text,
        'p_duree': (parseInt(duree.text) ?? 1).clamp(1, 60),
        'p_prix': parseInt(prix.text),
        'p_max': parseInt(max.text),
        'p_description': desc.text,
        'p_actif': actif,
      });
      setState(() => _f = _charger());
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(onPressed: () => _editer(), icon: const Icon(Icons.add_rounded), label: Text('Nouveau pack'.tr)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return EmptyState(errorMessage(snap.error!), icon: Icons.error_outline);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final l = snap.data!;
            if (l.isEmpty) return EmptyState('Aucun pack.\nCréez vos offres : elles apparaîtront chez les ateliers.'.tr, icon: Icons.workspace_premium_outlined);
            return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
              for (final p in l)
                Card(
                  child: ListTile(
                    onTap: () => _editer(p),
                    leading: Icon(Icons.workspace_premium_rounded, color: (p['actif'] as bool) ? AppColors.gold : Colors.grey),
                    title: Text('${p['nom']} · ${fmtDA((p['prix'] as num).toDouble())}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text([
                      '{0} mois'.trf([p['duree_mois']]),
                      p['max_employes'] == null ? 'Employés illimités'.tr : '{0} employé(s) au maximum'.trf([p['max_employes']]),
                      if (!(p['actif'] as bool)) 'Masqué'.tr,
                    ].join(' · ')),
                    trailing: const Icon(Icons.edit_rounded),
                  ),
                ),
            ]);
          },
        ),
      );
}

// ====================================================================== réglages

class _Reglages extends StatefulWidget {
  const _Reglages();

  @override
  State<_Reglages> createState() => _ReglagesState();
}

class _ReglagesState extends State<_Reglages> {
  final _rip = TextEditingController();
  final _tit = TextEditingController();
  final _jours = TextEditingController();
  bool _charge = false;

  @override
  void initState() {
    super.initState();
    _db.from('plateforme_reglages').select().eq('id', 1).maybeSingle().then((r) {
      if (!mounted) return;
      setState(() {
        _rip.text = (r?['rip'] ?? '') as String;
        _tit.text = (r?['titulaire'] ?? '') as String;
        _jours.text = '${r?['jours_essai'] ?? 7}';
        _charge = true;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_rip, _tit, _jours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _enregistrer() async {
    try {
      await _db.rpc('proprio_reglages', params: {'p_rip': _rip.text, 'p_titulaire': _tit.text, 'p_jours': (parseInt(_jours.text) ?? 7).clamp(0, 90)});
      if (mounted) showSnack(context, 'Enregistré'.tr);
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => !_charge
      ? const Center(child: CircularProgressIndicator())
      : ListView(padding: const EdgeInsets.all(16), children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SectionTitle('Paiement BaridiMob'.tr, subtitle: 'Affiché aux ateliers quand ils choisissent un pack'.tr),
              TextField(controller: _rip, decoration: InputDecoration(labelText: 'RIP'.tr, prefixIcon: const Icon(Icons.account_balance_rounded))),
              const SizedBox(height: 10),
              TextField(controller: _tit, decoration: InputDecoration(labelText: 'Nom du titulaire'.tr, prefixIcon: const Icon(Icons.person_rounded))),
              const SizedBox(height: 18),
              SectionTitle('Essai gratuit'.tr, subtitle: 'Pour chaque nouvel atelier inscrit'.tr),
              TextField(
                controller: _jours,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: 'Jours d\'essai'.tr, prefixIcon: const Icon(Icons.timer_rounded)),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _enregistrer, icon: const Icon(Icons.save_rounded), label: Text('Enregistrer'.tr)),
            ]),
          ),
        ]);
}
