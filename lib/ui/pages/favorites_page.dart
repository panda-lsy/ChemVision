import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import 'favorite_detail_page.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesControllerProvider);
    final items = state.filteredItems;

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
              AccentPill(label: '${state.items.length} 个收藏'),
            ],
          ),
          const SizedBox(height: 18),
          Text('收藏', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 14),
          // Search bar
          TextField(
            controller: _searchController,
            cursorColor: AppColors.aqua,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '搜索名称、分子式...',
              prefixIcon:
                  const Icon(Icons.search, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      color: AppColors.textMuted,
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(favoritesControllerProvider.notifier)
                            .search('');
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              ref.read(favoritesControllerProvider.notifier).search(v);
              setState(() {});
            },
          ),
          // Category chips
          if (state.categories.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final all = state.selectedCategory == null;
                    return InputChip(
                      label: const Text('全部'),
                      selected: all,
                      onSelected: (_) {
                        ref
                            .read(favoritesControllerProvider.notifier)
                            .filterByCategory(null);
                      },
                      backgroundColor: AppColors.glass,
                      selectedColor: AppColors.aqua.withOpacity(0.2),
                      labelStyle:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: all
                                    ? AppColors.aqua
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                      side: BorderSide(
                          color: all
                              ? AppColors.aqua.withOpacity(0.4)
                              : Colors.white.withOpacity(0.1)),
                      shape: const StadiumBorder(),
                    );
                  }
                  final cat = state.categories[index - 1];
                  final sel = state.selectedCategory == cat;
                  return InputChip(
                    label: Text(cat),
                    selected: sel,
                    onSelected: (_) {
                      ref
                          .read(favoritesControllerProvider.notifier)
                          .filterByCategory(cat);
                    },
                    backgroundColor: AppColors.glass,
                    selectedColor: AppColors.aqua.withOpacity(0.2),
                    labelStyle:
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: sel
                                  ? AppColors.aqua
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                    side: BorderSide(
                        color: sel
                            ? AppColors.aqua.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1)),
                    shape: const StadiumBorder(),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          // List
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_border,
                            size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          state.searchQuery != null
                              ? '未找到匹配结果'
                              : '暂无收藏',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final r = item.structureResult;
                      final displayName = _displayName(r.resolvedName,
                          r.englishName, r.chineseName);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  FavoriteDetailPage(item: item),
                            ),
                          ),
                          onLongPress: () =>
                              _confirmDelete(context, ref, item.id),
                          child: GlassPanel(
                            radius: 16,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 中英文名称
                                      if (r.chineseName != null &&
                                          r.chineseName!.isNotEmpty) ...[
                                        Text(
                                          r.chineseName!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors
                                                      .textPrimary),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      if (r.englishName != null &&
                                          r.englishName!.isNotEmpty &&
                                          r.englishName !=
                                              r.chineseName) ...[
                                        Text(
                                          r.englishName!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.textSecondary,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                      ],
                                      // 分子式和分子量
                                      Row(
                                        children: [
                                          Text(
                                            r.molecularFormula,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: AppColors.aqua,
                                                    fontWeight:
                                                        FontWeight.w600),
                                          ),
                                          if (r.molecularWeight > 0) ...[
                                            const SizedBox(width: 12),
                                            Text(
                                              '${r.molecularWeight.toStringAsFixed(2)} g/mol',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: AppColors
                                                          .textMuted),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      // 查询关键词
                                      Text(
                                        item.query,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 11,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (item.category != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.aqua.withOpacity(0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      item.category!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.aqua,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _displayName(String? resolved, String? en, String? zh) {
    if (en != null && en.isNotEmpty && zh != null && zh.isNotEmpty) {
      return '$en（$zh）';
    }
    if (en != null && en.isNotEmpty) return en;
    if (zh != null && zh.isNotEmpty) return zh;
    return resolved ?? '';
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('删除收藏'),
        content: const Text('确定要删除这条收藏吗？'),
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
            child: const Text('删除', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
