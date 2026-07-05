import 'dart:convert';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../widgets/primary_button.dart';

class ExportImageDialog extends StatefulWidget {
  const ExportImageDialog({
    super.key,
    required this.exportSvg,
    required this.exportPng,
  });

  final Future<String?> Function() exportSvg;
  final Future<String?> Function(String bgColor) exportPng;

  @override
  State<ExportImageDialog> createState() => _ExportImageDialogState();
}

class _ExportImageDialogState extends State<ExportImageDialog> {
  String _format = 'svg';
  String _bgMode = 'transparent';
  String? _previewDataUrl;
  bool _loading = false;

  static const _bgOptions = {
    'transparent': '透明',
    '#ffffff': '日间',
    '#0b0f1a': '夜间',
  };

  Future<void> _generatePreview() async {
    setState(() => _loading = true);
    try {
      if (_format == 'svg') {
        final svg = await widget.exportSvg();
        if (svg != null && mounted) {
          setState(() => _previewDataUrl =
              'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}');
        }
      } else {
        final bg = _bgMode == 'transparent' ? 'transparent' : _bgMode;
        final png = await widget.exportPng(bg);
        if (png != null && mounted && png.isNotEmpty && png != '{}') {
          setState(() => _previewDataUrl = png);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generatePreview());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0d1627) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('导出图片', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ChoiceChip(
                label: const Text('PNG'), selected: _format == 'png',
                onSelected: (_) { setState(() => _format = 'png'); _generatePreview(); },
              )),
              const SizedBox(width: 8),
              Expanded(child: ChoiceChip(
                label: const Text('SVG'), selected: _format == 'svg',
                onSelected: (_) { setState(() => _format = 'svg'); _generatePreview(); },
              )),
            ]),
            if (_format == 'png') ...[
              const SizedBox(height: 10),
              Row(
                children: _bgOptions.entries.map((e) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: e.key != _bgOptions.keys.last ? 6 : 0),
                    child: ChoiceChip(
                      label: Text(e.value, style: const TextStyle(fontSize: 12)),
                      selected: _bgMode == e.key,
                      onSelected: (_) { setState(() => _bgMode = e.key); _generatePreview(); },
                    ),
                  ),
                )).toList(),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              height: 200, width: double.infinity,
              decoration: BoxDecoration(
                color: _bgMode == 'transparent'
                    ? (isDark ? Colors.white10 : Colors.grey.shade100)
                    : (_bgMode == '#ffffff' ? Colors.white : const Color(0xFF0b0f1a)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _previewDataUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(_previewDataUrl!.split(',').last),
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Center(child: Text('预览加载中...')),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('关闭'),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}
