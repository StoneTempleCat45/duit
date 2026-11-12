import 'package:flutter/material.dart';

import '../domain/budget_math.dart';

/// Brand colours. The palette matches the Duit web app: an ink blue accent,
/// a sunny yellow highlight, and cool blue-grey neutrals.
abstract final class AppColors {
  static const accentLight = Color(0xFF2F4BD8);
  static const accentDark = Color(0xFF7088FF);
  static const highlight = Color(0xFFFFC93C);
  static const warning = Color(0xFFFF9F43);
  static const dangerLight = Color(0xFFD23B4B);
  static const dangerDark = Color(0xFFFF6B7A);
  static const success = Color(0xFF2AA876);

  /// Second stop of the brand gradient (ink blue -> violet).
  static const violetLight = Color(0xFF6A4DFF);
  static const violetDark = Color(0xFF8E7BFF);
}

/// Brand gradients. Both stops are saturated enough for white text in
/// light and dark mode.
abstract final class AppGradients {
  static List<Color> brand(Brightness b) => b == Brightness.dark
      ? const [Color(0xFF4F6BFF), Color(0xFF7B5CFF)]
      : const [AppColors.accentLight, AppColors.violetLight];

  static LinearGradient brandLinear(BuildContext context) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: brand(Theme.of(context).brightness),
      );

  /// Vertical gradient for chart bars and fills.
  static LinearGradient bars(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: dark
          ? const [AppColors.accentDark, AppColors.violetDark]
          : const [AppColors.accentLight, AppColors.violetLight],
    );
  }
}

const String kDisplayFont = 'Bricolage';
const String kBodyFont = 'DMSans';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  final scheme = ColorScheme.fromSeed(seedColor: AppColors.accentLight, brightness: brightness).copyWith(
    primary: dark ? AppColors.accentDark : AppColors.accentLight,
    onPrimary: dark ? const Color(0xFF0E1220) : Colors.white,
    surface: dark ? const Color(0xFF0E1220) : const Color(0xFFF1F3F8),
    onSurface: dark ? const Color(0xFFE9ECF5) : const Color(0xFF141A2B),
    onSurfaceVariant: dark ? const Color(0xFF99A2BD) : const Color(0xFF5D6680),
    surfaceContainerLowest: dark ? const Color(0xFF171C2E) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF1C2236) : const Color(0xFFF7F8FC),
    surfaceContainerHighest: dark ? const Color(0xFF262D45) : const Color(0xFFE3E7F0),
    outlineVariant: dark ? const Color(0xFF262D45) : const Color(0xFFDDE2EC),
    error: dark ? AppColors.dangerDark : AppColors.dangerLight,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kBodyFont,
  );

  TextStyle? display(TextStyle? s, FontWeight w, {double spacing = -0.5}) =>
      s?.copyWith(fontFamily: kDisplayFont, fontWeight: w, letterSpacing: spacing);

  final t = base.textTheme;
  final textTheme = t.copyWith(
    displayMedium: display(t.displayMedium, FontWeight.w800, spacing: -1.5),
    displaySmall: display(t.displaySmall, FontWeight.w800, spacing: -1),
    headlineMedium: display(t.headlineMedium, FontWeight.w700),
    headlineSmall: display(t.headlineSmall, FontWeight.w700),
    titleLarge: display(t.titleLarge, FontWeight.w700, spacing: -0.2),
    titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: t.labelMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.6),
  );

  final radius = BorderRadius.circular(14);

  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: textTheme.titleMedium,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      indicatorColor: scheme.primary.withValues(alpha: 0.14),
      elevation: 0,
      labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}

/// Colour for the budget bar and warnings at each level.
Color levelColor(BuildContext context, BudgetLevel level) {
  final scheme = Theme.of(context).colorScheme;
  return switch (level) {
    BudgetLevel.normal => scheme.primary,
    BudgetLevel.warning => AppColors.warning,
    BudgetLevel.over => scheme.error,
  };
}
