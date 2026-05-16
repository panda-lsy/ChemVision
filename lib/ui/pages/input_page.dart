import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../main.dart';
import '../../providers/structure_controller.dart';
import '../../providers/theme_mode_provider.dart';
import '../../services/ai_settings_store.dart';
import '../../services/ocr_service.dart';
import '../../services/vivo_aigc_client.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/quick_tag.dart';
import '../widgets/voice_input_overlay.dart';
import 'loading_page.dart';
import 'structure_recognition_page.dart';

enum ResolveMode { exact, infer }

class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  final TextEditingController _controller = TextEditingController();
  ResolveMode _mode = ResolveMode.exact;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入化学名称')),
      );
      return;
    }

    // 先添加到历史记录（立即显示）
    ref.read(searchHistoryListProvider.notifier).add(query);
    
    ref.read(structureControllerProvider.notifier).reset();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoadingPage(
          query: query,
          mode: _mode == ResolveMode.infer ? 'infer' : 'exact',
        ),
      ),
    );
  }

  void _removeHistory(String query) async {
    await ref.read(searchHistoryListProvider.notifier).remove(query);
  }

  Future<void> _startVoiceInput() async {
    try {
      debugPrint('[语音输入] 开始语音输入流程');
      final result = await showVoiceInputOverlay(context, ref);
      debugPrint('[语音输入] 返回结果：$result');
      
      if (result != null && result.isNotEmpty) {
        if (mounted) {
          setState(() {
            _controller.text = result;
          });
          debugPrint('[语音输入] 已填充文本到输入框');
        }
      } else if (result == null) {
        debugPrint('[语音输入] 结果为空（可能取消或出错）');
      }
    } catch (e) {
      debugPrint('[语音输入] 异常：$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音输入失败：$e')),
        );
      }
    }
  }

  Future<void> _pickImageAndRecognize() async {
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
                  leading: const Icon(Icons.camera_alt,
                      color: AppColors.aqua),
                  title: const Text('拍照'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library,
                      color: AppColors.aqua),
                  title: const Text('从相册选择'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('正在识别...')),
      );

      final bytes = await image.readAsBytes();
      final base64Image = await compute(_encodeBytes, bytes);

      final settings = await AiSettingsStore().load();
      if (settings.apiKey.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先在设置中配置 API Key')),
          );
        }
        return;
      }

      // 先尝试使用 OCR 服务识别
      final ocrService = OcrService();
      final ocrResult = await ocrService.recognize(
        imageBase64: base64Image,
        pos: 0, // 只需要文字
        apiKey: settings.apiKey,
      );

      if (!ocrResult.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('OCR 识别失败：${ocrResult.error}')),
          );
        }
        return;
      }

      // 如果 OCR 识别到文本，直接使用
      if (ocrResult.allText.isNotEmpty) {
        if (mounted) {
          setState(() {
            _controller.text = ocrResult.allText.trim();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('识别完成')),
          );
        }
        return;
      }

      // 如果 OCR 没有识别到文本，使用多模态 LLM 识别
      final mimeType = _detectMimeType(bytes);
      final dataUri = 'data:$mimeType;base64,$base64Image';
      final client = VivoAigcClient();
      final result = await client.generateMultimodal(
        apiKey: settings.apiKey,
        model: settings.textModel,
        prompt: '请识别图片中的化学物质，只返回化学名称（中文名或英文名），不要其他内容。'
            '如果无法识别，返回空。',
        imageBase64: dataUri,
        baseUrl: settings.baseUrl,
      );

      if (mounted && result.trim().isNotEmpty) {
        setState(() {
          _controller.text = result.trim();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('识别完成')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('识别失败: $e')),
        );
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

// compute helper for base64 encoding
String _encodeBytes(Uint8List bytes) {
  return base64Encode(bytes);
}

  @override
  Widget build(BuildContext context) {
    const panelRadius = 22.0;
    final isDark = ref.watch(themeModeProvider) != ThemeMode.light;
    final hintText = _mode == ResolveMode.infer
        ? '输入用途或描述，例如：止痛消炎用药'
        : '输入化学名称，如：苯甲酸';
    
    // 监听搜索词变化（必须在 build 中调用）
    ref.listen<String>(
      searchQueryControllerProvider,
      (previous, next) {
        if (next.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _controller.text = next;
              });
              // 清空控制器，避免重复触发
              ref.read(searchQueryControllerProvider.notifier).state = '';
            }
          });
        }
      },
    );
    
    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION', style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              IconButton(
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
                icon: Icon(
                  isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                  size: 18,
                  color: isDark ? AppColors.textMuted : AppColors.dayBluePrimary,
                ),
              ),
              const AccentPill(label: '端侧意图识别'),
            ],
          ),
          const SizedBox(height: 18),
          Text('输入化学名称', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          _buildModeToggle(context),
          const SizedBox(height: 18),
          GlassPanel(
            radius: panelRadius,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '文本输入',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            letterSpacing: 0.6,
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      _mode == ResolveMode.exact ? '解析模式' : '推测模式',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  cursorColor: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimary : AppColors.dayTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.mic_none),
                      color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                      onPressed: _startVoiceInput,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
                      onPressed: _pickImageAndRecognize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '生成结构', onPressed: _submit),
          const SizedBox(height: 10),
          PrimaryButton(
            label: '印刷体结构识别',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StructureRecognitionPage(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildHistorySection(context),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GlassPanel(
              radius: panelRadius,
              child: Text(
                '支持语音、文字、识图。文字支持三种输入方式：中文 IUPAC、常用俗名、分子式。\n'
                '解析模式：适合已知名称，先翻译（中文→英文 IUPAC）再进行精确解析。\n'
                '推测模式：适合用途或效果描述，会生成最多 5 个候选名称并尝试解析。\n'
                '输入后会自动进行命名解析与结构推理，生成可编辑的 SVG 结构图（支持点击/编辑原子）。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.bottomRight,
            child: IconButton(
              icon: const Icon(Icons.edit, size: 20),
              color: AppColors.textMuted,
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final history = ref.watch(searchHistoryListProvider).take(8).toList();
    if (history.isEmpty) {
      return Text(
        '暂无搜索记录',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: history
          .map(
            (item) => QuickTag(
              label: item,
              onTap: () {
                setState(() {
                  _controller.text = item;
                });
              },
              onDelete: () => _removeHistory(item),
            ),
          )
          .toList(),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassStrong : AppColors.dayGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.dayBluePrimary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          _buildModeOption(
            context,
            mode: ResolveMode.exact,
            label: '解析模式',
            icon: Icons.search,
          ),
          _buildModeOption(
            context,
            mode: ResolveMode.infer,
            label: '推测模式',
            icon: Icons.auto_awesome,
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption(
    BuildContext context, {
    required ResolveMode mode,
    required String label,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _mode == mode;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            _mode = mode;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: selected
                ? (isDark
                    ? const LinearGradient(
                        colors: [AppColors.aqua, Color(0xFF9EF5D2)],
                      )
                    : const LinearGradient(
                        colors: [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
                      ))
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected
                    ? (isDark ? AppColors.ink : Colors.white)
                    : (isDark ? AppColors.textSecondary : AppColors.dayTextSecondary),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? (isDark ? AppColors.ink : Colors.white)
                          : (isDark
                              ? AppColors.textSecondary
                              : AppColors.dayTextSecondary),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
