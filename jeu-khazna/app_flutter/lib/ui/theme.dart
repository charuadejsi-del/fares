import 'package:flutter/material.dart';

class K {
  static const bg = Color(0xFF0F1115);
  static const card = Color(0xFF181B22);
  static const cell = Color(0xFF10131A);
  static const line = Color(0xFF2A2F3A);
  static const text = Color(0xFFEEF0F4);
  static const muted = Color(0xFF8B93A3);
  static const gold = Color(0xFFF2B84B);
  static const good = Color(0xFF3ECF8E);
  static const bad = Color(0xFFFF5D5D);
  static const op = Color(0xFF4AA3FF);
  static const ex = Color(0xFFC48BFF);

  static Color role(String? r) => r == 'ex' ? ex : op;
  static String roleName(String? r) => r == 'ex' ? 'الخبير' : 'المشغّل';
  static String roleDesc(String? r) =>
      r == 'ex' ? 'معك الدليل: تعرف الحلول، لكن لا ترى الأقفال' : 'أمام الخزنة: ترى الأقفال، لكن بلا دليل';
}

ThemeData buildTheme() {
  // ألوان عامّة فقط (بلا أنماط مكوّنات)، لتجنّب اختلاف واجهات الثيم بين إصدارات Flutter.
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: K.gold,
      onPrimary: Color(0xFF1A1406),
      secondary: K.gold,
      surface: K.card,
      onSurface: K.text,
      error: K.bad,
    ),
    scaffoldBackgroundColor: K.bg,
  );
}

/// زرّ رئيسي ذهبي كبير.
ButtonStyle bigButton([Color bg = K.gold, Color fg = const Color(0xFF1A1406)]) => FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      minimumSize: const Size(double.infinity, 54),
      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

ButtonStyle outlineButton() => OutlinedButton.styleFrom(
      foregroundColor: K.text,
      minimumSize: const Size(double.infinity, 50),
      side: const BorderSide(color: K.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

InputDecoration fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: K.cell,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: K.gold, width: 2)),
    );

/// بطاقة داكنة بحدود.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? border;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.border});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: K.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border ?? K.line),
        ),
        child: child,
      );
}

/// شارة الدور.
class RoleChip extends StatelessWidget {
  final String? role;
  const RoleChip(this.role, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: K.role(role).withAlpha(50), borderRadius: BorderRadius.circular(99)),
        child: Text(K.roleName(role),
            style: TextStyle(color: K.role(role), fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
