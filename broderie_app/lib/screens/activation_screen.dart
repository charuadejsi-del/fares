import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _code = TextEditingController();
  final _activation = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_nom, _code, _activation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _valider() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await session.activer(nom: _nom.text.trim(), code: _code.text.trim().toLowerCase(), activation: _activation.text.trim().toUpperCase());
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
                  Text('Activer votre atelier'.tr, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text('Entrez le code d\'activation reçu de Warchati. Votre atelier sera créé, vide et privé : vous seul et vos employés y aurez accès.'.tr,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nom,
                    decoration: InputDecoration(labelText: 'Nom de votre atelier'.tr, prefixIcon: const Icon(Icons.store_rounded)),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatoire'.tr : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _code,
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')), LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      labelText: 'Code de l\'atelier (pour la connexion des employés)'.tr,
                      helperText: 'Ex. : ghania · 3 à 30 lettres, chiffres ou tirets'.tr,
                      prefixIcon: const Icon(Icons.tag_rounded),
                    ),
                    validator: (v) => RegExp(r'^[a-z0-9-]{3,30}$').hasMatch((v ?? '').trim().toLowerCase()) ? null : 'Code invalide'.tr,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _activation,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: 'Code d\'activation'.tr, hintText: 'WAR-XXXXXX', prefixIcon: const Icon(Icons.vpn_key_rounded)),
                    validator: (v) => (v ?? '').trim().length < 6 ? 'Obligatoire'.tr : null,
                    onFieldSubmitted: (_) => _valider(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _busy ? null : _valider,
                    icon: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
                    label: Text('Activer'.tr),
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
