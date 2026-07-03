import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/edit_history_item.dart';
import '../../providers/edit_history_provider.dart';
import '../../providers/structure_service_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/ketcher_editor_controller.dart';
import '../widgets/ketcher_editor_view.dart';
import '../widgets/primary_button.dart';
import 'save_confirm_page.dart';

class StructureEditorPage extends ConsumerStatefulWidget {
  const StructureEditorPage({
    super.key,
    this.initialSmiles = '',
    this.title,
    this.skipSaveConfirm = false,
  });

  final String initialSmiles;
  final String? title;

  /// true: skip confirm page after naming (used when caller handles save itself).
  final bool skipSaveConfirm;

  @override
  ConsumerState<StructureEditorPage> createState() =>
      _StructureEditorPageState();
}

class _StructureEditorPageState extends ConsumerState<StructureEditorPage> {
  KetcherEditorController? _controller;
  String _currentSmiles = '';
  bool _isDirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentSmiles = widget.initialSmiles;
  }

  Future<void> _saveAndBack() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final latest = await _controller?.getSmiles();
      if (!mounted) return;
      final rawSmiles = (latest != null && latest.isNotEmpty)
          ? latest
          : _currentSmiles.trim();
      final smiles = rawSmiles.trim();

      if (smiles.isEmpty || smiles == '{}') {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先绘制结构式')),
          );
        }
        return;
      }

      // 1. AI 推断名称（异步加载，带 loading 态）
      String aiName = '';
      try {
        final service = _getStructureService();
        if (service != null) {
          final result = await service.reverseResolveName(smiles);
          if (result.isValid) {
            aiName = result.chineseName ??
                result.englishName ??
                result.resolvedName ??
                '';
          }
        }
      } catch (_) {}

      if (!mounted) return;

      // 2. 弹出命名页面（AI 名称预填），用户可编辑
      final namingResult =
          await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _SaveNamingPage(
            smiles: smiles,
            prefillName: aiName,
            structureService: _getStructureService(),
          ),
        ),
      );

      if (!mounted) return;
      if (namingResult == null) {
        setState(() => _isSaving = false);
        return; // user cancelled naming
      }

      final finalSmiles = namingResult['smiles'] ?? smiles;
      final finalName = namingResult['name'] ?? '';

      // 3. 保存到编辑历史
      final historyItem = EditHistoryItem.fromSmiles(finalSmiles);
      ref.read(editHistoryControllerProvider.notifier).add(historyItem);

      // 4. 根据来源决定是否显示确认页
      if (widget.skipSaveConfirm) {
        // 从识别/生成结构进入：不弹确认页，直接返回
        if (!mounted) return;
        Navigator.of(context).pop(finalSmiles);
        return;
      }

      // 从编辑-Ketcher进入：弹出确认页
      final shouldFavorite = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) =>
              SaveConfirmPage(smiles: finalSmiles, aiName: finalName),
        ),
      );

      if (!mounted) return;

      if (shouldFavorite == true) {
        final isReaction = EditHistoryItem.isReactionSmiles(finalSmiles);
        if (isReaction) {
          Navigator.of(context).pop(finalSmiles);
        } else {
          // 收藏：再次弹出命名页让用户最终确认名称
          final favResult =
              await Navigator.of(context).push<Map<String, String>>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => _SaveNamingPage(
                smiles: finalSmiles,
                prefillName: finalName,
                structureService: _getStructureService(),
              ),
            ),
          );
          if (favResult != null && mounted) {
            Navigator.of(context)
                .pop(favResult['smiles'] ?? finalSmiles);
          }
        }
      } else {
        Navigator.of(context).pop(finalSmiles);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _cancel() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _ConfirmCancelPage(),
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  dynamic _getStructureService() {
    try {
      return ref.read(structureServiceProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = widget.title ?? '结构编辑器';

    return AppScaffold(
      scroll: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _isSaving ? null : _cancel,
                icon: const Icon(Icons.arrow_back),
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0f172a) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.dayBluePrimary.withValues(alpha: 0.12),
                  ),
                ),
                child: KetcherEditorView(
                  initialSmiles: _currentSmiles,
                  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
                  onControllerReady: (controller) {
                    _controller = controller;
                  },
                  onSmilesUpdated: (smiles) {
                    setState(() {
                      _currentSmiles = smiles;
                      _isDirty = true;
                    });
                  },
                  onError: (message) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? AppColors.glass : AppColors.dayGlassStrong,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _currentSmiles.isEmpty
                  ? 'SMILES: （画板为空）'
                  : 'SMILES: $_currentSmiles',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.dayTextMuted,
                    fontFamily: 'monospace',
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 44,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                    side: BorderSide(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _isSaving ? null : _cancel,
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: PrimaryButton(
                    label: _isSaving ? 'AI 识别名称中…' : '保存并返回',
                    onPressed: _isSaving ? null : _saveAndBack,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 全屏命名页面（避免 iframe z-index 问题）
class _SaveNamingPage extends StatefulWidget {
  const _SaveNamingPage({
    required this.smiles,
    this.prefillName = '',
    this.structureService,
  });
  final String smiles;
  final String prefillName;
  final dynamic structureService;

  @override
  State<_SaveNamingPage> createState() => _SaveNamingPageState();
}

class _SaveNamingPageState extends State<_SaveNamingPage> {
  final _nameController = TextEditingController();
  bool _isResolving = false;
  bool _autoResolved = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.prefillName;
    if (widget.prefillName.isEmpty && !_autoResolved) {
      // auto-resolve if no prefill name provided (e.g. re-edit from results)
      WidgetsBinding.instance.addPostFrameCallback((_) => _aiResolve());
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _aiResolve() async {
    if (widget.structureService == null) return;
    if (_isResolving) return;
    setState(() => _isResolving = true);
    try {
      final result =
          await widget.structureService.reverseResolveName(widget.smiles);
      if (result.isValid && mounted) {
        final name = result.chineseName ??
            result.englishName ??
            result.resolvedName ??
            '';
        if (name.isNotEmpty) {
          setState(() => _nameController.text = name);
        }
      }
    } catch (e) {
      debugPrint('[AI命名] 失败: $e');
    }
    if (mounted) {
      setState(() {
        _isResolving = false;
        _autoResolved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0d1627) : Colors.white,
      appBar: AppBar(
        title: const Text('更新名称'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? AppColors.glass : AppColors.dayGlassStrong,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'SMILES: ${widget.smiles}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.dayTextMuted,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: '输入化学名称（可选）',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _isResolving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(
                    _isResolving ? 'AI 识别中...' : 'AI 检测命名'),
                onPressed: _isResolving ? null : _aiResolve,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: PrimaryButton(
                      label: '保存',
                      onPressed: () => Navigator.pop(context, {
                        'smiles': widget.smiles,
                        'name': _nameController.text.trim(),
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏确认取消页面
class _ConfirmCancelPage extends StatelessWidget {
  const _ConfirmCancelPage();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0d1627) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 64,
                    color: isDark ? AppColors.amber : Colors.orange),
                const SizedBox(height: 24),
                Text('取消编辑',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text('编辑内容尚未保存，确定取消？',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                    textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(18)),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('继续编辑'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(18)),
                          ),
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('确定取消'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
