import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'i18n.dart';

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
  static const darkBg = Color(0xFF0A0C11);
  static const darkSurface = Color(0xFF12151D);
  static const darkSurface2 = Color(0xFF1A1E29);
  static const darkLine = Color(0xFF262B38);

  // Barre latérale (obsidienne)
  static const sidebar = Color(0xFF080A0F);
  static const sidebarHover = Color(0xFF141824);
  static const champagne = Color(0xFFF3DC8C);

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

/// PC (Windows, macOS, Linux) : souris, clavier, écran large.
bool get estBureau =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

/// Transition PC : fondu + léger glissement, rapide et sobre (style Windows 11).
class _TransitionBureau extends PageTransitionsBuilder {
  const _TransitionBureau();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> a, Animation<double> b, Widget child) {
    final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: c,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.025), end: Offset.zero).animate(c), child: child),
    );
  }
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
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    brightness: b,
    // Police du système : Segoe UI Variable sur Windows, Roboto sur Android → 100 % natif
    fontFamily: defaultTargetPlatform == TargetPlatform.windows ? 'Segoe UI Variable Text' : null,
    fontFamilyFallback: const ['Segoe UI', 'Roboto'],
    visualDensity: estBureau ? VisualDensity.compact : VisualDensity.standard,
    materialTapTargetSize: estBureau ? MaterialTapTargetSize.shrinkWrap : MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
      TargetPlatform.windows: _TransitionBureau(),
      TargetPlatform.linux: _TransitionBureau(),
      TargetPlatform.macOS: _TransitionBureau(),
    }),
    splashFactory: estBureau ? InkRipple.splashFactory : InkSparkle.splashFactory,
  );
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
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: line)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: radius),
      selectedColor: dark ? AppColors.gold : AppColors.violetDeep,
      selectedTileColor: AppColors.gold.withValues(alpha: 0.12),
      iconColor: dark ? const Color(0xFFB7BDCB) : const Color(0xFF6F6858),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: WidgetStateProperty.all(estBureau),
      thickness: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 9 : 6),
      radius: const Radius.circular(8),
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => AppColors.gold.withValues(alpha: s.contains(WidgetState.hovered) || s.contains(WidgetState.dragged) ? 0.75 : 0.35)),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: line)),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(surface),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: line))),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.gold.withValues(alpha: 0.6),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
      checkColor: const WidgetStatePropertyAll(AppColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.gold : null),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.gold,
      linearTrackColor: line,
      circularTrackColor: Colors.transparent,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: radius)),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.gold.withValues(alpha: dark ? 0.22 : 0.28) : Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? (dark ? AppColors.gold : AppColors.violetDeep) : null),
        textStyle: const WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? AppColors.gold : AppColors.violetDeep,
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: AppColors.rose, textColor: Colors.white),
    drawerTheme: DrawerThemeData(backgroundColor: AppColors.sidebar, surfaceTintColor: Colors.transparent),
  );
}

/// Préférences d'interface mémorisées sur l'appareil (barre latérale réduite…).
class UiPrefs extends ChangeNotifier {
  UiPrefs._();
  static final instance = UiPrefs._();
  bool sidebarReduite = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      sidebarReduite = p.getBool('sidebar_reduite') ?? false;
    } catch (_) {}
  }

  Future<void> basculerSidebar() async {
    sidebarReduite = !sidebarReduite;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('sidebar_reduite', sidebarReduite);
    } catch (_) {}
  }
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
