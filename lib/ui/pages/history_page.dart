import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/quick_tag.dart';

/// 搜索历史页面
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  @override
  Widget build(BuildContext context) {
    // 使用 ref.watch 监听 Provider 变化
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
              Text('搜索历史', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              if (allHistory.isNotEmpty)
                TextButton.icon(
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: const Text('清空'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                  ),
                  onPressed: () {
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
                              // 清空并同步更新
                              ref.read(searchHistoryListProvider.notifier).clear();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.aqua,
                            ),
                            child: const Text('清空'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
              const SizedBox(height: 14),
          // 历史列表区域 - 使用 Expanded 占满剩余空间
          Expanded(
            child: allHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
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
                : Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 200),
                    child: GlassPanel(
                      radius: 22,
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: allHistory
                              .map(
                                (item) => SizedBox(
                                  width: (MediaQuery.of(context).size.width - 48) / 2, // 每行两个，减去 padding
                                  child: QuickTag(
                                    label: item,
                                    onTap: () {
                                      // 不关闭页面，只显示提示
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('已选择：$item'),
                                          backgroundColor: AppColors.aqua,
                                          action: SnackBarAction(
                                            label: '使用',
                                            textColor: Colors.white,
                                            onPressed: () {
                                              // 设置搜索词
                                              ref.read(searchQueryControllerProvider.notifier).state = item;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('已填充到输入框，请切换到"识别"标签页'),
                                                  backgroundColor: AppColors.aqua,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                    onDelete: () {
                                      // 删除并同步更新
                                      ref.read(searchHistoryListProvider.notifier).remove(item);
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
