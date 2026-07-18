import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/scan_history_item.dart';
import '../../providers/scan_history_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'structure_recognition_page.dart';

/// 历史页面 — 顶部 Tab 切换"搜索历史"与"扫描历史"
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchCount = ref.watch(searchHistoryListProvider).length;
    final scanState = ref.watch(scanHistoryControllerProvider);
    final scanCount = scanState.items.length;

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
              AccentPill(
                  label: _tabController.index == 0
                      ? '$searchCount 条记录'
                      : '$scanCount 条记录'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Text('历史记录',
                  style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 14),
          // Tab 切换
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glass
                  : AppColors.dayGlass,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: '搜索历史'),
                Tab(text: '扫描历史'),
              ],
              labelColor:
                  isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              unselectedLabelColor: AppColors.textMuted,
              indicator: BoxDecoration(
                color: isDark
                    ? AppColors.glassStrong
                    : AppColors.dayBluePrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return IndexedStack(
                  index: _tabController.index,
                  children: [
                    _SearchHistoryTab(isDark: isDark),
                    _ScanHistoryTab(isDark: isDark),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 搜索历史 Tab
// ──────────────────────────────────────────────────────────────────────────

class _SearchHistoryTab extends ConsumerWidget {
  const _SearchHistoryTab({required this.isDark});
  final bool isDark;

  void _useQuery(WidgetRef ref, String query) {
    ref.read(searchQueryControllerProvider.notifier).state = query;
    ref.read(bottomNavIndexProvider.notifier).state = 0;
  }

  void _removeQuery(WidgetRef ref, String query) {
    ref.read(searchHistoryListProvider.notifier).remove(query);
  }

  void _clearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('清空搜索历史'),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final allHistory = ref.watch(searchHistoryListProvider);
    if (allHistory.isEmpty) {
      return const _EmptyState(
        icon: Icons.history,
        text: '暂无搜索历史',
      );
    }
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '搜索内容',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: () => _clearAll(context, ref),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.dayBluePrimary.withValues(alpha: 0.1),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: allHistory.length,
              itemBuilder: (context, index) {
                final query = allHistory[index];
                return _HistoryRow(
                  query: query,
                  isDark: isDark,
                  onUse: () => _useQuery(ref, query),
                  onDelete: () => _removeQuery(ref, query),
                );
              },
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

// ──────────────────────────────────────────────────────────────────────────
// 扫描历史 Tab
// ──────────────────────────────────────────────────────────────────────────

class _ScanHistoryTab extends ConsumerWidget {
  const _ScanHistoryTab({required this.isDark});
  final bool isDark;

  void _clearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('清空扫描历史'),
        content: const Text('确定要清空所有扫描历史吗？原图将一并删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(scanHistoryControllerProvider.notifier).clearAll();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.aqua),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanHistoryControllerProvider);
    if (state.items.isEmpty) {
      return const _EmptyState(
        icon: Icons.document_scanner_outlined,
        text: '暂无扫描历史',
      );
    }
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '扫描结果',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '查看',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    color: AppColors.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                        minWidth: 32, minHeight: 32),
                    onPressed: () => _clearAll(context, ref),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.dayBluePrimary.withValues(alpha: 0.1),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return _ScanHistoryRow(
                  item: item,
                  isDark: isDark,
                  onUse: () => _openScanResult(context, ref, item),
                  onDelete: () => ref
                      .read(scanHistoryControllerProvider.notifier)
                      .delete(item.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openScanResult(
      BuildContext context, WidgetRef ref, ScanHistoryItem item) {
    // 用原图重新进入 OCSR 流程,以便对照显示原图与识别结果
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StructureRecognitionPage.fromScanHistory(item),
      ),
    );
  }
}

class _ScanHistoryRow extends StatelessWidget {
  const _ScanHistoryRow({
    required this.item,
    required this.isDark,
    required this.onUse,
    required this.onDelete,
  });

  final ScanHistoryItem item;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // 原图缩略图(供对照记忆)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              item.imageBytes,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: AppColors.glass,
                child: const Icon(Icons.broken_image, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.molecularFormula.isNotEmpty
                      ? '${item.molecularFormula} · 完整度 ${(item.completenessScore * 100).toInt()}%'
                      : '完整度 ${(item.completenessScore * 100).toInt()}%',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatTime(item.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                ),
              ],
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
              child: const Text('查看', style: TextStyle(fontSize: 13)),
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

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }
}

// ──────────────────────────────────────────────────────────────────────────
// 空状态
// ──────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
