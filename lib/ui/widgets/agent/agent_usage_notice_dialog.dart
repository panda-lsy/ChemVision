/// Agent 使用须知弹窗 — 首次进入 Agent 页时展示
///
/// 对应赛题"安全边界"与"AI 生成内容风险提示":
/// - 明确告知用户 Agent 能力边界
/// - 提示 AI 生成内容可能存在错误
/// - 未成年人使用需在监护人/教师指导下使用
/// - 通过 SharedPreferences 记录已读状态,仅首次显示
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../theme/app_colors.dart';

class AgentUsageNoticeDialog extends StatefulWidget {
  const AgentUsageNoticeDialog({super.key});

  static const _prefKey = 'agent_usage_notice_shown';

  /// 检查是否需要展示(首次进入时)
  /// 返回 true 表示需要展示。
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_prefKey) ?? false;
    return !shown;
  }

  /// 标记为已读
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  State<AgentUsageNoticeDialog> createState() => _AgentUsageNoticeDialogState();
}

class _AgentUsageNoticeDialogState extends State<AgentUsageNoticeDialog> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.navy : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.aqua, AppColors.lime]
                    : [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ChemEdu Agent 使用须知',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '欢迎使用化学学习智能助手。使用前请阅读以下要点:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _NoticeItem(
              icon: Icons.school_outlined,
              title: '辅导而非代答',
              description: '作业辅导采用分步启发式,引导你思考而非直接给出答案,目的是帮助你理解知识点。',
              isDark: isDark,
            ),
            _NoticeItem(
              icon: Icons.warning_amber_outlined,
              title: 'AI 生成可能出错',
              description: '讲解、诊断、规划均由大模型生成,可能存在事实性错误。请结合教材和教师讲解核实关键信息。',
              isDark: isDark,
              accent: const Color(0xFFE07B00),
            ),
            _NoticeItem(
              icon: Icons.insights_outlined,
              title: '学情诊断仅供参考',
              description: '基于本地学习记录生成,不能替代教师正式评价。重要决策请咨询任课教师。',
              isDark: isDark,
            ),
            _NoticeItem(
              icon: Icons.child_care_outlined,
              title: '未成年人使用',
              description: '中小学生请在家长或教师指导下使用。学习数据仅存于本机,不上传服务器。',
              isDark: isDark,
              accent: const Color(0xFF7986CB),
            ),
            _NoticeItem(
              icon: Icons.security_outlined,
              title: '隐私保护',
              description: '不收集个人身份信息,不进行用户画像分析。仅 OCSR/LLM 调用时会传输 SMILES/文本。',
              isDark: isDark,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            '稍后再看',
            style: TextStyle(
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('我已知悉,开始使用'),
        ),
      ],
    );
  }
}

class _NoticeItem extends StatelessWidget {
  const _NoticeItem({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
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
      ),
    );
  }
}

/// 便捷调用:在 AgentPage 首次进入时展示
///
/// 返回 true 表示用户已确认;false 表示用户取消或稍后。
Future<bool> showAgentUsageNoticeIfNeeded(BuildContext context) async {
  if (!await AgentUsageNoticeDialog.shouldShow()) return true;
  if (!context.mounted) return false;
  final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AgentUsageNoticeDialog(),
      ) ??
      false;
  if (accepted) {
    await AgentUsageNoticeDialog.markShown();
  }
  return accepted;
}
