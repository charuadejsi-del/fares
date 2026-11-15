import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/commerce.dart';
import '../data/session.dart';
import '../data/stock.dart';
import '../theme.dart';
import '../utils.dart';
import 'admin_screens.dart';
import 'modules.dart';
import 'refs_screens.dart';
import 'settings_screen.dart';
import 'stock/achats_screen.dart' show AchatsModule;
import 'stock/produits_screen.dart' show ProduitsScreen;

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

enum _Cle { accueil, broderie, paie, stock, ventes, achats }

class _Dest {
  final _Cle cle;
  final String label;
  final String title;
  final IconData icon;
  final IconData selected;
  const _Dest(this.cle, this.label, this.title, this.icon, this.selected);
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _loading = true;
  String? _error;

  List<_Dest> get _dests => [
        if (session.admin) const _Dest(_Cle.accueil, 'Accueil', 'Vue d\'ensemble', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
        if (session.peut(Espace.broderie))
          const _Dest(_Cle.broderie, 'Broderie', 'Broderie', Icons.blur_on_outlined, Icons.blur_on_rounded),
        if (session.peut(Espace.paie))
          const _Dest(_Cle.paie, 'Ouvriers', 'Ouvriers · salaires & avances', Icons.groups_outlined, Icons.groups_rounded),
        if (session.peut(Espace.stock))
          const _Dest(_Cle.stock, 'Robes', 'Stock des robes terminées', Icons.checkroom_outlined, Icons.checkroom_rounded),
        if (session.peut(Espace.stock))
          const _Dest(_Cle.ventes, 'Ventes', 'Ventes · commandes · clients', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded),
        if (session.peut(Espace.stock))
          const _Dest(_Cle.achats, 'Achats', 'Achats · matières · fournisseurs', Icons.shopping_basket_outlined, Icons.shopping_basket_rounded),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Future.wait<void>([
        if (session.peut(Espace.broderie) || session.peut(Espace.paie)) data.loadRefs(),
        if (session.peut(Espace.stock)) stock.load(),
        if (session.peut(Espace.stock)) commerce.load().catchError((_) {}),
      ]);
    } catch (e) {
      _error = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
    _rafraichirAlertes();
  }

  List<Alerte> _alertes = [];

  Future<void> _rafraichirAlertes() async {
    try {
      final a = await calculerAlertes();
      if (mounted) setState(() => _alertes = a);
    } catch (_) {}
  }

  void _aller(_Cle c) {
    final i = _dests.indexWhere((d) => d.cle == c);
    if (i >= 0) setState(() => _index = i);
  }

  Widget _page(_Dest d) {
    if (_loading && !data.refsLoaded && !stock.loaded) return const Center(child: CircularProgressIndicator());
    if (_error != null && !data.refsLoaded && !stock.loaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
          ]),
        ),
      );
    }
    return switch (d.cle) {
      _Cle.accueil => VueEnsembleScreen(
          onAller: (i) => _aller(switch (i) {
            1 => _Cle.broderie,
            2 => _Cle.paie,
            _ => _Cle.ventes,
          }),
        ),
      _Cle.broderie => BroderieModule(onGoToOuvriers: session.peut(Espace.paie) ? () => _aller(_Cle.paie) : null),
      _Cle.paie => const OuvriersScreen(),
      _Cle.stock => const ProduitsScreen(),
      _Cle.ventes => const VentesModule(),
      _Cle.achats => const AchatsModule(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final dests = _dests;
    if (dests.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Atelier'), actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ]),
        body: const Center(child: Text('Aucun accès n\'est attribué à ce compte.\nDemandez à l\'administrateur.', textAlign: TextAlign.center)),
      );
    }
    if (_index >= dests.length) _index = 0;
    final d = dests[_index];
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 840;
    final appBar = AppBar(
      title: Row(children: [
        if (!wide) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.diamond_rounded, color: AppColors.ink, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(d.title, overflow: TextOverflow.ellipsis)),
      ]),
      actions: [
        IconButton(
          tooltip: 'Alertes',
          onPressed: () async {
            await _rafraichirAlertes();
            if (!context.mounted) return;
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AlertesScreen(alertes: _alertes)));
          },
          icon: Badge(
            isLabelVisible: _alertes.isNotEmpty,
            label: Text('${_alertes.length}'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
        IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        IconButton(
          tooltip: 'Réglages',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 6),
      ],
    );

    if (dests.length == 1) return Scaffold(appBar: appBar, body: _page(d));

    if (wide) {
      final extended = w >= 1150;
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 230,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 14)],
                  ),
                  child: const Icon(Icons.diamond_rounded, color: AppColors.ink),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session.atelier?.nom ?? 'Atelier',
                          overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white, letterSpacing: 0.3)),
                      Text(session.membre?.nom ?? '', overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              ]),
            ),
            destinations: [
              for (final x in dests) NavigationRailDestination(icon: Icon(x.icon), selectedIcon: Icon(x.selected), label: Text(x.label)),
            ],
          ),
          Container(width: 1.5, color: AppColors.gold.withValues(alpha: 0.35)),
          Expanded(child: Scaffold(appBar: appBar, body: _page(d))),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: _page(d),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final x in dests) NavigationDestination(icon: Icon(x.icon), selectedIcon: Icon(x.selected), label: x.label)],
      ),
    );
  }
}
