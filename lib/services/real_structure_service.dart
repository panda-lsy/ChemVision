import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../models/structure_result.dart';
import 'ai_settings_store.dart';
import 'structure_cache_store.dart';
import 'structure_service.dart';
import 'vivo_aigc_client.dart';

class NameToStructureService implements StructureService {
  NameToStructureService({
    AiSettingsStore? settingsStore,
    VivoAigcClient? client,
    PubChemClient? pubchemClient,
    OpsinClient? opsinClient,
    StructureCacheStore? cacheStore,
  })  : _settingsStore = settingsStore ?? AiSettingsStore(),
        _client = client ?? VivoAigcClient(),
        _pubchem = pubchemClient ?? PubChemClient(),
        _opsin = opsinClient ?? OpsinClient(),
        _cacheStore = cacheStore ?? StructureCacheStore();

  final AiSettingsStore _settingsStore;
  final VivoAigcClient _client;
  final PubChemClient _pubchem;
  final OpsinClient _opsin;
  final StructureCacheStore _cacheStore;

  static const String _normalizationPromptPath =
      'assets/prompts/name_normalization.txt';
  static const String _inferPromptPath =
      'assets/prompts/infer_candidates.txt';
  static Future<String>? _normalizationPromptCache;
  static Future<String>? _inferPromptCache;
  static const List<String> _invalidExactPrefixes = [
    'the provided content is not a valid chinese chemical name',
    'invalid chinese chemical name',
  ];
  static const List<String> _invalidInferPrefixes = [
    'the provided content is not a valid',
    'invalid chinese chemical name',
    'not a valid chinese chemical name',
  ];

  @override
  Future<StructureResult> generateStructure(String query, {String? mode}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return StructureResult.invalid(message: '请输入化学名称');
    }

    final settings = await _settingsStore.load();
    final normalizedMode = (mode ?? '').trim().toLowerCase();
    bool? forceInfer;
    if (normalizedMode == 'infer') {
      forceInfer = true;
    } else if (normalizedMode == 'exact') {
      forceInfer = false;
    }
    final useInfer = forceInfer ?? _looksLikeDescription(trimmed);
    final apiKey = settings.apiKey.trim();
    final model = settings.textModel.trim();
    if (apiKey.isEmpty || model.isEmpty) {
      return StructureResult.invalid(message: '请先在设置中配置 API Key 与模型');
    }

    final cacheMode = useInfer ? 'infer' : 'exact';
    final cached = await _cacheStore.get(trimmed, mode: cacheMode);
    if (cached != null) {
      return cached;
    }

