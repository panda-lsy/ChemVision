import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/structure_result.dart';
import 'ai_settings_store.dart';
import 'name_resolver_client.dart';
import 'structure_service.dart';
import 'vivo_aigc_client.dart';

class NameToStructureService implements StructureService {
  NameToStructureService({
    AiSettingsStore? settingsStore,
    VivoAigcClient? client,
    NameResolverClient? resolver,
  })  : _settingsStore = settingsStore ?? AiSettingsStore(),
        _client = client ?? VivoAigcClient(),
        _resolver = resolver ?? NameResolverClient();

  final AiSettingsStore _settingsStore;
  final VivoAigcClient _client;
  final NameResolverClient _resolver;

  static const String _normalizationPromptPath =
      'assets/prompts/name_normalization.txt';
  static Future<String>? _normalizationPromptCache;

  @override
  Future<StructureResult> generateStructure(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return StructureResult.invalid(message: '请输入化学名称');
    }

    final settings = await _settingsStore.load();
    final apiKey = settings.apiKey.trim();
    final model = settings.textModel.trim();
    if (apiKey.isEmpty || model.isEmpty) {
      return StructureResult.invalid(message: '请先在设置中配置 API Key 与模型');
    }

    try {
      final normalizedName =
          await _normalizeName(trimmed, apiKey, model, settings.baseUrl);
      if (normalizedName.isEmpty) {
        return StructureResult.invalid(message: '名称标准化失败');
      }

      final result = await _resolver.resolve(normalizedName);
      return StructureResult(
        smiles: result.canonicalSmiles,
        resolvedName: result.resolvedName ?? normalizedName,
        molecularFormula: result.molecularFormula ?? '',
        molecularWeight: result.molecularWeight ?? 0,
        isValid: true,
        confidence: 0.9,
      );
    } on DioException catch (error) {
      return StructureResult.invalid(message: _formatDioError(error));
    } catch (error) {
      return StructureResult.invalid(message: '解析失败: $error');
    }
  }

  Future<String> _normalizeName(
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
    return _extractSingleLine(text) ?? query;
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
}

class RealStructureService extends NameToStructureService {
  RealStructureService({
    AiSettingsStore? settingsStore,
    VivoAigcClient? client,
    NameResolverClient? resolver,
  }) : super(
          settingsStore: settingsStore,
          client: client,
          resolver: resolver,
        );
}
