import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class MoleculeReveal extends StatefulWidget {
  const MoleculeReveal({super.key, this.svgString});

  final String? svgString;

  @override
  State<MoleculeReveal> createState() => _MoleculeRevealState();
}

class _MoleculeRevealState extends State<MoleculeReveal>
    with TickerProviderStateMixin {
  AnimationController? _revealController;
  late final AnimationController _floatController;
  bool _revealDone = false;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 4500),
      vsync: this,
    );
    _updateReveal();
  }

  @override
  void didUpdateWidget(MoleculeReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.svgString != widget.svgString) {
      _updateReveal();
    }
  }

  void _updateReveal() {
    if (widget.svgString != null && widget.svgString!.isNotEmpty) {
      _revealController?.dispose();
      _revealController = AnimationController(
        duration: const Duration(milliseconds: 1600),
        vsync: this,
      )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _revealDone = true;
            });
            _floatController.repeat();
          }
        });
      _revealController!.forward();
    } else {
      _revealController?.dispose();
      _revealController = null;
      _floatController.stop();
      _revealDone = false;
    }
  }

  @override
  void dispose() {
    _revealController?.dispose();
    _floatController.dispose();
    super.dispose();
  }

  // Custom cubic-bezier(0.16, 1, 0.3, 1) approximation
  static double _cubicEase(double t) {
    // Approximation of cubic-bezier(0.16, 1, 0.3, 1)
    if (t <= 0) return 0;
    if (t >= 1) return 1;
    final t2 = t * t;
    final t3 = t2 * t;
    return 3.0 * 0.3 * t * (1 - t) * (1 - t) +
        3.0 * 1.0 * t2 * (1 - t) +
        t3;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF38D5C1) : AppColors.dayBluePrimary;
    if (widget.svgString == null || widget.svgString!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_revealDone) {
      // Float animation
      return AnimatedBuilder(
        animation: _floatController,
        builder: (context, child) {
          final t = _floatController.value;
          final translateY = -5 * math.sin(t * 2 * math.pi) +
              4 * math.sin(t * 4 * math.pi);
          return Transform.translate(
            offset: Offset(0, translateY),
            child: child,
          );
        },
        child: Container(
          width: double.infinity,
          height: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                ),
              ],
            ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            color: Colors.black26,
            child: Center(
              child: Icon(
                Icons.check_circle_outline,
                color: accent,
                size: 32,
              ),
            ),
          ),
        ),
      );
    }

    // Reveal animation
    return AnimatedBuilder(
      animation: _revealController!,
      builder: (context, child) {
        final t = _cubicEase(_revealController!.value);

        // Interpolate keyframes
        double opacity;
        double scale;
        double rotate;
        double blur;

        if (t < 0.3) {
          final p = t / 0.3;
          opacity = p * 0.65;
          scale = 0.2 + p * 0.88; // 0.2 -> 1.08
          rotate = -14 + p * 17; // -14 -> 3
          blur = 14 - p * 11; // 14 -> 3
        } else if (t < 0.6) {
          final p = (t - 0.3) / 0.3;
          opacity = 0.65 + p * 0.35; // 0.65 -> 1
          scale = 1.08 - p * 0.12; // 1.08 -> 0.96
          rotate = 3 - p * 4; // 3 -> -1
          blur = 3 - p * 3; // 3 -> 0
        } else {
          final p = (t - 0.6) / 0.4;
          opacity = 1;
          scale = 0.96 + p * 0.04; // 0.96 -> 1
          rotate = -1 + p; // -1 -> 0
          blur = 0;
        }

        return Opacity(
          opacity: opacity.clamp(0, 1),
          child: Transform.rotate(
            angle: rotate * math.pi / 180,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3 * opacity),
                      blurRadius: 10 + blur,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  color: Colors.black26,
                  child: Center(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: accent,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
