import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/structure_recognition_result.dart';
import '../../models/structure_result.dart';
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
  const StructureRecognitionPage({super.key});

  @override
  ConsumerState<StructureRecognitionPage> createState() =>
      _StructureRecognitionPageState();
}

class _StructureRecognitionPageState
    extends ConsumerState<StructureRecognitionPage> {
  Uint8List? _imageBytes;
  String? _dataUri;
  int? _selectedIndex;

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

      // Auto-trigger recognition
      ref
          .read(structureRecognitionControllerProvider.notifier)
          .recognizeFromImage(_dataUri!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('图片选取失败: $e')),
        );
      }
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择图片来源',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: AppColors.aqua),
                  title: const Text('拍照'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.photo_library, color: AppColors.aqua),
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
              Text('ChemVISION',
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
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 12),
                  Text(
                    _statusText(state.status),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
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
