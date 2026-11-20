// نظام التصميم: أجواء غرفة عمليات استخباراتية (أسود، أخضر نيون، كهرماني للتحذير).
import 'package:flutter/material.dart';

import '../core/ext_locks.dart';

class K {
  // الألوان
  static const bg = Color(0xFF030605);
  static const panel = Color(0xF00A110F);
  static const panelSolid = Color(0xFF0A110F);
  static const cell = Color(0xFF07100D);
  static const line = Color(0xFF16352C);
  static const neon = Color(0xFF00FF9C);
  static const neonDim = Color(0xFF00A86A);
  static const amber = Color(0xFFFFB020);
  static const danger = Color(0xFFFF3B4E);
  static const text = Color(0xFFD7F5E9);
  static const muted = Color(0xFF6E8F83);
  static const agent = Color(0xFF00E5FF); // العميل الميداني
  static const analyst = Color(0xFFFFB020); // المحلّل

  // أسطح الواجهة الجديدة (نفس هوية لوحة المدير)
  static const surface = Color(0xFF0D1617);
  static const surface2 = Color(0xFF121D1E);
  static const border = Color(0xFF1B2A2B);
  static const borderStrong = Color(0xFF26393A);
  static const text2 = Color(0xFFA4B8B3);
  static const violet = Color(0xFF9D8CFF);
  static const ink = Color(0xFF00170D);

  // الخطوط
  static const font = 'Tajawal';
  static const mono = 'Mono';

  static Color role(String? r) => r == 'ex' ? analyst : agent;
  static String roleName(String? r) => r == 'ex' ? 'المحلّل' : 'العميل';
  static String roleTitle(String? r) => r == 'ex' ? 'المحلّل في القاعدة' : 'العميل الميداني';
  static String roleDesc(String? r) => r == 'ex'
      ? 'في القاعدة مع الملفّات السرّية: تعرف الحلول، لكنك لا ترى الأقفال'
      : 'داخل الهدف أمام الأقفال: ترى كل شيء، لكن بلا دليل';
  static IconData roleIcon(String? r) => r == 'ex' ? Icons.terminal : Icons.person_pin_circle;

  static const roomNames = {
    'keypad': 'لوحة الدخول',
    'wires': 'صندوق الإنذار',
    'cipher': 'الرسالة المعترَضة',
    'maze': 'أنفاق التهوية',
    'lights': 'جهاز الإشارات',
    'dial': 'قرص الخزنة',
    'radio': 'تردّد الراديو',
  };
  static const roomIcons = {
    'keypad': Icons.dialpad,
    'wires': Icons.cable,
    'cipher': Icons.mark_email_unread_outlined,
    'maze': Icons.grid_4x4,
    'lights': Icons.wb_incandescent_outlined,
    'dial': Icons.settings_backup_restore,
    'radio': Icons.cell_tower,
  };

  /// اسم أي قفل (الكلاسيكية والموسّعة).
  static String room(String id) => roomNames[id] ?? kExtInfo[id]?.title ?? id;

  /// رمز تعبيري للأقفال الموسّعة (null للكلاسيكية التي لها أيقونة).
  static String? roomEmoji(String id) => kExtInfo[id]?.icon;

  static List<BoxShadow> glow(Color c, [double r = 18, int a = 110]) =>
      [BoxShadow(color: c.withAlpha(a), blurRadius: r)];

  static const TextStyle monoStyle = TextStyle(fontFamily: mono, color: neon, letterSpacing: 1.5);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: K.font,
    colorScheme: const ColorScheme.dark(
      primary: K.neon,
      onPrimary: Color(0xFF00170D),
      secondary: K.amber,
      surface: K.panelSolid,
      onSurface: K.text,
      error: K.danger,
    ),
    scaffoldBackgroundColor: K.bg,
  );
}

InputDecoration fieldDecoration(String hint, {IconData? icon}) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: K.muted),
      prefixIcon: icon == null ? null : Icon(icon, color: K.neonDim),
      filled: true,
      fillColor: K.cell,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: K.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: K.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: K.neon, width: 1.5)),
    );
