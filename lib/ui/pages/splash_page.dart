import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_mode_provider.dart';
import '../../services/app_version_service.dart';
import '../../theme/app_colors.dart';
import '../../ui/widgets/bottom_nav_shell.dart';
import '../widgets/pulse_dots.dart';

/// 开屏加载页面
/// 参考原型：doc/prototype/screen-01-splash.html
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    // Logo 脉冲动画
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.15,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // 淡入动画
    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeInController,
      curve: Curves.easeOut,
    ));
    _fadeInController.forward();

    // 2.5 秒后跳转到主页面
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const BottomNavShell(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? null : const Color(0xFF1F48B3),
          gradient: isDark
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.navyDeep, AppColors.navyDarker],
                )
              : null,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo
              FadeTransition(
                opacity: _fadeInAnimation,
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: Builder(
                    builder: (context) {
                      // 尝试加载 Logo，失败则显示占位图标
                      return Image.asset(
                        isDark ? 'icon4prototype.png' : 'logo.png',
                        width: 130,
                        height: 130,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Logo 加载失败：$error');
                          debugPrint('堆栈：$stackTrace');
                          return Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: AppColors.aqua.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.science,
                              size: 60,
                              color: AppColors.aqua,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 应用名称
              FadeTransition(
                opacity: _fadeInAnimation,
                child: Column(
                  children: [
                    Text(
                      'ChemVISION',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 1.2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '化学结构式智能助手',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 4,
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 加载指示器
              FadeTransition(
                opacity: _fadeInAnimation,
                child: const PulseDots(),
              ),

              const Spacer(flex: 1),

              // 底部版本信息
              FadeTransition(
                opacity: _fadeInAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      Text(
                        'Powered by vivo BlueLM',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 0.5,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppVersionService().fullVersion,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
