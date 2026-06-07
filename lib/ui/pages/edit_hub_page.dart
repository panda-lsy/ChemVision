import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'structure_editor_page.dart';
import 'reaction_editor_page.dart';
import 'reaction_page.dart';

/// 编辑入口页
///
/// 替代原 ReactionPage 作为底部导航 Tab。
/// 提供三个入口：结构式编辑器、反应式编辑器、AI 反应补全。
class EditHubPage extends ConsumerWidget {
  const EditHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              const AccentPill(label: '编辑'),
            ],
          ),
          const SizedBox(height: 18),
          Text('编辑工具', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          _buildEntryCard(
            context,
            isDark: isDark,
            icon: Icons.edit_note,
            title: 'Ketcher 编辑器',
            subtitle: '绘制化学结构式与反应方程式，支持导出',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StructureEditorPage(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildEntryCard(
            context,
            isDark: isDark,
            icon: Icons.auto_awesome,
            title: 'AI 反应补全',
            subtitle: '输入反应描述，AI 智能推测缺失的条件和产物',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReactionPage(),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEntryCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassPanel(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
          ],
        ),
      ),
    );
  }
}
