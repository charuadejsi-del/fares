import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
import '../i18n.dart';
import '../theme.dart';
import '../utils.dart';

/// Premier lancement d'un nouveau client : création de son atelier avec un code d'activation Warchati.
class ActivationScreen extends StatefulWidget {
  final VoidCallback onActive;
  const ActivationScreen({super.key, required this.onActive});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _form = GlobalKey<FormState>();
  final _nom = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nom]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await session.creerAtelier(_nom.text.trim());
      widget.onActive();
    } catch (e) {
      if (mounted) showSnack(context, errorMessage(e), error: true);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(gradient: AppColors.goldGradient, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.storefront_rounded, size: 36, color: AppColors.ink),
                  ),
                  const SizedBox(height: 16),
                  Text('Créer votre atelier'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('Votre atelier sera créé, vide et privé, avec une période d\'essai gratuite : vous seul et vos employés y aurez accès.'.tr,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nom,
                    decoration: InputDecoration(labelText: 'Nom de votre atelier'.tr, prefixIcon: const Icon(Icons.store_rounded)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire'.tr : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : _valider,
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                    label: Text('Créer'.tr),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      session.clear();
                      await Supabase.instance.client.auth.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: Text('Se déconnecter'.tr),
                  ),
                ]),
              ),
            ),
          ),
        ),
      );
}
