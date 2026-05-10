import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/pages/splash_page.dart';
import 'ui/widgets/bottom_nav_shell.dart';

class ChemVisionApp extends StatelessWidget {
  const ChemVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChemVISION',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const SplashPage(),
    );
  }
}
