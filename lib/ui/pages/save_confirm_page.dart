import 'package:flutter/material.dart';

import '../../models/edit_history_item.dart';
import '../../theme/app_colors.dart';
import '../widgets/primary_button.dart';

/// 保存后确认页面（全屏，避免 iframe z-index 问题）
///
/// 检测 SMILES 类型，提示用户是否收藏。
class SaveConfirmPage extends StatelessWidget {
  const SaveConfirmPage({super.key, required this.smiles, this.aiName});

  final String smiles;
  final String? aiName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReaction = EditHistoryItem.isReactionSmiles(smiles);
    final typeLabel = isReaction ? '反应式' : '结构式';
    final typeIcon = isReaction ? Icons.device_thermostat : Icons.science;
    final typeColor =
        isDark ? AppColors.aqua : AppColors.dayBluePrimary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0d1627) : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 1),
              // 类型图标
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, size: 36, color: typeColor),
              ),
              const SizedBox(height: 16),
              Text(
                '已保存到编辑历史',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              // 类型标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // AI 推断名称
              if (aiName != null && aiName!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: typeColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: typeColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          aiName!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: typeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // SMILES 预览
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.glass : AppColors.dayGlassStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  smiles,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '是否收藏？',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.dayTextSecondary,
                    ),
              ),
              const Spacer(flex: 1),
              // 按钮
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark
                              ? AppColors.textPrimary
                              : AppColors.dayTextPrimary,
                          side: BorderSide(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('跳过'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 48,
                      child: PrimaryButton(
                        label: '收藏',
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