    try {
      if (useInfer) {
        final candidates = await _inferCandidates(
          trimmed,
          apiKey,
          model,
          settings.baseUrl,
        );
        if (candidates.isEmpty) {
          return StructureResult.invalid(message: '推测失败，未生成候选名称');
        }

        final resolvedResults = <_ResolutionResult>[];
        String? lastError;
        for (var index = 0; index < candidates.length; index++) {
          final candidate = candidates[index];
          final parsed = _parseCandidatePair(candidate);
          final englishName = parsed['english'];
          final chineseName = parsed['chinese'];
          // Use the English name (or the full candidate if no parsing was successful)
          final nameToResolve = englishName ?? candidate;
          final outcome = await _resolveExact(nameToResolve, originalName: null);
          if (outcome.result != null) {
            // Add English and Chinese name info to resolution result
            final resultWithNames = _ResolutionResult(
              canonicalSmiles: outcome.result!.canonicalSmiles,
              source: outcome.result!.source,
              molecularFormula: outcome.result!.molecularFormula,
              molecularWeight: outcome.result!.molecularWeight,
              resolvedName: outcome.result!.resolvedName,
              englishName: englishName,
              chineseName: chineseName,
            );
            resolvedResults.add(resultWithNames);
          } else if (outcome.error != null) {
            lastError = _formatExternalError(outcome.error);
          }
        }

        if (resolvedResults.isEmpty) {
          return StructureResult.invalid(
            message: lastError == null
                ? '推测未命中，请尝试更明确的用途描述'
                : '推测未命中：$lastError',
          );
        }

        final primary = resolvedResults.first;
        final alternatives = <StructureCandidate>[];
        for (var index = 1; index < resolvedResults.length; index++) {
          alternatives.add(
            _toCandidate(
              resolvedResults[index],
              confidence: _inferConfidence(index),
            ),
          );
        }
        final structureResult = _buildStructureResult(
          primary,
          fallbackName: trimmed,
          confidence: _inferConfidence(0),
          alternatives: alternatives,
        );
        await _cacheStore.set(trimmed, structureResult, mode: cacheMode);
        return structureResult;
      }

      var englishName = trimmed;
      String? chineseName;
      var normalizedName = trimmed;
      if (_looksChinese(trimmed)) {
        final pair = await _normalizeNameWithChinese(trimmed, apiKey, model, settings.baseUrl);
        englishName = pair['english'] ?? trimmed;
        chineseName = pair['chinese'];
        if (chineseName == null || chineseName.isEmpty) {
          chineseName = trimmed;
        }
        normalizedName = pair['english'] ?? trimmed;
      }
      if (kDebugMode) {
        debugPrint('[Resolver] Normalized name: $normalizedName, English: $englishName, Chinese: $chineseName');
      }
      final iupacName = _sanitizeName(normalizedName);
      if (_isInvalidExactOutput(iupacName) || _looksChinese(iupacName)) {
        return StructureResult.invalid(message: '中文名称翻译失败，请换用英文名');
      }
      final resolverInput = iupacName.isEmpty ? trimmed : iupacName;

      final outcome = await _resolveExact(
        resolverInput,
        originalName: trimmed,
      );
      final resolved = outcome.result;
      if (resolved == null) {
        if (outcome.notFound) {
          return StructureResult.invalid(message: '未找到匹配的化合物');
        }
        return StructureResult.invalid(
          message: _formatExternalError(outcome.error),
        );
      }

      final resolvedWithNames = _ResolutionResult(
        canonicalSmiles: resolved.canonicalSmiles,
        source: resolved.source,
        molecularFormula: resolved.molecularFormula,
        molecularWeight: resolved.molecularWeight,
        resolvedName: resolved.resolvedName,
        englishName: englishName,
        chineseName: chineseName,
      );

      final structureResult = _buildStructureResult(
        resolvedWithNames,
        fallbackName: resolverInput,
        confidence: 0.9,
      );
      await _cacheStore.set(trimmed, structureResult, mode: cacheMode);
      return structureResult;
    } on DioException catch (error) {
      return StructureResult.invalid(message: _formatDioError(error));
    } catch (error) {
      return StructureResult.invalid(message: '解析失败: $error');
    }
  }

  Future<Map<String, String?>> _normalizeNameWithChinese(
    String query,
    String apiKey,
    String model,
    String baseUrl,
  ) async {
    final template = await _loadNormalizationPrompt();
    final prompt = template.contains('{{query}}')
        ? template.replaceAll('{{query}}', query)
        : '$template\nChinese name: $query';

    final text = await _client.generateText(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
    );
    return _parseNormalizedNamePair(text, query);
  }

  Map<String, String?> _parseNormalizedNamePair(String text, String originalQuery) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) {
      return {'english': originalQuery, 'chinese': originalQuery};
    }
    cleaned = cleaned.replaceAll('```', '').replaceAll('"', '');
    final lines = cleaned.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    
    if (lines.isEmpty) {
      return {'english': originalQuery, 'chinese': originalQuery};
    }
    
    String englishName = originalQuery;
    String chineseName = originalQuery;
    
    if (lines.length >= 1) {
      englishName = lines[0].startsWith('-') ? lines[0].substring(1).trim() : lines[0];
    }
    if (lines.length >= 2) {
      chineseName = lines[1].startsWith('-') ? lines[1].substring(1).trim() : lines[1];
    }
    
    return {'english': englishName, 'chinese': chineseName};
  }

  Future<String> _normalizeName(
    String query,
    String apiKey,
    String model,
    String baseUrl,
  ) async {
    final result = await _normalizeNameWithChinese(query, apiKey, model, baseUrl);
    return result['english'] ?? query;
  }

  Future<String> _loadNormalizationPrompt() async {
    _normalizationPromptCache ??=
        rootBundle.loadString(_normalizationPromptPath);
    try {
      return await _normalizationPromptCache!;
    } catch (_) {
      return 'Translate the given Chinese chemical name into an English IUPAC '
          'name. Output only one line.';
    }
  }

  String? _extractSingleLine(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    cleaned = cleaned.replaceAll('```', '').replaceAll('"', '');
    final line = cleaned.split(RegExp(r'\r?\n')).first.trim();
    if (line.startsWith('-')) {
      return line.substring(1).trim();
    }
    return line;
  }

  Future<List<String>> _inferCandidates(
    String query,
    String apiKey,
    String model,
    String baseUrl,
  ) async {
    final template = await _loadInferPrompt();
    final prompt = template.contains('{{query}}')
        ? template.replaceAll('{{query}}', query)
        : '$template\nDescription: $query';

    final text = await _client.generateText(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
    );

    return _extractCandidates(text);
  }

  Future<String> _loadInferPrompt() async {
    _inferPromptCache ??= rootBundle.loadString(_inferPromptPath);
    try {
      return await _inferPromptCache!;
    } catch (_) {
      return 'You are a medicinal chemist. Given a description of a drug\'s '
          'therapeutic use, mechanism, or effect, propose up to 5 well-known '
          'generic drug names (INN). Output each name on a new line without '
          'additional text.\nDescription: {{query}}';
    }
  }

  List<String> _extractCandidates(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) {
      return [];
    }
    cleaned = cleaned.replaceAll('```', '');
    final lines = cleaned.split(RegExp(r'\r?\n'));
    final results = <String>[];
    final seen = <String>{};
    for (final raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) {
        continue;
      }
      line = line.replaceAll(RegExp(r'^[\-\*\d\.\)\s]+'), '').trim();
      line = _sanitizeName(line);
      if (line.isEmpty) {
        continue;
      }
      final lower = line.toLowerCase();
      if (_invalidInferPrefixes.any(lower.startsWith)) {
        continue;
      }
      if (seen.add(lower)) {
        results.add(line);
      }
      if (results.length >= 5) {
        break;
      }
    }
    return results;
  }

  Map<String, String?> _parseCandidatePair(String text) {
    // Parse "English (Chinese)" format
    final match = RegExp(r'^([^()]+)\s*\(([^)]*)\)').firstMatch(text);
    if (match != null) {
      final rawChinese = match.group(2)?.trim();
      final normalizedChinese = (rawChinese == null ||
              rawChinese.isEmpty ||
              rawChinese.toLowerCase() == 'unknown')
          ? null
          : rawChinese;
      return {
        'english': match.group(1)?.trim(),
        'chinese': normalizedChinese,
      };
    }
    return {'english': text, 'chinese': null};
  }

  bool _isInvalidExactOutput(String text) {
    final lower = text.trim().toLowerCase();
    if (lower.isEmpty) {
      return false;
    }
    return _invalidExactPrefixes.any(lower.startsWith);
  }

  Future<_ResolveOutcome> _resolveExact(
    String query, {
    String? originalName,
  }) async {
    final candidates = _dedupeCandidates([query, originalName]);

    // Run PubChem first; if it succeeds, skip OPSIN entirely.
    final pubchemResult = await _pubchem.queryAny(candidates);
    if (pubchemResult.smiles != null && pubchemResult.smiles!.trim().isNotEmpty) {
      final resolvedName = pubchemResult.name ?? query;
      return _ResolveOutcome(
        result: _ResolutionResult(
          canonicalSmiles: pubchemResult.smiles!.trim(),
          source: 'pubchem',
          molecularFormula: pubchemResult.formula,
          molecularWeight: pubchemResult.weight,
          resolvedName: resolvedName,
        ),
        notFound: false,
        error: null,
      );
    }

    // PubChem failed — try OPSIN as fallback.
    final opsinResult = await _opsin.query(query);
    if (opsinResult.smiles != null && opsinResult.smiles!.trim().isNotEmpty) {
      final resolvedName = opsinResult.name ?? query;
      return _ResolveOutcome(
        result: _ResolutionResult(
          canonicalSmiles: opsinResult.smiles!.trim(),
          source: 'opsin',
          molecularFormula: opsinResult.formula,
          molecularWeight: opsinResult.weight,
          resolvedName: resolvedName,
        ),
        notFound: false,
        error: null,
      );
    }

    final notFound = pubchemResult.notFound && opsinResult.notFound;
    final error = pubchemResult.error ?? opsinResult.error;
    return _ResolveOutcome(result: null, notFound: notFound, error: error);
  }

  List<String> _dedupeCandidates(List<String?> names) {
    final results = <String>[];
    final seen = <String>{};
    for (final name in names) {
      final cleaned = _sanitizeName(name ?? '');
      if (cleaned.isEmpty) {
        continue;
      }
      final key = cleaned.toLowerCase();
      if (seen.add(key)) {
        results.add(cleaned);
      }
    }
    return results;
  }

  String _sanitizeName(String value) {
    var cleaned = value.trim();
    cleaned = cleaned.replaceAll(RegExp(r'''^["'`]+|["'`]+$'''), '');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'^(IUPAC|IUPAC name|Name|English name|英文名|标准名称|标准名)[:：]\s*',
        caseSensitive: false,
      ),
      '',
    );
    cleaned = cleaned.trim().replaceAll(RegExp(r'[。．，,;；]+$'), '');
    return cleaned.trim();
  }

  bool _looksChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  StructureResult _buildStructureResult(
    _ResolutionResult result, {
    required String fallbackName,
    required double confidence,
    List<StructureCandidate> alternatives = const [],
  }) {
    return StructureResult(
      smiles: result.canonicalSmiles,
      resolvedName: result.resolvedName ?? fallbackName,
      englishName: result.englishName,
      chineseName: result.chineseName,
      molecularFormula: result.molecularFormula ?? '',
      molecularWeight: result.molecularWeight ?? 0,
      isValid: true,
      confidence: confidence,
      alternatives: alternatives,
    );
  }

  StructureCandidate _toCandidate(
    _ResolutionResult result, {
    required double confidence,
  }) {
    return StructureCandidate(
      smiles: result.canonicalSmiles,
      resolvedName: result.resolvedName,
      englishName: result.englishName,
      chineseName: result.chineseName,
      molecularFormula: result.molecularFormula ?? '',
      molecularWeight: result.molecularWeight ?? 0,
      source: result.source,
      confidence: confidence,
    );
  }

  double _inferConfidence(int index) {
    final score = 0.9 - index * 0.12;
    if (score < 0.3) {
      return 0.3;
    }
    return score;
  }

  String _formatExternalError(String? error) {
    if (error == null || error.trim().isEmpty) {
      return '解析失败，请稍后重试';
    }
    final lower = error.toLowerCase();
    if (lower.contains('connection') ||
        lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('cors')) {
      return '网络连接失败，可能被浏览器 CORS 限制或服务不可达';
    }
    if (lower.startsWith('http_') || lower.contains('timeout')) {
      return '解析服务响应异常，请稍后再试';
    }
    return error;
  }

  String _formatDioError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return error.message ?? '连接失败';
  }

  bool _looksLikeDescription(String text) {
    final lower = text.toLowerCase();
    const keywords = [
      'drug',
      'medicine',
      'treat',
      'treatment',
      'used for',
      'pain',
      'anti-inflammatory',
      'antibiotic',
      '止痛',
      '消炎',
      '抗炎',
      '抗生素',
      '治疗',
      '用于',
      '药',
      '用途',
    ];
    if (keywords.any(lower.contains)) {
      return true;
    }
    final words = text.trim().split(RegExp(r'\s+'));
    if (words.length >= 4) {
      return true;
    }
    return text.length > 40 && text.contains(' ');
  }
}

