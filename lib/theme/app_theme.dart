import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.navyDeep,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.aqua,
        secondary: AppColors.lime,
        surface: AppColors.navy,
        background: AppColors.navyDeep,
        onPrimary: AppColors.ink,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.mist,
          letterSpacing: 0.8,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        labelLarge: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.mist,
          letterSpacing: 1.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glass,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.aqua, width: 1.4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.glass,
        selectedColor: AppColors.aqua.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textPrimary,
        ),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.navy,
        contentTextStyle: TextStyle(color: AppColors.mist),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
