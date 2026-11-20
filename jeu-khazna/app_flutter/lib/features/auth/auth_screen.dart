import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/auth.dart';
import '../../core/services.dart';
import '../../widgets/spy_ui.dart';

/// شاشة الدخول / إنشاء حساب (إجبارية قبل اللعب).
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  bool _signup = false;
  bool _busy = false;
  bool _accept = false;
  bool _hide = true;
  String? _error;
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _nick = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _nick.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final nick = _nick.text.trim();
    String? err;
    if (!email.contains('@') || !email.contains('.')) err = 'اكتب بريداً صحيحاً';
    if (pass.length < 6) err ??= 'كلمة السر 6 أحرف على الأقل';
    if (_signup && (nick.length < 2 || nick.length > 20)) err ??= 'الاسم الحركي من 2 إلى 20 حرفاً';
    if (_signup && !_accept) err ??= 'وافق على سياسة الخصوصية أولاً';
    if (err != null) {
      setState(() => _error = err);
      ref.read(audioProvider).fx(Sfx.error, HapticKind.medium);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signup) {
        await authService.signUp(email: email, password: pass, nickname: nick);
      } else {
        await authService.signIn(email: email, password: pass);
      }
      ref.read(audioProvider).fx(Sfx.success, HapticKind.light);
      if (mounted) context.go('/home');
    } catch (e) {
      ref.read(audioProvider).fx(Sfx.error, HapticKind.medium);
      if (mounted) setState(() => _error = authErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SpyBackground(
        image: 'assets/images/home_bg.jpg',
        child: SafeArea(
          child: Center(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(22), children: [
              const Center(child: GlitchTitle('الخزنة', size: 50)),
              const SizedBox(height: 4),
              Center(child: MonoLabel(_signup ? 'NEW AGENT // تجنيد' : 'AGENT LOGIN // دخول')),
              const SizedBox(height: 22),
              HudPanel(
                label: _signup ? 'RECRUIT' : 'ACCESS',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_signup) ...[
                    TextField(
                      controller: _nick,
                      maxLength: 20,
                      textInputAction: TextInputAction.next,
                      decoration: fieldDecoration('الاسم الحركي', icon: Icons.badge_outlined),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: fieldDecoration('البريد الإلكتروني', icon: Icons.alternate_email),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pass,
                    obscureText: _hide,
                    textDirection: TextDirection.ltr,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: fieldDecoration('كلمة السر', icon: Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _hide = !_hide),
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: K.muted),
                      ),
                    ),
                  ),
                  if (_signup) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Checkbox(
                        value: _accept,
                        activeColor: K.neon,
                        checkColor: K.bg,
                        onChanged: (v) => setState(() => _accept = v ?? false),
                      ),
                      const Text('أوافق على ', style: TextStyle(fontSize: 13.5)),
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: const Text('سياسة الخصوصية',
                            style: TextStyle(fontSize: 13.5, color: K.neon, decoration: TextDecoration.underline)),
                      ),
                    ]),
                    const Text('🎁 100 دقيقة لعب مجاناً عند التسجيل',
                        style: TextStyle(color: K.amber, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: K.danger, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 16),
                  _busy
                      ? const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: K.neon)))
                      : NeonButton(
                          label: _signup ? 'إنشاء الحساب' : 'دخول',
                          icon: _signup ? Icons.person_add_alt_1 : Icons.login,
                          onTap: _submit,
                        ),
                ]),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _signup = !_signup;
                          _error = null;
                        }),
                child: Text(_signup ? 'عندي حساب ← دخول' : 'جديد؟ أنشئ حساباً',
                    style: const TextStyle(color: K.agent, fontSize: 15.5, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => context.push('/privacy'),
                child: const Text('سياسة الخصوصية', style: TextStyle(color: K.muted, fontSize: 13)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
