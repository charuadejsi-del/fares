import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palette « Maison de couture » : noir profond, or et pierres précieuses.
class AppColors {
  static const violet = Color(0xFF7C6CF6); // améthyste
  static const violetDeep = Color(0xFF1B2440); // encre
  static const gold = Color(0xFFD4AF37);
  static const teal = Color(0xFF19B3A6); // émeraude claire
  static const rose = Color(0xFFE5486B); // rubis
  static const sky = Color(0xFF4FA3F7); // saphir
  static const green = Color(0xFF2EBD7A); // émeraude
  static const ink = Color(0xFF0E1320);

  // Sombre
  static const darkBg = Color(0xFF07090E);
  static const darkSurface = Color(0xFF10141D);
  static const darkSurface2 = Color(0xFF181D29);
  static const darkLine = Color(0xFF242A39);

  // Clair (ivoire)
  static const lightBg = Color(0xFFF6F3EC);
  static const lightSurface = Colors.white;
  static const lightSurface2 = Color(0xFFF1ECE1);
  static const lightLine = Color(0xFFE6DFD0);

  /// Couleurs des séries (graphiques, avatars).
  static const series = [gold, violet, teal, rose, sky, green, Color(0xFFF59E0B), Color(0xFFB794F4)];

  static Color forName(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return series[h % series.length];
  }

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0E1320), Color(0xFF1C2541), Color(0xFF6E5216)],
    stops: [0, 0.55, 1],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9C7A1E), Color(0xFFD4AF37), Color(0xFFF3DC8C)],
  );
}

/// Couleurs annexes accessibles depuis le thème.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color surface2;
  final Color line;
  final Color muted;
  const AppPalette({required this.surface2, required this.line, required this.muted});

  @override
  AppPalette copyWith({Color? surface2, Color? line, Color? muted}) =>
      AppPalette(surface2: surface2 ?? this.surface2, line: line ?? this.line, muted: muted ?? this.muted);

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      surface2: Color.lerp(surface2, other.surface2, t)!,
      line: Color.lerp(line, other.line, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

extension PaletteX on BuildContext {
  AppPalette get pal => Theme.of(this).extension<AppPalette>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? AppColors.darkBg : AppColors.lightBg;
  final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
  final line = dark ? AppColors.darkLine : AppColors.lightLine;
  final cs = ColorScheme.fromSeed(seedColor: AppColors.gold, brightness: b).copyWith(
    primary: dark ? AppColors.gold : AppColors.violetDeep,
    onPrimary: dark ? AppColors.ink : Colors.white,
    secondary: AppColors.gold,
    onSecondary: AppColors.ink,
    surface: surface,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
    outlineVariant: line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: b);
  final radius = BorderRadius.circular(12);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    extensions: [
      AppPalette(
        surface2: dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        line: line,
        muted: dark ? const Color(0xFF8F97AB) : const Color(0xFF6F6858),
      ),
    ],
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: cs.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: cs.primary, width: 1.6)),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        side: BorderSide(color: line),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      side: BorderSide(color: line),
      showCheckmark: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: AppColors.gold,
      labelColor: dark ? AppColors.gold : AppColors.violetDeep,
      unselectedLabelColor: dark ? const Color(0xFF8F97AB) : const Color(0xFF6F6858),
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
      dividerColor: line,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.gold.withValues(alpha: 0.22),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: dark ? const Color(0xFF0A0D14) : AppColors.ink,
      indicatorColor: AppColors.gold.withValues(alpha: 0.22),
      selectedIconTheme: const IconThemeData(color: AppColors.gold),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF8F97AB)),
      selectedLabelTextStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFFB7BDCB), fontWeight: FontWeight.w600),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? AppColors.gold : AppColors.violetDeep,
      foregroundColor: dark ? AppColors.ink : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

/// Thème choisi (clair / sombre / système), mémorisé sur l'appareil.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._() : super(ThemeMode.dark);
  static final instance = ThemeController._();
  static const _key = 'theme_mode';

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      value = ThemeMode.values.firstWhere((m) => m.name == v, orElse: () => ThemeMode.dark);
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, m.name);
    } catch (_) {}
  }
}
