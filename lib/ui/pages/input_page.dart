import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/structure_controller.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/quick_tag.dart';
import 'loading_page.dart';
import 'settings_page.dart';

enum ResolveMode { exact, infer }

class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _history = [];
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

    _addHistory(query);
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

  void _addHistory(String query) {
    setState(() {
      _history.removeWhere((item) => item == query);
      _history.insert(0, query);
      if (_history.length > 8) {
        _history.removeRange(8, _history.length);
      }
    });
  }

  void _removeHistory(String query) {
    setState(() {
      _history.removeWhere((item) => item == query);
    });
  }

  void _showFeatureHint(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const panelRadius = 22.0;
    final hintText = _mode == ResolveMode.infer
        ? '输入用途或描述，例如：止痛消炎用药'
        : '输入化学名称，如：苯甲酸';
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
                icon: const Icon(Icons.settings, size: 20),
                color: AppColors.textMuted,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
              const SizedBox(width: 6),
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
                  cursorColor: AppColors.aqua,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    prefixIcon: IconButton(
                      icon: const Icon(Icons.mic_none),
                      color: AppColors.textSecondary,
                      onPressed: () => _showFeatureHint('录音功能开发中'),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.photo_camera_outlined),
                      color: AppColors.textSecondary,
                      onPressed: () => _showFeatureHint('拍照识别功能开发中'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '生成结构', onPressed: _submit),
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
    if (_history.isEmpty) {
      return Text(
        '暂无搜索记录',
        style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _history
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.glassStrong,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                ? const LinearGradient(
                    colors: [AppColors.aqua, Color(0xFF9EF5D2)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? AppColors.ink : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected ? AppColors.ink : AppColors.textSecondary,
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
