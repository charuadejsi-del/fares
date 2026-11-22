import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';

SupabaseClient get _db => Supabase.instance.client;

/// Abonnement de l'atelier : état, packs proposés par Warchati, paiement BaridiMob et preuve.
class AbonnementScreen extends StatefulWidget {
  const AbonnementScreen({super.key});

  @override
  State<AbonnementScreen> createState() => _AbonnementScreenState();
}

class _AbonnementScreenState extends State<AbonnementScreen> {
  late Future<(List<Map<String, dynamic>>, Map<String, dynamic>?, List<Map<String, dynamic>>)> _f = _charger();

  Future<(List<Map<String, dynamic>>, Map<String, dynamic>?, List<Map<String, dynamic>>)> _charger() async {
    final r = await Future.wait([
      _db.from('packs').select().eq('actif', true).order('ordre').order('prix'),
      _db.from('plateforme_reglages').select().eq('id', 1).maybeSingle(),
      _db.from('demandes_abonnement').select('*, packs(nom, duree_mois)').order('created_at', ascending: false).limit(20),
    ]);
    await session.load();
    return (
      List<Map<String, dynamic>>.from(r[0] as List),
      r[1] as Map<String, dynamic>?,
      List<Map<String, dynamic>>.from(r[2] as List),
    );
  }

  void _recharger() => setState(() => _f = _charger());

  Future<void> _payer(Map<String, dynamic> pack, Map<String, dynamic>? reglages) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PaiementDialog(pack: pack, reglages: reglages),
    );
    if (ok == true) {
      if (mounted) showSnack(context, 'Preuve envoyée. Votre abonnement sera activé après vérification.'.tr);
      _recharger();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Mon abonnement'.tr)),
        body: FutureBuilder(
          future: _f,
          builder: (context, snap) {
            if (snap.hasError) return EmptyState(errorMessage(snap.error!), icon: Icons.error_outline);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final (packs, reglages, demandes) = snap.data!;
            final a = session.atelier!;
            final muted = Theme.of(context).colorScheme.onSurfaceVariant;
            final enAttente = demandes.any((d) => d['statut'] == 'attente');
            final j = a.joursRestants;
            final couleur = !a.actif ? AppColors.rose : (j != null && j <= 7 ? AppColors.gold : AppColors.green);
            return RefreshIndicator(
              onRefresh: () async => _recharger(),
              child: ListView(padding: const EdgeInsets.all(16), children: [
                AppCard(
                  child: Row(children: [
                    Icon(Icons.workspace_premium_rounded, size: 40, color: couleur),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          a.suspendu
                              ? 'Atelier suspendu'.tr
                              : a.illimite
                                  ? 'Abonnement illimité'.tr
                                  : a.essai
                                      ? 'Période d\'essai gratuite'.tr
                                      : 'Abonnement en cours'.tr,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        if (!a.illimite)
                          Text(
                            j! < 0 ? 'Terminé le {0} : lecture seule'.trf([fmtDate(a.abonnementFin!)]) : 'Jusqu\'au {0} · {1} jour(s) restant(s)'.trf([fmtDate(a.abonnementFin!), j]),
                            style: TextStyle(color: couleur, fontWeight: FontWeight.w700),
                          ),
                        if (a.maxEmployes != null) Text('{0} employé(s) au maximum'.trf([a.maxEmployes]), style: TextStyle(color: muted)),
                      ]),
                    ),
                  ]),
                ),
                if (enAttente) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Row(children: [
                      const Icon(Icons.hourglass_top_rounded, color: AppColors.gold),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Votre preuve de paiement est en cours de vérification.'.tr, style: const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                  ),
                ],
                const SizedBox(height: 18),
                SectionTitle('Choisissez votre pack'.tr),
                const SizedBox(height: 8),
                if (packs.isEmpty)
                  EmptyState('Aucun pack disponible pour le moment.'.tr, icon: Icons.inventory_2_outlined)
                else
                  AutoGrid(minItemWidth: 260, children: [
                    for (final p in packs)
                      AppCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['nom'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(fmtDA((p['prix'] as num).toDouble()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.gold)),
                          Text('{0} mois'.trf([p['duree_mois']]), style: TextStyle(color: muted)),
                          Text(p['max_employes'] == null ? 'Employés illimités'.tr : '{0} employé(s) au maximum'.trf([p['max_employes']]), style: TextStyle(color: muted)),
                          if (p['description'] != null) ...[const SizedBox(height: 6), Text(p['description'] as String)],
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: enAttente ? null : () => _payer(p, reglages),
                            icon: const Icon(Icons.payments_rounded),
                            label: Text('Choisir ce pack'.tr),
                          ),
                        ]),
                      ),
                  ]),
                if (demandes.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionTitle('Mes demandes'.tr),
                  for (final d in demandes)
                    ListTile(
                      leading: Icon(
                        switch (d['statut']) { 'validee' => Icons.check_circle_rounded, 'refusee' => Icons.cancel_rounded, _ => Icons.hourglass_top_rounded },
                        color: switch (d['statut']) { 'validee' => AppColors.green, 'refusee' => AppColors.rose, _ => AppColors.gold },
                      ),
                      title: Text('${(d['packs'] as Map?)?['nom'] ?? ''} · ${fmtDA((d['montant'] as num).toDouble())}'),
                      subtitle: Text([
                        fmtDate(DateTime.parse(d['created_at'] as String).toLocal()),
                        switch (d['statut']) { 'validee' => 'Validée'.tr, 'refusee' => 'Refusée'.tr, _ => 'En attente'.tr },
                        if (d['motif'] != null) d['motif'] as String,
                      ].join(' · ')),
                    ),
                ],
              ]),
            );
          },
        ),
      );
}

