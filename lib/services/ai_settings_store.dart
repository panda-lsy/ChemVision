import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ai_models.dart';
import '../config/app_config.dart';

class AiSettings {
  final String apiKey;
  final String asrApiKey;
  final String textModel;
  final String? embeddingModel;
  final String baseUrl;
  final String ocsrEndpoint;

  const AiSettings({
    required this.apiKey,
    required this.textModel,
    required this.baseUrl,
    required this.ocsrEndpoint,
    this.asrApiKey = '',
    this.embeddingModel,
  });

  AiSettings copyWith({
    String? apiKey,
    String? asrApiKey,
    String? textModel,
    String? baseUrl,
    String? ocsrEndpoint,
    String? embeddingModel,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      asrApiKey: asrApiKey ?? this.asrApiKey,
      textModel: textModel ?? this.textModel,
      baseUrl: baseUrl ?? this.baseUrl,
      ocsrEndpoint: ocsrEndpoint ?? this.ocsrEndpoint,
      embeddingModel: embeddingModel ?? this.embeddingModel,
    );
  }
}

class AiSettingsStore {
  static const String _apiKeyKey = 'ai_api_key';
  static const String _asrApiKeyKey = 'asr_api_key';
  static const String _textModelKey = 'ai_text_model';
  static const String _embeddingModelKey = 'ai_embedding_model';
  static const String _baseUrlKey = 'ai_base_url';

  // Read old preferences once for migration. The old API key is kept separate
  // because it was also used by the independent speech-recognition service.
  static const String _legacyApiKeyKey = 'vivo_api_key';
  static const String _legacyTextModelKey = 'vivo_text_model';
  static const String _legacyEmbeddingModelKey = 'vivo_embedding_model';
  static const String _legacyBaseUrlKey = 'vivo_base_url';
  static const String _ocsrEndpointKey = 'ocsr_endpoint';

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawLegacyApiKey = prefs.getString(_legacyApiKeyKey) ?? '';
    final rawLegacyBaseUrl = prefs.getString(_legacyBaseUrlKey);
    final hasCurrentBaseUrl = prefs.containsKey(_baseUrlKey);
    final legacyBaseUrlIsMissing = rawLegacyBaseUrl?.trim().isNotEmpty != true;
    final migratingLegacyVivoConfig = !hasCurrentBaseUrl &&
        (legacyBaseUrlIsMissing || _isLegacyVivoBaseUrl(rawLegacyBaseUrl));
    final apiKey = prefs.getString(_apiKeyKey) ??
        (migratingLegacyVivoConfig ? '' : rawLegacyApiKey);
    final asrApiKey = prefs.getString(_asrApiKeyKey) ??
        (migratingLegacyVivoConfig ? rawLegacyApiKey : '');
    final rawBaseUrl = prefs.getString(_baseUrlKey) ??
        (migratingLegacyVivoConfig
            ? defaultOpenAiCompatibleBaseUrl
            : rawLegacyBaseUrl ?? defaultOpenAiCompatibleBaseUrl);
    final rawTextModel = prefs.getString(_textModelKey) ??
        prefs.getString(_legacyTextModelKey) ??
        '';
    final rawEmbeddingModel = prefs.getString(_embeddingModelKey) ??
        prefs.getString(_legacyEmbeddingModelKey);
    final rawOcsrEndpoint = prefs.getString(_ocsrEndpointKey) ?? '';

    final textModel =
        migratingLegacyVivoConfig && _isLegacyCatalogModel(rawTextModel.trim())
            ? ''
            : rawTextModel.trim();
    final embeddingModel = migratingLegacyVivoConfig
        ? null
        : _normalizeOptional(rawEmbeddingModel);
    final baseUrl = _normalizeBaseUrl(rawBaseUrl);
    final ocsrEndpoint = rawOcsrEndpoint.trim().isEmpty
        ? _defaultOcsrEndpoint()
        : _migrateOcsrEndpoint(rawOcsrEndpoint.trim());

