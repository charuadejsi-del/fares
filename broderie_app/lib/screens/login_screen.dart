import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/session.dart';
import '../theme.dart';
import '../utils.dart';
import '../i18n.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _code = TextEditingController();
  bool _signup = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => _code.text = p.getString('code_atelier') ?? '');
  }
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _code.dispose();
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
          showSnack(context, 'Compte créé. Confirmez votre adresse via l\'email reçu, puis connectez-vous.'.tr);
          setState(() => _signup = false);
        }
      } else {
        final saisie = _email.text.trim();
        final code = _code.text.trim().toLowerCase();
        try {
          await auth.signInWithPassword(email: emailDeConnexion(saisie, code), password: _pass.text);
        } on AuthException {
          // anciens comptes employés (sans code d'atelier)
          if (saisie.contains('@') || code.isEmpty) rethrow;
          await auth.signInWithPassword(email: emailDeConnexion(saisie), password: _pass.text);
        }
        if (!saisie.contains('@')) (await SharedPreferences.getInstance()).setString('code_atelier', code);
      }
    } catch (e) {
      if (mounted) {
        var msg = errorMessage(e);
        if (msg.contains('Invalid login credentials')) msg = 'Email ou mot de passe incorrect.'.tr;
        if (msg.contains('Email not confirmed')) msg = 'Adresse email pas encore confirmée (voir votre boîte mail).'.tr;
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
        Text('ورشتي · Warchati', style: TextStyle(color: Colors.white, fontSize: grand ? 40 : 28, fontWeight: FontWeight.w900, height: 1.1)),
        Text('Gestion d\'atelier · Broderie · Couture · Gros'.tr,
            style: TextStyle(color: AppColors.gold, fontSize: grand ? 15 : 12.5, fontWeight: FontWeight.w800, letterSpacing: 2.4)),
      ]);

  static List<(IconData, String, String)> get _atouts => [
    (Icons.blur_on_rounded, 'Production broderie'.tr, 'Points, robes et paie des brodeurs'.tr),
    (Icons.groups_rounded, 'Ouvriers & paie'.tr, 'Avances, salaires, clôture du mois'.tr),
    (Icons.point_of_sale_rounded, 'Stock & ventes en gros'.tr, 'Factures, clients, versements'.tr),
    (Icons.shield_moon_rounded, 'Contrôle total'.tr, 'Accès par employé et journal des actions'.tr),
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
                    Text(_signup ? 'Nouvel atelier'.tr : 'Bienvenue'.tr, style: t.textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(_signup ? 'Créez votre compte, puis activez votre atelier avec le code reçu de Warchati'.tr : 'Connectez-vous pour ouvrir votre atelier'.tr,
                        style: t.textTheme.bodyMedium?.copyWith(color: t.extension<AppPalette>()?.muted)),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: InputDecoration(
                        labelText: _signup ? 'Email'.tr : 'Email ou identifiant employé'.tr,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (_signup) return s.contains('@') ? null : 'Email invalide'.tr;
                        return s.length < 3 ? 'Identifiant trop court'.tr : null;
                      },
                    ),
                    if (!_signup) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        decoration: InputDecoration(
                          labelText: 'Code de l\'atelier (employés)'.tr,
                          helperText: 'Laissez vide si vous vous connectez avec votre email'.tr,
                          prefixIcon: const Icon(Icons.tag_rounded),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: _hide,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Mot de passe'.tr,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _hide = !_hide),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? '6 caractères minimum'.tr : null,
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _busy
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_signup ? 'Créer le compte'.tr : 'Se connecter'.tr),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() => _signup = !_signup),
                      child: Text(_signup ? 'J\'ai déjà un compte'.tr : 'Première utilisation ? Créer un compte'.tr),
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
                Text('© Gestion d\'atelier — application native Windows & Android'.tr,
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
