import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../config/app_config.dart';
import '../../models/structure_result.dart';
import '../../theme/app_colors.dart';
import '../../utils/js_utils.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_webview.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.query, required this.result});

  final String query;
  final StructureResult result;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  InAppWebViewController? _controller;
  String _currentSmiles = '';
  String? _selectedAtomId;
  String? _selectedElement;

  @override
  void initState() {
    super.initState();
    _currentSmiles = widget.result.smiles;
  }

  void _showElementPicker() {
    final atomId = _selectedAtomId;
    if (atomId == null) {
      return;
    }

    const elements = ['C', 'O', 'N', 'S', 'Cl', 'Br'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '修改元素',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: elements
                        .map(
                          (element) => ChoiceChip(
                            label: Text(element),
                            selected: element == _selectedElement,
                            onSelected: (_) => _applyElement(atomId, element),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _applyElement(String atomId, String element) {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final safeId = escapeForSingleQuotedJs(atomId);
    final safeElement = escapeForSingleQuotedJs(element);
    controller.evaluateJavascript(
      source: "updateAtomElement('$safeId', '$safeElement');",
    );
    Navigator.of(context).pop();
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
              const AccentPill(label: '结构已生成'),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.query, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 260,
                    child: StructureWebView(
                      smiles: widget.result.smiles,
                      onWebViewReady: (controller) {
                        _controller = controller;
                      },
                      onAtomSelected: (atomId, element) {
                        setState(() {
                          _selectedAtomId = atomId;
                          _selectedElement = element;
                        });
                        _showElementPicker();
                      },
                      onSmilesUpdated: (smiles) {
                        setState(() {
                          _currentSmiles = smiles;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('新 SMILES: $smiles')),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.result.molecularFormula,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFF9F3DD),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '分子量 ${widget.result.molecularWeight.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'SMILES: $_currentSmiles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF7EC8E3),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      widget.result.isValid ? Icons.check_circle : Icons.error,
                      color:
                          widget.result.isValid ? AppColors.aqua : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.result.isValid ? '结构合法' : '结构不合法',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: '收藏',
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: Colors.white.withOpacity(0.25)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('重新生成'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '渲染引擎：${AppConfig.renderEngineName}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