class _ResolveOutcome {
  final _ResolutionResult? result;
  final bool notFound;
  final String? error;

  const _ResolveOutcome({
    required this.result,
    required this.notFound,
    required this.error,
  });
}

class _ResolutionResult {
  final String canonicalSmiles;
  final String? source;
  final String? molecularFormula;
  final double? molecularWeight;
  final String? resolvedName;
  final String? englishName;
  final String? chineseName;

  const _ResolutionResult({
    required this.canonicalSmiles,
    this.source,
    this.molecularFormula,
    this.molecularWeight,
    this.resolvedName,
    this.englishName,
    this.chineseName,
  });
}

class _SourceResult {
  final String? smiles;
  final String? formula;
  final double? weight;
  final String? name;
  final String? error;
  final bool notFound;

  const _SourceResult({
    required this.smiles,
    required this.formula,
    required this.weight,
    required this.name,
    required this.error,
    required this.notFound,
  });
}

class PubChemClient {
  PubChemClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  static const String _baseUrl =
      'https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/name';
  final Dio _dio;

  Future<_SourceResult> queryAny(List<String> names) async {
    if (names.isEmpty) {
      return const _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'empty_query',
        notFound: false,
      );
    }

    bool allNotFound = true;
    String? lastError;
    for (final name in names) {
      final result = await query(name);
      if (result.smiles != null && result.smiles!.trim().isNotEmpty) {
        return result;
      }
      if (!result.notFound) {
        allNotFound = false;
      }
      if (result.error != null) {
        lastError = result.error;
      }
    }

