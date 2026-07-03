import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_config.dart';
import '../../models/structure_result.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/structure_view.dart';
import 'settings_page.dart';
import 'structure_editor_page.dart';
import 'structure_editor_page.dart';

class ResultPage extends ConsumerStatefulWidget {
  const ResultPage({
    super.key,
    required this.query,
    required this.result,
  });

  final String query;
  final StructureResult result;

  @override
  ConsumerState<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends ConsumerState<ResultPage> {
  String _currentSmiles = '';
  String _pageTitle = '';
  bool _viewportInteracting = false;
  bool _resolvingNames = false;
  bool _showEditButton = false;
  final ScrollController _candidateScrollController = ScrollController();
  late final List<StructureCandidate> _candidates;
  late StructureCandidate _activeCandidate;
  bool _isFavorited = false;
  
  @override
  void dispose() {
    _candidateScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _activeCandidate = _primaryCandidate();
    _candidates = [_activeCandidate, ...widget.result.alternatives]
        .where((item) => item.smiles.trim().isNotEmpty)
        .toList();
    _currentSmiles = _activeCandidate.smiles;
    _pageTitle = _resolveTitleByCandidate(_activeCandidate);
    _checkIfFavorited();
  }

  void _checkIfFavorited() {
    // 检查当前结构是否已收藏
    final service = ref.read(favoritesServiceProvider);
    final allFavorites = service.getAll();
    _isFavorited = allFavorites.any((item) => 
      item.structureResult.smiles == _activeCandidate.smiles);
  }

  StructureCandidate _primaryCandidate() {
    return StructureCandidate(
      smiles: widget.result.smiles,
      resolvedName: widget.result.resolvedName,
      englishName: widget.result.englishName,
      chineseName: widget.result.chineseName,
      molecularFormula: widget.result.molecularFormula,
      molecularWeight: widget.result.molecularWeight,
      source: null,
      confidence: widget.result.confidence,
    );
  }

  String _candidateDisplayName(StructureCandidate c) {
    final en = c.englishName ?? '';
    final zh = c.chineseName ?? '';
    if (en.isNotEmpty && zh.isNotEmpty) return '$en（$zh）';
    if (en.isNotEmpty) return en;
    if (zh.isNotEmpty) return zh;
    return c.resolvedName ?? c.smiles;
  }

  String _resolveTitleByCandidate(StructureCandidate c) {
    final display = _candidateDisplayName(c).trim();
    if (display.isNotEmpty && display != c.smiles) {
      return display;
    }
    return _pageTitle.trim().isNotEmpty ? _pageTitle : widget.query;
  }

  StructureResult _buildCurrentResult() {
    return StructureResult(
      smiles: _currentSmiles,
      resolvedName: _activeCandidate.resolvedName,
      englishName: _activeCandidate.englishName,
      chineseName: _activeCandidate.chineseName,
      molecularFormula: _activeCandidate.molecularFormula,
      molecularWeight: _activeCandidate.molecularWeight,
      isValid: widget.result.isValid,
      confidence: _activeCandidate.confidence,
      message: widget.result.message,
      alternatives: _candidates.where((item) => item != _activeCandidate).toList(),
    );
  }

  Future<void> _editTitle() async {
    final isDark = ref.read(themeModeProvider) != ThemeMode.light;
    final controller = TextEditingController(text: _pageTitle);
    final value = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) {
        return Dialog(
          elevation: 16,
          shadowColor: Colors.black54,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.glass
                      : AppColors.dayGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.dayBluePrimary.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? AppColors.shadow
                          : AppColors.dayShadow,
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '编辑名称',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.dayTextPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.dayTextPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '输入化合物名称',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.15)
                                : AppColors.dayBluePrimary.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? AppColors.aqua
                                : AppColors.dayBluePrimary,
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : AppColors.dayBluePrimary.withValues(alpha: 0.06),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            '取消',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.dayTextMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text.trim()),
                          style: TextButton.styleFrom(
                            backgroundColor: isDark
                                ? AppColors.aqua.withValues(alpha: 0.15)
                                : AppColors.dayBluePrimary.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            '保存',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.aqua
                                  : AppColors.dayBluePrimary,
                              fontWeight: FontWeight.w600,
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
      },
    );
    if (!mounted || value == null || value.isEmpty) {
      return;
    }
    setState(() => _pageTitle = value);
  }

  void _openViewMode() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ViewModePage(smiles: _currentSmiles);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  void _selectCandidate(StructureCandidate candidate) {
    setState(() {
      _activeCandidate = candidate;
      _currentSmiles = candidate.smiles;
      _pageTitle = _resolveTitleByCandidate(candidate);
      _checkIfFavorited(); // 重新检查收藏状态
    });
  }

  Future<void> _openEditorPage() async {
    final updatedSmiles = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => StructureEditorPage(
          initialSmiles: _currentSmiles,
          title: '结构式编辑器',
          skipSaveConfirm: true,
        ),
      ),
    );
    if (updatedSmiles != null && updatedSmiles.isNotEmpty && mounted) {
      final previousCandidate = _activeCandidate;
      setState(() {
        _currentSmiles = updatedSmiles;
        _resolvingNames = true;
        _activeCandidate = StructureCandidate(
          smiles: updatedSmiles,
          resolvedName: '解析中…',
          englishName: null,
          chineseName: null,
          molecularFormula: _activeCandidate.molecularFormula,
          molecularWeight: _activeCandidate.molecularWeight,
          source: _activeCandidate.source,
          confidence: _activeCandidate.confidence,
        );
      });
      final namingResult = await Navigator.of(context).push<Map<String, String>>(
        MaterialPageRoute(
          builder: (_) => NameResolvePage(
            smiles: updatedSmiles,
          ),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _resolvingNames = false;
        if (namingResult != null) {
          final name = namingResult['name'] ?? '';
          final s = namingResult['smiles'] ?? updatedSmiles;
          _activeCandidate = StructureCandidate(
            smiles: s,
            resolvedName: name.isNotEmpty ? name : null,
            englishName: name.isNotEmpty ? name : null,
            chineseName: null,
            molecularFormula: _activeCandidate.molecularFormula,
            molecularWeight: _activeCandidate.molecularWeight,
            source: _activeCandidate.source,
            confidence: _activeCandidate.confidence,
          );
          _pageTitle = name.isNotEmpty ? name : '已修改结构';
          _currentSmiles = s;
        } else {
          _activeCandidate = StructureCandidate(
            smiles: updatedSmiles,
            resolvedName: '已修改结构',
            englishName: null,
            chineseName: null,
            molecularFormula: _activeCandidate.molecularFormula,
            molecularWeight: _activeCandidate.molecularWeight,
            source: _activeCandidate.source,
            confidence: _activeCandidate.confidence,
          );
          _pageTitle = '已修改结构';
        }
        _checkIfFavorited();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;
    return AppScaffold(
      scroll: true,
      scrollPhysics: _viewportInteracting
          ? const NeverScrollableScrollPhysics()
          : const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 18,
                  color: isDark ? AppColors.textMuted : AppColors.dayBluePrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 20),
                color: AppColors.textMuted,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
                ),
              ),
              const SizedBox(width: 6),
              const AccentPill(label: '结构已生成'),
            ],
          ),
          const SizedBox(height: 18),
          // 点击标题区域不退出查看模式
          GestureDetector(
            onTap: _editTitle,
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              onEnter: (_) => setState(() => _showEditButton = true),
              onExit: (_) => setState(() => _showEditButton = false),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pageTitle,
                      style: Theme.of(context).textTheme.headlineMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _showEditButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
                      onPressed: _editTitle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (_activeCandidate.resolvedName != null &&
                  _activeCandidate.resolvedName!.isNotEmpty)
                Expanded(
                  child: Text('标准名称 ${_activeCandidate.resolvedName}',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              TextButton.icon(
                onPressed: _openViewMode,
                icon: Icon(
                  Icons.open_in_full,
                  size: 14,
                  color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                ),
                label: Text(
                  '查看模式',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final height =
                  (constraints.maxWidth * 0.7).clamp(400.0, 700.0).toDouble();
              return SizedBox(
                height: height,
                width: double.infinity,
                child: StructureView(
                  smiles: _currentSmiles,
                  readOnly: true,
                  interactive: false,
                  onSmilesUpdated: (smiles) {
                    setState(() => _currentSmiles = smiles);
                  },
                  onViewportInteraction: (active) {
                    if (_viewportInteracting == active) {
                      return;
                    }
                    setState(() {
                      _viewportInteracting = active;
                    });
                  },
                  onEditTitle: _editTitle,
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openEditorPage,
              icon: const Icon(Icons.edit),
              label: const Text('打开结构式编辑器'),
            ),
          ),
          if (_resolvingNames) ...[
            const SizedBox(height: 8),
            Text(
              '解析中…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_activeCandidate.englishName != null &&
              _activeCandidate.englishName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _activeCandidate.chineseName != null &&
                      _activeCandidate.chineseName!.isNotEmpty
                  ? '${_activeCandidate.englishName} (${_activeCandidate.chineseName})'
                  : _activeCandidate.englishName!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                  ),
            ),
          ],
          if (_activeCandidate.molecularFormula.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              _activeCandidate.molecularFormula,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFFF9F3DD)
                      : AppColors.dayBluePrimary,
                  fontWeight: FontWeight.w700),
            ),
          ],
          if (_activeCandidate.molecularWeight > 0) ...[
            const SizedBox(height: 6),
            Text(
              '分子量 ${_activeCandidate.molecularWeight.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.aqua.withValues(alpha: 0.12)
                  : AppColors.dayBluePrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'SMILES: $_currentSmiles',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? const Color(0xFF7EC8E3)
                      : AppColors.dayBluePrimary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                widget.result.isValid ? Icons.check_circle : Icons.error,
                color: widget.result.isValid
                    ? (isDark
                        ? AppColors.aqua
                        : AppColors.dayBluePrimary)
                    : Colors.redAccent,
              ),
              const SizedBox(width: 6),
              Text(
                widget.result.isValid ? '结构合法' : '结构不合法',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          if (_candidates.length > 1) ...[
            const SizedBox(height: 14),
            Text('推测候选',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: 6),
            SizedBox(
              height: 172,
              child: Scrollbar(
                controller: _candidateScrollController,
                thumbVisibility: true,
                child: ListView.separated(
                  controller: _candidateScrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: _candidates.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  padding: const EdgeInsets.only(top: 6, bottom: 6),
                  itemBuilder: (context, index) {
                    final candidate = _candidates[index];
                    final isActive = candidate.smiles == _activeCandidate.smiles;
                    return SizedBox(
                      width: 160,
                      child: GestureDetector(
                        onTap: () => _selectCandidate(candidate),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isActive
                                  ? (isDark
                                      ? AppColors.aqua
                                      : AppColors.dayBluePrimary)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : AppColors.dayBluePrimary.withValues(alpha: 0.15)),
                              width: isActive ? 2 : 1,
                            ),
                            color: isActive
                                ? (isDark
                                    ? AppColors.glassStrong
                                    : AppColors.dayBluePrimary
                                        .withValues(alpha: 0.12))
                                : Colors.transparent,
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: (isDark
                                              ? AppColors.aqua
                                              : AppColors.dayBluePrimary)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _candidateDisplayName(candidate),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      height: 1.2,
                                    ),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                candidate.molecularFormula,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.textMuted
                                          : AppColors.dayTextMuted,
                                      fontSize: 11,
                                      height: 1.0,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '置信度 ${(candidate.confidence * 100).toStringAsFixed(0)}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.textMuted
                                          : AppColors.dayTextMuted,
                                      fontSize: 11,
                                      height: 1.0,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: BouncyButton(
                    onPressed: _isFavorited
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('该结构已在收藏中'),
                                backgroundColor: AppColors.navy,
                              ),
                            );
                          }
                        : () async {
                            await ref
                                .read(favoritesControllerProvider.notifier)
                                .add(_buildCurrentResult(), _pageTitle);
                            setState(() {
                              _isFavorited = true;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('已添加到收藏'),
                                  backgroundColor: AppColors.aqua,
                                ),
                              );
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: _isFavorited
                            ? null
                            : isDark
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.aqua,
                                      Color(0xFF4EDCC8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : const LinearGradient(
                                    colors: [
                                      AppColors.dayBluePrimary,
                                      AppColors.dayBlueAccent,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                        color: _isFavorited ? Colors.transparent : null,
                        border: _isFavorited
                            ? Border.all(
                                color: (isDark
                                        ? AppColors.aqua
                                        : AppColors.dayBluePrimary)
                                    .withValues(alpha: 0.6),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isFavorited ? Icons.check : Icons.star_border,
                              size: 20,
                              color: _isFavorited
                                  ? (isDark
                                      ? AppColors.aqua
                                      : AppColors.dayBluePrimary)
                                  : Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isFavorited ? '已收藏' : '收藏',
                              style: TextStyle(
                                color: _isFavorited
                                    ? (isDark
                                        ? AppColors.aqua
                                        : AppColors.dayBluePrimary)
                                    : Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? AppColors.textPrimary : AppColors.dayBluePrimary,
                      backgroundColor: isDark
                          ? Colors.transparent
                          : AppColors.dayBluePrimary.withValues(alpha: 0.12),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.25)
                            : AppColors.dayBluePrimary.withValues(alpha: 0.55),
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
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.transparent,
            ),
            child: Text(
              '渲染引擎：${AppConfig.renderEngineName}',
              style: Theme.of(context).textTheme.bodySmall,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
}
}

class _ViewModePage extends StatelessWidget {
  const _ViewModePage({required this.smiles});

  final String smiles;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.open_in_full, size: 18, color: Color(0xFF38d5c1)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '查看模式 — 双指/滚轮缩放，拖动平移',
                      style: TextStyle(color: Color(0xFF9fb1c9), fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF9fb1c9)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: const Color(0x800B0F1A),
                    child: StructureView(
                      smiles: smiles,
                      readOnly: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
