import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_view.dart';
import '../widgets/structure_view_controller.dart';

class FavoriteDetailPage extends ConsumerStatefulWidget {
  const FavoriteDetailPage({super.key, required this.item});

  final FavoriteItem item;

  @override
  ConsumerState<FavoriteDetailPage> createState() =>
      _FavoriteDetailPageState();
}

class _FavoriteDetailPageState extends ConsumerState<FavoriteDetailPage> {
  StructureViewController? _controller;
  late TextEditingController _notesController;
  late TextEditingController _categoryController;
  late TextEditingController _tagInputController;
  late List<String> _tags;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _notesController =
        TextEditingController(text: widget.item.notes ?? '');
    _categoryController =
        TextEditingController(text: widget.item.category ?? '');
    _tagInputController = TextEditingController();
    _tags = List<String>.from(widget.item.tags);
  }

  @override
  void dispose() {
    _notesController.dispose();
    _categoryController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _addTag(String tag) {
    final t = tag.trim();
    if (t.isNotEmpty && !_tags.contains(t)) {
      setState(() {
        _tags.add(t);
        _isDirty = true;
      });
    }
    _tagInputController.clear();
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _isDirty = true;
    });
  }

  Future<void> _save() async {
    final updated = widget.item.copyWith(
      category: _categoryController.text.trim().isNotEmpty
          ? _categoryController.text.trim()
          : null,
      tags: _tags,
      notes: _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null,
      clearCategory: _categoryController.text.trim().isEmpty,
      clearNotes: _notesController.text.trim().isEmpty,
    );
    await ref
        .read(favoritesControllerProvider.notifier)
        .updateItem(updated);
    setState(() => _isDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.item.structureResult;
    final displayName =
        _displayName(r.resolvedName, r.englishName, r.chineseName);

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
              const AccentPill(label: '收藏详情'),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.item.query,
              style: Theme.of(context).textTheme.headlineMedium),
          if (displayName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('标准名称 $displayName',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          // 结构式渲染卡片
          GlassPanel(
            padding: EdgeInsets.zero,
            radius: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = (constraints.maxWidth * 0.7)
                      .clamp(400.0, 700.0)
                      .toDouble();
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: StructureView(
                      smiles: r.smiles,
                      readOnly: true,
                      interactive: false,
                      onControllerReady: (c) => _controller = c,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 分子信息
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.molecularFormula.isNotEmpty)
                  Text(
                    r.molecularFormula,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: isDark
                            ? const Color(0xFFF9F3DD)
                            : AppColors.dayBluePrimary,
                        fontWeight: FontWeight.w700),
                  ),
                if (r.molecularWeight > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '分子量 ${r.molecularWeight.toStringAsFixed(2)} g/mol',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.glass
                        : AppColors.dayGlassStrong,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    'SMILES: ${r.smiles}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.dayTextMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // ── 编辑区：分类 ──
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分类',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _categoryController,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    hintText: '输入分类，如：有机化学、醇类',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── 编辑区：标签 ──
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('标签',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_tags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _tags
                        .map((tag) => Chip(
                              label: Text(tag,
                                  style: const TextStyle(fontSize: 12)),
                              deleteIcon:
                                  const Icon(Icons.close, size: 14),
                              onDeleted: () => _removeTag(tag),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: isDark
                                  ? AppColors.aqua.withValues(alpha: 0.15)
                                  : AppColors.dayBluePrimary
                                      .withValues(alpha: 0.10),
                              side: BorderSide(
                                  color: (isDark
                                          ? AppColors.aqua
                                          : AppColors.dayBluePrimary)
                                      .withValues(alpha: 0.3)),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tagInputController,
                  onSubmitted: _addTag,
                  decoration: InputDecoration(
                    hintText: '输入标签，回车添加',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () =>
                          _addTag(_tagInputController.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── 编辑区：笔记 ──
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('笔记',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  onChanged: (_) => _markDirty(),
                  maxLines: 4,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: '记录学习心得、易错点、关键知识点...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // ── 操作按钮 ──
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.textPrimary
                          : AppColors.dayTextPrimary,
                      side: BorderSide(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PrimaryButton(
                    label: _isDirty ? '保存修改' : '已保存',
                    onPressed: _isDirty ? _save : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 48,
                width: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(
                        color: Colors.redAccent, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除收藏'),
                        content: const Text('确定删除此收藏？不可撤销。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref
                                  .read(favoritesControllerProvider
                                      .notifier)
                                  .delete(widget.item.id);
                              Navigator.of(context).pop();
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.redAccent),
                            child: const Text('删除'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Icon(Icons.delete_outline, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
}
