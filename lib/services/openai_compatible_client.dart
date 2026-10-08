import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/ai_models.dart';

/// Client for APIs that implement the OpenAI-compatible chat and embeddings
/// endpoints. The provider and model are selected by the configured base URL
/// and model names.
class OpenAiCompatibleClient {
  OpenAiCompatibleClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
              ),
            );

  final Dio _dio;

  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
    final uri = _buildEndpoint(baseUrl, '/chat/completions');
    final body = {
      'model': model,
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream': false,
    };
    final response = await _post(uri, apiKey: apiKey, body: body);
    _ensureSuccess(response);

    final data = response.data;
    if (data is Map) {
      final content = _extractChatContent(data);
      if (content != null) {
        _logResponse(content);
        return content;
      }
    }
    throw Exception(
        _responseError(response) ?? '服务响应缺少 choices[0].message.content');
  }

  /// [imageBase64] may be a data URI such as "data:image/jpeg;base64,...".
  Future<String> generateMultimodal({
    required String apiKey,
    required String model,
    required String prompt,
    required String imageBase64,
    required String baseUrl,
  }) async {
    final uri = _buildEndpoint(baseUrl, '/chat/completions');
    final body = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {'url': imageBase64},
            },
          ],
        },
      ],
      'stream': false,
      'temperature': 0.3,
      'max_tokens': 2048,
    };
    final response = await _post(uri, apiKey: apiKey, body: body);
    _ensureSuccess(response);

    final data = response.data;
    if (data is Map) {
      final content = _extractChatContent(data);
      if (content != null) {
        _logResponse(content);
        return content;
      }
    }
    throw Exception(
        _responseError(response) ?? '服务响应缺少 choices[0].message.content');
  }

  Future<List<List<double>>> generateEmbeddings({
    required String apiKey,
    required String model,
    required List<String> input,
    required String baseUrl,
  }) async {
    final uri = _buildEndpoint(baseUrl, '/embeddings');
    final body = {'model': model, 'input': input};
    final response = await _post(uri, apiKey: apiKey, body: body);
    _ensureSuccess(response);

    final data = response.data;
    final entries = data is Map ? data['data'] : null;
    if (entries is! List || entries.isEmpty) {
      throw Exception(_responseError(response) ?? 'Embedding 响应缺少 data');
    }
    if (entries.length != input.length) {
      throw Exception('Embedding 响应向量数量与输入数量不一致');
    }

    final indexedEntries = <({int index, List<double> embedding})>[];
    final seenIndices = <int>{};
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final rawEmbedding = entry is Map ? entry['embedding'] : null;
      if (rawEmbedding is! List || rawEmbedding.isEmpty) {
        throw Exception('Embedding 响应格式无效');
      }
      final vector = <double>[];
      for (final value in rawEmbedding) {
        if (value is! num) {
          throw Exception('Embedding 向量包含非数字值');
        }
        vector.add(value.toDouble());
      }
      final rawIndex = entry is Map ? entry['index'] : null;
      final index = rawIndex is int ? rawIndex : i;
      if (index < 0 || index >= input.length || !seenIndices.add(index)) {
        throw Exception('Embedding 响应包含无效或重复的 index');
      }
      indexedEntries.add((
        index: index,
        embedding: vector,
      ));
    }
    indexedEntries.sort((a, b) => a.index.compareTo(b.index));
    return indexedEntries.map((entry) => entry.embedding).toList();
  }

  Uri _buildEndpoint(String baseUrl, String endpoint) {
    final rawBase = baseUrl.trim().isEmpty
        ? defaultOpenAiCompatibleBaseUrl
        : baseUrl.trim();
    final normalizedBase = rawBase.replaceFirst(RegExp(r'/+$'), '');
    final parsed = Uri.tryParse(normalizedBase);
    if (parsed == null ||
        !const {'http', 'https'}.contains(parsed.scheme.toLowerCase()) ||
        parsed.host.isEmpty) {
      throw ArgumentError.value(baseUrl, 'baseUrl', '请输入有效的 API Base URL');
    }

    var basePath = parsed.path.replaceFirst(RegExp(r'/+$'), '');
    for (final suffix in const [
      '/v1/chat/completions',
      '/chat/completions',
      '/v1/embeddings',
      '/embeddings',
    ]) {
      if (basePath.endsWith(suffix)) {
        basePath = basePath.substring(0, basePath.length - suffix.length);
        break;
      }
    }

    final versionedBasePath = basePath.endsWith('/v1')
        ? basePath
        : '${basePath.isEmpty ? '' : basePath}/v1';
    return parsed.replace(
      path: '$versionedBasePath$endpoint',
      fragment: '',
    );
  }

  Future<Response<dynamic>> _post(
    Uri uri, {
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final key = apiKey.trim();
    if (key.isNotEmpty) {
      headers['Authorization'] = 'Bearer $key';
    }
    _logRequest(uri, headers, body);

    try {
      return await _retryPost(uri, headers: headers, body: body);
    } on DioException catch (error) {
      if (kIsWeb) {
        throw Exception('网络连接失败；请检查 API Base URL 是否支持浏览器 CORS');
      }
      throw Exception(error.message ?? '网络连接失败');
    }
  }

  void _ensureSuccess(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw Exception(_responseError(response) ?? 'HTTP $status');
    }
  }

  String? _responseError(Response<dynamic> response) {
    final data = response.data;
    if (data is Map) {
      final error = data['error'];
      if (error is Map && error['message'] is String) {
        return 'HTTP ${response.statusCode}: ${error['message']}';
      }
      if (error is String && error.isNotEmpty) {
        return 'HTTP ${response.statusCode}: $error';
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return 'HTTP ${response.statusCode}: $message';
      }
    }
    if (data is String && data.isNotEmpty) {
      return 'HTTP ${response.statusCode}: $data';
    }
    return null;
  }

  String? _extractChatContent(Map data) {
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;

    final message = first['message'];
    final content = message is Map ? message['content'] : null;
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    if (content is List) {
      final text = content
          .whereType<Map>()
          .where((part) => part['type'] == 'text' && part['text'] is String)
          .map((part) => part['text'] as String)
          .join();
      if (text.trim().isNotEmpty) return text.trim();
    }
    final completionText = first['text'];
    if (completionText is String && completionText.trim().isNotEmpty) {
      return completionText.trim();
    }
    return null;
  }

  void _logRequest(Uri uri, Map<String, String> headers, Map body) {
    if (!kDebugMode) return;
    final safeHeaders = Map<String, String>.from(headers);
    if (safeHeaders.containsKey('Authorization')) {
      safeHeaders['Authorization'] = 'Bearer ***';
    }
    final messages = body['messages'];
    final input = body['input'];
    debugPrint(
      '[OpenAICompatible] URL: ${uri.origin}${uri.path}',
    );
    debugPrint('[OpenAICompatible] Headers: ${jsonEncode(safeHeaders)}');
    debugPrint(
      '[OpenAICompatible] Request metadata: '
      'model=${body['model']}, '
      'messages=${messages is List ? messages.length : 0}, '
      'inputs=${input is List ? input.length : 0}',
    );
  }

  void _logResponse(String content) {
    if (kDebugMode) {
      debugPrint(
          '[OpenAICompatible] Response received (${content.length} characters)');
    }
  }

  Future<Response<dynamic>> _retryPost(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    int maxAttempts = 3,
  }) async {
    DioException? lastDioError;
    Response<dynamic>? lastServerError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _dio.postUri<dynamic>(
          uri,
          options: Options(
            headers: headers,
            validateStatus: (_) => true,
          ),
          data: body,
        );
        final status = response.statusCode ?? 0;
        if (status < 500) {
          return response;
        }
        lastServerError = response;
        lastDioError = null;
        if (kDebugMode) {
          debugPrint(
              '[OpenAICompatible] Retry $attempt/$maxAttempts (HTTP $status)');
        }
      } on DioException catch (error) {
        lastDioError = error;
        lastServerError = null;
        if (kDebugMode) {
          debugPrint(
              '[OpenAICompatible] Retry $attempt/$maxAttempts (${error.type})');
        }
      }
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    if (lastDioError != null) throw lastDioError;
    if (lastServerError != null) return lastServerError;
    throw Exception('请求失败，已重试 $maxAttempts 次');
  }
}
