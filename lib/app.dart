import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'ui/pages/input_page.dart';

class ChemVisionApp extends StatelessWidget {
  const ChemVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChemVISION',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const InputPage(),
    );
  }
}
