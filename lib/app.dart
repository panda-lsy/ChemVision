import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'ui/pages/splash_page.dart';
// imports intentionally minimal here
import 'providers/asr_provider.dart';
import 'providers/theme_mode_provider.dart';

class ChemVisionApp extends ConsumerStatefulWidget {
  const ChemVisionApp({super.key});

  @override
  ConsumerState<ChemVisionApp> createState() => _ChemVisionAppState();
}

class _ChemVisionAppState extends ConsumerState<ChemVisionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      try {
        ref.read(asrControllerProvider.notifier).cancel();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'ChemVISION',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashPage(),
    );
  }
}
