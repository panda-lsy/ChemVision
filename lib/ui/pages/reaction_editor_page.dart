import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reaction_equation.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../../utils/svg_export.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/ketcher_editor_controller.dart';
import '../widgets/ketcher_editor_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/export_image_dialog.dart';

/// 反应方程式编辑页面
///
/// 使用 Ketcher 的反应模式编辑完整的反应方程式。
/// 上半区：Ketcher 编辑器（反应模式）
/// 下半区：元信息面板（标题、条件、导出、保存）
class ReactionEditorPage extends ConsumerStatefulWidget {
  const ReactionEditorPage({
    super.key,
    this.initialEquation,
  });

  final ReactionEquation? initialEquation;

  @override
  ConsumerState<ReactionEditorPage> createState() => _ReactionEditorPageState();
}

class _ReactionEditorPageState extends ConsumerState<ReactionEditorPage> {
  KetcherEditorController? _controller;
  late ReactionEquation _equation;
  final _titleController = TextEditingController();
  final _temperatureController = TextEditingController();
  final _catalystController = TextEditingController();
  final _solventController = TextEditingController();
  final _otherController = TextEditingController();
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _equation = widget.initialEquation ?? ReactionEquation();
    _titleController.text = _equation.title;
    _temperatureController.text = _equation.conditions['temperature'] ?? '';
    _catalystController.text = _equation.conditions['catalyst'] ?? '';
    _solventController.text = _equation.conditions['solvent'] ?? '';
    _otherController.text = _equation.conditions['other'] ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _temperatureController.dispose();
    _catalystController.dispose();
    _solventController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  /// 保存到收藏
  Future<void> _saveToCollection() async {
    // 从 Ketcher 获取当前数据
    final rxn = await _controller?.getRxn();
    final svg = await _controller?.exportSvg();

    _equation.title = _titleController.text.trim();
    _equation.conditions = {
      'temperature': _temperatureController.text.trim(),
      'catalyst': _catalystController.text.trim(),
      'solvent': _solventController.text.trim(),
      'other': _otherController.text.trim(),
    };
    _equation.rxnData = rxn;
    _equation.svgString = svg;

    // 保存到反应收藏 Hive box
    await ref.read(reactionFavoritesControllerProvider.notifier).add(_equation);

    if (mounted) {
      setState(() => _isDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('反应方程式已保存到收藏')),
      );
    }
  }

  void _showExportDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => ExportImageDialog(
        exportSvg: () => _controller?.exportSvg() ?? Future.value(null),
        exportPng: (bg) => _controller?.exportPng(data: bg) ?? Future.value(null),
      ),
    );
  }

  /// 取消
  Future<void> _cancel() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消编辑'),
        content: const Text('编辑内容尚未保存，确定取消？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续编辑'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定取消'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  /// 导出 SVG
  Future<void> _exportSvg() async {
    final svg = await _controller?.exportSvg();
    if (svg == null || !mounted) return;
    try {
      await downloadSvg(svg, 'reaction_${DateTime.now().millisecondsSinceEpoch}.svg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SVG 已导出')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SVG 导出失败: $e')),
        );
      }
    }
  }

  /// 导出 PNG
  Future<void> _exportPng() async {
    final png = await _controller?.exportPng();
    if (png == null || !mounted) return;
    try {
      await downloadDataUrl(png, 'reaction_${DateTime.now().millisecondsSinceEpoch}.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PNG 已导出')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PNG 导出失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 标题栏 ──
          Row(
            children: [
              IconButton(
                onPressed: _cancel,
                icon: const Icon(Icons.arrow_back),
                color:
                    isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '反应方程式编辑器',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: '导出图片',
                onPressed: _controller == null ? null : () => _showExportDialog(context, isDark),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Ketcher 编辑器区域 ──
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.all(8),
              radius: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: KetcherEditorView(
                  initialSmiles: _equation.rxnData ?? '',
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  onControllerReady: (controller) {
                    _controller = controller;
                  },
                  onSmilesUpdated: (_) => _markDirty(),
                  onError: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── 元信息面板 ──
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 反应标题
                TextField(
                  controller: _titleController,
                  onChanged: (_) => _markDirty(),
                  decoration: const InputDecoration(
                    hintText: '反应标题（可选）',
                    isDense: true,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),

                // 反应条件
                Text('反应条件',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _temperatureController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: '温度',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _catalystController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: '催化剂',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _solventController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: '溶剂',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _otherController,
                        onChanged: (_) => _markDirty(),
                        decoration: const InputDecoration(
                          hintText: '其他条件',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── 操作按钮 ──
          Row(
            children: [
              // 导出按钮
              IconButton(
                onPressed: _exportSvg,
                icon: const Icon(Icons.image, size: 20),
                tooltip: '导出 SVG',
                color:
                    isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
              ),
              IconButton(
                onPressed: _exportPng,
                icon: const Icon(Icons.photo, size: 20),
                tooltip: '导出 PNG',
                color:
                    isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
              ),
              const Spacer(),
              SizedBox(
                height: 42,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
                    side: BorderSide(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _cancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: PrimaryButton(
                  label: '保存到收藏',
                  onPressed: _saveToCollection,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
