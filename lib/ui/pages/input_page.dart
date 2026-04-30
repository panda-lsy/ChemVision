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

class InputPage extends ConsumerStatefulWidget {
  const InputPage({super.key});

  @override
  ConsumerState<InputPage> createState() => _InputPageState();
}

class _InputPageState extends ConsumerState<InputPage> {
  final TextEditingController _controller = TextEditingController();

  final List<String> _samples = const [
    '苯甲酸',
    '乙醇',
    '2-甲基戊烷',
    '丙酮',
    '甲苯',
  ];

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

    ref.read(structureControllerProvider.notifier).reset();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoadingPage(query: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 18),
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '文本输入',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
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
                  decoration: const InputDecoration(
                    hintText: '输入化学名称，如：苯甲酸',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: '生成结构', onPressed: _submit),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _samples
                .map((item) => QuickTag(
                      label: item,
                      onTap: () {
                        setState(() {
                          _controller.text = item;
                        });
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          GlassPanel(
            child: Text(
              '输入后将自动进行命名解析与结构推理，生成可编辑结构图。',
              style: Theme.of(context).textTheme.bodyMedium,
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
}
