import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/reaction_completion_result.dart';
import '../../services/ai_settings_store.dart';
import '../../services/reaction_completion_service.dart';
import '../../services/reaction_knowledge_base_store.dart';
import '../../utils/reaction_kb_export.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/quick_tag.dart';
import '../../providers/reaction_favorites_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum KnowledgeFilterOption {
  all,
  hasEmbedding,
  noEmbedding,
  hasSource,
  noSource,
}

enum KnowledgeSortOption {
  newestFirst,
  oldestFirst,
  titleAsc,
  titleDesc,
}

enum BatchExportMode {
  selected,
  filtered,
}

class ReactionPage extends StatefulWidget {
  const ReactionPage({super.key});

  @override
  State<ReactionPage> createState() => _ReactionPageState();
}

class _ReactionPageState extends State<ReactionPage> {
  final TextEditingController _queryController = TextEditingController();
  final TextEditingController _knowledgeSearchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _keywordsController = TextEditingController();
  final TextEditingController _equationController = TextEditingController();
  final TextEditingController _reactantsController = TextEditingController();
  final TextEditingController _productsController = TextEditingController();
  final TextEditingController _reactionTypeController = TextEditingController();
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _catalystController = TextEditingController();
  final TextEditingController _solventController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _conditionRationaleController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _sourceChapterController = TextEditingController();
  final TextEditingController _explanationController = TextEditingController();

  final ReactionCompletionService _service = ReactionCompletionService();
  final ReactionKnowledgeBaseStore _store = ReactionKnowledgeBaseStore();

  ReactionCompletionResult? _result;
  List<ReactionKnowledgeEntry> _knowledgeEntries = const [];
  final Set<String> _selectedKnowledgeIds = {};
  bool _isLoading = false;
  bool _isSavingEntry = false;
  String? _editingEntryId;
  String? _error;
  KnowledgeFilterOption _knowledgeFilter = KnowledgeFilterOption.all;
  KnowledgeSortOption _knowledgeSort = KnowledgeSortOption.newestFirst;

  static const _samples = [
    '乙酸+乙醇→?',
    '乙醇氧化→?',
    '乙烯+水→?',
    '苯+溴→?',
  ];

  @override
  void initState() {
    super.initState();
    _loadKnowledgeEntries();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _knowledgeSearchController.dispose();
    _titleController.dispose();
    _keywordsController.dispose();
    _equationController.dispose();
    _reactantsController.dispose();
    _productsController.dispose();
    _reactionTypeController.dispose();
    _temperatureController.dispose();
    _catalystController.dispose();
    _solventController.dispose();
    _otherController.dispose();
    _conditionRationaleController.dispose();
    _sourceController.dispose();
    _sourceChapterController.dispose();
    _explanationController.dispose();
    super.dispose();
  }

  Future<void> _loadKnowledgeEntries() async {
    final entries = await _store.loadAll();
    if (!mounted) return;
    setState(() {
      _knowledgeEntries = entries;
      _selectedKnowledgeIds.removeWhere(
        (id) => entries.every((entry) => entry.id != id),
      );
    });
  }

