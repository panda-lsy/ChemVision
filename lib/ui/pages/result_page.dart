import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  const ResultPage({super.key, required this.query, required this.result});

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
    // Schedule SVG export for all candidates after UI renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _exportSvgsForAllCandidates();
    });
  }

  Future<void> _exportSvgsForAllCandidates() async {
    // Wait for main structure to render first
    await Future.delayed(const Duration(milliseconds: 1000));
    _exportAndCacheSvg();
    // Then export SVGs for other candidates
    for (int i = 1; i < _candidates.length; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _currentSmiles = _candidates[i].smiles;
        });
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await _exportAndCacheSvgForIndex(i);
        }
      }
    }
    // Restore to first candidate
    if (mounted) {
      setState(() {
        _currentSmiles = _activeCandidate.smiles;
      });
    }
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

  void _selectCandidate(StructureCandidate candidate) {
    setState(() {
      _activeCandidate = candidate;
      _currentSmiles = candidate.smiles;
    });
    // If SVG is not cached yet, export it after rendering
    if (candidate.svgString == null || candidate.svgString!.isEmpty) {
      Future.delayed(const Duration(milliseconds: 1200), () {
        _exportAndCacheSvg();
      });
    }
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
    controller.updateAtomElement(atomId, element);
    Navigator.of(context).pop();
  }

  Future<void> _exportAndCacheSvg() async {
    final controller = _controller;
    if (controller == null || controller.exportSvg == null) {
      return;
    }
    try {
      // Wait longer for SVG to render completely
      await Future.delayed(const Duration(milliseconds: 1000));
      final svgString = await controller.exportSvg!();
      if (svgString != null && svgString.isNotEmpty && mounted) {
        // Update active candidate with cached SVG
        final index = _candidates.indexOf(_activeCandidate);
        if (index >= 0) {
          final updatedCandidate = StructureCandidate(
            smiles: _activeCandidate.smiles,
            resolvedName: _activeCandidate.resolvedName,
            englishName: _activeCandidate.englishName,
            chineseName: _activeCandidate.chineseName,
            molecularFormula: _activeCandidate.molecularFormula,
            molecularWeight: _activeCandidate.molecularWeight,
            source: _activeCandidate.source,
            confidence: _activeCandidate.confidence,
            svgString: svgString,
          );
          setState(() {
            _candidates[index] = updatedCandidate;
            _activeCandidate = updatedCandidate;
          });
        }
      }
    } catch (e) {
      // Silently ignore SVG export errors
    }
  }

  Future<void> _exportAndCacheSvgForIndex(int index) async {
    final controller = _controller;
    if (controller == null || controller.exportSvg == null || index >= _candidates.length) {
      return;
    }
    try {
      final svgString = await controller.exportSvg!();
      if (svgString != null && svgString.isNotEmpty && mounted) {
        final candidate = _candidates[index];
        final updatedCandidate = StructureCandidate(
          smiles: candidate.smiles,
          resolvedName: candidate.resolvedName,
          englishName: candidate.englishName,
          chineseName: candidate.chineseName,
          molecularFormula: candidate.molecularFormula,
          molecularWeight: candidate.molecularWeight,
          source: candidate.source,
          confidence: candidate.confidence,
          svgString: svgString,
        );
        setState(() {
          _candidates[index] = updatedCandidate;
        });
      }
    } catch (e) {
      // Silently ignore SVG export errors
    }
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
              const AccentPill(label: '结构已生成'),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.query, style: Theme.of(context).textTheme.headlineMedium),
          if (_activeCandidate.resolvedName != null &&
              _activeCandidate.resolvedName!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '标准名称 ${_activeCandidate.resolvedName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = (constraints.maxWidth * 0.56)
                          .clamp(320.0, 560.0)
                          .toDouble();
                      return SizedBox(
                        height: height,
                        width: double.infinity,
                        child: StructureView(
                          smiles: _currentSmiles,
                          onControllerReady: (controller) {
                            _controller = controller;
                            _exportAndCacheSvg();
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
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                if (_activeCandidate.molecularFormula.isNotEmpty)
                  Text(
                    _activeCandidate.molecularFormula,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: const Color(0xFFF9F3DD),
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                if (_activeCandidate.molecularFormula.isNotEmpty)
                  const SizedBox(height: 6),
                if (_activeCandidate.molecularWeight > 0)
                  Text(
                    '分子量 ${_activeCandidate.molecularWeight.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (_candidates.length > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    '推测候选',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
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
                            width: 208,
                            child: GestureDetector(
                              onTap: () => _selectCandidate(candidate),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isActive
                                        ? AppColors.aqua
                                        : Colors.white.withOpacity(0.06),
                                  ),
                                  color: isActive
                                      ? AppColors.glassStrong
                                      : Colors.transparent,
                                ),
                                padding: const EdgeInsets.all(6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 7,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: AspectRatio(
                                            aspectRatio: 1.0,
                                            child: Container(
                                              color: Colors.black26,
                                              child: candidate.svgString != null && candidate.svgString!.isNotEmpty
                                                  ? SvgPicture.string(
                                                      candidate.svgString!,
                                                      fit: BoxFit.contain,
                                                      placeholderBuilder: (context) => const Center(
                                                        child: SizedBox(
                                                          width: 24,
                                                          height: 24,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            valueColor: AlwaysStoppedAnimation(Colors.white54),
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : const Center(
                                                      child: Icon(
                                                        Icons.science,
                                                        color: Colors.white24,
                                                        size: 32,
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Display English (Chinese) name if available
                                    if (candidate.englishName != null && candidate.englishName!.isNotEmpty)
                                      Text(
                                        candidate.chineseName != null && candidate.chineseName!.isNotEmpty
                                            ? '${candidate.englishName}(${candidate.chineseName})'
                                            : candidate.englishName!,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppColors.textMuted,
                                              fontSize: 10,
                                              height: 1.0,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (candidate.englishName != null && candidate.englishName!.isNotEmpty)
                                      const SizedBox(height: 2),
                                    Text(
                                      candidate.resolvedName ?? candidate.smiles,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            height: 1.0,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      candidate.molecularFormula,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                      side: BorderSide(color: Colors.white.withOpacity(0.25)),
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
