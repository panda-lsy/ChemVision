import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class _IconConfig {
  const _IconConfig({
    required this.icon,
    required this.color,
    required this.size,
    required this.top,
    required this.left,
    required this.right,
    required this.bottom,
    required this.delayFraction,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? top; // fraction of container height
  final double? left;
  final double? right;
  final double? bottom;
  final double delayFraction; // fraction of 5.5s cycle
}

class FloatingChemIcons extends StatefulWidget {
  const FloatingChemIcons({super.key, this.visible = true});

  final bool visible;

  @override
  State<FloatingChemIcons> createState() => _FloatingChemIconsState();
}

class _FloatingChemIconsState extends State<FloatingChemIcons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _icons = [
    _IconConfig(
      icon: Icons.science,
      color: AppColors.aqua,
      size: 14,
      top: 0.08,
      left: -0.02,
      right: null,
      bottom: null,
      delayFraction: 0,
    ),
    _IconConfig(
      icon: Icons.local_florist,
      color: AppColors.lime,
      size: 12,
      top: -0.04,
      left: null,
      right: 0.04,
      bottom: null,
      delayFraction: 1.1 / 5.5,
    ),
    _IconConfig(
      icon: Icons.access_time,
      color: AppColors.amber,
      size: 11,
      top: null,
      left: 0,
      right: null,
      bottom: 0.12,
      delayFraction: 2.3 / 5.5,
    ),
    _IconConfig(
      icon: Icons.description,
      color: Color(0xFFA0D2F0),
      size: 13,
      top: null,
      left: null,
      right: 0.06,
      bottom: 0,
      delayFraction: 3.5 / 5.5,
    ),
    _IconConfig(
      icon: Icons.show_chart,
      color: AppColors.aqua,
      size: 10,
      top: 0.48,
      left: null,
      right: -0.06,
      bottom: null,
      delayFraction: 1.7 / 5.5,
    ),
    _IconConfig(
      icon: Icons.star,
      color: Color(0xFF9BC4FF),
      size: 12,
      top: 0.62,
      left: -0.06,
      right: null,
      bottom: null,
      delayFraction: 2.9 / 5.5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 5500),
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
      opacity: widget.visible ? 0.45 : 0.0,
      duration: const Duration(milliseconds: 600),
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: _icons.map((config) {
                final t =
                    (_controller.value + config.delayFraction) % 1.0;
                // pFloat animation: translateY oscillation, scale pulse, opacity pulse
                final floatY = -18 *
                    math.sin(t * 2 * math.pi) *
                    (1 - 0.3 * math.cos(t * 4 * math.pi));
                final floatX =
                    5 * math.sin(t * 2 * math.pi + 1.2);
                final scale =
                    1.0 + 0.2 * math.sin(t * 2 * math.pi);
                final opacity = 0.25 +
                    0.35 *
                        (0.5 -
                            0.5 * math.cos(t * 2 * math.pi));

                return Positioned(
                  top: config.top != null
                      ? config.top! * 250 + floatY
                      : null,
                  bottom: config.bottom != null
                      ? config.bottom! * 250 - floatY
                      : null,
                  left: config.left != null
                      ? config.left! * 290 + floatX
                      : null,
                  right: config.right != null
                      ? config.right! * 290 - floatX
                      : null,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(
                        config.icon,
                        color: config.color,
                        size: config.size,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
