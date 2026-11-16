import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';
import 'dashboard_screen.dart';
import 'production_screen.dart';
import 'quick_entry_screen.dart';
import 'refs_screens.dart';
import 'stock/clients_screen.dart';
import 'stock/commandes_screen.dart';
import 'stock/ventes_screen.dart';
import 'travaux_screens.dart';
import '../i18n.dart';

/// Espace avec onglets en haut. Le bouton « retour » revient à l'onglet précédent.
class _Onglets extends StatefulWidget {
  final List<(String, IconData, Widget)> onglets;
  const _Onglets(this.onglets);

  @override
  State<_Onglets> createState() => _OngletsState();
}

class _OngletsState extends State<_Onglets> with SingleTickerProviderStateMixin {
  late final _ctrl = TabController(length: widget.onglets.length, vsync: this);
  final _historique = <int>[];
  int _precedent = 0;
  bool _enRetour = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_change);
    Retours.inscrire(_peut, _revenir);
  }

  @override
  void dispose() {
    Retours.desinscrire(_peut, _revenir);
    _ctrl.removeListener(_change);
    _ctrl.dispose();
    super.dispose();
  }

  void _change() {
    if (_ctrl.indexIsChanging || _ctrl.index == _precedent) return;
    if (!_enRetour) _historique.add(_precedent);
    _enRetour = false;
    _precedent = _ctrl.index;
    Retours.signaler();
  }

  bool _peut() => mounted && PageActive.of(context) && _historique.isNotEmpty;

  bool _revenir() {
    if (!_peut()) return false;
    _enRetour = true;
    _ctrl.animateTo(_historique.removeLast());
    return true;
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: TabBar(
            controller: _ctrl,
            isScrollable: MediaQuery.sizeOf(context).width < 760,
            tabAlignment: MediaQuery.sizeOf(context).width < 760 ? TabAlignment.start : TabAlignment.fill,
            dividerColor: context.pal.line,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800),
            tabs: [for (final o in widget.onglets) Tab(icon: Icon(o.$2, size: 20), text: o.$1, height: 56)],
          ),
        ),
        Expanded(child: TabBarView(controller: _ctrl, children: [for (final o in widget.onglets) o.$3])),
      ]);
}

class BroderieModule extends StatelessWidget {
  final VoidCallback? onGoToOuvriers;
  const BroderieModule({super.key, this.onGoToOuvriers});

  @override
  Widget build(BuildContext context) => _Onglets([
        ('Saisie'.tr, Icons.add_circle_outline_rounded, QuickEntryScreen(onGoToRefs: onGoToOuvriers)),
        ('Historique'.tr, Icons.history_rounded, const ProductionScreen()),
        ('Statistiques'.tr, Icons.insights_rounded, const DashboardScreen()),
        ('Dessins'.tr, Icons.local_florist_outlined, const DessinsScreen()),
      ]);
}

/// Espace Ouvriers : équipe, saisie du travail (pièce / mois / extra), historique, tâches & tarifs.
class OuvriersModule extends StatelessWidget {
  const OuvriersModule({super.key});

  @override
  Widget build(BuildContext context) => _Onglets([
        ('Équipe'.tr, Icons.groups_rounded, const OuvriersScreen()),
        ('Saisie du travail'.tr, Icons.add_task_rounded, const TravauxSaisieScreen()),
        ('Historique'.tr, Icons.history_rounded, const TravauxHistoriqueScreen()),
        ('Tâches & tarifs'.tr, Icons.content_cut_rounded, const TachesScreen()),
      ]);
}

/// Espace Ventes : ventes, commandes/devis, clients.
class VentesModule extends StatelessWidget {
  const VentesModule({super.key});

  @override
  Widget build(BuildContext context) => _Onglets([
        ('Ventes'.tr, Icons.receipt_long_outlined, VentesScreen()),
        ('Commandes & devis'.tr, Icons.assignment_outlined, CommandesScreen()),
        ('Clients'.tr, Icons.storefront_outlined, ClientsScreen()),
      ]);
}
