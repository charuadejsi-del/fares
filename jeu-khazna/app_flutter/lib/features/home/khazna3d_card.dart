// بطاقة «الخزنة 3D»: تفتح نسخة الـ 3D المثبّتة (مع كود الغرفة إن وُجد)، أو تحمّلها إن لم تكن مثبّتة.
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../widgets/spy_ui.dart';
import '../../widgets/ui_kit.dart';

const _download = 'https://github.com/charuadejsi-del/fares/releases/download/khazna3d-latest/khazna3d.apk';

class Khazna3dCard extends StatelessWidget {
  const Khazna3dCard({super.key});

  Future<void> _open(BuildContext context, {String? code}) async {
    final uri = Uri.parse(code == null ? 'khazna3d://open' : 'khazna3d://join?code=$code');
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (ok || !context.mounted) return;
    // غير مثبّتة: نعرض التحميل
    final go = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: HudPanel(
          label: '3D // غير مثبّتة',
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text(
              'نسخة «الخزنة 3D» غير مثبّتة على هاتفك بعد.\nحمّلها مرّة واحدة (حوالي 140MB)، ثبّتها، ثم عُد واضغط الزر من جديد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: K.text2, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 14),
            NeonButton(label: 'تحميل الخزنة 3D', icon: Icons.download, onTap: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      ),
    );
    if (go == true) {
      await launchUrl(Uri.parse(_download), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _join(BuildContext context) async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: HudPanel(
          label: '3D // رمز الغرفة',
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: ctl,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontFamily: K.mono, fontSize: 34, color: K.text, letterSpacing: 12),
              decoration: fieldDecoration('0000'),
            ),
            const SizedBox(height: 14),
            NeonButton(label: 'دخول', icon: Icons.login, onTap: () => Navigator.of(ctx).pop(ctl.text.trim())),
          ]),
        ),
      ),
    );
    ctl.dispose();
    if (code == null || !RegExp(r'^\d{4}$').hasMatch(code) || !context.mounted) return;
    await _open(context, code: code);
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) return const SizedBox.shrink();
    return GlassCard(
      padding: const EdgeInsets.all(14),
      accent: K.neon,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.view_in_ar, color: K.neon, size: 34),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('الخزنة 3D', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: K.text)),
              SizedBox(height: 2),
              Text('تسلّل حقيقي ثلاثي الأبعاد: حرّاس، ليزر، كاميرات، وخزنة — مع صديقك وصوت مباشر',
                  style: TextStyle(fontSize: 12.5, color: K.text2, height: 1.4)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: NeonButton(label: 'العب 3D', icon: Icons.play_arrow, onTap: () => _open(context))),
          const SizedBox(width: 10),
          Expanded(child: NeonButton(label: 'انضمّ بكود', icon: Icons.dialpad, onTap: () => _join(context))),
        ]),
      ]),
    );
  }
}
