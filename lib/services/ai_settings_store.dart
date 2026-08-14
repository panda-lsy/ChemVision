import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/ai_models.dart';
import '../config/app_config.dart';

class AiSettings {
  final String apiKey;
  final String textModel;
  final String? embeddingModel;
  final String? rerankModel;
  final String baseUrl;
  final String ocsrEndpoint;

  const AiSettings({
    required this.apiKey,
    required this.textModel,
    required this.baseUrl,
    required this.ocsrEndpoint,
    this.embeddingModel,
    this.rerankModel,
  });

  AiSettings copyWith({
    String? apiKey,
    String? textModel,
    String? baseUrl,
    String? ocsrEndpoint,
    String? embeddingModel,
    String? rerankModel,
  }) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      textModel: textModel ?? this.textModel,
      baseUrl: baseUrl ?? this.baseUrl,
      ocsrEndpoint: ocsrEndpoint ?? this.ocsrEndpoint,
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
  static const String _ocsrEndpointKey = 'ocsr_endpoint';

  Future<AiSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString(_apiKeyKey) ?? '';
    final rawTextModel = prefs.getString(_textModelKey) ?? '';
    final embeddingModel = prefs.getString(_embeddingModelKey);
    final rerankModel = prefs.getString(_rerankModelKey);
    final hasBaseUrl = prefs.containsKey(_baseUrlKey);
    final rawBaseUrl = prefs.getString(_baseUrlKey) ?? defaultAigcBaseUrl;
    final rawOcsrEndpoint = prefs.getString(_ocsrEndpointKey) ?? '';

    final textModel = _migrateTextModel(rawTextModel);
    final baseUrl = hasBaseUrl
      ? _migrateBaseUrl(rawBaseUrl)
      : _defaultAigcBaseUrl();
    final ocsrEndpoint = rawOcsrEndpoint.trim().isEmpty
        ? _defaultOcsrEndpoint()
        : _migrateOcsrEndpoint(rawOcsrEndpoint.trim());

    if (textModel != rawTextModel) {
      await prefs.setString(_textModelKey, textModel);
    }
    if (baseUrl != rawBaseUrl) {
      await prefs.setString(_baseUrlKey, baseUrl);
    }
    if (ocsrEndpoint != rawOcsrEndpoint.trim()) {
      await prefs.setString(_ocsrEndpointKey, ocsrEndpoint);
    }

    return AiSettings(
      apiKey: apiKey,
      textModel: textModel,
      embeddingModel: _normalizeOptional(embeddingModel),
      rerankModel: _normalizeOptional(rerankModel),
      baseUrl: baseUrl,
      ocsrEndpoint: ocsrEndpoint,
    );
  }

  Future<void> save(AiSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, settings.apiKey);
    await prefs.setString(_textModelKey, settings.textModel);
    await _setOptional(prefs, _embeddingModelKey, settings.embeddingModel);
    await _setOptional(prefs, _rerankModelKey, settings.rerankModel);
    await prefs.setString(_baseUrlKey, settings.baseUrl);
    await prefs.setString(_ocsrEndpointKey, settings.ocsrEndpoint);
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
      return _defaultAigcBaseUrl();
    }
    if (!trimmed.contains('://') &&
        (trimmed.startsWith('localhost') || trimmed.startsWith('10.0.2.2'))) {
      trimmed = 'http://$trimmed';
    }
    // On Web, keep localhost:8787 or worker URL — the proxy is required for CORS.
    if (kIsWeb &&
        (trimmed.startsWith('http://localhost:8787') ||
            trimmed.startsWith('http://10.0.2.2:8787') ||
            trimmed.contains('.workers.dev'))) {
      return trimmed;
    }
    // On Web, if stored value is a direct external URL, force proxy.
    if (kIsWeb && trimmed.startsWith('https://api-ai.vivo.com.cn')) {
      return AppConfig.webProxyBaseUrl;
    }
    // On non-Web, migrate away from localhost:8787 to the direct URL.
    if (!kIsWeb &&
        (trimmed.startsWith('http://localhost:8787') ||
            trimmed.startsWith('http://10.0.2.2:8787'))) {
      return AppConfig.vivoTextGenerationUrl;
    }
    if (trimmed.contains('/api/v1')) {
      return AppConfig.vivoTextGenerationUrl;
    }
    if (trimmed == 'https://api-ai.vivo.com.cn') {
      return AppConfig.vivoTextGenerationUrl;
    }
    return trimmed;
  }

  /// On Web, always use the local proxy to avoid CORS.
  /// On Android, use the direct Vivo URL.
  String _defaultAigcBaseUrl() {
    if (kIsWeb) {
      return AppConfig.webProxyBaseUrl;
    }
    return defaultAigcBaseUrl;
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
      await prefs.remove(key);
      return;
    }
    await prefs.setString(key, normalized);
  }
}
