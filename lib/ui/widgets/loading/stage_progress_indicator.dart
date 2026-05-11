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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.aqua : AppColors.dayBluePrimary;
    final doneColor = isDark ? AppColors.textSecondary : AppColors.dayTextSecondary;
    final pendingColor = isDark
        ? AppColors.textMuted
        : AppColors.dayTextMuted;
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
                activeColor: activeColor,
                doneColor: doneColor,
                pendingColor: pendingColor,
              ),
              if (i < _stages.length - 1)
                Expanded(
                  child: _StageConnector(
                    isDone: i < currentStage,
                    doneColor: activeColor,
                    pendingColor: pendingColor,
                  ),
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
                            ? activeColor
                            : i < currentStage
                                ? doneColor
                                : pendingColor,
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
    required this.activeColor,
    required this.doneColor,
    required this.pendingColor,
  });

  final IconData icon;
  final bool isActive;
  final bool isDone;
  final Color activeColor;
  final Color doneColor;
  final Color pendingColor;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? activeColor
        : isDone
            ? doneColor
            : pendingColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: color.withValues(alpha: isActive ? 0.7 : 0.45),
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.3),
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
  const _StageConnector({
    required this.isDone,
    required this.doneColor,
    required this.pendingColor,
  });

  final bool isDone;
  final Color doneColor;
  final Color pendingColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        color: isDone
            ? doneColor.withValues(alpha: 0.5)
            : pendingColor.withValues(alpha: 0.28),
      ),
    );
  }
}