    if (!prefs.containsKey(_textModelKey) || textModel != rawTextModel) {
      await prefs.setString(_textModelKey, textModel);
    }
    if (!prefs.containsKey(_baseUrlKey) || baseUrl != rawBaseUrl) {
      await prefs.setString(_baseUrlKey, baseUrl);
    }
    if (!prefs.containsKey(_apiKeyKey)) {
      await prefs.setString(_apiKeyKey, apiKey);
    }
    if (!prefs.containsKey(_asrApiKeyKey)) {
      await prefs.setString(_asrApiKeyKey, asrApiKey);
    }
    if (!prefs.containsKey(_embeddingModelKey)) {
      if (embeddingModel != null) {
        await prefs.setString(_embeddingModelKey, embeddingModel);
      } else if (migratingLegacyVivoConfig) {
        await prefs.setString(_embeddingModelKey, '');
      }
    }
    if (ocsrEndpoint != rawOcsrEndpoint.trim()) {
      await prefs.setString(_ocsrEndpointKey, ocsrEndpoint);
    }

    return AiSettings(
      apiKey: apiKey,
      asrApiKey: asrApiKey,
      textModel: textModel,
      embeddingModel: embeddingModel,
      baseUrl: baseUrl,
      ocsrEndpoint: ocsrEndpoint,
    );
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, settings.apiKey);
    await prefs.setString(_asrApiKeyKey, settings.asrApiKey);
    await prefs.setString(_textModelKey, settings.textModel);
    await _setOptional(prefs, _embeddingModelKey, settings.embeddingModel);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
    await prefs.setString(_ocsrEndpointKey, settings.ocsrEndpoint);
  }

  String? _normalizeOptional(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  String _normalizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return defaultOpenAiCompatibleBaseUrl;
    if (!trimmed.contains('://') &&
        (trimmed.startsWith('localhost') || trimmed.startsWith('10.0.2.2'))) {
      return 'http://$trimmed';
    }
    return trimmed;
  }

  bool _isLegacyVivoBaseUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.startsWith('https://api-ai.vivo.com.cn') ||
        trimmed.startsWith(AppConfig.cloudflareWorkerUrl) ||
        trimmed.startsWith('http://localhost:8787') ||
        trimmed.startsWith('http://127.0.0.1:8787') ||
        trimmed.startsWith('http://10.0.2.2:8787');
  }

  bool _isLegacyCatalogModel(String value) {
    return const {
      'Volc-DeepSeek-V3.2',
      'Doubao-Seed-2.0-pro',
      'Doubao-Seed-2.0-mini',
      'Doubao-Seed-2.0-lite',
      'qwen3.5-plus',
      'Doubao-Seedream-4.5',
    }.contains(value);
  }

  /// OCSR 默认端点：Web 端走 CF Worker 代理，其他平台走本地代理或直连
  String _defaultOcsrEndpoint() {
    if (kIsWeb) {
      return AppConfig.webDecimerBaseUrl;
    }
    return AppConfig.decimerBaseUrl;
  }

  /// 迁移旧的 Cloudflare Worker OCSR 代理 URL 到新的直连域名
  /// 旧: https://api.chemvision.qzz.io/decimer (Worker 代理,有 1003 错误)
  /// 新: https://agent.shengxia.me/decimer (直连,SSL 通过 Cloudflare 代理)
  String _migrateOcsrEndpoint(String value) {
    if (value.contains('api.chemvision.qzz.io') && value.contains('decimer')) {
      return AppConfig.decimerBaseUrl;
    }
    // 非 Web 平台:本地开发用的 localhost 端点在真机上不可达,迁移回默认地址
    if (!kIsWeb &&
        (value.startsWith('http://localhost:8787') ||
            value.startsWith('http://10.0.2.2:8787'))) {
      return AppConfig.decimerBaseUrl;
    }
    return value;
  }

  Future<void> _setOptional(
    SharedPreferences prefs,
    String key,
    String? value,
  ) async {
    final normalized = _normalizeOptional(value);
    if (normalized == null) {
      // Keep an empty value so a legacy preference cannot be re-imported.
      await prefs.setString(key, '');
      return;
    }
    await prefs.setString(key, normalized);
  }
}
