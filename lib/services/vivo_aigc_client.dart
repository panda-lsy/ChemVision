import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

class VivoAigcClient {
  VivoAigcClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl.isEmpty ? AppConfig.vivoAigcBaseUrl : baseUrl,
    );

    final requestId = _generateRequestId();
    final queryParameters = {
      'requestId': requestId,
      'request_id': requestId,
    };
    final body = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': prompt,
        }
      ],
      'stream': false,
    };
    final uri = _buildTextGenerationUri(normalizedBase, queryParameters);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    _logRequest(uri, headers, body);

    Response response;
    try {
      response = await _retryPost(uri, headers: headers, body: body);
    } on DioException catch (error) {
      if (kIsWeb) {
        throw Exception('网络连接失败，请检查网络或确认接口支持 CORS');
      }
      final message = error.message ?? '网络连接失败';
      throw Exception(message);
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('网络连接失败: $error');
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw Exception('HTTP $statusCode: ${response.data}');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final extracted = _extractChatContent(data);
      if (extracted != null) {
        _logResponse(extracted);
        return extracted;
      }
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final message = error['message'];
        if (message is String && message.isNotEmpty) {
          throw Exception(message);
        }
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        throw Exception(message);
      }
    }
    throw Exception('服务响应异常');
  }

  /// Generate text with multimodal input (text + image).
  /// [imageBase64] should be a data URI like "data:image/jpeg;base64,..."
  Future<String> generateMultimodal({
    required String apiKey,
    required String model,
    required String prompt,
    required String imageBase64,
    required String baseUrl,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl.isEmpty ? AppConfig.vivoAigcBaseUrl : baseUrl,
    );

    final requestId = _generateRequestId();
    final queryParameters = {
      'requestId': requestId,
      'request_id': requestId,
    };
    final body = {
      'model': model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image_url',
              'image_url': {'url': imageBase64},
            },
            {
              'type': 'text',
              'text': prompt,
            },
          ],
        }
      ],
      'stream': false,
      'temperature': 0.3,
      'max_tokens': 2048,
    };
    final uri = _buildTextGenerationUri(normalizedBase, queryParameters);
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    _logRequest(uri, headers, body);

    Response response;
    try {
      response = await _retryPost(uri, headers: headers, body: body);
    } on DioException catch (error) {
      if (kIsWeb) {
        throw Exception('网络连接失败，请检查网络或确认接口支持 CORS');
      }
      final message = error.message ?? '网络连接失败';
      throw Exception(message);
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('网络连接失败: $error');
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw Exception('HTTP $statusCode: ${response.data}');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final extracted = _extractChatContent(data);
      if (extracted != null) {
        _logResponse(extracted);
        return extracted;
      }
    }
    throw Exception('服务响应异常');
  }

  Future<List<List<double>>> generateEmbeddings({
    required String apiKey,
    required String modelName,
    required List<String> sentences,
    required String baseUrl,
  }) async {
    final normalizedBase = _normalizeBaseUrl(
      baseUrl.isEmpty ? AppConfig.vivoAigcBaseUrl : baseUrl,
    );
    final requestId = _generateRequestId();
    final uri = Uri.parse('$normalizedBase/embedding-model-api/predict/batch')
        .replace(queryParameters: {'requestId': requestId});
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
    final body = {
      'model_name': modelName,
      'sentences': sentences,
    };

    _logRequest(uri, headers, body);

    Response response;
    try {
      response = await _retryPost(uri, headers: headers, body: body);
    } on DioException catch (error) {
      if (kIsWeb) {
        throw Exception('网络连接失败，请检查网络或确认接口支持 CORS');
      }
      final message = error.message ?? '网络连接失败';
      throw Exception(message);
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('网络连接失败: $error');
    }

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw Exception('HTTP $statusCode: ${response.data}');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final vectors = data['data'];
      if (vectors is List) {
        return vectors
            .whereType<List>()
            .map(
              (row) => row
                  .map((item) => item is num ? item.toDouble() : double.parse(item.toString()))
                  .toList(),
            )
            .toList();
      }
    }
    throw Exception('Embedding 服务响应异常');
  }

  String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildTextGenerationUri(
    String baseUrl,
    Map<String, dynamic> queryParameters,
  ) {
    final normalizedBase = _normalizeBaseUrl(baseUrl);
    String endpoint;
    if (normalizedBase.contains(AppConfig.vivoTextGenerationPath)) {
      endpoint = normalizedBase;
    } else if (normalizedBase.endsWith('/v1')) {
      endpoint = '$normalizedBase${AppConfig.vivoTextGenerationPath}';
    } else {
      endpoint =
          '$normalizedBase/v1${AppConfig.vivoTextGenerationPath}';
    }

    final stringParams = queryParameters.map(
      (key, value) => MapEntry(key, value.toString()),
    );
    return Uri.parse(endpoint).replace(queryParameters: stringParams);
  }

  void _logRequest(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) {
    if (!kDebugMode) {
      return;
    }
    final safeHeaders = Map<String, String>.from(headers);
    final authorization = safeHeaders['Authorization'];
    if (authorization != null) {
      safeHeaders['Authorization'] = _maskAuthorization(authorization);
    }
    debugPrint('[VivoAigc] URL: $uri');
    debugPrint('[VivoAigc] Headers: ${jsonEncode(safeHeaders)}');
    debugPrint('[VivoAigc] Body: ${jsonEncode(body)}');
  }

  void _logResponse(String content) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[VivoAigc] Response: $content');
  }

  String _maskAuthorization(String value) {
    const prefix = 'Bearer ';
    if (!value.startsWith(prefix)) {
      return '***';
    }
    final token = value.substring(prefix.length);
    if (token.length <= 6) {
      return '$prefix***';
    }
    final tail = token.substring(token.length - 4);
    return '$prefix***$tail';
  }

  String? _extractChatContent(Map<String, dynamic> data) {
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
        final text = first['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }
    return null;
  }

  String _generateRequestId() {
    final random = Random();
    String hex(int length) {
      const chars = '0123456789abcdef';
      return List.generate(
        length,
        (_) => chars[random.nextInt(chars.length)],
      ).join();
    }

    return '${hex(8)}-${hex(4)}-${hex(4)}-${hex(4)}-${hex(12)}';
  }

  /// Retry POST up to [maxAttempts] times with exponential backoff.
  /// Retries on network errors and non-200 status codes.
  Future<Response> _retryPost(
    Uri uri, {
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    int maxAttempts = 3,
  }) async {
    DioException? lastDioError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await _dio.postUri(
          uri,
          options: Options(
            headers: headers,
            validateStatus: (_) => true,
          ),
          data: body,
        );
        final status = response.statusCode ?? 0;
        // Treat 200 as success; 4xx are client errors (no retry); 5xx/0 retry.
        if (status == 200 || (status >= 400 && status < 500)) {
          return response;
        }
        if (kDebugMode) {
          debugPrint('[VivoAigc] Retry $attempt/$maxAttempts (HTTP $status)');
        }
      } on DioException catch (e) {
        lastDioError = e;
        if (kDebugMode) {
          debugPrint('[VivoAigc] Retry $attempt/$maxAttempts (${e.type})');
        }
      }
      if (attempt < maxAttempts) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    if (lastDioError != null) throw lastDioError;
    throw Exception('请求失败，已重试 $maxAttempts 次');
  }
}
