import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_data.dart';
import '../utils.dart';
import 'dashboard_screen.dart';
import 'production_screen.dart';
import 'refs_screens.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Dest {
  final String label;
  final IconData icon;
  final IconData selected;
  const _Dest(this.label, this.icon, this.selected);
}

const _dests = [
  _Dest('Tableau de bord', Icons.dashboard_outlined, Icons.dashboard),
  _Dest('Production', Icons.precision_manufacturing_outlined, Icons.precision_manufacturing),
  _Dest('Ouvriers', Icons.people_outline, Icons.people),
  _Dest('Dessins', Icons.draw_outlined, Icons.draw),
  _Dest('Machines', Icons.settings_input_component_outlined, Icons.settings_input_component),
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

  Future<void> _logout() async {
    data.clear();
    await Supabase.instance.client.auth.signOut();
  }

  Widget _page() {
    if (_loading && !data.refsLoaded) return const Center(child: CircularProgressIndicator());
    if (_error != null && !data.refsLoaded) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ]),
      );
    }
    return switch (_index) {
      0 => const DashboardScreen(),
      1 => const ProductionScreen(),
      2 => const OuvriersScreen(),
      3 => const DessinsScreen(),
      _ => const MachinesScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final appBar = AppBar(
      title: Text(_dests[_index].label),
      actions: [
        IconButton(tooltip: 'Actualiser', onPressed: _load, icon: const Icon(Icons.refresh)),
        PopupMenuButton<String>(
          tooltip: 'Compte',
          icon: const Icon(Icons.account_circle_outlined),
          itemBuilder: (_) => [
            PopupMenuItem(enabled: false, child: Text(email)),
            const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout), title: Text('Se déconnecter'))),
          ],
          onSelected: (v) {
            if (v == 'logout') _logout();
          },
        ),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: MediaQuery.sizeOf(context).width >= 1100 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            destinations: [
              for (final d in _dests)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _page()),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: [
          for (final d in _dests) NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selected), label: d.label),
        ],
      ),
    );
  }
}
