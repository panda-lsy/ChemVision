import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.scroll = false,
    this.scrollPhysics,
    this.drawer,
    this.scaffoldKey,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scroll;
  final ScrollPhysics? scrollPhysics;
  final Widget? drawer;
  final GlobalKey<ScaffoldState>? scaffoldKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenGradient =
        isDark ? AppColors.screenGradient : AppColors.lightScreenGradient;
    final topGlow = isDark
        ? AppColors.aqua.withValues(alpha: 0.2)
        : AppColors.dayBlueAccent.withValues(alpha: 0.18);
    final bottomGlow = isDark
        ? AppColors.lime.withValues(alpha: 0.12)
        : AppColors.dayBluePrimary.withValues(alpha: 0.12);

    final content = Padding(
      padding: padding,
      child: scroll
          ? SingleChildScrollView(
              physics: scrollPhysics,
              child: child,
            )
          : child,
    );

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: isDark ? AppColors.navyDeep : AppColors.dayBackground,
      drawer: drawer,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: screenGradient),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    topGlow,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -120,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    bottomGlow,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(child: content),
        ],
      ),
    );
  }
}
