import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'ui/pages/splash_page.dart';
// imports intentionally minimal here
import 'providers/asr_provider.dart';
import 'providers/theme_mode_provider.dart';

class ChemEduApp extends ConsumerStatefulWidget {
  const ChemEduApp({super.key});

  @override
  ConsumerState<ChemEduApp> createState() => _ChemEduAppState();
}

class _ChemEduAppState extends ConsumerState<ChemEduApp>
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
      title: 'ChemEdu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashPage(),
    );
  }
}
