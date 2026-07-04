import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/edit_history_item.dart';
import '../../models/structure_result.dart';
import '../../providers/edit_history_provider.dart';
import '../../providers/structure_service_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/ketcher_editor_controller.dart';
import '../widgets/ketcher_editor_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_view.dart';
import 'save_confirm_page.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/reaction_favorites_provider.dart';
import '../../models/structure_result.dart';
import '../../models/reaction_equation.dart';

class StructureEditorPage extends ConsumerStatefulWidget {
  const StructureEditorPage({
    super.key,
    this.initialSmiles = '',
    this.title,
    this.skipSaveConfirm = false,
  });

  final String initialSmiles;
  final String? title;
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

      // 1. AI resolve name (get candidates)
      StructureResult? resolveResult;
      try {
        final service = _getStructureService();
        if (service != null) {
          resolveResult = await service.reverseResolveName(smiles);
        }
      } catch (_) {}

      if (!mounted) return;

      // 2. Show unified naming page (candidates + manual input)
      final namingResult =
          await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => NameResolvePage(
            smiles: smiles,
            resolveResult: resolveResult,
          ),
        ),
      );

      if (!mounted) return;
      if (namingResult == null) {
        setState(() => _isSaving = false);
        return;
      }

      final finalSmiles = namingResult['smiles'] ?? smiles;
      final finalName = namingResult['name'] ?? '';

      // 3. Save to edit history
      final historyItem = EditHistoryItem.fromSmiles(finalSmiles);
      ref.read(editHistoryControllerProvider.notifier).add(historyItem);

      // 4. Confirm page (if not skip)
      if (widget.skipSaveConfirm) {
        if (!mounted) return;
        Navigator.of(context).pop({
          'smiles': finalSmiles,
          'name': finalName,
        });
        return;
      }

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
          // save to reaction favorites
          try {
            final equation = ReactionEquation(title: finalName, rxnData: finalSmiles);
            ref.read(reactionFavoritesControllerProvider.notifier).add(equation);
          } catch (_) {}
          Navigator.of(context).pop({'smiles': finalSmiles, 'name': finalName});
        } else {
          // save to structure favorites
          try {
            final sResult = StructureResult(
              smiles: finalSmiles,
              resolvedName: finalName.isNotEmpty ? finalName : null,
              englishName: finalName.isNotEmpty ? finalName : null,
              chineseName: null,
              molecularFormula: '',
              molecularWeight: 0,
              isValid: true,
              confidence: 1.0,
            );
            await ref.read(favoritesControllerProvider.notifier).add(sResult, finalName);
          } catch (_) {}
          Navigator.of(context).pop({'smiles': finalSmiles, 'name': finalName});
        }
      } else {
        Navigator.of(context).pop({'smiles': finalSmiles, 'name': finalName});
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

/// ============================================================
/// Unified naming page: candidates list + manual input
/// ============================================================
class NameResolvePage extends StatefulWidget {
  const NameResolvePage({
    required this.smiles,
    this.resolveResult,
  });
  final String smiles;
  final StructureResult? resolveResult;

  @override
  State<NameResolvePage> createState() => _NameResolvePageState();
}

class _NameResolvePageState extends State<NameResolvePage> {
  final _nameController = TextEditingController();
  List<_NameCandidate> _candidates = const [];
  int _selectedIndex = -1;
  bool _isCustomName = false;

  @override
  void initState() {
    super.initState();
    _buildCandidates();
    // Auto-select the first (primary) candidate
    if (_candidates.isNotEmpty) {
      _selectedIndex = 0;
      _nameController.text = _candidates[0].displayName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _buildCandidates() {
    final r = widget.resolveResult;
    final candidates = <_NameCandidate>[];

    // Primary name from the resolve result
    final primaryEn = r?.englishName;
    final primaryZh = r?.chineseName;
    final primaryResolved = r?.resolvedName;
    if ((primaryEn != null && primaryEn.isNotEmpty) ||
        (primaryZh != null && primaryZh.isNotEmpty) ||
        (primaryResolved != null && primaryResolved.isNotEmpty)) {
      candidates.add(_NameCandidate(
        englishName: primaryEn,
        chineseName: primaryZh,
        resolvedName: primaryResolved,
        source: 'AI 识别',
        confidence: r?.confidence ?? 0,
      ));
    }

    // Alternatives
    if (r?.alternatives != null) {
      for (final alt in r!.alternatives) {
        if ((alt.englishName ?? '').isEmpty &&
            (alt.chineseName ?? '').isEmpty) {
          continue;
        }
        candidates.add(_NameCandidate(
          englishName: alt.englishName,
          chineseName: alt.chineseName,
          resolvedName: alt.resolvedName,
          source: alt.source ?? '候选',
          confidence: alt.confidence,
        ));
      }
    }

    setState(() {
      _candidates = candidates;
      if (candidates.isEmpty) {
        _selectedIndex = -1;
      }
    });
  }

  void _selectCandidate(int index) {
    setState(() {
      _selectedIndex = index;
      _isCustomName = false;
      _nameController.text = _candidates[index].displayName;
    });
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
      body: Column(
        children: [
          // Structure preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                child: StructureView(
                  smiles: widget.smiles,
                  readOnly: true,
                  interactive: false,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // SMILES
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.glass
                    : AppColors.dayGlassStrong,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'SMILES: ${widget.smiles}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: isDark
                          ? AppColors.textMuted
                          : AppColors.dayTextMuted,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Manual name input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _nameController,
              onChanged: (_) {
                if (!_isCustomName) {
                  setState(() => _isCustomName = true);
                }
              },
              decoration: InputDecoration(
                hintText: '输入或选择化学名称',
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _nameController.clear();
                          setState(() => _isCustomName = true);
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Candidate list
          if (_candidates.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '候选名称',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary,
                        ),
                  ),
                  const Spacer(),
                  if (_selectedIndex >= 0)
                    Text(
                      _candidates[_selectedIndex].source,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.aqua,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _candidates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final c = _candidates[index];
                  final selected = index == _selectedIndex && !_isCustomName;
                  return GestureDetector(
                    onTap: () => _selectCandidate(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? (isDark
                                  ? AppColors.aqua
                                  : AppColors.dayBluePrimary)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.dayBluePrimary
                                      .withValues(alpha: 0.15)),
                          width: selected ? 1.5 : 1,
                        ),
                        color: selected
                            ? (isDark
                                ? AppColors.aqua.withValues(alpha: 0.1)
                                : AppColors.dayBluePrimary
                                    .withValues(alpha: 0.08))
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                if (c.chineseName != null &&
                                    c.englishName != null &&
                                    c.displayName != c.chineseName)
                                  Text(
                                    c.chineseName!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isDark
                                              ? AppColors.textMuted
                                              : AppColors.dayTextMuted,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle,
                                size: 20, color: AppColors.aqua),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else
            Expanded(child: Container()),
          const SizedBox(height: 10),
          // Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
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
          ),
        ],
      ),
    );
  }
}

class _NameCandidate {
  final String? englishName;
  final String? chineseName;
  final String? resolvedName;
  final String source;
  final double confidence;

  const _NameCandidate({
    this.englishName,
    this.chineseName,
    this.resolvedName,
    required this.source,
    required this.confidence,
  });

  String get displayName {
    final en = englishName ?? '';
    final zh = chineseName ?? '';
    if (en.isNotEmpty && zh.isNotEmpty) return '$en ($zh)';
    if (en.isNotEmpty) return en;
    if (zh.isNotEmpty) return zh;
    return resolvedName ?? '';
  }
}

/// ============================================================
/// Cancel confirmation
/// ============================================================
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