  Future<void> _completeReaction() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入不完整的反应信息')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await AiSettingsStore().load();
      final result = await _service.completeReaction(
        query: query,
        settings: settings,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _result = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveKnowledgeEntry() async {
    final title = _titleController.text.trim();
    final keywords = _splitKeywords(_keywordsController.text);
    final equation = _equationController.text.trim();
    final source = _sourceController.text.trim();
    final explanation = _explanationController.text.trim();

    if (title.isEmpty || keywords.isEmpty || equation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标题、关键词和反应式不能为空')),
      );
      return;
    }

    setState(() {
      _isSavingEntry = true;
    });

    final settings = await AiSettingsStore().load();

    final entry = ReactionKnowledgeEntry(
      id: _editingEntryId ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      keywords: keywords,
      completedEquation: equation,
      conditionFields: {
        'temperature': _temperatureController.text.trim(),
        'catalyst': _catalystController.text.trim(),
        'solvent': _solventController.text.trim(),
        'other': _otherController.text.trim(),
      },
      sourceReference: source.isEmpty ? '未填写来源' : source,
      explanation: explanation.isEmpty ? '用户自定义知识库条目' : explanation,
      reactants: _splitKeywords(_reactantsController.text),
      products: _splitKeywords(_productsController.text),
      reactionType: _reactionTypeController.text.trim(),
      conditionRationale: _conditionRationaleController.text.trim(),
      sourceChapter: _sourceChapterController.text.trim(),
    );

    try {
      final prepared = await _service.prepareKnowledgeEntry(
        entry,
        settings: settings,
      );
      await _store.upsert(prepared);
      await _loadKnowledgeEntries();
      _clearKnowledgeForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingEntryId == null ? '已保存到个人知识库' : '已更新知识库条目'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingEntry = false;
        });
      }
    }
  }

  Future<void> _deleteKnowledgeEntry(String id) async {
    await _store.remove(id);
    _selectedKnowledgeIds.remove(id);
    await _loadKnowledgeEntries();
  }

  void _toggleKnowledgeSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedKnowledgeIds.add(id);
      } else {
        _selectedKnowledgeIds.remove(id);
      }
    });
  }

  void _selectAllKnowledgeEntries() {
    final filteredEntries = _filteredKnowledgeEntries;
    setState(() {
      _selectedKnowledgeIds
        ..clear()
        ..addAll(filteredEntries.map((entry) => entry.id));
    });
  }

  void _clearKnowledgeSelection() {
    setState(() {
      _selectedKnowledgeIds.clear();
    });
  }

  List<ReactionKnowledgeEntry> _selectedEntries() {
    return _knowledgeEntries
        .where((entry) => _selectedKnowledgeIds.contains(entry.id))
        .toList();
  }

  List<ReactionKnowledgeEntry> get _filteredKnowledgeEntries {
    final keyword = _knowledgeSearchController.text.trim().toLowerCase();
    final filtered = _knowledgeEntries.where((entry) {
      final matchSearch = keyword.isEmpty || _matchesSearch(entry, keyword);
      if (!matchSearch) {
        return false;
      }
      switch (_knowledgeFilter) {
        case KnowledgeFilterOption.all:
          return true;
        case KnowledgeFilterOption.hasEmbedding:
          return (entry.embedding?.isNotEmpty ?? false);
        case KnowledgeFilterOption.noEmbedding:
          return !(entry.embedding?.isNotEmpty ?? false);
        case KnowledgeFilterOption.hasSource:
          return entry.sourceReference.trim().isNotEmpty &&
              entry.sourceReference.trim() != '未填写来源';
        case KnowledgeFilterOption.noSource:
          return entry.sourceReference.trim().isEmpty ||
              entry.sourceReference.trim() == '未填写来源';
      }
    }).toList();

    filtered.sort((a, b) {
      switch (_knowledgeSort) {
        case KnowledgeSortOption.newestFirst:
          return _idSortValue(b.id).compareTo(_idSortValue(a.id));
        case KnowledgeSortOption.oldestFirst:
          return _idSortValue(a.id).compareTo(_idSortValue(b.id));
        case KnowledgeSortOption.titleAsc:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case KnowledgeSortOption.titleDesc:
          return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      }
    });
    return filtered;
  }

  bool _matchesSearch(ReactionKnowledgeEntry entry, String keyword) {
    final buffer = StringBuffer()
      ..write(entry.title)
      ..write(' ')
      ..write(entry.completedEquation)
      ..write(' ')
      ..write(entry.sourceReference)
      ..write(' ')
      ..write(entry.explanation)
      ..write(' ')
      ..write(entry.keywords.join(' '));
    return buffer.toString().toLowerCase().contains(keyword);
  }

  int _idSortValue(String id) {
    return int.tryParse(id) ?? 0;
  }

  Future<void> _exportKnowledgeBaseToFile({bool selectedOnly = false}) async {
    final entries = selectedOnly ? _selectedEntries() : _knowledgeEntries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可导出的知识库条目')),
      );
      return;
    }

    final jsonText = await _store.exportJson(entries);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    await saveTextToFile(
      fileName: 'reaction_knowledge_base_$stamp.json',
      text: jsonText,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出 ${entries.length} 条知识库到文件')),
      );
    }
  }

  Future<void> _exportFilteredKnowledgeBaseToFile() async {
    final entries = _filteredKnowledgeEntries;
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前筛选结果为空，无法导出')),
      );
      return;
    }
    final jsonText = await _store.exportJson(entries);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    await saveTextToFile(
      fileName: 'reaction_knowledge_base_filtered_$stamp.json',
      text: jsonText,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出筛选结果 ${entries.length} 条到文件')),
      );
    }
  }

  Future<ImportDuplicateStrategy?> _selectImportDuplicateStrategy() async {
    return showDialog<ImportDuplicateStrategy>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: const Text('选择导入去重策略'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('覆盖：遇到重复条目时，用导入文件替换本地记录。'),
            SizedBox(height: 8),
            Text('合并：遇到重复条目时，合并关键词和字段，保留较完整信息。'),
            SizedBox(height: 8),
            Text('跳过：遇到重复条目时，保留本地记录，不导入该条。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImportDuplicateStrategy.skip),
            child: const Text('跳过重复'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, ImportDuplicateStrategy.merge),
            child: const Text('合并重复'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ImportDuplicateStrategy.overwrite),
            child: const Text('覆盖重复'),
          ),
        ],
      ),
    );
  }

  String _importStrategyLabel(ImportDuplicateStrategy strategy) {
    switch (strategy) {
      case ImportDuplicateStrategy.overwrite:
        return '覆盖';
      case ImportDuplicateStrategy.merge:
        return '合并';
      case ImportDuplicateStrategy.skip:
        return '跳过';
    }
  }

  Future<void> _importKnowledgeBaseFromFile() async {
    final strategy = await _selectImportDuplicateStrategy();
    if (strategy == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入失败：无法读取文件内容')),
        );
      }
      return;
    }

    try {
      final jsonText = utf8.decode(bytes);
      final count = await _store.importJson(
        jsonText,
        strategy: strategy,
      );
      await _loadKnowledgeEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已从文件导入 $count 条知识库记录（${_importStrategyLabel(strategy)}策略）')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  Future<void> _batchDeleteKnowledgeEntries() async {
    if (_selectedKnowledgeIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择要删除的知识库条目')),
      );
      return;
    }

    await _store.removeMany(_selectedKnowledgeIds);
    _clearKnowledgeSelection();
    await _loadKnowledgeEntries();
  }

  Future<void> _rebuildEmbeddings() async {
    final messenger = ScaffoldMessenger.of(context);
    final targetEntries = _selectedKnowledgeIds.isEmpty
        ? List<ReactionKnowledgeEntry>.from(_knowledgeEntries)
        : _knowledgeEntries
            .where((entry) => _selectedKnowledgeIds.contains(entry.id))
            .toList();

    if (targetEntries.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('没有可重建向量的条目')),
      );
      return;
    }

    final settings = await AiSettingsStore().load();
    // Web 端 API Key 由 Worker 注入
    if (!kIsWeb && settings.apiKey.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('请先在设置里配置 API Key 才能生成向量')),
      );
      return;
    }

    setState(() {
      _isSavingEntry = true;
    });

    try {
      final updatedEntries = <ReactionKnowledgeEntry>[];
      for (final entry in _knowledgeEntries) {
        if (_selectedKnowledgeIds.isNotEmpty &&
            !_selectedKnowledgeIds.contains(entry.id)) {
          updatedEntries.add(entry);
          continue;
        }
        final prepared = await _service.prepareKnowledgeEntry(
          entry,
          settings: settings,
        );
        updatedEntries.add(prepared);
      }
      await _store.saveAll(updatedEntries);
      await _loadKnowledgeEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已重建 ${targetEntries.length} 条知识库的 EMB 向量')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('重建向量失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingEntry = false;
        });
      }
    }
  }

  void _clearKnowledgeForm() {
    _editingEntryId = null;
    _titleController.clear();
    _keywordsController.clear();
    _equationController.clear();
    _reactantsController.clear();
    _productsController.clear();
    _reactionTypeController.clear();
    _temperatureController.clear();
    _catalystController.clear();
    _solventController.clear();
    _otherController.clear();
    _conditionRationaleController.clear();
    _sourceController.clear();
    _sourceChapterController.clear();
    _explanationController.clear();
  }

  void _fillKnowledgeForm(ReactionKnowledgeEntry entry) {
    _editingEntryId = entry.id;
    _titleController.text = entry.title;
    _keywordsController.text = entry.keywords.join('，');
    _equationController.text = entry.completedEquation;
    _reactantsController.text = entry.reactants.join('，');
    _productsController.text = entry.products.join('，');
    _reactionTypeController.text = entry.reactionType;
    _temperatureController.text = entry.conditionFields['temperature'] ?? '';
    _catalystController.text = entry.conditionFields['catalyst'] ?? '';
    _solventController.text = entry.conditionFields['solvent'] ?? '';
    _otherController.text = entry.conditionFields['other'] ?? '';
    _conditionRationaleController.text = entry.conditionRationale;
    _sourceController.text = entry.sourceReference;
    _sourceChapterController.text = entry.sourceChapter;
    _explanationController.text = entry.explanation;
  }

  List<String> _splitKeywords(String raw) {
    return raw
        .split(RegExp(r'[，,、\n\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
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
              AccentPill(label: '知识库 ${_knowledgeEntries.length}'),
            ],
          ),
          const SizedBox(height: 18),
          Text('反应方程式语义补全', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          GlassPanel(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '你可以把每本教材的差异知识单独填到个人知识库里。系统不会预置固定教材答案，而是先检索你自己的条目，再调用大模型做补全。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _queryController,
                  maxLines: 4,
                  minLines: 3,
                  cursorColor: AppColors.aqua,
                  decoration: const InputDecoration(
                    hintText: '例如：乙酸和乙醇，缺少条件；或者：乙烯和水反应',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samples
                      .map(
                        (item) => QuickTag(
                          label: item,
                          onTap: () {
                            setState(() {
                              _queryController.text = item;
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: _isLoading ? '补全中...' : '开始补全',
                  onPressed: _isLoading ? null : _completeReaction,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[
            GlassPanel(
              radius: 20,
              child: Text(
                _error!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.redAccent.shade100),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_result != null) ...[
            _buildResultCard(context, _result!),
            const SizedBox(height: 16),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.star_border, size: 18),
                label: const Text("收藏此反应"),
                onPressed: () {
                  try {
                    final eq = ReactionEquation(
                      title: result.completedEquation.length > 30
                          ? '${result.completedEquation.substring(0, 30)}...'
                          : result.completedEquation,
                      rxnData: result.completedEquation,
                    );
                    ProviderScope.containerOf(context)
                        .read(reactionFavoritesControllerProvider.notifier)
                        .add(eq);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("已添加到反应收藏")),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("收藏失败: $e")),
                      );
                    }
                  }
                },
              ),
            ),
          ],
          _buildKnowledgeManager(context),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, ReactionCompletionResult result) {
    final confidencePercent = (result.confidence * 100).toStringAsFixed(0);

    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: result.usedModel ? AppColors.aqua : AppColors.amber,
              ),
              const SizedBox(width: 8),
              Text(
                result.usedModel ? '模型补全结果' : '模板补全结果',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text('$confidencePercent%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.aqua,
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 12),
          Text('补全方程式', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          SelectableText(
            result.completedEquation,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.dayBluePrimary
                      : const Color(0xFFF9F3DD),
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (result.reactants.isNotEmpty || result.products.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (result.reactants.isNotEmpty)
                  _buildChemChip(
                    context,
                    '反应物: ${result.reactants.join(' + ')}',
                    AppColors.aqua,
                  ),
                if (result.products.isNotEmpty)
                  _buildChemChip(
                    context,
                    '产物: ${result.products.join(' + ')}',
                    AppColors.amber,
                  ),
              ],
            ),
          ],
          if (result.reactionType.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildChemChip(context, '反应类型: ${result.reactionType}', AppColors.aqua),
          ],
          const SizedBox(height: 12),
          Text('条件字段', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          _fieldRow(context, '温度/热源', result.conditionFields['temperature']),
          _fieldRow(context, '催化剂', result.conditionFields['catalyst']),
          _fieldRow(context, '溶剂', result.conditionFields['solvent']),
          _fieldRow(context, '其他', result.conditionFields['other']),
          if (result.conditionRationale.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('条件推断依据', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              result.conditionRationale,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppColors.dayTextPrimary.withValues(alpha: 0.85)
                        : AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
            ),
          ],
          const SizedBox(height: 12),
          Text('推理说明', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Text(
            result.explanation,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text('来源引用', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: result.sourceReferences
                .map((item) => QuickTag(label: item, onTap: () {}))
                .toList(),
          ),
          if (result.candidateTitles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('候选模板', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.candidateTitles
                  .map((item) => QuickTag(label: item, onTap: () {}))
                  .toList(),
            ),
          ],
          if (result.matchedKeywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('命中关键词', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: result.matchedKeywords
                  .map((item) => QuickTag(label: item, onTap: () {}))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKnowledgeManager(BuildContext context) {
    final filteredEntries = _filteredKnowledgeEntries;
    return GlassPanel(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('个人知识库', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _knowledgeSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索标题 / 反应式 / 关键词 / 来源',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _knowledgeFilter == KnowledgeFilterOption.all,
                onSelected: (_) => setState(() {
                  _knowledgeFilter = KnowledgeFilterOption.all;
                }),
              ),
              ChoiceChip(
                label: const Text('有向量'),
                selected: _knowledgeFilter == KnowledgeFilterOption.hasEmbedding,
                onSelected: (_) => setState(() {
                  _knowledgeFilter = KnowledgeFilterOption.hasEmbedding;
                }),
              ),
              ChoiceChip(
                label: const Text('无向量'),
                selected: _knowledgeFilter == KnowledgeFilterOption.noEmbedding,
                onSelected: (_) => setState(() {
                  _knowledgeFilter = KnowledgeFilterOption.noEmbedding;
                }),
              ),
              ChoiceChip(
                label: const Text('有来源'),
                selected: _knowledgeFilter == KnowledgeFilterOption.hasSource,
                onSelected: (_) => setState(() {
                  _knowledgeFilter = KnowledgeFilterOption.hasSource;
                }),
              ),
              ChoiceChip(
                label: const Text('无来源'),
                selected: _knowledgeFilter == KnowledgeFilterOption.noSource,
                onSelected: (_) => setState(() {
                  _knowledgeFilter = KnowledgeFilterOption.noSource;
                }),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<KnowledgeSortOption>(
                  value: _knowledgeSort,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: '排序',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: KnowledgeSortOption.newestFirst,
                      child: Text('最新优先'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeSortOption.oldestFirst,
                      child: Text('最早优先'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeSortOption.titleAsc,
                      child: Text('标题 A-Z'),
                    ),
                    DropdownMenuItem(
                      value: KnowledgeSortOption.titleDesc,
                      child: Text('标题 Z-A'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _knowledgeSort = value;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '当前显示 ${filteredEntries.length} / ${_knowledgeEntries.length} 条',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.light
                    ? AppColors.dayTextMuted
                    : AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _importKnowledgeBaseFromFile,
                icon: const Icon(Icons.file_upload_outlined, size: 18),
                label: const Text('从文件导入'),
              ),
              FilledButton.tonalIcon(
                onPressed: _knowledgeEntries.isEmpty
                    ? null
                    : () => _exportKnowledgeBaseToFile(selectedOnly: false),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('一键导出为文件'),
              ),
              PopupMenuButton<BatchExportMode>(
                enabled: _selectedKnowledgeIds.isNotEmpty || filteredEntries.isNotEmpty,
                onSelected: (mode) async {
                  switch (mode) {
                    case BatchExportMode.selected:
                      await _exportKnowledgeBaseToFile(selectedOnly: true);
                      break;
                    case BatchExportMode.filtered:
                      await _exportFilteredKnowledgeBaseToFile();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<BatchExportMode>(
                    value: BatchExportMode.selected,
                    enabled: _selectedKnowledgeIds.isNotEmpty,
                    child: const Text('导出所选条目'),
                  ),
                  PopupMenuItem<BatchExportMode>(
                    value: BatchExportMode.filtered,
                    enabled: filteredEntries.isNotEmpty,
                    child: const Text('仅导出当前筛选结果'),
                  ),
                ],
                child: IgnorePointer(
                  child: FilledButton.tonalIcon(
                    onPressed: () {},
                    icon: const Icon(Icons.outbox_outlined, size: 18),
                    label: const Text('批量导出'),
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _selectedKnowledgeIds.isEmpty
                    ? null
                    : _batchDeleteKnowledgeEntries,
                icon: const Icon(Icons.delete_forever_outlined, size: 18),
                label: const Text('批量删除'),
              ),
              FilledButton.tonalIcon(
                onPressed: _knowledgeEntries.isEmpty ? null : _rebuildEmbeddings,
                icon: const Icon(Icons.scatter_plot_outlined, size: 18),
                label: Text(
                  _selectedKnowledgeIds.isEmpty ? '重建全部向量' : '重建所选向量',
                ),
              ),
              TextButton(
                onPressed: filteredEntries.isEmpty ? null : _selectAllKnowledgeEntries,
                child: const Text('全选'),
              ),
              TextButton(
                onPressed: _selectedKnowledgeIds.isEmpty ? null : _clearKnowledgeSelection,
                child: const Text('清除选择'),
              ),
              TextButton(
                onPressed: _knowledgeEntries.isEmpty
                    ? null
                    : () async {
                        await _store.clear();
                        _clearKnowledgeSelection();
                        await _loadKnowledgeEntries();
                      },
                child: const Text('清空全部'),
              ),
            ],
          ),
          if (_editingEntryId != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.aqua.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.aqua.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18, color: AppColors.aqua),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '正在编辑条目，保存将覆盖当前记录。',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: _clearKnowledgeForm,
                    child: const Text('取消编辑'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '这里不预置固定教材答案，用户可按自己的教材版本逐条补充反应模板。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: '标题，例如：乙酸乙酯的酯化反应'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _keywordsController,
            decoration: const InputDecoration(
              hintText: '关键词，多个用逗号分隔，如：乙酸,乙醇,酯化,浓硫酸',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _equationController,
            decoration: const InputDecoration(hintText: '完整反应式，例如：CH3COOH + C2H5OH ⇌ CH3COOC2H5 + H2O'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _reactantsController,
                  decoration: const InputDecoration(hintText: '反应物，逗号分隔，如：乙酸,乙醇'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _productsController,
                  decoration: const InputDecoration(hintText: '产物，逗号分隔，如：乙酸乙酯,水'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reactionTypeController,
            decoration: const InputDecoration(hintText: '反应类型，如：化合/分解/置换/复分解/酯化/氧化还原'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _temperatureController,
                  decoration: const InputDecoration(hintText: '温度/热源'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _catalystController,
                  decoration: const InputDecoration(hintText: '催化剂'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _solventController,
                  decoration: const InputDecoration(hintText: '溶剂'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _otherController,
                  decoration: const InputDecoration(hintText: '其他条件'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _conditionRationaleController,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(hintText: '条件推断依据（为什么需要该条件，如：吸热反应需高温提供活化能）'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  decoration: const InputDecoration(hintText: '来源引用，如：人教版选必2 P52'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _sourceChapterController,
                  decoration: const InputDecoration(hintText: '教材章节，如：人教版必修1 第三章'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _explanationController,
            maxLines: 3,
            minLines: 2,
            decoration: const InputDecoration(hintText: '补充说明 / 适用场景 / 教材差异'),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: _isSavingEntry
                ? '保存中...'
                : (_editingEntryId == null ? '保存到个人知识库' : '保存修改'),
            onPressed: _isSavingEntry ? null : _saveKnowledgeEntry,
          ),
          const SizedBox(height: 12),
          if (_knowledgeEntries.isEmpty)
            Text(
              '当前知识库为空，你可以先从教材中录入 1-2 条典型反应。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else if (filteredEntries.isEmpty)
            Text(
              '当前筛选结果为空，请调整搜索关键词或筛选条件。',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: filteredEntries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.light
                              ? AppColors.dayGlassStrong
                              : AppColors.glass,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? AppColors.dayBluePrimary.withValues(alpha: 0.12)
                                  : Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: _selectedKnowledgeIds.contains(entry.id),
                                  onChanged: (value) => _toggleKnowledgeSelection(
                                    entry.id,
                                    value ?? false,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.title,
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _fillKnowledgeForm(entry),
                                  icon: const Icon(Icons.edit_outlined),
                                  color: AppColors.aqua,
                                ),
                                IconButton(
                                  onPressed: () => _deleteKnowledgeEntry(entry.id),
                                  icon: const Icon(Icons.delete_outline),
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? AppColors.dayTextMuted
                                      : AppColors.textMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(entry.completedEquation, style: Theme.of(context).textTheme.bodyMedium),
                            if (entry.reactionType.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '类型: ${entry.reactionType}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).brightness == Brightness.light
                                          ? AppColors.dayBluePrimary
                                          : AppColors.aqua,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              '条件: ${entry.conditionFields.entries.where((e) => e.value.trim().isNotEmpty).map((e) => '${e.key}=${e.value}').join(' · ')}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? AppColors.dayTextMuted
                                      : AppColors.textMuted),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: entry.keywords
                                  .map((item) => QuickTag(label: item, onTap: () {}))
                                  .toList(),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry.sourceChapter.isNotEmpty
                                  ? '${entry.sourceChapter} · ${entry.sourceReference}'
                                  : entry.sourceReference,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.light
                                      ? AppColors.dayBluePrimary
                                      : AppColors.aqua),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _fieldRow(BuildContext context, String label, String? value) {
    final display = (value == null || value.trim().isEmpty) ? '待补全' : value;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppColors.dayTextMuted
                        : AppColors.textMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              display,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChemChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}