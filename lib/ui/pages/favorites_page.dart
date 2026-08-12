import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/error_book_item.dart';
import '../../providers/error_book_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'favorite_detail_page.dart';
import 'reaction_favorite_detail_page.dart';

enum _FavoritesTab { structure, reaction, errorBook }

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  final _searchController = TextEditingController();
  _FavoritesTab _currentTab = _FavoritesTab.structure;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              AccentPill(label: switch (_currentTab) {
                _FavoritesTab.structure =>
                  '${ref.watch(favoritesControllerProvider).items.length} 个结构式',
                _FavoritesTab.reaction =>
                  '${ref.watch(reactionFavoritesControllerProvider).items.length} 个反应式',
                _FavoritesTab.errorBook =>
                  '${ref.watch(errorBookControllerProvider).items.length} 条错题',
              }),
            ],
          ),
          const SizedBox(height: 18),
          Text('收藏', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),

          // 分栏切换
          _buildTabSwitcher(isDark),
          const SizedBox(height: 14),

          // 搜索栏
          _buildSearchBar(isDark),
          const SizedBox(height: 10),

          // 内容区
          Expanded(
            child: switch (_currentTab) {
              _FavoritesTab.structure => _buildStructureTab(isDark),
              _FavoritesTab.reaction => _buildReactionTab(isDark),
              _FavoritesTab.errorBook => _buildErrorBookTab(isDark),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassStrong : AppColors.dayGlass,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.dayBluePrimary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          _buildTabOption(
            isDark,
            tab: _FavoritesTab.structure,
            label: '结构式',
            icon: Icons.science,
          ),
          _buildTabOption(
            isDark,
            tab: _FavoritesTab.reaction,
            label: '反应式',
            icon: Icons.device_thermostat,
          ),
          _buildTabOption(
            isDark,
            tab: _FavoritesTab.errorBook,
            label: '错题本',
            icon: Icons.menu_book_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTabOption(
    bool isDark, {
    required _FavoritesTab tab,
    required String label,
    required IconData icon,
  }) {
    final selected = _currentTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentTab = tab;
            _searchController.clear();
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? (isDark
                    ? const LinearGradient(
                        colors: [AppColors.aqua, Color(0xFF9EF5D2)])
                    : const LinearGradient(
                        colors: [AppColors.dayBluePrimary, AppColors.dayBlueAccent]))
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected
                      ? (isDark ? AppColors.ink : Colors.white)
                      : (isDark ? AppColors.textSecondary : AppColors.dayTextSecondary)),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selected
                            ? (isDark ? AppColors.ink : Colors.white)
                            : (isDark
                                ? AppColors.textSecondary
                                : AppColors.dayTextSecondary),
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return TextField(
      controller: _searchController,
      cursorColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
      style: TextStyle(
          color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary),
      decoration: InputDecoration(
        hintText: switch (_currentTab) {
          _FavoritesTab.structure => '搜索名称、分子式...',
          _FavoritesTab.reaction => '搜索反应标题、条件...',
          _FavoritesTab.errorBook => '搜索错题标题、内容...',
        },
        prefixIcon: Icon(Icons.search,
            color:
                isDark ? AppColors.textSecondary : AppColors.dayTextSecondary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                onPressed: () {
                  _searchController.clear();
                  switch (_currentTab) {
                    case _FavoritesTab.structure:
                      ref.read(favoritesControllerProvider.notifier).search('');
                    case _FavoritesTab.reaction:
                      ref
                          .read(reactionFavoritesControllerProvider.notifier)
                          .search('');
                    case _FavoritesTab.errorBook:
                      ref.read(errorBookControllerProvider.notifier).search('');
                  }
                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (v) {
        switch (_currentTab) {
          case _FavoritesTab.structure:
            ref.read(favoritesControllerProvider.notifier).search(v);
          case _FavoritesTab.reaction:
            ref.read(reactionFavoritesControllerProvider.notifier).search(v);
          case _FavoritesTab.errorBook:
            ref.read(errorBookControllerProvider.notifier).search(v);
        }
        setState(() {});
      },
    );
  }

  // ── 结构式收藏栏（保留原有逻辑） ──

  Widget _buildStructureTab(bool isDark) {
    final state = ref.watch(favoritesControllerProvider);
    final items = state.filteredItems;

    if (items.isEmpty) {
      return _buildEmptyState(isDark, state.searchQuery != null);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final r = item.structureResult;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FavoriteDetailPage(item: item),
              ),
            ),
            onLongPress: () =>
                _confirmDeleteStructure(context, ref, item.id),
            child: GlassPanel(
              radius: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (r.chineseName != null &&
                            r.chineseName!.isNotEmpty) ...[
                          Text(r.chineseName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textPrimary
                                          : AppColors.dayTextPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                        ],
                        if (r.englishName != null &&
                            r.englishName!.isNotEmpty &&
                            r.englishName != r.chineseName) ...[
                          Text(r.englishName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.textSecondary
                                          : AppColors.dayTextSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                        ],
                        Row(children: [
                          Text(r.molecularFormula,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: isDark
                                          ? AppColors.aqua
                                          : AppColors.dayBluePrimary,
                                      fontWeight: FontWeight.w600)),
                          if (r.molecularWeight > 0) ...[
                            const SizedBox(width: 12),
                            Text('${r.molecularWeight.toStringAsFixed(2)} g/mol',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: isDark
                                            ? AppColors.textMuted
                                            : AppColors.dayTextMuted)),
                          ],
                        ]),
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final tag in item.tags.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.aqua
                                            : AppColors.dayBluePrimary)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.aqua
                                                  : AppColors.dayBluePrimary)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 编辑按钮
                  IconButton(
                    icon: Icon(Icons.edit,
                        size: 18,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FavoriteDetailPage(item: item),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 反应式收藏栏 ──

  Widget _buildReactionTab(bool isDark) {
    final state = ref.watch(reactionFavoritesControllerProvider);
    final items = state.filteredItems;

    if (items.isEmpty) {
      return _buildEmptyState(isDark, state.searchQuery != null);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final eq = item.equation;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReactionFavoriteDetailPage(item: item),
              ),
            ),
            onLongPress: () =>
                _confirmDeleteReaction(context, ref, item.id),
            child: GlassPanel(
              radius: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eq.title.isNotEmpty ? eq.title : '未命名反应',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textPrimary
                                      : AppColors.dayTextPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (eq.conditionSummary.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '条件: ${eq.conditionSummary}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textMuted
                                      : AppColors.dayTextMuted,
                                  fontSize: 11,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final tag in item.tags.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.aqua
                                            : AppColors.dayBluePrimary)
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(tag,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 10,
                                              color: isDark
                                                  ? AppColors.aqua
                                                  : AppColors.dayBluePrimary)),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 编辑按钮
                  IconButton(
                    icon: Icon(Icons.edit,
                        size: 18,
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ReactionFavoriteDetailPage(item: item),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 错题本栏 ──

  Widget _buildErrorBookTab(bool isDark) {
    final state = ref.watch(errorBookControllerProvider);
    final items = state.filteredItems;

    if (items.isEmpty) {
      return _buildEmptyState(isDark, state.searchQuery != null);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _showErrorBookDetail(item),
            onLongPress: () => _confirmDeleteErrorBook(context, ref, item.id),
            child: GlassPanel(
              radius: 16,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              item.reviewed
                                  ? Icons.check_circle
                                  : Icons.bookmark_border,
                              size: 16,
                              color: item.reviewed
                                  ? (isDark
                                      ? AppColors.lime
                                      : const Color(0xFF3D8E3D))
                                  : (isDark
                                      ? AppColors.amber
                                      : const Color(0xFFE07B00)),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.title,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textPrimary
                                          : AppColors.dayTextPrimary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (item.compoundName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '化合物: ${item.compoundName}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.aqua
                                      : AppColors.dayBluePrimary,
                                  fontSize: 12,
                                ),
                          ),
                        ],
                        if (item.preview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            item.preview,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondary
                                      : AppColors.dayTextSecondary,
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.knowledgePointIds.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final kp in item.knowledgePointIds.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: (isDark
                                            ? AppColors.amber
                                            : const Color(0xFFE07B00))
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    kp,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppColors.amber
                                              : const Color(0xFFE07B00),
                                        ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(item.createdAt),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.textMuted
                                    : AppColors.dayTextMuted,
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // 标记已复习
                  IconButton(
                    icon: Icon(
                      item.reviewed
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 18,
                      color: item.reviewed
                          ? (isDark
                              ? AppColors.lime
                              : const Color(0xFF3D8E3D))
                          : (isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted),
                    ),
                    onPressed: () => ref
                        .read(errorBookControllerProvider.notifier)
                        .toggleReviewed(item.id),
                    tooltip: item.reviewed ? '标记未复习' : '标记已复习',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorBookDetail(ErrorBookItem item) {
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
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.dayTextPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.dayTextMuted,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    if (item.compoundName.isNotEmpty)
                      Text(
                        '化合物: ${item.compoundName}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.aqua
                              : AppColors.dayBluePrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (item.smiles.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'SMILES: ${item.smiles}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    GlassPanel(
                      padding: const EdgeInsets.all(12),
                      radius: 12,
                      child: Text(
                        item.content,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.7,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                      ),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '备注: ${item.note}',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              ref
                                  .read(errorBookControllerProvider.notifier)
                                  .toggleReviewed(item.id);
                              Navigator.pop(context);
                            },
                            icon: Icon(
                              item.reviewed
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: isDark
                                  ? AppColors.lime
                                  : const Color(0xFF3D8E3D),
                            ),
                            label: Text(
                              item.reviewed ? '已复习' : '标记已复习',
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.lime
                                    : const Color(0xFF3D8E3D),
                              ),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _confirmDeleteErrorBook(context, ref, item.id);
                          },
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          label: const Text('删除',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteErrorBook(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除错题'),
        content: const Text('确定要删除这条错题吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(errorBookControllerProvider.notifier).delete(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.redAccent)),
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

  Widget _buildEmptyState(bool isDark, bool hasSearch) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_border,
              size: 48,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted),
          const SizedBox(height: 12),
          Text(
            hasSearch ? '未找到匹配结果' : '暂无收藏',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color:
                    isDark ? AppColors.textMuted : AppColors.dayTextMuted),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteStructure(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏'),
        content: const Text('确定要删除这条结构式收藏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(favoritesControllerProvider.notifier).delete(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteReaction(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏'),
        content: const Text('确定要删除这条反应式收藏吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(reactionFavoritesControllerProvider.notifier)
                  .delete(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('删除',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
