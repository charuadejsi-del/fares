import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/couture.dart';
import '../data/models.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets.dart';
import 'coupe_screen.dart';
import 'ouvrier_detail_screen.dart';
import 'refs_screens.dart' show OuvrierForm;
import 'travaux_screens.dart' show TravauxSaisieScreen;

/// Onglets simples pour un atelier.
class OngletsAtelier extends StatelessWidget {
  final List<(String, IconData, Widget)> onglets;
  const OngletsAtelier(this.onglets, {super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: onglets.length,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final o in onglets) Tab(icon: Icon(o.$2), text: o.$1)]),
          ),
          Expanded(child: TabBarView(children: [for (final o in onglets) o.$3])),
        ]),
      );
}

/// Espace d'un atelier interne (appliqué / akkach, finition) : paquets reçus, saisie du travail, équipe.
class AtelierInterneModule extends StatelessWidget {
  final List<String> etapes;
  const AtelierInterneModule({super.key, required this.etapes});

  List<String> get _deps => {for (final e in etapes) ...?departementsEtape[e]}.toList();

  @override
  Widget build(BuildContext context) => OngletsAtelier([
        ('Paquets'.tr, Icons.inventory_2_rounded, PaquetsAtelier(etapes: etapes)),
        ('Saisie du travail'.tr, Icons.add_task_rounded, TravauxSaisieScreen(departements: _deps, etapes: etapes)),
        ('Équipe'.tr, Icons.groups_rounded, EquipeAtelier(departements: _deps)),
        if (etapes.contains('finition')) ('Entrées au stock'.tr, Icons.inventory_rounded, const EntreesStock()),
      ]);
}

// ====================================================================== paquets de l'atelier

class PaquetsAtelier extends StatelessWidget {
  final List<String> etapes;
  const PaquetsAtelier({super.key, required this.etapes});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([data, couture]),
        builder: (context, _) {
          final liste = data.lots.where((l) => etapes.contains(l.etape)).toList();
          final wide = MediaQuery.sizeOf(context).width >= 1000;
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          return RefreshIndicator(
            onRefresh: data.loadLots,
            child: ListView(padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 16, wide ? 24 : 16, 40), children: [
              AutoGrid(minItemWidth: 170, children: [
                for (final e in etapes)
                  StatTile(
                    label: etapeNom(e),
                    value: '${liste.where((l) => l.etape == e).length}',
                    icon: iconeEtape(e),
                    color: couleurEtape(e),
                    sub: '{0} pièces'.trf([fmtInt(liste.where((l) => l.etape == e).fold<int>(0, (s, l) => s + l.nbPieces))]),
                  ),
              ]),
              const SizedBox(height: 14),
              if (liste.isEmpty)
                EmptyState('Aucun paquet dans cet atelier pour l\'instant.'.tr, icon: Icons.inventory_2_outlined)
              else
                AutoGrid(minItemWidth: 340, children: [
                  for (final l in liste)
                    AppCard(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: l.id))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text('#${l.numero}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 10),
                          Text('{0} pièces'.trf([fmtInt(l.nbPieces)]), style: TextStyle(color: muted, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (etapes.length > 1) PuceEtape(l.etape),
                        ]),
                        if (l.modele != null || l.couleur != null)
                          Text([if (l.modele != null) l.modele!, if (l.couleur != null) l.couleur!].join(' · '), style: TextStyle(color: muted)),
                        const SizedBox(height: 8),
                        FrisesParcours(l),
                        const SizedBox(height: 10),
                        if (l.suivante == 'stock')
                          FilledButton.icon(
                            onPressed: () => entrerStockDialogue(context, l),
                            icon: Icon(iconeEtape('stock')),
                            label: Text('Entrer au stock'.tr),
                          )
                        else if (l.suivante != null)
                          FilledButton.tonalIcon(
                            onPressed: () => deplacerAvecDialogue(context, l, l.suivante!),
                            icon: Icon(iconeEtape(l.suivante!)),
                            label: Text('Envoyer à : {0}'.trf([etapeNom(l.suivante!)])),
                          ),
                      ]),
                    ),
                ]),
            ]),
          );
        },
      );
}

