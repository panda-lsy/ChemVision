import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class GlowRing extends StatefulWidget {
  const GlowRing({super.key, this.visible = false, this.size = 170});

  final bool visible;
  final double size;

  @override
  State<GlowRing> createState() => _GlowRingState();
}

class _GlowRingState extends State<GlowRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 800),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          // scale: 1.0 -> 1.1 -> 1.0 (ease-in-out)
          final scale =
              1.0 + 0.1 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));
          // border opacity: 0.08 -> 0.22 -> 0.08
          final borderOpacity =
              0.08 + 0.14 * (0.5 - 0.5 * math.cos(t * 2 * math.pi));

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.aqua.withOpacity(borderOpacity),
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
