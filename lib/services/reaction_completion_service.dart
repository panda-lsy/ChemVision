import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../models/reaction_completion_result.dart';
import '../services/ai_settings_store.dart';
import '../services/reaction_knowledge_base_store.dart';
import '../services/vivo_aigc_client.dart';

class ReactionCompletionService {
  ReactionCompletionService({VivoAigcClient? client})
      : _client = client ?? VivoAigcClient();

  final VivoAigcClient _client;
  final ReactionKnowledgeBaseStore _store = ReactionKnowledgeBaseStore();
  static const String _embeddingModel = 'bge-base-zh-v1.5';

  Future<ReactionCompletionResult> completeReaction({
    required String query,
    required AiSettings settings,
  }) async {
    final normalized = _normalizeQuery(query);
    if (normalized.isEmpty) {
      throw ArgumentError('请输入反应信息');
    }

    final knowledgeBase = await _store.loadAll();
    final matches = await _rankKnowledgeBase(
      normalized,
      knowledgeBase,
      settings,
    );
    final fallback = _buildFallbackResult(normalized, matches);

    if (settings.apiKey.trim().isEmpty) {
      return fallback.copyWith(usedModel: false);
    }

    final prompt = _buildPrompt(normalized, matches, knowledgeBase);
    try {
      final response = await _client.generateText(
        apiKey: settings.apiKey,
        model: settings.textModel,
        prompt: prompt,
        baseUrl: settings.baseUrl.isEmpty
            ? AppConfig.vivoAigcBaseUrl
            : settings.baseUrl,
      );

      final parsed = _parseModelResponse(
        normalized: normalized,
        rawResponse: response,
        fallback: fallback,
        matches: matches,
      );
      return parsed ?? fallback.copyWith(usedModel: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReactionCompletion] 模型请求失败：$e');
      }
      return fallback.copyWith(usedModel: false);
    }
  }

  Future<List<_ReactionMatch>> _rankKnowledgeBase(
    String query,
    List<ReactionKnowledgeEntry> knowledgeBase,
    AiSettings settings,
  ) async {
    final queryTokens = _tokenize(query);
    final matches = <_ReactionMatch>[];
    List<double>? queryEmbedding;

    final hasEntryEmbeddings = knowledgeBase.any((entry) => entry.embedding != null && entry.embedding!.isNotEmpty);
    if (settings.apiKey.trim().isNotEmpty && hasEntryEmbeddings) {
      try {
        queryEmbedding = await _embedText(
          query,
          settings: settings,
          isQuery: true,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[ReactionCompletion] query embedding failed: $e');
        }
      }
    }

    for (final entry in knowledgeBase) {
      final matched = entry.keywords
          .where((keyword) => query.contains(keyword) || _tokenize(keyword).any(queryTokens.contains))
          .toList();
      final keywordScore = matched.isEmpty
          ? 0.0
          : (matched.length / entry.keywords.length).clamp(0.18, 0.96).toDouble();

      double embeddingScore = 0.0;
      if (queryEmbedding != null && entry.embedding != null && entry.embedding!.isNotEmpty) {
        embeddingScore = _cosineSimilarity(queryEmbedding, entry.embedding!).clamp(0.0, 1.0);
      }

      final confidence = (keywordScore * 0.45 + embeddingScore * 0.55)
          .clamp(0.08, 0.98)
          .toDouble();

      if (matched.isEmpty && embeddingScore <= 0.0) {
        continue;
      }

      matches.add(_ReactionMatch(entry: entry, matchedKeywords: matched, confidence: confidence));
    }

    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches;
  }

  Future<List<double>> _embedText(
    String text, {
    required AiSettings settings,
    required bool isQuery,
  }) async {
    final input = isQuery
        ? '为这个句子生成表示以用于检索相关文章：$text'
        : text;
    final vectors = await _client.generateEmbeddings(
      apiKey: settings.apiKey,
      modelName: _embeddingModel,
      sentences: [input],
      baseUrl: settings.baseUrl.isEmpty ? AppConfig.vivoAigcBaseUrl : settings.baseUrl,
    );
    if (vectors.isEmpty) {
      throw Exception('Embedding 返回为空');
    }
    return vectors.first;
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    final length = a.length < b.length ? a.length : b.length;
    if (length == 0) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (var i = 0; i < length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  ReactionCompletionResult _buildFallbackResult(
    String query,
    List<_ReactionMatch> matches,
  ) {
    final best = matches.isNotEmpty ? matches.first : null;
    if (best == null) {
      return ReactionCompletionResult(
        query: query,
        completedEquation: '知识库为空或未命中，建议先在“个人知识库”中添加教材反应模板。',
        conditionFields: const {
          'temperature': '待补全',
          'catalyst': '待补全',
          'solvent': '待补全',
          'other': '待补全',
        },
        explanation:
          '当前没有可用的个人知识库条目，或输入与知识库未匹配。请先补充教材版本对应的反应模板，再重新发起补全。',
        confidence: 0.08,
        sourceReferences: const ['个人知识库为空'],
        matchedKeywords: const [],
        candidateTitles: const [],
        usedModel: false,
      );
    }

    return ReactionCompletionResult(
      query: query,
      completedEquation: best.entry.completedEquation,
      conditionFields: best.entry.conditionFields,
      explanation: best.entry.explanation,
      confidence: best.confidence,
      sourceReferences: [best.entry.sourceReference],
      matchedKeywords: best.matchedKeywords,
      candidateTitles: matches.take(3).map((m) => m.entry.title).toList(),
      usedModel: false,
    );
  }

  String _buildPrompt(
    String query,
    List<_ReactionMatch> matches,
    List<ReactionKnowledgeEntry> knowledgeBase,
  ) {
    final kbContext = matches.isEmpty
        ? (knowledgeBase.isEmpty
            ? '个人知识库为空'
            : '无本地命中')
        : matches
            .take(3)
            .map(
              (match) => '- ${match.entry.title} | 公式: ${match.entry.completedEquation} | 条件: ${match.entry.conditionFields.entries.map((e) => '${e.key}=${e.value}').join(', ')} | 来源: ${match.entry.sourceReference}',
            )
            .join('\n');

    return '''
你是 ChemVISION 的化学反应式语义补全引擎。
任务：根据用户输入，补全可能的完整反应方程式，并拆分条件字段（temperature/catalyst/solvent/other），同时给出来源引用和推理说明。

要求：
1. 仅输出 JSON，不要输出多余说明。
2. JSON 必须包含以下字段：completedEquation, conditionFields, explanation, confidence, sourceReferences, candidateTitles, matchedKeywords。
3. 如果信息不足，返回尽可能保守的补全结果，并在 explanation 中说明。
4. 优先使用本地知识检索结果作为候选上下文，再进行推理。

用户输入：$query

本地知识候选：
$kbContext

输出示例：
{
  "completedEquation": "...",
  "conditionFields": {
    "temperature": "...",
    "catalyst": "...",
    "solvent": "...",
    "other": "..."
  },
  "explanation": "...",
  "confidence": 0.72,
  "sourceReferences": ["..."],
  "candidateTitles": ["..."],
  "matchedKeywords": ["..."]
}
''';
  }

  ReactionCompletionResult? _parseModelResponse({
    required String normalized,
    required String rawResponse,
    required ReactionCompletionResult fallback,
    required List<_ReactionMatch> matches,
  }) {
    final jsonText = _extractJson(rawResponse);
    if (jsonText == null) {
      return null;
    }

    try {
      final data = jsonDecode(jsonText);
      if (data is! Map<String, dynamic>) {
        return null;
      }

      final completedEquation = _stringOrNull(data['completedEquation']) ?? fallback.completedEquation;
      final explanation = _stringOrNull(data['explanation']) ?? fallback.explanation;
      final confidence = _doubleOrNull(data['confidence']) ?? fallback.confidence;
      final conditionFields = _mapStringToString(data['conditionFields']) ?? fallback.conditionFields;
      final sourceReferences = _stringList(data['sourceReferences']) ?? fallback.sourceReferences;
      final candidateTitles = _stringList(data['candidateTitles']) ?? fallback.candidateTitles;
      final matchedKeywords = _stringList(data['matchedKeywords']) ?? fallback.matchedKeywords;

      return ReactionCompletionResult(
        query: normalized,
        completedEquation: completedEquation,
        conditionFields: conditionFields,
        explanation: explanation,
        confidence: confidence.clamp(0.0, 1.0),
        sourceReferences: sourceReferences,
        matchedKeywords: matchedKeywords,
        candidateTitles: candidateTitles,
        usedModel: true,
      );
    } catch (_) {
      return null;
    }
  }

  String _normalizeQuery(String query) {
    return query.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<String> _tokenize(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), '');
    final tokens = <String>[];
    for (final keyword in _defaultKeywords) {
      if (normalized.contains(keyword)) {
        tokens.add(keyword);
      }
    }
    if (tokens.isEmpty) {
      tokens.addAll(normalized.split('')); 
    }
    return tokens.toSet().toList();
  }

  static const List<String> _defaultKeywords = [
    '酸',
    '碱',
    '中和',
    '苯',
    '乙烯',
    '乙醇',
    '乙酸',
    '溴',
    '氧化',
    '酯化',
    '水合',
    '加热',
    '回流',
    '催化',
    'FeBr3',
    'CuO',
    'H3PO4',
    'NaOH',
    'HCl',
  ];

  Future<ReactionKnowledgeEntry> prepareKnowledgeEntry(
    ReactionKnowledgeEntry entry, {
    required AiSettings settings,
  }) async {
    if (settings.apiKey.trim().isEmpty) {
      return entry;
    }

    final text = [
      entry.title,
      entry.keywords.join(' '),
      entry.completedEquation,
      entry.conditionFields.values.join(' '),
      entry.sourceReference,
      entry.explanation,
    ].join('\n');

    try {
      final embedding = await _embedText(
        text,
        settings: settings,
        isQuery: false,
      );
      return ReactionKnowledgeEntry(
        id: entry.id,
        title: entry.title,
        keywords: entry.keywords,
        completedEquation: entry.completedEquation,
        conditionFields: entry.conditionFields,
        sourceReference: entry.sourceReference,
        explanation: entry.explanation,
        embedding: embedding,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ReactionCompletion] entry embedding failed: $e');
      }
      return entry;
    }
  }

  String? _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      return null;
    }
    return text.substring(start, end + 1);
  }

  String? _stringOrNull(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  Map<String, String>? _mapStringToString(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      final v = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty) {
        result[key] = v;
      }
    }
    return result;
  }

  List<String>? _stringList(dynamic value) {
    if (value is! List) {
      return null;
    }
    final result = value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
    return result;
  }
}

class _ReactionMatch {
  const _ReactionMatch({
    required this.entry,
    required this.matchedKeywords,
    required this.confidence,
  });

  final ReactionKnowledgeEntry entry;
  final List<String> matchedKeywords;
  final double confidence;
}

extension on ReactionCompletionResult {
  ReactionCompletionResult copyWith({
    String? completedEquation,
    Map<String, String>? conditionFields,
    String? explanation,
    double? confidence,
    List<String>? sourceReferences,
    List<String>? matchedKeywords,
    List<String>? candidateTitles,
    bool? usedModel,
  }) {
    return ReactionCompletionResult(
      query: query,
      completedEquation: completedEquation ?? this.completedEquation,
      conditionFields: conditionFields ?? this.conditionFields,
      explanation: explanation ?? this.explanation,
      confidence: confidence ?? this.confidence,
      sourceReferences: sourceReferences ?? this.sourceReferences,
      matchedKeywords: matchedKeywords ?? this.matchedKeywords,
      candidateTitles: candidateTitles ?? this.candidateTitles,
      usedModel: usedModel ?? this.usedModel,
    );
  }
}