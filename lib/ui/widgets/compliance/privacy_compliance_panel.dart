/// 隐私与合规说明面板 — 用于设置页
///
/// 对应赛题"数据合规"评审项:
/// - 未成年人保护(K12 学生使用时,数据本地存储不上传)
/// - AI 生成内容风险提示
/// - 数据控制权(用户可随时清除全部数据)
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../glass_panel.dart';

class PrivacyCompliancePanel extends StatelessWidget {
  const PrivacyCompliancePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 20,
                color: isDark ? AppColors.lime : AppColors.dayBluePrimary,
              ),
              const SizedBox(width: 8),
              Text(
                '隐私与合规',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ComplianceItem(
            icon: Icons.storage_outlined,
            title: '本地优先存储',
            description: '扫描记录、收藏、学情画像等数据全部存储在设备本地 Hive 数据库,不主动上传至任何服务器。',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _ComplianceItem(
            icon: Icons.child_care_outlined,
            title: '未成年人保护',
            description: '面向 K12 学生的教育产品:不收集个人身份信息,不进行用户画像分析,不向第三方共享学习数据。',
            isDark: isDark,
            accent: const Color(0xFF7986CB),
          ),
          const SizedBox(height: 10),
          _ComplianceItem(
            icon: Icons.cloud_off_outlined,
            title: '云端数据传输',
            description: '仅化合物结构识别(OCSR)和大模型(LLM)调用会向已配置的服务端发送 SMILES/文本。可在设置中关闭或更换为本地部署模型。',
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _ComplianceItem(
            icon: Icons.smart_toy_outlined,
            title: 'AI 生成内容提示',
            description: 'Agent 讲解、学情诊断、学习规划均由 AI 生成,可能存在错误。请结合教材和教师指导核实关键信息,不可替代正式评价。',
            isDark: isDark,
            accent: const Color(0xFFE07B00),
          ),
          const SizedBox(height: 10),
          _ComplianceItem(
            icon: Icons.delete_outline,
            title: '数据控制权',
            description: '用户拥有完整数据控制权,可随时通过「存储管理」清除全部学习记录、收藏和缓存,操作不可恢复。',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 14,
                color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '符合《个人信息保护法》《未成年人保护法》对教育类应用的基本要求',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComplianceItem extends StatelessWidget {
  const _ComplianceItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.isDark,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isDark;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ??
        (isDark ? AppColors.aqua : AppColors.dayBlueAccent);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.5,
                  color: isDark
                      ? AppColors.textSecondary
                      : AppColors.dayTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
