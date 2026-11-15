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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.violetDeep, t.scaffoldBackgroundColor, t.scaffoldBackgroundColor],
            stops: const [0, 0.55, 1],
          ),
        ),
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24)],
                        ),
                        child: const Icon(Icons.diamond_rounded, size: 40, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Atelier Broderie', textAlign: TextAlign.center, style: t.textTheme.headlineSmall),
                    Text(_signup ? 'Créer le compte administrateur de l\'atelier' : 'Connexion',
                        textAlign: TextAlign.center, style: t.textTheme.bodyMedium),
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
            ),
          ),
        ),
      ),
      ),
    );
  }
}
