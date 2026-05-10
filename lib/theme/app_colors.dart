import 'package:flutter/material.dart';

class AppColors {
  static const Color ink = Color(0xFF0B0F1A);
  static const Color navy = Color(0xFF0F172A);
  static const Color navyDeep = Color(0xFF0D1627);
  static const Color navyDarker = Color(0xFF0F1A30);
  static const Color aqua = Color(0xFF38D5C1);
  static const Color aquaLight = Color(0xFF5CE0D0);
  static const Color lime = Color(0xFFB7F171);
  static const Color amber = Color(0xFFF6B355);
  static const Color mist = Color(0xFFE9EEF5);
  static const Color soft = Color(0xFFCDD6E5);
  static const Color textPrimary = Color(0xFFF3F6FB);
  static const Color textSecondary = Color(0xFFB9C7DE);
  static const Color textMuted = Color(0xFFA9B6CB);
  static const Color glass = Color(0x14FFFFFF);
  static const Color glassStrong = Color(0x1FFFFFFF);
  static const Color shadow = Color(0x72050C18);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      navyDeep,
      navyDarker,
    ],
  );
}
