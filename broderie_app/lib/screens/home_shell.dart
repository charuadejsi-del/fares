import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../theme.dart';
import '../utils.dart';
import 'dashboard_screen.dart';
import 'production_screen.dart';
import 'quick_entry_screen.dart';
import 'refs_screens.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Dest {
  final String label;
  final String title;
  final IconData icon;
  final IconData selected;
  const _Dest(this.label, this.title, this.icon, this.selected);
}

const _dests = [
  _Dest('Accueil', 'Tableau de bord', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded),
  _Dest('Saisie', 'Saisie rapide', Icons.add_circle_outline_rounded, Icons.add_circle_rounded),
  _Dest('Historique', 'Historique', Icons.history_rounded, Icons.history_rounded),
  _Dest('Ouvriers', 'Ouvriers', Icons.people_outline_rounded, Icons.people_rounded),
  _Dest('Dessins', 'Dessins', Icons.local_florist_outlined, Icons.local_florist_rounded),
];

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _loading = true;
  String? _error;

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
      await data.loadRefs();
    } catch (e) {
      _error = errorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _go(int i) => setState(() => _index = i);

  Widget _page() {
    if (_loading && !data.refsLoaded) return const Center(child: CircularProgressIndicator());
    if (_error != null && !data.refsLoaded) {
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
    return switch (_index) {
      0 => const DashboardScreen(),
      1 => QuickEntryScreen(onGoToRefs: () => _go(3)),
      2 => const ProductionScreen(),
      3 => const OuvriersScreen(),
      _ => const DessinsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 840;
    final appBar = AppBar(
      title: Row(children: [
        if (!wide) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Text(_dests[_index].title),
      ]),
      actions: [
        IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        IconButton(
          tooltip: 'Réglages',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        const SizedBox(width: 6),
      ],
    );

    if (wide) {
      final extended = w >= 1150;
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: extended,
            minExtendedWidth: 220,
            selectedIndex: _index,
            onDestinationSelected: _go,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 20),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                ),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Atelier', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                    Text('Broderie', style: TextStyle(color: context.pal.muted, fontSize: 12)),
                  ]),
                ],
              ]),
            ),
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
            ],
          ),
          VerticalDivider(width: 1, color: context.pal.line),
          Expanded(child: Scaffold(appBar: appBar, body: _page())),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          for (final d in _dests) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
        ],
      ),
    );
  }
}
