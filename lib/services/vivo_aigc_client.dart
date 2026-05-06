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
    if (kIsWeb && normalizedBase == AppConfig.vivoAigcBaseUrl) {
      throw Exception('Web环境暂不支持直连，请使用手机端测试或配置代理');
    }

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

    final response = await _dio.postUri(
      uri,
      options: Options(
        headers: headers,
        validateStatus: (_) => true,
      ),
      data: body,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode != 200) {
      throw Exception('HTTP $statusCode: ${response.data}');
    }

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final extracted = _extractChatContent(data);
      if (extracted != null) {
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

  String _maskAuthorization(String value) {
    const prefix = 'Bearer ';
    if (!value.startsWith(prefix)) {
      return '***';
    }
    final token = value.substring(prefix.length);
    if (token.length <= 6) {
      return '${prefix}***';
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
}
