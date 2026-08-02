/// Agent 步骤进度卡片 — 展示单个步骤的状态和摘要
///
/// 对应赛题"任务规划与执行可视化":用户能看到 Agent 的每一步动作。
import 'package:flutter/material.dart';

import '../../../models/agent_task.dart';
import '../../../theme/app_colors.dart';
import '../glass_panel.dart';

class AgentStepCard extends StatelessWidget {
  const AgentStepCard({
    super.key,
    required this.step,
    required this.index,
    required this.total,
  });

  final AgentStep step;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final status = _StatusVisual.fromStatus(step.status);

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusIndicator(
            status: status,
            isDark: isDark,
            index: index,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}/$total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        step.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: status.textColor(isDark),
                        ),
                      ),
                    ),
                    if (step.durationSeconds > 0 &&
                        step.status == AgentStepStatus.completed)
                      Text(
                        '${step.durationSeconds}s',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                if (step.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.dayTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (step.result != null && step.result!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: status.bgColor(isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      step.result!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: status.textColor(isDark),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
                if (step.error != null && step.status == AgentStepStatus.failed) ...[
                  const SizedBox(height: 6),
                  Text(
                    step.error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({
    required this.status,
    required this.isDark,
    required this.index,
  });

  final _StatusVisual status;
  final bool isDark;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (status.status == 'executing') {
      return SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(
            isDark ? AppColors.aqua : AppColors.dayBlueAccent,
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status.iconBgColor(isDark),
        border: Border.all(
          color: status.borderColor(isDark),
          width: 1.5,
        ),
      ),
      child: Icon(
        status.icon,
        size: 14,
        color: status.iconColor(isDark),
      ),
    );
  }
}

class _StatusVisual {
  const _StatusVisual({
    required this.status,
    required this.icon,
  });

  factory _StatusVisual.fromStatus(AgentStepStatus status) {
    switch (status) {
      case AgentStepStatus.pending:
        return const _StatusVisual(status: 'pending', icon: Icons.access_time);
      case AgentStepStatus.executing:
        return const _StatusVisual(status: 'executing', icon: Icons.autorenew);
      case AgentStepStatus.completed:
        return const _StatusVisual(status: 'completed', icon: Icons.check);
      case AgentStepStatus.failed:
        return const _StatusVisual(status: 'failed', icon: Icons.close);
      case AgentStepStatus.skipped:
        return const _StatusVisual(status: 'skipped', icon: Icons.remove);
    }
  }

  final String status;
  final IconData icon;

  Color textColor(bool isDark) {
    switch (status) {
      case 'pending':
        return isDark ? AppColors.textSecondary : AppColors.dayTextSecondary;
      case 'executing':
        return isDark ? AppColors.aquaLight : AppColors.dayBlueAccent;
      case 'completed':
        return isDark ? AppColors.lime : AppColors.dayBluePrimary;
      case 'failed':
        return isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);
      case 'skipped':
        return isDark ? AppColors.textMuted : AppColors.dayTextMuted;
      default:
        return isDark ? AppColors.textPrimary : AppColors.dayTextPrimary;
    }
  }

  Color bgColor(bool isDark) {
    switch (status) {
      case 'completed':
        return isDark
            ? AppColors.lime.withValues(alpha: 0.10)
            : AppColors.dayBluePrimary.withValues(alpha: 0.08);
      case 'failed':
        return const Color(0xFFFDECEC);
      case 'executing':
        return isDark
            ? AppColors.aqua.withValues(alpha: 0.10)
            : AppColors.dayBlueAccent.withValues(alpha: 0.10);
      default:
        return isDark
            ? AppColors.glass
            : AppColors.dayGlass;
    }
  }

  Color iconBgColor(bool isDark) {
    switch (status) {
      case 'completed':
        return isDark
            ? AppColors.lime.withValues(alpha: 0.22)
            : AppColors.dayBluePrimary.withValues(alpha: 0.18);
      case 'failed':
        return const Color(0xFFFDECEC);
      case 'executing':
        return isDark
            ? AppColors.aqua.withValues(alpha: 0.20)
            : AppColors.dayBlueAccent.withValues(alpha: 0.18);
      default:
        return Colors.transparent;
    }
  }

  Color iconColor(bool isDark) {
    switch (status) {
      case 'pending':
        return isDark ? AppColors.textMuted : AppColors.dayTextMuted;
      case 'executing':
        return isDark ? AppColors.aqua : AppColors.dayBlueAccent;
      case 'completed':
        return isDark ? AppColors.lime : AppColors.dayBluePrimary;
      case 'failed':
        return const Color(0xFFC62828);
      case 'skipped':
        return isDark ? AppColors.textMuted : AppColors.dayTextMuted;
      default:
        return isDark ? AppColors.textPrimary : AppColors.dayTextPrimary;
    }
  }

  Color borderColor(bool isDark) {
    switch (status) {
      case 'pending':
        return isDark ? Colors.white24 : const Color(0x223D77DE);
      case 'executing':
        return Colors.transparent;
      case 'completed':
        return Colors.transparent;
      case 'failed':
        return Colors.transparent;
      case 'skipped':
        return isDark ? Colors.white12 : const Color(0x113D77DE);
      default:
        return Colors.transparent;
    }
  }
}
