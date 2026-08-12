import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../models/agent_session_record.dart';
import '../../models/agent_task.dart';
import '../../models/scan_history_item.dart';
import '../../providers/agent_provider.dart';
import '../../providers/scan_history_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'structure_recognition_page.dart';

/// 历史页面 — 顶部 Tab 切换"搜索历史"、"扫描历史"与"对话历史"
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
    _tabController = TabController(length: 3, vsync: this);
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
    final chatCount =
        ref.watch(agentControllerProvider.select((s) => s.sessions.length));

    final countLabel = switch (_tabController.index) {
      0 => '$searchCount 条记录',
      1 => '$scanCount 条记录',
      _ => '$chatCount 条记录',
    };

    return AppScaffold(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemEdu',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              AccentPill(label: countLabel),
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
                Tab(text: '对话历史'),
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
                    _ChatHistoryTab(isDark: isDark),
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
// 对话历史 Tab
// ──────────────────────────────────────────────────────────────────────────

class _ChatHistoryTab extends ConsumerWidget {
  const _ChatHistoryTab({required this.isDark});
  final bool isDark;

  void _clearAll(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('清空对话历史'),
        content: const Text('确定要清空所有对话历史吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(agentControllerProvider.notifier).clearAllSessions();
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
    final sessions =
        ref.watch(agentControllerProvider.select((s) => s.sessions));
    if (sessions.isEmpty) {
      return const _EmptyState(
        icon: Icons.chat_outlined,
        text: '暂无对话历史',
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
                    '对话内容',
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
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return _ChatHistoryRow(
                  session: session,
                  isDark: isDark,
                  onTap: () => _openChatDetail(context, ref, session),
                  onDelete: () => ref
                      .read(agentControllerProvider.notifier)
                      .deleteSession(session.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openChatDetail(
      BuildContext context, WidgetRef ref, AgentSessionRecord session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: isDark ? AppColors.navy : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.aqua
                                : AppColors.dayBluePrimary)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        session.typeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.aqua
                              : AppColors.dayBluePrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(session.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    // 用户问题
                    GlassPanel(
                      padding: const EdgeInsets.all(12),
                      radius: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: isDark
                                    ? AppColors.textSecondary
                                    : AppColors.dayTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '我的问题',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.dayTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            session.userInput,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.dayTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Agent 回答
                    if (session.resultTitle != null) ...[
                      Text(
                        session.resultTitle!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.dayTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (session.resultSummary != null &&
                        session.resultSummary!.isNotEmpty) ...[
                      Text(
                        session.resultSummary!,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    ...session.sections.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GlassPanel(
                          padding: const EdgeInsets.all(12),
                          radius: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.aqua
                                      : AppColors.dayBluePrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                s.content,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.7,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.dayTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (session.error != null &&
                        session.error!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFC62828), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                session.error!,
                                style: const TextStyle(
                                  color: Color(0xFFC62828),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (session.safetyNotice != null &&
                        session.safetyNotice!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isDark
                                  ? AppColors.amber
                                  : const Color(0xFFE07B00))
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: isDark
                                  ? AppColors.amber
                                  : const Color(0xFFE07B00),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                session.safetyNotice!,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.dayTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
  }
}

class _ChatHistoryRow extends StatelessWidget {
  const _ChatHistoryRow({
    required this.session,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
  });

  final AgentSessionRecord session;
  final bool isDark;
  final VoidCallback onTap;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (isDark
                                ? AppColors.aqua
                                : AppColors.dayBluePrimary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        session.typeLabel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.aqua
                              : AppColors.dayBluePrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (session.status == AgentTaskStatus.failed)
                      Text(
                        '· 失败',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? const Color(0xFFE57373)
                              : const Color(0xFFC62828),
                        ),
                      ),
                    const Spacer(),
                    Text(
                      _formatTime(session.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.userInput,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (session.preview.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    session.preview,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                          fontSize: 11,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 56,
            child: TextButton(
              onPressed: onTap,
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
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${dt.month}/${dt.day}';
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
