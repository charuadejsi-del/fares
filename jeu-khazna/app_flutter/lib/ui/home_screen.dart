import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/controller.dart';
import '../core/game.dart';
import '../net/transport.dart';
import 'play_screen.dart';
import 'theme.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _playerName {
    final n = _name.text.trim();
    if (n.isEmpty) return 'لاعب';
    return n.length > 20 ? n.substring(0, 20) : n;
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _playLocal() {
    final c = GameController.local(meName: _playerName);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayScreen(controller: c)));
  }

  Future<void> _playOnline({required bool host}) async {
    if (!onlineAvailable) {
      _toast('اللعب أونلاين غير مفعّل في هذه النسخة (يحتاج إعداد Supabase).');
      return;
    }
    String code = GameController.newRoomCode();
    if (!host) {
      code = _code.text.trim();
      if (!RegExp(r'^\d{4}$').hasMatch(code)) {
        _toast('أدخل رمزاً من 4 أرقام.');
        return;
      }
    }
    setState(() => _busy = true);
    final c = GameController.online(meName: _playerName, code: code, isHost: host);
    try {
      await c.connect();
    } catch (e) {
      c.dispose();
      if (mounted) {
        setState(() => _busy = false);
        _toast('تعذّر الاتصال. تحقّق من الإنترنت وأعد المحاولة.');
      }
      return;
    }
    if (!mounted) {
      c.dispose();
      return;
    }
    setState(() => _busy = false);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlayScreen(controller: c)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const _VaultLogo(),
                  const SizedBox(height: 8),
                  const Text('الخزنة',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900)),
                  const Text('ألغاز جماعية: لا أحد يستطيع حلّها وحده',
                      textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 15)),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _name,
                    maxLength: 20,
                    textInputAction: TextInputAction.done,
                    decoration: fieldDecoration('اسمك (مثلاً: فارس)').copyWith(counterText: ''),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    style: bigButton(),
                    onPressed: _busy ? null : _playLocal,
                    icon: const Icon(Icons.phone_android),
                    label: const Text('العب على هاتف واحد'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: outlineButton(),
                    onPressed: _busy ? null : () => _playOnline(host: true),
                    icon: const Icon(Icons.wifi),
                    label: const Text('إنشاء غرفة أونلاين'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          keyboardType: TextInputType.number,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.center,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: fieldDecoration('رمز الغرفة').copyWith(counterText: ''),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 110,
                        child: OutlinedButton(
                          style: outlineButton(),
                          onPressed: _busy ? null : () => _playOnline(host: false),
                          child: const Text('دخول'),
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                  if (!onlineAvailable) ...[
                    const SizedBox(height: 10),
                    const Text('اللعب أونلاين يُفعَّل بعد إعداد Supabase. وضع الهاتف الواحد يعمل الآن.',
                        textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 22),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TutorialScreen())),
                    icon: const Icon(Icons.school_outlined, color: K.gold),
                    label: const Text('كيف تُلعب؟ (شرح في دقيقة)', style: TextStyle(color: K.gold, fontSize: 16)),
                  ),
                  const SizedBox(height: 6),
                  Text('${kRooms.length} أقفال · ${kDuration ~/ 60} دقائق · كل خطأ −$kPenalty ثانية',
                      textAlign: TextAlign.center, style: const TextStyle(color: K.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VaultLogo extends StatelessWidget {
  const _VaultLogo();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Center(
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: K.card,
            border: Border.all(color: K.gold, width: 3),
            boxShadow: [BoxShadow(color: K.gold.withAlpha(60), blurRadius: 30)],
          ),
          child: const Icon(Icons.lock, size: 48, color: K.gold),
        ),
      ),
    );
  }
}
