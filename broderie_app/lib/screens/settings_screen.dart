import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/app_data.dart';
import '../theme.dart';
import '../widgets.dart';
import 'refs_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SectionTitle('Apparence', subtitle: 'Thème de l\'application'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.instance,
                builder: (context, mode, _) => SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Clair')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Sombre')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Auto')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) => ThemeController.instance.set(s.first),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.precision_manufacturing_outlined),
                title: const Text('Machines'),
                subtitle: Text('${data.machines.length} machine(s)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MachinesScreen())),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Compte'),
                subtitle: Text(email),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: context.cs.error),
                title: Text('Se déconnecter', style: TextStyle(color: context.cs.error)),
                onTap: () async {
                  data.clear();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Atelier Broderie · v2.0', style: TextStyle(color: context.pal.muted, fontSize: 12))),
        ],
      ),
    );
  }
}
