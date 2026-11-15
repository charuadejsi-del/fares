import 'package:flutter/material.dart';

import '../theme.dart';
import 'dashboard_screen.dart';
import 'production_screen.dart';
import 'quick_entry_screen.dart';
import 'refs_screens.dart';
import 'stock/achats_screen.dart';
import 'stock/clients_screen.dart';
import 'stock/commandes_screen.dart';
import 'stock/produits_screen.dart';
import 'stock/ventes_screen.dart';

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

/// Espace Stock & ventes.
class StockModule extends StatelessWidget {
  const StockModule({super.key});

  @override
  Widget build(BuildContext context) => const _Onglets([
        ('Stock', Icons.inventory_2_outlined, ProduitsScreen()),
        ('Ventes', Icons.receipt_long_outlined, VentesScreen()),
        ('Commandes', Icons.assignment_outlined, CommandesScreen()),
        ('Clients', Icons.storefront_outlined, ClientsScreen()),
        ('Achats', Icons.shopping_basket_outlined, AchatsModule()),
      ]);
}
