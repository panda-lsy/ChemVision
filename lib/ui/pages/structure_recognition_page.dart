import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/scan_history_item.dart';
import '../../models/structure_recognition_result.dart';
import '../../models/structure_result.dart';
import '../../providers/scan_history_provider.dart';
import '../../providers/structure_recognition_controller.dart';
import '../../providers/structure_service_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import 'result_page.dart';

class StructureRecognitionPage extends ConsumerStatefulWidget {
  const StructureRecognitionPage({
    super.key,
    this.viewItem,
    this.initialSource,
  });

  /// 从扫描历史进入时的只读视图项(非空时进入 view-only 模式)
  final ScanHistoryItem? viewItem;

  /// 进入页面时直接使用的图片来源(跳过页内来源选择弹窗)
  final ImageSource? initialSource;

  /// 从扫描历史项构造 view-only 实例
  factory StructureRecognitionPage.fromScanHistory(
    ScanHistoryItem item, {
    Key? key,
  }) =>
      StructureRecognitionPage(key: key, viewItem: item);

  @override
  ConsumerState<StructureRecognitionPage> createState() =>
      _StructureRecognitionPageState();
}

class _StructureRecognitionPageState
    extends ConsumerState<StructureRecognitionPage> {
  Uint8List? _imageBytes;
  String? _dataUri;
  int? _selectedIndex;
  bool _isViewOnly = false;
  ScanHistoryItem? _viewItem;

  @override
  void initState() {
    super.initState();
    if (widget.viewItem != null) {
      _isViewOnly = true;
      _viewItem = widget.viewItem;
      _imageBytes = widget.viewItem!.imageBytes;
    } else if (widget.initialSource != null) {
      // 从主页相机按钮进入:直接拉起拍照/相册并自动识别
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pickImage(widget.initialSource!);
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = await compute(_encodeBytes, bytes);
      final mimeType = _detectMimeType(bytes);

      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _dataUri = 'data:$mimeType;base64,$base64Image';
        _selectedIndex = null;
      });

      // Auto-trigger recognition (await 完成后自动保存扫描历史)
      await ref
          .read(structureRecognitionControllerProvider.notifier)
          .recognizeFromImage(_dataUri!);

      // 识别完成后自动保存扫描历史(无论是否有候选)
      // view-only 模式(从扫描历史进入)不重复保存
      if (!_isViewOnly && _imageBytes != null && mounted) {
        final recognitionState =
            ref.read(structureRecognitionControllerProvider);
        final result = recognitionState.result;
        if (result != null && result.recognizedSmiles.isNotEmpty) {
          ref.read(scanHistoryControllerProvider.notifier).add(
                ScanHistoryItem.fromRecognition(
                  imageBytes: _imageBytes!,
                  recognizedSmiles: result.recognizedSmiles,
                  completenessScore: result.completenessScore,
                ),
              );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选取失败: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceSheet() async {
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;
    final bgColor =
        isDark ? AppColors.navy : AppColors.dayGlass;
    final accentColor =
        isDark ? AppColors.aqua : AppColors.dayBluePrimary;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : AppColors.dayBluePrimary.withValues(alpha: 0.08);
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('选择图片来源',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_alt, color: accentColor),
                  title: const Text('拍照'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                Divider(color: dividerColor, height: 1),
                ListTile(
                  leading: Icon(Icons.photo_library, color: accentColor),
                  title: const Text('从相册选择'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (source != null) _pickImage(source);
  }

  void _confirmSelection(StructureCandidate candidate) {
    final service = ref.read(imageStructureServiceProvider);
    final result = service.resolveToStructure(candidate);

    // 扫描历史已在识别完成时自动保存,此处不再重复

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          query: candidate.englishName ?? candidate.resolvedName ?? candidate.smiles,
          result: result,
        ),
      ),
    );
  }

  /// view-only 模式下从扫描历史项直接进入详情页
  void _enterResultPageFromView() {
    final item = _viewItem;
    if (item == null) return;
    final candidate = StructureCandidate(
      smiles: item.recognizedSmiles,
      resolvedName: item.resolvedName,
      englishName: item.englishName,
      chineseName: item.chineseName,
      molecularFormula: item.molecularFormula,
      molecularWeight: item.molecularWeight,
      source: '扫描历史',
      confidence: item.completenessScore,
    );
    // view-only 模式不重复保存历史
    final service = ref.read(imageStructureServiceProvider);
    final result = service.resolveToStructure(candidate);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          query: candidate.englishName ?? candidate.resolvedName ?? candidate.smiles,
          result: result,
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _dataUri = null;
      _selectedIndex = null;
    });
    ref.read(structureRecognitionControllerProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;
    final state = ref.watch(structureRecognitionControllerProvider);
    final isLoading = state.status == StructureRecognitionStatus.analyzing ||
        state.status == StructureRecognitionStatus.scoring ||
        state.status == StructureRecognitionStatus.searching;

    // view-only 模式(从扫描历史进入):只展示原图 + 已识别结果,不触发识别
    if (_isViewOnly && _viewItem != null) {
      return AppScaffold(
        scroll: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
                const SizedBox(width: 4),
                Text('ChemEdu',
                    style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                const AccentPill(label: '扫描历史'),
              ],
            ),
            const SizedBox(height: 18),
            // 原图
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_viewItem!.imageBytes,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            _buildViewOnlySummary(context, _viewItem!, isDark),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '查看结构详情',
              onPressed: _enterResultPageFromView,
            ),
          ],
        ),
      );
    }

    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
              ),
              const SizedBox(width: 4),
              Text('ChemEdu',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              const AccentPill(label: '结构识别'),
            ],
          ),
          const SizedBox(height: 18),

          // Image preview
          GestureDetector(
            onTap: _showImageSourceSheet,
            child: GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(12),
              child: _imageBytes == null
                  ? Container(
                      height: 200,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.document_scanner_outlined,
                              size: 48,
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.dayTextMuted),
                          const SizedBox(height: 12),
                          Text('点击拍照或选择化学结构图',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isDark
                                        ? AppColors.textMuted
                                        : AppColors.dayTextMuted,
                                  )),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.memory(_imageBytes!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.contain),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceSheet,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(_imageBytes == null ? '拍照识别' : '重新选择'),
                ),
              ),
              if (_imageBytes != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('清除'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Loading state
          if (isLoading) ...[
            Center(
              child: GlassPanel(
                radius: 22,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 12),
                    Text(
                      _statusText(state.status),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Error state
          if (state.status == StructureRecognitionStatus.failure &&
              state.errorMessage != null) ...[
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(state.errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Results
          if (state.status == StructureRecognitionStatus.complete &&
              state.result != null) ...[
            _buildResultSection(context, state.result!, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildResultSection(
      BuildContext context, StructureRecognitionResult result, bool isDark) {
    final score = result.completenessScore;
    final scoreColor = score > 0.7
        ? AppColors.aqua
        : score > 0.4
            ? AppColors.amber
            : Colors.redAccent;
    final candidates = result.candidates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Completeness score + SMILES
        GlassPanel(
          radius: 22,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: score,
                          strokeWidth: 5,
                          backgroundColor: (isDark
                                  ? AppColors.textMuted
                                  : AppColors.dayTextMuted)
                              .withValues(alpha: 0.2),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                        Text(
                          '${(score * 100).toInt()}%',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('完整度评分',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          score > 0.7
                              ? '结构完整度较高'
                              : score > 0.4
                                  ? '结构可能不完整，建议选择候选'
                                  : '结构完整度较低，请选择候选或重新识别',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scoreColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('识别 SMILES', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.glassStrong
                      : AppColors.dayGlassStrong,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  result.recognizedSmiles,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Candidates
        if (candidates.isNotEmpty) ...[
          Text('候选化合物',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 8),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemBuilder: (context, index) {
                final c = candidates[index];
                final isActive = _selectedIndex == index;
                return SizedBox(
                  width: 160,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
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
                                  : AppColors.dayBluePrimary
                                      .withValues(alpha: 0.15)),
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
                            c.englishName ?? c.resolvedName ?? c.smiles,
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
                            c.molecularFormula,
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
                          const SizedBox(height: 2),
                          Text(
                            '置信度 ${(c.confidence * 100).toStringAsFixed(0)}%',
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
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: '确认选择',
            onPressed: _selectedIndex != null
                ? () => _confirmSelection(candidates[_selectedIndex!])
                : null,
          ),
        ] else ...[
          // No candidates — offer to use recognized SMILES directly
          PrimaryButton(
            label: '使用识别结果',
            onPressed: () {
              final candidate = StructureCandidate(
                smiles: result.recognizedSmiles,
                resolvedName: '识别结果',
                molecularFormula: '',
                molecularWeight: 0,
                source: '图像识别',
                confidence: result.completenessScore,
              );
              _confirmSelection(candidate);
            },
          ),
        ],
      ],
    );
  }

  String _statusText(StructureRecognitionStatus status) {
    switch (status) {
      case StructureRecognitionStatus.analyzing:
        return '正在分析图像...';
      case StructureRecognitionStatus.scoring:
        return '正在评估结构完整度...';
      case StructureRecognitionStatus.searching:
        return '正在搜索候选化合物...';
      default:
        return '处理中...';
    }
  }

  /// view-only 模式:展示扫描历史项的识别摘要
  Widget _buildViewOnlySummary(
      BuildContext context, ScanHistoryItem item, bool isDark) {
    final score = item.completenessScore;
    final scoreColor = score > 0.7
        ? AppColors.aqua
        : score > 0.4
            ? AppColors.amber
            : Colors.redAccent;
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 完整度评分
          Row(
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: score,
                      strokeWidth: 5,
                      backgroundColor: (isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted)
                          .withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                    ),
                    Text(
                      '${(score * 100).toInt()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.molecularFormula.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.molecularWeight > 0
                            ? '${item.molecularFormula} · 分子量 ${item.molecularWeight.toStringAsFixed(2)}'
                            : item.molecularFormula,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textMuted
                                  : AppColors.dayTextMuted,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('识别 SMILES', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.glassStrong
                  : AppColors.dayGlassStrong,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              item.recognizedSmiles,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _detectMimeType(List<int> bytes) {
  if (bytes.length >= 4) {
    if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'image/png';
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'image/jpeg';
    if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'image/webp';
  }
  return 'image/jpeg';
}

String _encodeBytes(Uint8List bytes) => base64Encode(bytes);