class _PaiementDialog extends StatefulWidget {
  final Map<String, dynamic> pack;
  final Map<String, dynamic>? reglages;
  const _PaiementDialog({required this.pack, required this.reglages});

  @override
  State<_PaiementDialog> createState() => _PaiementDialogState();
}

class _PaiementDialogState extends State<_PaiementDialog> {
  Uint8List? _photo;
  String _ext = 'jpg';
  bool _busy = false;

  Future<void> _choisir() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
    if (x == null) return;
    final b = await x.readAsBytes();
    setState(() {
      _photo = b;
      _ext = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
    });
  }

  Future<void> _envoyer() async {
    final a = session.atelier;
    if (_photo == null || a == null) return;
    setState(() => _busy = true);
    try {
      final path = '${a.id}/${DateTime.now().millisecondsSinceEpoch}.$_ext';
      await _db.storage.from('preuves').uploadBinary(path, _photo!, fileOptions: FileOptions(contentType: 'image/${_ext == 'png' ? 'png' : 'jpeg'}'));
      await _db.from('demandes_abonnement').insert({'pack_id': widget.pack['id'], 'montant': widget.pack['prix'], 'preuve_path': path});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rip = widget.reglages?['rip'] as String?;
    final titulaire = widget.reglages?['titulaire'] as String?;
    return AlertDialog(
      title: Text('Payer : {0}'.trf([widget.pack['nom']])),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Montant à payer'.tr),
            Text(fmtDA((widget.pack['prix'] as num).toDouble()), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.gold)),
            const SizedBox(height: 12),
            Text('1. Envoyez le montant avec BaridiMob vers ce RIP :'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .1), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SelectableText(rip ?? 'RIP non encore renseigné'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .5)),
                    if (titulaire != null) Text(titulaire),
                  ]),
                ),
                if (rip != null)
                  IconButton(
                    tooltip: 'Copier'.tr,
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: rip));
                      if (context.mounted) showSnack(context, 'Copié'.tr);
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 14),
            Text('2. Ajoutez la capture du reçu de paiement :'.tr, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (_photo != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_photo!, height: 220, fit: BoxFit.contain)),
            OutlinedButton.icon(onPressed: _choisir, icon: const Icon(Icons.image_rounded), label: Text(_photo == null ? 'Choisir la capture'.tr : 'Changer la capture'.tr)),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Annuler'.tr)),
        FilledButton.icon(
          onPressed: _photo == null || rip == null || _busy ? null : _envoyer,
          icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
          label: Text('Envoyer la preuve'.tr),
        ),
      ],
    );
  }
}
