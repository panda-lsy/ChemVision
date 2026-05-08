import 'package:flutter/material.dart';
import '../../config/app_config.dart';
import '../../models/structure_result.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_view.dart';
import '../widgets/structure_view_controller.dart';
import 'settings_page.dart';

class ResultPage extends StatefulWidget {
  const ResultPage({
    super.key,
    required this.query,
    required this.result,
  });

  final String query;
  final StructureResult result;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  StructureViewController? _controller;
  String _currentSmiles = '';
  String? _selectedAtomId;
  String? _selectedElement;
  final ScrollController _candidateScrollController = ScrollController();
  late final List<StructureCandidate> _candidates;
  late StructureCandidate _activeCandidate;
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

  void _selectCandidate(StructureCandidate candidate) {
    setState(() {
      _activeCandidate = candidate;
      _currentSmiles = candidate.smiles;
    });
  }

  void _showElementPicker() {
    final atomId = _selectedAtomId;
    if (atomId == null) return;

    const elements = ['C', 'O', 'N', 'S', 'Cl', 'Br'];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
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
                  Text('修改元素',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: elements
                        .map((element) => ChoiceChip(
                              label: Text(element),
                              selected: element == _selectedElement,
                              onSelected: (_) =>
                                  _applyElement(atomId, element),
                            ))
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
    if (controller == null) return;
    controller.updateAtomElement(atomId, element);
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
              Text('ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.settings, size: 20),
                      color: AppColors.textMuted,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage()),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const AccentPill(label: '结构已生成'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.query,
              style: Theme.of(context).textTheme.headlineMedium),
          if (_activeCandidate.resolvedName != null &&
              _activeCandidate.resolvedName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('标准名称 ${_activeCandidate.resolvedName}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main interactive structure view
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = (constraints.maxWidth * 0.7)
                          .clamp(400.0, 700.0)
                          .toDouble();
                      return SizedBox(
                        height: height,
                        width: double.infinity,
                        child: StructureView(
                          smiles: _currentSmiles,
                          onControllerReady: (controller) {
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
                            setState(() => _currentSmiles = smiles);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('新 SMILES: $smiles')));
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_activeCandidate.englishName != null &&
                    _activeCandidate.englishName!.isNotEmpty)
                  Text(
                    _activeCandidate.chineseName != null &&
                            _activeCandidate.chineseName!.isNotEmpty
                        ? '${_activeCandidate.englishName}(${_activeCandidate.chineseName})'
                        : _activeCandidate.englishName!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                if (_activeCandidate.englishName != null &&
                    _activeCandidate.englishName!.isNotEmpty)
                  const SizedBox(height: 6),
                if (_activeCandidate.molecularFormula.isNotEmpty)
                  Text(
                    _activeCandidate.molecularFormula,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFF9F3DD),
                        fontWeight: FontWeight.w700),
                  ),
                if (_activeCandidate.molecularFormula.isNotEmpty)
                  const SizedBox(height: 6),
                if (_activeCandidate.molecularWeight > 0)
                  Text(
                    '分子量 ${_activeCandidate.molecularWeight.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                // Candidate carousel
                if (_candidates.length > 1) ...[
                  const SizedBox(height: 12),
                  Text('推测候选',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted)),
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
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 12),
                        padding:
                            const EdgeInsets.only(top: 6, bottom: 6),
                        itemBuilder: (context, index) {
                          final candidate = _candidates[index];
                          final isActive = candidate.smiles ==
                              _activeCandidate.smiles;
                          return SizedBox(
                            width: 160,
                            child: GestureDetector(
                              onTap: () => _selectCandidate(candidate),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.aqua
                                        : Colors.white
                                            .withOpacity(0.06),
                                  ),
                                  color: isActive
                                      ? AppColors.glassStrong
                                      : Colors.transparent,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
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
                                            color: AppColors.textMuted,
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
                                            color: AppColors.textMuted,
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
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.aqua.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'SMILES: $_currentSmiles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF7EC8E3),
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      widget.result.isValid
                          ? Icons.check_circle
                          : Icons.error,
                      color: widget.result.isValid
                          ? AppColors.aqua
                          : Colors.redAccent,
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
                child: SizedBox(
                  height: 52,
                  child: PrimaryButton(
                    label: '收藏',
                    onPressed: () {},
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('重新生成'),
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
