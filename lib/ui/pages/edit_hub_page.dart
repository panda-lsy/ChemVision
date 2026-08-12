import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/edit_history_item.dart';
import '../../models/reaction_equation.dart';
import '../../providers/edit_history_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../providers/structure_service_provider.dart';
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

  /// 打开 Ketcher 编辑器，处理返回结果（区分结构式/反应式）
  Future<void> _openKetcherEditor(
      BuildContext context, WidgetRef ref) async {
    final resultMap = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => const StructureEditorPage(),
      ),
    );
    if (resultMap == null || !context.mounted) return;
    final result = resultMap['smiles'] ?? '';
    if (result.isEmpty) return;

    // 区分结构式和反应式
    final isReaction = result.contains('>') || result.contains('>>');

    if (isReaction) {
      // 反应式：保存到反应收藏
      final equation = ReactionEquation(
        title: '',
        rxnData: result,
        reactionType: '',
        explanation: '',
        conditionRationale: '',
        sourceReferences: const [],
        confidence: 1.0,
      );
      ref.read(reactionFavoritesControllerProvider.notifier).add(equation);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到反应收藏')),
        );
      }
    } else {
      // 结构式：AI 推测名称后保存到结构收藏
      try {
        final service = ref.read(structureServiceProvider);
        final resolved = await service.reverseResolveName(result);
        final name = resolved.isValid
            ? (resolved.chineseName ?? resolved.englishName ?? resolved.resolvedName ?? '')
            : '';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已保存: $name')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('结构式已保存')),
          );
        }
      }
    }
  }

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
              Text('ChemEdu',
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
            onTap: () => _openKetcherEditor(context, ref),
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
          // ── 编辑历史 ──
          _buildHistorySection(context, ref, isDark),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      BuildContext context, WidgetRef ref, bool isDark) {
    final historyState = ref.watch(editHistoryControllerProvider);
    final items = historyState.items;

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('编辑历史',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => ref
                  .read(editHistoryControllerProvider.notifier)
                  .clearAll(),
              child: const Text('清空', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.take(20).map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StructureEditorPage(
                      initialSmiles: item.smiles,
                    ),
                  ),
                ),
                child: GlassPanel(
                  radius: 14,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      // 类型标签
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (item.isReaction
                                  ? AppColors.amber
                                  : (isDark
                                      ? AppColors.aqua
                                      : AppColors.dayBluePrimary))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.isReaction ? '反应' : '结构',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: item.isReaction
                                ? AppColors.amber
                                : (isDark
                                    ? AppColors.aqua
                                    : AppColors.dayBluePrimary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // SMILES
                      Expanded(
                        child: Text(
                          item.smiles,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontFamily: 'monospace',
                                color: isDark
                                    ? AppColors.textMuted
                                    : AppColors.dayTextMuted,
                              ),
                        ),
                      ),
                      // 删除
                      GestureDetector(
                        onTap: () => ref
                            .read(editHistoryControllerProvider.notifier)
                            .delete(item.id),
                        child: Icon(Icons.close,
                            size: 14,
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.dayTextMuted),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
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
