import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';

/// 搜索历史页面 — 表格布局
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  void _useQuery(String query) {
    ref.read(searchQueryControllerProvider.notifier).state = query;
    ref.read(bottomNavIndexProvider.notifier).state = 0;
  }

  void _removeQuery(String query) {
    ref.read(searchHistoryListProvider.notifier).remove(query);
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('清空历史'),
        content: const Text('确定要清空所有搜索历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(searchHistoryListProvider.notifier).clear();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.aqua),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allHistory = ref.watch(searchHistoryListProvider);

    return AppScaffold(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              AccentPill(label: '${allHistory.length} 条记录'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('搜索历史',
                  style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (allHistory.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  onPressed: _clearAll,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: allHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          '暂无搜索历史',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : GlassPanel(
                    radius: 22,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 8),
                    child: Column(
                      children: [
                        // 表头
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '搜索内容',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '使用',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : AppColors.dayBluePrimary
                                  .withValues(alpha: 0.1),
                        ),
                        // 表格内容
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: allHistory.length,
                            itemBuilder: (context, index) {
                              final item = allHistory[index];
                              return _HistoryRow(
                                query: item,
                                isDark: isDark,
                                onUse: () => _useQuery(item),
                                onDelete: () => _removeQuery(item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.query,
    required this.isDark,
    required this.onUse,
    required this.onDelete,
  });

  final String query;
  final bool isDark;
  final VoidCallback onUse;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppColors.dayBluePrimary.withValues(alpha: 0.06),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              query,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          SizedBox(
            width: 56,
            child: TextButton(
              onPressed: onUse,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor:
                    isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
              child: const Text('使用', style: TextStyle(fontSize: 13)),
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              color: AppColors.textMuted,
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
