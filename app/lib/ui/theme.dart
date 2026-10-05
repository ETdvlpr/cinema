import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFF0B0B10);
  static const surface = Color(0xFF15151D);
  static const surfaceHigh = Color(0xFF1F1F2A);
  static const outline = Color(0xFF2C2C3A);
  static const gold = Color(0xFFF4B860);
  static const goldDeep = Color(0xFFE08E2B);
  static const text = Color(0xFFF5F3EE);
  static const textMuted = Color(0xFF9C9AAB);
  static const danger = Color(0xFFFF6B6B);
}

ThemeData buildTheme() {
  // Amharic titles need an Ethiopic font on every platform (notably web).
  final ethiopic = GoogleFonts.notoSansEthiopic().fontFamily!;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      onPrimary: Color(0xFF231505),
      secondary: AppColors.goldDeep,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceContainerHighest: AppColors.surfaceHigh,
      outline: AppColors.outline,
      error: AppColors.danger,
    ),
  );

  TextStyle display(TextStyle? s) => GoogleFonts.outfit(textStyle: s).copyWith(fontFamilyFallback: [ethiopic]);
  TextStyle body(TextStyle? s) => GoogleFonts.inter(textStyle: s).copyWith(fontFamilyFallback: [ethiopic]);
  final t = base.textTheme;

  return base.copyWith(
    textTheme: t
        .copyWith(
          displaySmall: display(t.displaySmall).copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineMedium: display(t.headlineMedium).copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
          headlineSmall: display(t.headlineSmall).copyWith(fontWeight: FontWeight.w700),
          titleLarge: display(t.titleLarge).copyWith(fontWeight: FontWeight.w600),
          titleMedium: display(t.titleMedium).copyWith(fontWeight: FontWeight.w600),
          titleSmall: body(t.titleSmall).copyWith(fontWeight: FontWeight.w600),
          bodyLarge: body(t.bodyLarge),
          bodyMedium: body(t.bodyMedium),
          bodySmall: body(t.bodySmall).copyWith(color: AppColors.textMuted),
          labelLarge: body(t.labelLarge).copyWith(fontWeight: FontWeight.w600),
          labelMedium: body(t.labelMedium),
          labelSmall: body(t.labelSmall).copyWith(letterSpacing: 0.6),
        )
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.gold.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.gold : AppColors.textMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => body(t.labelMedium).copyWith(
          color: states.contains(WidgetState.selected) ? AppColors.gold : AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1, thickness: 1),
  );
}
