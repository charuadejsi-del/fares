import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
import '../theme.dart';
import '../utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = Supabase.instance.client.auth;
    try {
      if (_signup) {
        final res = await auth.signUp(email: _email.text.trim().toLowerCase(), password: _pass.text);
        if (res.session == null && mounted) {
          showSnack(context, 'Compte créé. Confirmez votre adresse via l\'email reçu, puis connectez-vous.');
          setState(() => _signup = false);
        }
      } else {
        await auth.signInWithPassword(email: emailDeConnexion(_email.text), password: _pass.text);
      }
    } catch (e) {
      if (mounted) {
        var msg = errorMessage(e);
        if (msg.contains('Invalid login credentials')) msg = 'Email ou mot de passe incorrect.';
        if (msg.contains('Email not confirmed')) msg = 'Adresse email pas encore confirmée (voir votre boîte mail).';
        showSnack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _marque({bool grand = false}) => Column(crossAxisAlignment: grand ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
        Container(
          padding: EdgeInsets.all(grand ? 18 : 14),
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(grand ? 26 : 20),
            boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.45), blurRadius: 34)],
          ),
          child: Icon(Icons.diamond_rounded, size: grand ? 46 : 36, color: AppColors.ink),
        ),
        SizedBox(height: grand ? 26 : 14),
        Text('Atelier', style: TextStyle(color: Colors.white, fontSize: grand ? 44 : 30, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1)),
        Text('Broderie · Couture · Gros',
            style: TextStyle(color: AppColors.gold, fontSize: grand ? 15 : 12.5, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
      ]);

  static const _atouts = [
    (Icons.blur_on_rounded, 'Production broderie', 'Points, robes et paie des brodeurs'),
    (Icons.groups_rounded, 'Ouvriers & paie', 'Avances, salaires, clôture du mois'),
    (Icons.point_of_sale_rounded, 'Stock & ventes en gros', 'Factures, clients, versements'),
    (Icons.shield_moon_rounded, 'Contrôle total', 'Accès par employé et journal des actions'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final large = MediaQuery.sizeOf(context).width >= 900;
    final carte = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, 18))],
        ),
        padding: const EdgeInsets.all(28),
        child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(_signup ? 'Nouvel atelier' : 'Bienvenue', style: t.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_signup ? 'Créer le compte administrateur de l\'atelier' : 'Connectez-vous pour ouvrir votre atelier',
                        style: t.textTheme.bodyMedium?.copyWith(color: t.extension<AppPalette>()?.muted)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: _signup ? 'Email' : 'Email ou identifiant employé',
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (_signup) return s.contains('@') ? null : 'Email invalide';
                        return s.length < 3 ? 'Identifiant trop court' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? '6 caractères minimum' : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_signup ? 'Créer le compte' : 'Se connecter'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _signup = !_signup),
                      child: Text(_signup ? 'J\'ai déjà un compte' : 'Première utilisation ? Créer un compte'),
                    ),
                  ]),
                ),
      ),
    );
    const fond = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF07090E), Color(0xFF141B2E), Color(0xFF3A2C0C)],
        stops: [0, 0.6, 1],
      ),
    );
    if (large) {
      return Scaffold(
        body: Row(children: [
          Expanded(
            flex: 5,
            child: Container(
              decoration: fond,
              padding: const EdgeInsets.fromLTRB(64, 56, 48, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _marque(grand: true),
                const Spacer(),
                for (final a in _atouts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
                        ),
                        child: Icon(a.$1, color: AppColors.gold, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.$2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(a.$3, style: const TextStyle(color: Color(0xFFB7BDCB), fontSize: 13)),
                      ]),
                    ]),
                  ),
                const Spacer(),
                const Text('© Gestion d\'atelier — application native Windows & Android',
                    style: TextStyle(color: Color(0xFF6B7286), fontSize: 12)),
              ]),
            ),
          ),
          Container(width: 2, decoration: const BoxDecoration(gradient: AppColors.goldGradient)),
          Expanded(
            flex: 4,
            child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(32), child: carte)),
          ),
        ]),
      );
    }
    return Scaffold(
      body: Container(
        decoration: fond,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                _marque(),
                const SizedBox(height: 26),
                carte,
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
