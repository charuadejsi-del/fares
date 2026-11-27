import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../core/labels.dart';
import '../services/api.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  bool _signup = false;
  bool _busy = false;
  String? _error;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _commune = TextEditingController();
  final _address = TextEditingController();
  String? _wilaya;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signup) {
        final loggedIn = await Api.signUp(
          email: _email.text.trim(),
          password: _password.text,
          profile: {
            'full_name': _name.text.trim(),
            'phone': _phone.text.trim(),
            'wilaya': _wilaya,
            'commune': _commune.text.trim(),
            'address': _address.text.trim(),
          },
        );
        if (!loggedIn && mounted) {
          setState(() => _signup = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text(
                  'تم إنشاء الحساب. أكّد بريدك الإلكتروني ثم سجّل الدخول.')));
        }
      } else {
        await Api.signIn(_email.text.trim(), _password.text);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'مطلوب' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.print_rounded,
                      size: 64, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 8),
                  Text(appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text(_signup ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (_signup) ...[
                    TextFormField(
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'الاسم الكامل'),
                        validator: _required),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration:
                            const InputDecoration(labelText: 'رقم الهاتف'),
                        validator: (v) {
                          final t = (v ?? '').replaceAll(' ', '');
                          return RegExp(r'^0[5-7]\d{8}$').hasMatch(t)
                              ? null
                              : 'رقم غير صحيح (مثال: 0555123456)';
                        }),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _wilaya,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الولاية'),
                      items: [
                        for (final (c, n) in wilayas)
                          DropdownMenuItem(value: n, child: Text('$c - $n')),
                      ],
                      onChanged: (v) => setState(() => _wilaya = v),
                      validator: (v) => v == null ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _commune,
                        decoration: const InputDecoration(labelText: 'البلدية'),
                        validator: _required),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                        validator: _required),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textDirection: TextDirection.ltr,
                      decoration:
                          const InputDecoration(labelText: 'البريد الإلكتروني'),
                      validator: (v) =>
                          (v ?? '').contains('@') ? null : 'بريد غير صحيح'),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _password,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      decoration:
                          const InputDecoration(labelText: 'كلمة السر'),
                      validator: (v) => (v ?? '').length < 6
                          ? '6 أحرف على الأقل'
                          : null),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_signup ? 'إنشاء الحساب' : 'دخول'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signup = !_signup;
                              _error = null;
                            }),
                    child: Text(_signup
                        ? 'عندي حساب — تسجيل الدخول'
                        : 'ليس عندي حساب — إنشاء حساب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
