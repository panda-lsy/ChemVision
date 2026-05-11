import 'package:flutter/material.dart';

class AppColors {
  // Night mode (existing palette)
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

  // Day mode palette (picked from logo.png + 手绘海报.png)
  static const Color dayBluePrimary = Color(0xFF1F48B3);
  static const Color dayBlueAccent = Color(0xFF4F76D6);
  static const Color dayBlueDeep = Color(0xFF16358A);
  static const Color dayBackground = Color(0xFFF4F7FF);
  static const Color daySurface = Color(0xFFFFFFFF);
  static const Color dayTextPrimary = Color(0xFF0D2756);
  static const Color dayTextSecondary = Color(0xFF2C4A7C);
  static const Color dayTextMuted = Color(0xFF4A6A9E);
  static const Color dayGlass = Color(0xEBFFFFFF);
  static const Color dayGlassStrong = Color(0xFFF6FAFF);
  static const Color dayShadow = Color(0x1E1A49A4);

  static const LinearGradient lightScreenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFEAF1FF),
      Color(0xFFDDE8FF),
      Color(0xFFF5F8FF),
    ],
  );
}
