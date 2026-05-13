import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/jsme_editor_controller.dart';
import '../widgets/jsme_editor_view.dart';
import '../widgets/primary_button.dart';

class StructureEditorPage extends StatefulWidget {
  const StructureEditorPage({
    super.key,
    required this.initialSmiles,
    this.title,
  });

  final String initialSmiles;
  final String? title;

  @override
  State<StructureEditorPage> createState() => _StructureEditorPageState();
}

class _StructureEditorPageState extends State<StructureEditorPage> {
  JsmeEditorController? _controller;
  String _currentSmiles = '';

  @override
  void initState() {
    super.initState();
    _currentSmiles = widget.initialSmiles;
  }

  Future<void> _saveAndBack() async {
    final latest = await _controller?.getSmiles();
    if (!mounted) return;
    final result = (latest != null && latest.trim().isNotEmpty)
        ? latest.trim()
        : _currentSmiles.trim();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardTint = isDark ? AppColors.glass : AppColors.dayGlassStrong;
    final title = widget.title ?? '结构编辑器（JSME）';
    return AppScaffold(
      scroll: false,
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
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GlassPanel(
              padding: const EdgeInsets.all(12),
              radius: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '双指缩放、单指平移由编辑器内置支持；可直接使用原子/键/环/删除等工具。',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: isDark
                              ? AppColors.textMuted
                              : AppColors.dayTextMuted,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: JsmeEditorView(
                        smiles: _currentSmiles,
                        onControllerReady: (controller) => _controller = controller,
                        onSmilesUpdated: (smiles) {
                          setState(() => _currentSmiles = smiles);
                        },
                        themeMode: isDark ? 'dark' : 'light',
                        onError: (message) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(message)),
                          );
                        },
                        onDebugLog: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cardTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'SMILES: $_currentSmiles',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: isDark
                                ? AppColors.textMuted
                                : AppColors.dayTextMuted,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(label: '保存并返回', onPressed: _saveAndBack),
        ],
      ),
    );
  }
}
