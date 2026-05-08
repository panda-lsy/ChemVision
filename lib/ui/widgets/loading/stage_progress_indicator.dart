import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

class _StageDef {
  const _StageDef({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class StageProgressIndicator extends StatelessWidget {
  const StageProgressIndicator({super.key, required this.currentStage});

  final int currentStage;

  static const _stages = [
    _StageDef(icon: Icons.search, label: '意图识别'),
    _StageDef(icon: Icons.bolt, label: '结构推理'),
    _StageDef(icon: Icons.shield, label: '规则校验'),
    _StageDef(icon: Icons.image_outlined, label: '渲染输出'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots + connectors
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < _stages.length; i++) ...[
              _StageDot(
                icon: _stages[i].icon,
                isActive: i == currentStage,
                isDone: i < currentStage,
              ),
              if (i < _stages.length - 1)
                Expanded(
                  child: _StageConnector(isDone: i < currentStage),
                ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < _stages.length; i++)
              Expanded(
                child: Text(
                  _stages[i].label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: i == currentStage
                            ? AppColors.aqua
                            : i < currentStage
                                ? AppColors.textSecondary
                                : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: i == currentStage
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({
    required this.icon,
    required this.isActive,
    required this.isDone,
  });

  final IconData icon;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.aqua
        : isDone
            ? AppColors.aqua.withOpacity(0.6)
            : AppColors.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? AppColors.aqua.withOpacity(0.15)
            : Colors.transparent,
        border: Border.all(
          color: color.withOpacity(isActive ? 0.6 : 0.3),
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.aqua.withOpacity(0.3),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }
}

class _StageConnector extends StatelessWidget {
  const _StageConnector({required this.isDone});

  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: isDone
            ? AppColors.aqua.withOpacity(0.5)
            : AppColors.textMuted.withOpacity(0.2),
      ),
    );
  }
}
