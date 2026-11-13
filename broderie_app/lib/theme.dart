import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Palette de l'application.
class AppColors {
  static const violet = Color(0xFF8B5CF6);
  static const violetDeep = Color(0xFF5B21B6);
  static const gold = Color(0xFFE2B04A);
  static const teal = Color(0xFF14B8A6);
  static const rose = Color(0xFFF43F5E);
  static const sky = Color(0xFF38BDF8);
  static const green = Color(0xFF22C55E);

  // Sombre
  static const darkBg = Color(0xFF0E1015);
  static const darkSurface = Color(0xFF171A22);
  static const darkSurface2 = Color(0xFF1F2330);
  static const darkLine = Color(0xFF2A2F3D);

  // Clair
  static const lightBg = Color(0xFFF4F5FA);
  static const lightSurface = Colors.white;
  static const lightSurface2 = Color(0xFFF0EEFB);
  static const lightLine = Color(0xFFE6E4F0);

  /// Couleurs des séries (graphiques, avatars).
  static const series = [violet, gold, teal, rose, sky, green, Color(0xFFF97316), Color(0xFFA3E635)];

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
    colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6), Color(0xFFC084FC)],
  );

  static const goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB7791F), Color(0xFFE2B04A), Color(0xFFF6D98B)],
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
  final cs = ColorScheme.fromSeed(seedColor: AppColors.violet, brightness: b).copyWith(
    primary: dark ? const Color(0xFFA78BFA) : AppColors.violetDeep,
    secondary: AppColors.gold,
    surface: surface,
    surfaceContainerLowest: bg,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
    outlineVariant: line,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: b);
  final radius = BorderRadius.circular(14);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    extensions: [
      AppPalette(
        surface2: dark ? AppColors.darkSurface2 : AppColors.lightSurface2,
        line: line,
        muted: dark ? const Color(0xFF9AA0B4) : const Color(0xFF6B6F80),
      ),
    ],
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: cs.primary.withValues(alpha: 0.18),
      height: 68,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      indicatorColor: cs.primary.withValues(alpha: 0.18),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
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
