/// Agent 结果展示组件 — 分章节渲染最终结果
///
/// 对应赛题"结果交付"环节:把 Agent 的输出以结构化、可读的方式呈现给用户。
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../models/agent_task.dart';
import '../../../theme/app_colors.dart';
import '../glass_panel.dart';

/// 建议操作回调
/// [action] 被点击的建议操作
typedef SuggestedActionCallback = void Function(SuggestedAction action);

class AgentResultView extends StatelessWidget {
  const AgentResultView({
    super.key,
    required this.result,
    this.onAction,
  });

  final AgentTaskResult result;

  /// 建议操作点击回调(为 null 时显示 SnackBar 提示)
  final SuggestedActionCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题 Card(只显示标题,不显示缩略摘要)
        GlassPanel(
          padding: const EdgeInsets.all(16),
          radius: 18,
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: isDark ? AppColors.lime : AppColors.dayBluePrimary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 分章节内容(完整结果,支持 Markdown 渲染)
        ...result.sections.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SectionCard(section: s, isDark: isDark),
            )),

        // 建议操作
        if (result.suggestedActions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SuggestedActionsCard(
            actions: result.suggestedActions,
            onAction: onAction,
          ),
        ],

        // 安全提示
        if (result.safetyNotice != null && result.safetyNotice!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _SafetyNoticeCard(notice: result.safetyNotice!),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.isDark});

  final AgentResultSection section;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _sectionAccent(section.type, isDark);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                section.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: section.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              p: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
                height: 1.7,
                fontSize: 14,
              ),
              h1: theme.textTheme.titleLarge?.copyWith(
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
              h2: theme.textTheme.titleMedium?.copyWith(
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
              h3: theme.textTheme.titleSmall?.copyWith(
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
              code: theme.textTheme.bodySmall?.copyWith(
                backgroundColor: isDark
                    ? AppColors.glassStrong
                    : AppColors.dayGlass,
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
              codeblockDecoration: BoxDecoration(
                color: isDark ? AppColors.glassStrong : AppColors.dayGlass,
                borderRadius: BorderRadius.circular(8),
              ),
              listBullet: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
              ),
              strong: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _sectionAccent(ResultSectionType type, bool isDark) {
    switch (type) {
      case ResultSectionType.formula:
        return isDark ? AppColors.aqua : AppColors.dayBlueAccent;
      case ResultSectionType.reaction:
        return isDark ? AppColors.amber : const Color(0xFFE07B00);
      case ResultSectionType.knowledgeMap:
        return isDark ? AppColors.lime : const Color(0xFF3D8E3D);
      case ResultSectionType.recommendation:
        return isDark ? AppColors.aquaLight : AppColors.dayBluePrimary;
      case ResultSectionType.warning:
        return const Color(0xFFE57373);
      case ResultSectionType.text:
        return isDark ? AppColors.textSecondary : AppColors.dayTextSecondary;
    }
  }
}

class _SuggestedActionsCard extends StatelessWidget {
  const _SuggestedActionsCard({
    required this.actions,
    this.onAction,
  });

  final List<SuggestedAction> actions;
  final SuggestedActionCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                size: 18,
                color: isDark ? AppColors.amber : const Color(0xFFE07B00),
              ),
              const SizedBox(width: 6),
              Text(
                '建议下一步',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map((a) {
              return ActionChip(
                label: Text(a.label),
                avatar: Icon(_actionIcon(a.actionType), size: 16),
                backgroundColor: isDark
                    ? AppColors.aqua.withValues(alpha: 0.10)
                    : AppColors.dayBlueAccent.withValues(alpha: 0.08),
                side: BorderSide(
                  color: isDark
                      ? AppColors.aqua.withValues(alpha: 0.3)
                      : AppColors.dayBlueAccent.withValues(alpha: 0.25),
                ),
                labelStyle: TextStyle(
                  color: isDark ? AppColors.aquaLight : AppColors.dayBluePrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                onPressed: () {
                  if (onAction != null) {
                    onAction!(a);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('即将开放:${a.label}')),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(SuggestedActionType type) {
    switch (type) {
      case SuggestedActionType.practice:
        return Icons.quiz_outlined;
      case SuggestedActionType.review:
        return Icons.replay_outlined;
      case SuggestedActionType.explainMore:
        return Icons.menu_book_outlined;
      case SuggestedActionType.diagnose:
        return Icons.insights_outlined;
      case SuggestedActionType.planLearning:
        return Icons.route_outlined;
      case SuggestedActionType.saveFavorite:
        return Icons.star_border;
    }
  }
}

class _SafetyNoticeCard extends StatelessWidget {
  const _SafetyNoticeCard({required this.notice});

  final String notice;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0x33E57373)
            : const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0x66E57373)
              : const Color(0xFFE0B4B4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              notice,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFFE57373) : const Color(0xFFC62828),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 为 AgentResultSection 扩展 icon getter
extension AgentResultSectionIcon on AgentResultSection {
  IconData get icon {
    switch (type) {
      case ResultSectionType.formula:
        return Icons.science_outlined;
      case ResultSectionType.reaction:
        return Icons.bolt_outlined;
      case ResultSectionType.knowledgeMap:
        return Icons.account_tree_outlined;
      case ResultSectionType.recommendation:
        return Icons.tips_and_updates_outlined;
      case ResultSectionType.warning:
        return Icons.warning_amber_outlined;
      case ResultSectionType.text:
        return Icons.article_outlined;
    }
  }
}
