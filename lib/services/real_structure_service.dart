import 'dart:convert';

import 'package:dio/dio.dart';

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

    final prompt = _buildPrompt(trimmed);

    try {
      final text = await _client.generateText(
        apiKey: apiKey,
        model: model,
        prompt: prompt,
        baseUrl: settings.baseUrl,
      );
      final payload = _extractJson(text);
      if (payload == null) {
        return StructureResult.invalid(message: '模型返回格式不正确');
      }

      final smiles = _asString(payload['smiles']);
      final formula = _asString(payload['molecularFormula']);
      final weight = _asDouble(payload['molecularWeight']);
      final confidence = _asDouble(payload['confidence']) ?? 0.6;

      if (smiles == null || formula == null || weight == null) {
        return StructureResult.invalid(message: '模型返回字段缺失');
      }

      return StructureResult(
        smiles: smiles,
        molecularFormula: formula,
        molecularWeight: weight,
        isValid: true,
        confidence: confidence,
      );
    } on DioException catch (error) {
      return StructureResult.invalid(message: _formatDioError(error));
    } catch (error) {
      return StructureResult.invalid(message: '解析失败: $error');
    }
  }

  String _buildPrompt(String query) {
    return '你是化学结构解析助手。请根据给定化学名称输出 JSON，格式为：'
        '{"smiles":"...","molecularFormula":"...","molecularWeight":123.45,'
        '"confidence":0.9}。只输出 JSON，不要额外解释。化学名称：$query';
  }

  Map<String, dynamic>? _extractJson(String text) {
    final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
    if (match == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(match.group(0)!);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
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
