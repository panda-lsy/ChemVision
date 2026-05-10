import 'dart:convert';

import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// OCR 识别结果
class OcrResult {
  OcrResult({
    required this.success,
    this.texts = const [],
    this.error,
  });

  final bool success;
  final List<OcrTextLocation> texts;
  final String? error;

  /// 获取所有识别的文本（拼接）
  String get allText => texts.map((t) => t.words).join(' ');

  /// 获取第一个识别结果
  String get firstText => texts.isNotEmpty ? texts.first.words : '';
}

/// OCR 识别的文本及其位置
class OcrTextLocation {
  OcrTextLocation({
    required this.words,
    this.location,
  });

  final String words;
  final OcrLocation? location;
}

/// OCR 文本位置信息
class OcrLocation {
  OcrLocation({
    required this.topLeft,
    required this.topRight,
    required this.downLeft,
    required this.downRight,
  });

  final OcrPoint topLeft;
  final OcrPoint topRight;
  final OcrPoint downLeft;
  final OcrPoint downRight;
}

/// OCR 坐标点
class OcrPoint {
  OcrPoint({required this.x, required this.y});

  final double x;
  final double y;
}

/// Vivo OCR 服务
class OcrService {
  OcrService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// 识别图片中的文字
  /// 
  /// [imageBase64] Base64 编码的图片数据（不包含 data:image/xxx;base64, 前缀）
  /// [pos] 返回位置信息：0-只需文字，1-文字 + 绝对坐标，2-文字 + 相对坐标（推荐）
  /// [apiKey] Vivo API Key
  Future<OcrResult> recognize({
    required String imageBase64,
    int pos = 2,
    required String apiKey,
  }) async {
    try {
      final requestId = _generateRequestId();
      final businessId = 'aigc$apiKey';
      
      final response = await _dio.post(
        'http://api-ai.vivo.com.cn/ocr/general_recognition',
        queryParameters: {
          'requestId': requestId,
        },
        data: {
          'image': imageBase64,
          'pos': pos.toString(),
          'businessid': businessId,
          'sessid': requestId,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      if (response.statusCode != 200) {
        return OcrResult(
          success: false,
          error: 'HTTP ${response.statusCode}: 识别失败',
        );
      }

      final data = response.data;
      final errorCode = data['error_code'] as int?;

      if (errorCode != 0) {
        final errorMsg = data['error_msg'] ?? 'OCR 识别失败';
        return OcrResult(
          success: false,
          error: errorMsg,
        );
      }

      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return OcrResult(success: true);
      }

      // 解析识别结果
      final texts = <OcrTextLocation>[];
      
      // pos=0 时返回 words 数组
      if (result.containsKey('words')) {
        final wordsList = result['words'] as List<dynamic>;
        for (var word in wordsList) {
          if (word is Map<String, dynamic>) {
            texts.add(OcrTextLocation(
              words: word['words'] as String? ?? '',
            ));
          }
        }
      } 
      // pos=1 或 2 时返回 OCR 数组（带位置）
      else if (result.containsKey('OCR')) {
        final ocrList = result['OCR'] as List<dynamic>;
        for (var ocr in ocrList) {
          if (ocr is Map<String, dynamic>) {
            final locationData = ocr['location'] as Map<String, dynamic>?;
            OcrLocation? location;
            
            if (locationData != null) {
              location = _parseLocation(locationData);
            }

            texts.add(OcrTextLocation(
              words: ocr['words'] as String? ?? '',
              location: location,
            ));
          }
        }
      }

      return OcrResult(
        success: true,
        texts: texts,
      );
    } catch (e) {
      return OcrResult(
        success: false,
        error: 'OCR 识别异常：$e',
      );
    }
  }

  OcrLocation? _parseLocation(Map<String, dynamic> data) {
    try {
      final topLeftData = data['top_left'] as Map<String, dynamic>?;
      final topRightData = data['top_right'] as Map<String, dynamic>?;
      final downLeftData = data['down_left'] as Map<String, dynamic>?;
      final downRightData = data['down_right'] as Map<String, dynamic>?;

      if (topLeftData == null || topRightData == null ||
          downLeftData == null || downRightData == null) {
        return null;
      }

      return OcrLocation(
        topLeft: OcrPoint(
          x: (topLeftData['x'] as num).toDouble(),
          y: (topLeftData['y'] as num).toDouble(),
        ),
        topRight: OcrPoint(
          x: (topRightData['x'] as num).toDouble(),
          y: (topRightData['y'] as num).toDouble(),
        ),
        downLeft: OcrPoint(
          x: (downLeftData['x'] as num).toDouble(),
          y: (downLeftData['y'] as num).toDouble(),
        ),
        downRight: OcrPoint(
          x: (downRightData['x'] as num).toDouble(),
          y: (downRightData['y'] as num).toDouble(),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  String _generateRequestId() {
    // 生成 UUID v4
    final random = DateTime.now().millisecondsSinceEpoch;
    final micro = DateTime.now().microsecondsSinceEpoch;
    return '${random.toString().padLeft(8, '0')}-${(micro % 10000).toString().padLeft(4, '0')}-${(micro % 10000).toString().padLeft(4, '0')}-${(micro % 10000).toString().padLeft(4, '0')}-${random.toString().padLeft(12, '0')}';
  }
}
