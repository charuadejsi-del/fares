import 'package:flutter/material.dart';

import '../theme.dart';
import 'dashboard_screen.dart';
import 'production_screen.dart';
import 'quick_entry_screen.dart';
import 'refs_screens.dart';
import 'stock/clients_screen.dart';
import 'stock/commandes_screen.dart';
import 'stock/ventes_screen.dart';
import 'travaux_screens.dart';

/// Espace avec onglets en haut.
class _Onglets extends StatelessWidget {
  final List<(String, IconData, Widget)> onglets;
  const _Onglets(this.onglets);

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: onglets.length,
        child: Column(children: [
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TabBar(
              isScrollable: MediaQuery.sizeOf(context).width < 760,
              tabAlignment: MediaQuery.sizeOf(context).width < 760 ? TabAlignment.start : TabAlignment.fill,
              dividerColor: context.pal.line,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: [for (final o in onglets) Tab(icon: Icon(o.$2, size: 20), text: o.$1, height: 56)],
            ),
          ),
          Expanded(child: TabBarView(children: [for (final o in onglets) o.$3])),
        ]),
      );
}

/// Espace Broderie : saisie des points, historique, statistiques, dessins.
class BroderieModule extends StatelessWidget {
  final VoidCallback? onGoToOuvriers;
  const BroderieModule({super.key, this.onGoToOuvriers});

  @override
  Widget build(BuildContext context) => _Onglets([
        ('Saisie', Icons.add_circle_outline_rounded, QuickEntryScreen(onGoToRefs: onGoToOuvriers)),
        ('Historique', Icons.history_rounded, const ProductionScreen()),
        ('Statistiques', Icons.insights_rounded, const DashboardScreen()),
        ('Dessins', Icons.local_florist_outlined, const DessinsScreen()),
      ]);
}

/// Espace Ouvriers : équipe, saisie du travail (pièce / mois / extra), historique, tâches & tarifs.
class OuvriersModule extends StatelessWidget {
  const OuvriersModule({super.key});

  @override
  Widget build(BuildContext context) => _Onglets([
        ('Équipe', Icons.groups_rounded, const OuvriersScreen()),
        ('Saisie du travail', Icons.add_task_rounded, const TravauxSaisieScreen()),
        ('Historique', Icons.history_rounded, const TravauxHistoriqueScreen()),
        ('Tâches & tarifs', Icons.content_cut_rounded, const TachesScreen()),
      ]);
}

/// Espace Ventes : ventes, commandes/devis, clients.
class VentesModule extends StatelessWidget {
  const VentesModule({super.key});

  @override
  Widget build(BuildContext context) => const _Onglets([
        ('Ventes', Icons.receipt_long_outlined, VentesScreen()),
        ('Commandes & devis', Icons.assignment_outlined, CommandesScreen()),
        ('Clients', Icons.storefront_outlined, ClientsScreen()),
      ]);
}
