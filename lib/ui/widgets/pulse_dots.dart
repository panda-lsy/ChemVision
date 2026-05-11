import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PulseDots extends StatefulWidget {
  const PulseDots({super.key, this.count = 3});

  final int count;

  @override
  State<PulseDots> createState() => _PulseDotsState();
}

class _PulseDotsState extends State<PulseDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? AppColors.aqua : AppColors.dayBluePrimary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.count, (index) {
            final phase = (index / widget.count) * math.pi * 2;
            final value = (_controller.value * math.pi * 2) + phase;
            final scale = 0.7 + (math.sin(value) + 1) * 0.15;
            final opacity = 0.4 + (math.sin(value) + 1) * 0.25;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                    child: const SizedBox(width: 6, height: 6),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
