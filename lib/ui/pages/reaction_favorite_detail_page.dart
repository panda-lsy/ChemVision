import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reaction_equation.dart';
import '../../models/reaction_favorite_item.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import 'reaction_editor_page.dart';

class ReactionFavoriteDetailPage extends ConsumerStatefulWidget {
  const ReactionFavoriteDetailPage({super.key, required this.item});

  final ReactionFavoriteItem item;

  @override
  ConsumerState<ReactionFavoriteDetailPage> createState() =>
      _ReactionFavoriteDetailPageState();
}

class _ReactionFavoriteDetailPageState
    extends ConsumerState<ReactionFavoriteDetailPage> {
  late TextEditingController _notesController;
  late TextEditingController _categoryController;
  late TextEditingController _tagInputController;
  late List<String> _tags;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes ?? '');
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
        .read(reactionFavoritesControllerProvider.notifier)
        .updateItem(updated);
    setState(() => _isDirty = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }

  void _editAllInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EditReactionSheet(
        equation: widget.item.equation,
        onSaved: (updated) async {
          // Create new item with updated equation
          final newItem = ReactionFavoriteItem(
            id: widget.item.id,
            equation: updated,
            createdAt: widget.item.createdAt,
            category: widget.item.category,
            tags: widget.item.tags,
            notes: widget.item.notes,
          );
          await ref
              .read(reactionFavoritesControllerProvider.notifier)
              .updateItem(newItem);
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eq = widget.item.equation;

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
              const AccentPill(label: '反应收藏'),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            eq.title.isNotEmpty ? eq.title : '未命名反应',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          if (eq.conditionSummary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '条件: ${eq.conditionSummary}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),

          // 反应方程式（语义补全结果）
          if (eq.rxnData != null && eq.rxnData!.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('反应方程式',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(
                    eq.rxnData!,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFF9F3DD)
                              : AppColors.dayBluePrimary,
                        ),
                  ),
                  if (eq.reactionType.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.category_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text('类型: ${eq.reactionType}',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                  if (eq.confidence > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 16),
                        const SizedBox(width: 6),
                        Text(
                            '置信度: ${(eq.confidence * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          // 详细条件
          if (eq.conditionSummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('反应条件',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(eq.conditionSummary,
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (eq.conditionRationale.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('推断依据:',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Text(eq.conditionRationale,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondary
                                  : AppColors.dayTextSecondary,
                            )),
                  ],
                ],
              ),
            ),
          ],
          // 推理说明
          if (eq.explanation.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('推理说明',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(eq.explanation,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
          // 来源引用
          if (eq.sourceReferences.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('来源引用',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ...eq.sourceReferences.map((ref) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.link, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(ref,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],
          // SVG 预览（如果有）
          if (eq.svgString != null && eq.svgString!.isNotEmpty)
            GlassPanel(
              padding: const EdgeInsets.all(16),
              radius: 20,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 120),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.glass
                      : AppColors.dayGlassStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '反应方程式预览',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),

          // 分类编辑
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('分类', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _categoryController,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    hintText: '输入分类，如：有机反应、氧化还原',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 标签编辑
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('标签', style: Theme.of(context).textTheme.titleMedium),
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
                      onPressed: () => _addTag(_tagInputController.text),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 笔记
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('笔记', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  onChanged: (_) => _markDirty(),
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    hintText: '记录反应要点...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 操作按钮
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
                      side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.2),
                      ),
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
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.aqua
                          : AppColors.dayBluePrimary,
                      side: BorderSide(
                        color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                            .withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _editAllInfo(context),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PrimaryButton(
                    label: _isDirty ? '保存' : '已保存',
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
                    side: const BorderSide(color: Colors.redAccent),
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
                        content: const Text('确定删除此反应收藏？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              ref
                                  .read(reactionFavoritesControllerProvider
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
}


class _EditReactionSheet extends StatefulWidget {
  const _EditReactionSheet({required this.equation, this.onSaved});
  final ReactionEquation equation;
  final void Function(ReactionEquation updated)? onSaved;

  @override
  State<_EditReactionSheet> createState() => _EditReactionSheetState();
}

class _EditReactionSheetState extends State<_EditReactionSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _eqCtrl;
  late TextEditingController _typeCtrl;
  late TextEditingController _tempCtrl;
  late TextEditingController _catCtrl;
  late TextEditingController _solCtrl;
  late TextEditingController _otherCtrl;
  late TextEditingController _rationaleCtrl;
  late TextEditingController _explanationCtrl;

  @override
  void initState() {
    super.initState();
    final eq = widget.equation;
    _titleCtrl = TextEditingController(text: eq.title);
    _eqCtrl = TextEditingController(text: eq.rxnData ?? '');
    _typeCtrl = TextEditingController(text: eq.reactionType);
    _tempCtrl = TextEditingController(text: eq.conditions['temperature'] ?? '');
    _catCtrl = TextEditingController(text: eq.conditions['catalyst'] ?? '');
    _solCtrl = TextEditingController(text: eq.conditions['solvent'] ?? '');
    _otherCtrl = TextEditingController(text: eq.conditions['other'] ?? '');
    _rationaleCtrl = TextEditingController(text: eq.conditionRationale);
    _explanationCtrl = TextEditingController(text: eq.explanation);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _eqCtrl.dispose();
    _typeCtrl.dispose();
    _tempCtrl.dispose();
    _catCtrl.dispose();
    _solCtrl.dispose();
    _otherCtrl.dispose();
    _rationaleCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.equation.copyWith(
      title: _titleCtrl.text.trim(),
      rxnData: _eqCtrl.text.trim(),
      reactionType: _typeCtrl.text.trim(),
      explanation: _explanationCtrl.text.trim(),
      conditionRationale: _rationaleCtrl.text.trim(),
      conditions: {
        'temperature': _tempCtrl.text.trim(),
        'catalyst': _catCtrl.text.trim(),
        'solvent': _solCtrl.text.trim(),
        'other': _otherCtrl.text.trim(),
      },
    );
    widget.onSaved?.call(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0d1627) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('编辑反应信息', style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: '标题')),
                const SizedBox(height: 10),
                TextField(controller: _eqCtrl, decoration: const InputDecoration(labelText: '反应方程式'), maxLines: 3),
                const SizedBox(height: 10),
                TextField(controller: _typeCtrl, decoration: const InputDecoration(labelText: '反应类型')),
                const SizedBox(height: 10),
                Text('反应条件', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(controller: _tempCtrl, decoration: const InputDecoration(labelText: '温度'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _catCtrl, decoration: const InputDecoration(labelText: '催化剂'))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: _solCtrl, decoration: const InputDecoration(labelText: '溶剂'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _otherCtrl, decoration: const InputDecoration(labelText: '其他'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: _rationaleCtrl, decoration: const InputDecoration(labelText: '条件推断依据'), maxLines: 2),
                const SizedBox(height: 10),
                TextField(controller: _explanationCtrl, decoration: const InputDecoration(labelText: '推理说明'), maxLines: 3),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.aqua,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    child: const Text('保存'),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
