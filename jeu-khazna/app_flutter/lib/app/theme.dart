// نظام التصميم V3 «واقعي»: أسود مطفأ، فولاذ، لون مميّز واحد (كهرماني)، أخضر للحالة السليمة فقط.
import 'package:flutter/material.dart';

import '../core/ext_locks.dart';

class K {
  // الألوان
  static const bg = Color(0xFF0A0C0E);
  static const panel = Color(0xF0121518);
  static const panelSolid = Color(0xFF121518);
  static const cell = Color(0xFF0E1012);
  static const line = Color(0xFF22272C);
  static const neon = Color(0xFFE8A13A) /* اللون المميّز الوحيد */;
  static const neonDim = Color(0xFF9A7236);
  static const amber = Color(0xFFE8A13A);
  static const danger = Color(0xFFE5484D);
  static const text = Color(0xFFE6E8EA);
  static const muted = Color(0xFF7D858D);
  static const agent = Color(0xFF8DB4D9); // العميل الميداني
  static const analyst = Color(0xFFE8A13A); // المحلّل

  // أسطح الواجهة الجديدة (نفس هوية لوحة المدير)
  static const surface = Color(0xFF121518);
  static const surface2 = Color(0xFF16191D);
  static const border = Color(0xFF1C2024);
  static const borderStrong = Color(0xFF2C3238);
  static const text2 = Color(0xFFA3AAB1);
  static const violet = Color(0xFFA99BEA);
  static const ink = Color(0xFF120C02)
  static const ok = Color(0xFF6CD995); // الحالة السليمة (متّصل، صحيح)
  static const steel = Color(0xFFC9CED3);
  static const radius = 8.0;;

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

  /// لا توهّج نيون في V3: ظلّ داكن خفيف فقط.
  static List<BoxShadow> glow(Color c, [double r = 18, int a = 110]) =>
      [BoxShadow(color: Colors.black.withAlpha(110), blurRadius: r * .6, offset: const Offset(0, 4))];

  static const TextStyle monoStyle = TextStyle(fontFamily: mono, color: text, letterSpacing: 1.5);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: K.font,
    colorScheme: const ColorScheme.dark(
      primary: K.neon,
      onPrimary: K.ink,
      secondary: K.amber,
      surface: K.panelSolid,
      onSurface: K.text,
      error: K.danger,
    ),
    scaffoldBackgroundColor: K.bg,
    dividerColor: K.border,
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(K.radius), borderSide: const BorderSide(color: K.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(K.radius), borderSide: const BorderSide(color: K.line)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(K.radius), borderSide: const BorderSide(color: K.neon, width: 1.5)),
    );
