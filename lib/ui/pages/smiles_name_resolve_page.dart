import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/structure_result.dart';
import '../../providers/structure_service_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_view.dart';

class SmilesNameResolvePage extends ConsumerStatefulWidget {
  const SmilesNameResolvePage({
    super.key,
    required this.smiles,
    required this.previousCandidate,
  });

  final String smiles;
  final StructureCandidate previousCandidate;

  @override
  ConsumerState<SmilesNameResolvePage> createState() =>
      _SmilesNameResolvePageState();
}

class _SmilesNameResolvePageState extends ConsumerState<SmilesNameResolvePage> {
  bool _loading = true;
  List<StructureCandidate> _options = const [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final result =
        await ref.read(structureServiceProvider).reverseResolveName(widget.smiles);
    if (!mounted) {
      return;
    }
    final options = _buildOptions(result);
    setState(() {
      _options = options;
      _selectedIndex = 0;
      _loading = false;
    });
  }

  List<StructureCandidate> _buildOptions(StructureResult result) {
    final options = <StructureCandidate>[];
    final primaryName = result.englishName ?? result.resolvedName;
    if ((primaryName != null && primaryName.isNotEmpty) ||
        (result.chineseName != null && result.chineseName!.isNotEmpty)) {
      options.add(
        StructureCandidate(
          smiles: widget.smiles,
          resolvedName: result.resolvedName,
          englishName: result.englishName,
          chineseName: result.chineseName,
          molecularFormula: result.molecularFormula,
          molecularWeight: result.molecularWeight,
          source: 'resolved',
          confidence: result.confidence,
        ),
      );
    }
    for (final item in result.alternatives) {
      if ((item.englishName ?? '').isEmpty && (item.chineseName ?? '').isEmpty) {
        continue;
      }
      options.add(
        StructureCandidate(
          smiles: widget.smiles,
          resolvedName: item.resolvedName,
          englishName: item.englishName,
          chineseName: item.chineseName,
          molecularFormula: item.molecularFormula,
          molecularWeight: item.molecularWeight,
          source: item.source,
          confidence: item.confidence,
        ),
      );
    }
    if (options.isEmpty) {
      options.add(
        StructureCandidate(
          smiles: widget.smiles,
          resolvedName: '已修改结构',
          englishName: widget.previousCandidate.englishName,
          chineseName: widget.previousCandidate.chineseName,
          molecularFormula: widget.previousCandidate.molecularFormula,
          molecularWeight: widget.previousCandidate.molecularWeight,
          source: 'fallback',
          confidence: 0.5,
        ),
      );
    }
    return options;
  }

  String _titleOf(StructureCandidate c) {
    final en = c.englishName ?? '';
    final zh = c.chineseName ?? '';
    if (en.isNotEmpty && zh.isNotEmpty) {
      return '$en（$zh）';
    }
    if (en.isNotEmpty) {
      return en;
    }
    if (zh.isNotEmpty) {
      return zh;
    }
    return c.resolvedName ?? '已修改结构';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Text('更新名称', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: StructureView(smiles: widget.smiles, readOnly: true),
            ),
          ),
          const SizedBox(height: 14),
          if (_loading) ...[
            GlassPanel(
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.aqua : AppColors.dayBluePrimary,
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('解析中…'),
                ],
              ),
            ),
          ] else ...[
            Text('请选择名称候选', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final selected = index == _selectedIndex;
                  final isFallback = (option.resolvedName ?? '') == '已修改结构';
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? AppColors.dayBluePrimary
                              : Colors.white.withValues(alpha: 0.14),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleOf(option),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: isFallback
                                      ? AppColors.textMuted
                                      : null,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          if (isFallback &&
                              (widget.previousCandidate.englishName ?? '')
                                  .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '原名称：${_titleOf(widget.previousCandidate)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '使用该名称',
              onPressed: () => Navigator.of(context).pop(_options[_selectedIndex]),
            ),
          ],
        ],
      ),
    );
  }
}
