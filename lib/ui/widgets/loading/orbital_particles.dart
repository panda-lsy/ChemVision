import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class _ParticleConfig {
  const _ParticleConfig({
    required this.color,
    required this.size,
    required this.radius,
    required this.periodFraction,
    required this.startAngle,
    this.counterClockwise = false,
  });

  final Color color;
  final double size;
  final double radius;
  final double periodFraction; // fraction of the full cycle
  final double startAngle; // radians
  final bool counterClockwise;
}

class OrbitalParticles extends StatefulWidget {
  const OrbitalParticles({super.key, this.visible = false});

  final bool visible;

  @override
  State<OrbitalParticles> createState() => _OrbitalParticlesState();
}

class _OrbitalParticlesState extends State<OrbitalParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _particles = [
    _ParticleConfig(
      color: AppColors.aqua,
      size: 5,
      radius: 98,
      periodFraction: 1 / 3.4,
      startAngle: 0,
    ),
    _ParticleConfig(
      color: AppColors.lime,
      size: 4,
      radius: 112,
      periodFraction: 1 / 4.8,
      startAngle: math.pi / 2, // 90deg
    ),
    _ParticleConfig(
      color: AppColors.amber,
      size: 3,
      radius: 82,
      periodFraction: 1 / 6.0,
      startAngle: math.pi * 200 / 180, // 200deg
    ),
    _ParticleConfig(
      color: Color(0xFF9BC4FF),
      size: 4,
      radius: 108,
      periodFraction: 1 / 4.0,
      startAngle: math.pi * 310 / 180, // 310deg
      counterClockwise: true,
    ),
  ];

  static const _dayParticles = [
    _ParticleConfig(
      color: AppColors.dayBluePrimary,
      size: 5,
      radius: 98,
      periodFraction: 1 / 3.4,
      startAngle: 0,
    ),
    _ParticleConfig(
      color: AppColors.dayBlueAccent,
      size: 4,
      radius: 112,
      periodFraction: 1 / 4.8,
      startAngle: math.pi / 2,
    ),
    _ParticleConfig(
      color: Color(0xFF2C6EC9),
      size: 3,
      radius: 82,
      periodFraction: 1 / 6.0,
      startAngle: math.pi * 200 / 180,
    ),
    _ParticleConfig(
      color: Color(0xFF5A8FD9),
      size: 4,
      radius: 108,
      periodFraction: 1 / 4.0,
      startAngle: math.pi * 310 / 180,
      counterClockwise: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedOpacity(
      opacity: widget.visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 1000),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: const Size(290, 250),
            painter: _OrbitalPainter(
              progress: _controller.value,
              particles: isDark ? _particles : _dayParticles,
            ),
          );
        },
      ),
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  _OrbitalPainter({required this.progress, required this.particles});

  final double progress;
  final List<_ParticleConfig> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final p in particles) {
      final direction = p.counterClockwise ? -1.0 : 1.0;
      final angle =
          p.startAngle + progress * 2 * math.pi * p.periodFraction * 10 * direction;
      final x = center.dx + p.radius * math.cos(angle);
      final y = center.dy + p.radius * math.sin(angle);

      // Glow (blur effect)
      final glowPaint = Paint()
        ..color = p.color.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x, y), p.size + 4, glowPaint);

      // Particle
      final paint = Paint()..color = p.color;
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitalPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