    return _SourceResult(
      smiles: null,
      formula: null,
      weight: null,
      name: null,
      error: lastError,
      notFound: allNotFound,
    );
  }

  Future<_SourceResult> query(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'empty_query',
        notFound: false,
      );
    }

    final encoded = Uri.encodeComponent(trimmed);
    final url =
        '$_baseUrl/$encoded/property/CanonicalSMILES,IsomericSMILES,'
        'MolecularFormula,MolecularWeight,IUPACName/JSON';

    try {
      Response? response;
      DioException? lastDioError;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          response = await _dio.get(
            url,
            options: Options(validateStatus: (_) => true),
          );
          final s = response.statusCode ?? 0;
          // 200 = success; 4xx = client error (no retry); 5xx = server error (retry).
          if (s == 200 || (s >= 400 && s < 500)) break;
          if (kDebugMode) {
            debugPrint('[PubChem] Retry $attempt/3 (HTTP $s)');
          }
        } on DioException catch (e) {
          lastDioError = e;
          if (kDebugMode) {
            debugPrint('[PubChem] Retry $attempt/3 (${e.type})');
          }
        }
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
      if (response == null) {
        return _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: lastDioError?.message ?? 'connection_error',
          notFound: false,
        );
      }

      final status = response.statusCode ?? 0;
      final data = _decodeMap(response.data);
      if (kDebugMode) {
        debugPrint('[PubChem] $status $url');
      }
      if (status == 200 && data != null) {
        final fault = _findMapByKey(data, 'Fault');
        if (fault != null) {
          final message = _asString(fault['Message']) ??
              _asString(fault['Details']) ??
              _asString(fault['Description']);
          final code = _asString(fault['Code']) ?? '';
          final combined = '${code.toLowerCase()} ${message?.toLowerCase() ?? ''}';
          if (combined.contains('notfound')) {
            return const _SourceResult(
              smiles: null,
              formula: null,
              weight: null,
              name: null,
              error: 'not_found',
              notFound: true,
            );
          }
          return _SourceResult(
            smiles: null,
            formula: null,
            weight: null,
            name: null,
            error: message ?? 'fault',
            notFound: false,
          );
        }

        final properties = _findMapByKey(data, 'PropertyTable');
        final rawList = properties == null ? null : properties['Properties'];
        final list = _normalizePropertyList(rawList);
        if (list.isNotEmpty) {
          final first = _asMap(list.first);
          if (first != null) {
            final canonical = _asString(first['CanonicalSMILES']);
            final isomeric = _asString(first['IsomericSMILES']);
            final smilesFallback = _asString(first['SMILES']);
            final connectivity = _asString(first['ConnectivitySMILES']);
            final formula = _asString(first['MolecularFormula']);
            final weight = _asDouble(first['MolecularWeight']);
            final name = _asString(first['IUPACName']);
            final smiles = canonical ?? isomeric ?? smilesFallback ?? connectivity;
            if (smiles != null) {
              return _SourceResult(
                smiles: smiles,
                formula: formula,
                weight: weight,
                name: name,
                error: null,
                notFound: false,
              );
            }
          }
        }
        if (kDebugMode) {
          debugPrint('[PubChem] Missing properties in response');
          debugPrint('[PubChem] Keys: ${data.keys.toList()}');
          if (properties != null) {
            debugPrint('[PubChem] PropertyTable keys: ${properties.keys.toList()}');
            debugPrint('[PubChem] Properties type: ${rawList.runtimeType}');
          }
        }
        return const _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: 'no_smiles',
          notFound: false,
        );
      }

      final text = response.data?.toString() ?? '';
      if (status == 404 || text.contains('PUGREST.NotFound')) {
        return const _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: 'not_found',
          notFound: true,
        );
      }

      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'http_$status',
        notFound: false,
      );
    } on DioException catch (error) {
      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: error.message ?? 'connection_error',
        notFound: false,
      );
    } catch (error) {
      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'error: $error',
        notFound: false,
      );
    }
  }

  Map<String, dynamic>? _decodeMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  List<dynamic> _normalizePropertyList(dynamic raw) {
    if (raw is List) {
      return raw;
    }
    if (raw is Map) {
      return [raw];
    }
    return const [];
  }

  Map<String, dynamic>? _findMapByKey(
    Map<String, dynamic> data,
    String target,
  ) {
    final direct = _asMap(data[target]);
    if (direct != null) {
      return direct;
    }
    final lower = target.toLowerCase();
    for (final entry in data.entries) {
      if (entry.key.toLowerCase() == lower) {
        return _asMap(entry.value);
      }
    }
    return null;
  }

  String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class OpsinClient {
  OpsinClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  // On web, use the local proxy to avoid CORS; on other platforms, direct.
  static final String _baseUrl = kIsWeb
      ? '${AppConfig.proxyBaseUrl}/opsin'
      : 'https://opsin.ch.cam.ac.uk/opsin';
  final Dio _dio;

  Future<_SourceResult> query(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'empty_query',
        notFound: false,
      );
    }
    if (_looksChinese(trimmed)) {
      return const _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'skip_non_english',
        notFound: true,
      );
    }

    final encoded = Uri.encodeComponent(trimmed);
    final url = '$_baseUrl/$encoded.json';

    try {
      Response? response;
      DioException? lastDioError;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          response = await _dio.get(
            url,
            options: Options(validateStatus: (_) => true),
          );
          final s = response.statusCode ?? 0;
          // 200 = success; 4xx = client error (no retry); 5xx = server error (retry).
          if (s == 200 || (s >= 400 && s < 500)) break;
          if (kDebugMode) {
            debugPrint('[OPSIN] Retry $attempt/3 (HTTP $s)');
          }
        } on DioException catch (e) {
          lastDioError = e;
          if (kDebugMode) {
            debugPrint('[OPSIN] Retry $attempt/3 (${e.type})');
          }
        }
        if (attempt < 3) {
          await Future.delayed(Duration(milliseconds: 300 * attempt));
        }
      }
      if (response == null) {
        return _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: lastDioError?.message ?? 'connection_error',
          notFound: false,
        );
      }
      final status = response.statusCode ?? 0;
      final data = _decodeMap(response.data);
      if (kDebugMode) {
        debugPrint('[OPSIN] $status $url');
      }
      if (status == 200 && data != null) {
        final canonical = _asString(data['canonicalSmiles']);
        final smiles = _asString(data['smiles']) ?? canonical;
        final formula = _asString(data['molecularFormula']);
        final weight = _asDouble(data['molecularWeight']);
        final name = _asString(data['iupacName']);
        if (smiles != null) {
          return _SourceResult(
            smiles: smiles,
            formula: formula,
            weight: weight,
            name: name,
            error: null,
            notFound: false,
          );
        }
        return const _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: 'no_smiles',
          notFound: false,
        );
      }

      if (status == 404) {
        return const _SourceResult(
          smiles: null,
          formula: null,
          weight: null,
          name: null,
          error: 'not_found',
          notFound: true,
        );
      }

      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'http_$status',
        notFound: false,
      );
    } on DioException catch (error) {
      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: error.message ?? 'connection_error',
        notFound: false,
      );
    } catch (error) {
      return _SourceResult(
        smiles: null,
        formula: null,
        weight: null,
        name: null,
        error: 'error: $error',
        notFound: false,
      );
    }
  }

  bool _looksChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  Map<String, dynamic>? _decodeMap(dynamic data) {
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    if (data is List<int>) {
      try {
        final decoded = jsonDecode(utf8.decode(data));
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class RealStructureService extends NameToStructureService {
  RealStructureService({
    AiSettingsStore? settingsStore,
    VivoAigcClient? client,
    PubChemClient? pubchemClient,
    OpsinClient? opsinClient,
  }) : super(
          settingsStore: settingsStore,
          client: client,
          pubchemClient: pubchemClient,
          opsinClient: opsinClient,
        );
}