// ====================================================================== équipe de l'atelier

class EquipeAtelier extends StatelessWidget {
  final List<String> departements;
  const EquipeAtelier({super.key, required this.departements});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final liste = data.ouvriers.where((o) => departements.any((d) => d.toLowerCase() == o.departement.toLowerCase())).toList()
            ..sort((a, b) => a.actif == b.actif ? a.nom.compareTo(b.nom) : (a.actif ? -1 : 1));
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'fab-equipe-${departements.first}',
              onPressed: () => showDialog<bool>(context: context, builder: (_) => OuvrierForm(null, departement: departements.first)),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('Ajouter un ouvrier'.tr),
            ),
            body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
              Text('Départements : {0}'.trf([departements.join(' · ')]), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              if (liste.isEmpty)
                EmptyState('Aucun ouvrier dans cet atelier.\nAjoutez-les : payés au mois (travail suivi sans montant) ou à la pièce.'.tr, icon: Icons.groups_outlined)
              else
                AutoGrid(minItemWidth: 300, children: [
                  for (final o in liste)
                    AppCard(
                      onTap: masquerMontants ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => OuvrierDetailScreen(ouvrierId: o.id))),
                      child: Opacity(
                        opacity: o.actif ? 1 : .5,
                        child: Row(children: [
                          NameAvatar(o.nom, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(o.nom, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              Text(
                                [
                                  o.departement,
                                  switch (o.modePaie) {
                                    ModePaie.mois => 'Au mois'.tr,
                                    ModePaie.piece => 'À la pièce'.tr,
                                    ModePaie.points => 'Aux points'.tr,
                                  },
                                  if (!o.actif) 'Inactif'.tr,
                                ].join(' · '),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                              ),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Modifier'.tr,
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => showDialog<bool>(context: context, builder: (_) => OuvrierForm(o)),
                          ),
                        ]),
                      ),
                    ),
                ]),
            ]),
          );
        },
      );
}

// ====================================================================== entrées au stock

class EntreesStock extends StatelessWidget {
  const EntreesStock({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: data,
        builder: (context, _) {
          final liste = data.lots.where((l) => l.etape == 'stock').toList()
            ..sort((a, b) => (b.dateStock ?? b.createdAt).compareTo(a.dateStock ?? a.createdAt));
          final parModele = <String, int>{};
          for (final l in liste) {
            parModele.update(l.modele ?? 'Sans modèle'.tr, (v) => v + (l.piecesStock ?? l.nbPieces), ifAbsent: () => l.piecesStock ?? l.nbPieces);
          }
          final muted = Theme.of(context).colorScheme.onSurfaceVariant;
          return ListView(padding: const EdgeInsets.all(16), children: [
            if (liste.isEmpty) EmptyState('Aucun paquet entré au stock.'.tr, icon: Icons.inventory_outlined),
            if (parModele.isNotEmpty) ...[
              SectionTitle('Total par modèle'.tr),
              const SizedBox(height: 8),
              AutoGrid(minItemWidth: 200, children: [
                for (final e in parModele.entries)
                  StatTile(label: e.key, value: fmtInt(e.value), icon: Icons.checkroom_rounded, color: AppColors.green, sub: 'pièces'.tr),
              ]),
              const SizedBox(height: 16),
              SectionTitle('Paquets entrés'.tr),
              const SizedBox(height: 8),
            ],
            for (final l in liste)
              Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PaquetDetailScreen(lotId: l.id))),
                  leading: Icon(iconeEtape('stock'), color: couleurEtape('stock')),
                  title: Text('#${l.numero}${l.modele == null ? '' : ' · ${l.modele}'}'),
                  subtitle: Text([if (l.dateStock != null) fmtDate(l.dateStock!), if (l.couleur != null) l.couleur!].join(' · '), style: TextStyle(color: muted)),
                  trailing: Text('{0} pièces'.trf([fmtInt(l.piecesStock ?? l.nbPieces)]), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        },
      );
}
