import 'dart:math';

import 'package:dio/dio.dart';

class VivoAigcClient {
  VivoAigcClient({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
    final endpoint = _normalizeBaseUrl(baseUrl) + '/api/v1/text_generation';
    final response = await _dio.post(
      endpoint,
      queryParameters: {
        'module': 'aigc',
        'request_id': _generateRequestId(),
        'system_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
      data: {
        'model': model,
        'prompt': prompt,
      },
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final code = data['code'];
      if (code == 0) {
        final payload = data['data'];
        if (payload is Map<String, dynamic>) {
          final text = payload['text'];
          if (text is String) {
            return text;
          }
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
