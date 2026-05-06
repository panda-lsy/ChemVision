import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../models/structure_result.dart';
import 'ai_settings_store.dart';
import 'structure_service.dart';
import 'vivo_aigc_client.dart';

class RealStructureService implements StructureService {
  RealStructureService({AiSettingsStore? settingsStore, VivoAigcClient? client})
      : _settingsStore = settingsStore ?? AiSettingsStore(),
        _client = client ?? VivoAigcClient();

  final AiSettingsStore _settingsStore;
  final VivoAigcClient _client;
  static const String _promptAssetPath =
      'assets/prompts/structure_generation.txt';
  static Future<String>? _promptCache;

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

    final prompt = await _buildPrompt(trimmed);

    try {
      final text = await _client.generateText(
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        baseUrl: settings.baseUrl,
      );
      final smiles = _extractSmiles(text);
      if (smiles == null) {
        return StructureResult.invalid(message: '模型返回格式不正确');
      }

      return StructureResult(
        smiles: smiles,
        molecularFormula: 'N/A',
        molecularWeight: 0,
        isValid: true,
        confidence: 0.6,
      );
    } on DioException catch (error) {
      return StructureResult.invalid(message: _formatDioError(error));
    } catch (error) {
      return StructureResult.invalid(message: '解析失败: $error');
    }
  }

  Future<String> _buildPrompt(String query) async {
    final template = await _loadPromptTemplate();
    if (template.contains('{{query}}')) {
      return template.replaceAll('{{query}}', query);
    }
    return '$template\nChemical name: $query';
  }

  Future<String> _loadPromptTemplate() async {
    _promptCache ??= rootBundle.loadString(_promptAssetPath);
    try {
      return await _promptCache!;
    } catch (_) {
      return 'Convert the given chemical name to a standard SMILES string. '
          'Output exactly one line with the SMILES only.';
    }
  }

  String? _extractSmiles(String text) {
    var cleaned = text.trim();
    if (cleaned.isEmpty) {
      return null;
    }
    cleaned = cleaned.replaceAll('```', '');
    cleaned = cleaned.replaceAll('SMILES:', '').replaceAll('smiles:', '');
    final firstLine = cleaned.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.isEmpty) {
      return null;
    }
    return firstLine;
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
