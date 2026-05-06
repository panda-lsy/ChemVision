import 'package:shared_preferences/shared_preferences.dart';

import '../config/ai_models.dart';
import '../config/app_config.dart';

class AiSettings {
  final String apiKey;
  final String textModel;
  final String? embeddingModel;
  final String? rerankModel;
  final String baseUrl;

  const AiSettings({
    required this.apiKey,
    required this.textModel,
    required this.baseUrl,
    this.embeddingModel,
    this.rerankModel,
  });

  AiSettings copyWith({
    String? apiKey,
    String? textModel,
    String? baseUrl,
    String? embeddingModel,
    String? rerankModel,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      textModel: textModel ?? this.textModel,
      baseUrl: baseUrl ?? this.baseUrl,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      rerankModel: rerankModel ?? this.rerankModel,
    );
  }
}

class AiSettingsStore {
  static const String _apiKeyKey = 'vivo_api_key';
  static const String _textModelKey = 'vivo_text_model';
  static const String _embeddingModelKey = 'vivo_embedding_model';
  static const String _rerankModelKey = 'vivo_rerank_model';
  static const String _baseUrlKey = 'vivo_base_url';

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey) ?? '';
    final rawTextModel = prefs.getString(_textModelKey) ?? '';
    final embeddingModel = prefs.getString(_embeddingModelKey);
    final rerankModel = prefs.getString(_rerankModelKey);
    final rawBaseUrl = prefs.getString(_baseUrlKey) ?? defaultAigcBaseUrl;

    final textModel = _migrateTextModel(rawTextModel);
    final baseUrl = _migrateBaseUrl(rawBaseUrl);

    if (textModel != rawTextModel) {
      await prefs.setString(_textModelKey, textModel);
    }
    if (baseUrl != rawBaseUrl) {
      await prefs.setString(_baseUrlKey, baseUrl);
    }

    return AiSettings(
      apiKey: apiKey,
      textModel: textModel,
      embeddingModel: _normalizeOptional(embeddingModel),
      rerankModel: _normalizeOptional(rerankModel),
      baseUrl: baseUrl,
    );
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, settings.apiKey);
    await prefs.setString(_textModelKey, settings.textModel);
    await _setOptional(prefs, _embeddingModelKey, settings.embeddingModel);
    await _setOptional(prefs, _rerankModelKey, settings.rerankModel);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
  }

  String? _normalizeOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value;
  }

  String _migrateTextModel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == 'Doubao-Seedream-4.5') {
      return textGenerationModels.isNotEmpty
          ? textGenerationModels.first.name
          : trimmed;
    }
    return trimmed;
  }

  String _migrateBaseUrl(String value) {
    var trimmed = value.trim();
    if (trimmed.isEmpty) {
      return defaultAigcBaseUrl;
    }
    if (trimmed.contains('/api/v1')) {
      return AppConfig.vivoAigcBaseUrl;
    }
    if (trimmed == 'https://api-ai.vivo.com.cn') {
      return AppConfig.vivoAigcBaseUrl;
    }
    if (!trimmed.contains('://') && trimmed.startsWith('localhost')) {
      trimmed = 'http://$trimmed';
    }
    return trimmed;
  }

  Future<void> _setOptional(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, normalized);
  }
}
