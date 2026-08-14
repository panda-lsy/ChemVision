import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';

/// DECIMER OCSR 客户端
///
/// 通过 HTTP multipart/form-data 上传图片到 DECIMER 服务，返回 SMILES 字符串。
/// 服务端可以是：
/// - 自部署的 FastAPI 包装器（见 tools/decimer_server.py）
/// - 经 Cloudflare Worker 的 /decimer 子路径代理（见 cloudflare-worker/worker.js），
///   Worker 通过 env.DECIMER_UPSTREAM 转发到自部署的 FastAPI 包装器
///
/// 端点约定：POST {endpoint}/process_image
/// 表单字段：image（图片字节）
/// 响应：纯文本 SMILES，无法识别时返回空或 "INVALID"
class DecimerClient {
  DecimerClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                // OCSR 模型推理可能较慢，给到 60s
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

  final Dio _dio;

  /// 从 data URI 解析图片并调用 DECIMER 识别
  ///
  /// [dataUri] 形如 `data:image/jpeg;base64,...`
  /// [endpoint] 不带路径的 base url，如 `https://my-decimer.example.com`
  /// 返回纯文本 SMILES，无法识别时返回空字符串
  Future<String> recognizeFromDataUri({
    required String dataUri,
    required String endpoint,
  }) async {
    final parsed = _parseDataUri(dataUri);
    if (parsed == null) {
      throw const DecimerException('图片数据 URI 格式无效');
    }

    final uri = _buildProcessUri(endpoint);
    final filename = 'image.${parsed.extension}';

    final FormData formData;
    try {
      formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          parsed.bytes,
          filename: filename,
        ),
      });
    } catch (e) {
      throw DecimerException('构造 multipart 表单失败: $e');
    }

    if (kDebugMode) {
      debugPrint('[DECIMER] POST $uri (bytes=${parsed.bytes.length})');
    }

    Response? response;
    DioException? lastError;
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        response = await _dio.postUri(
          uri,
          data: formData,
          options: Options(
            headers: {'accept': 'text/plain, application/json'},
            validateStatus: (_) => true,
            responseType: ResponseType.plain,
          ),
        );
        final status = response.statusCode ?? 0;
        if (status == 200 || (status >= 400 && status < 500)) break;
        if (kDebugMode) {
          debugPrint('[DECIMER] Retry $attempt/2 (HTTP $status)');
        }
      } on DioException catch (e) {
        lastError = e;
        if (kDebugMode) {
          debugPrint('[DECIMER] Retry $attempt/2 (${e.type})');
        }
      }
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }

    if (response == null) {
      // DioException.message 可能为 null,真实原因通常在 error/type 中
      final message = lastError?.error?.toString() ??
          lastError?.message ??
          (lastError != null ? lastError.type.name : '连接失败');
      if (kIsWeb) {
        throw DecimerException('OCSR 服务请求失败：请确认已部署 Cloudflare Worker 代理。$message');
      }
      throw DecimerException('OCSR 服务请求失败: $message');
    }

    final status = response.statusCode ?? 0;
    if (status != 200) {
      final body = response.data?.toString() ?? '';
      throw DecimerException('OCSR 服务返回 HTTP $status: ${body.isEmpty ? "(无响应体)" : body}');
    }

    final raw = response.data?.toString() ?? '';
    final smiles = _parseSmilesResponse(raw);
    if (kDebugMode) {
      debugPrint('[DECIMER] Response: $raw');
      debugPrint('[DECIMER] Parsed SMILES: $smiles');
    }
    return smiles;
  }

  Uri _buildProcessUri(String endpoint) {
    final normalized = endpoint.trim().replaceAll(RegExp(r'/+$'), '');
    // 若用户填入的 endpoint 已包含 /process_image，则不再追加
    final String url;
    if (normalized.endsWith(AppConfig.decimerProcessPath)) {
      url = normalized;
    } else {
      url = '$normalized${AppConfig.decimerProcessPath}';
    }
    return Uri.parse(url);
  }

  /// 解析 data URI（data:image/jpeg;base64,...）
  _ParsedDataUri? _parseDataUri(String dataUri) {
    final trimmed = dataUri.trim();
    final match = RegExp(
      r'^data:([a-zA-Z]+/[a-zA-Z0-9.+-]+);base64,(.+)$',
    ).firstMatch(trimmed);
    if (match == null) return null;
    final mime = match.group(1)!;
    final base64Data = match.group(2)!;
    try {
      final bytes = base64Decode(base64Data);
      return _ParsedDataUri(
        bytes: bytes,
        mimeType: mime,
        extension: _mimeToExtension(mime),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DECIMER] base64 decode failed: $e');
      }
      return null;
    }
  }

  String _mimeToExtension(String mime) {
    switch (mime.toLowerCase()) {
      case 'image/png':
        return 'png';
      case 'image/webp':
        return 'webp';
      case 'image/gif':
        return 'gif';
      case 'image/bmp':
        return 'bmp';
      case 'image/jpeg':
      case 'image/jpg':
      default:
        return 'jpg';
    }
  }

  /// 解析 DECIMER 响应为 SMILES 字符串
  ///
  /// DECIMER 包装器约定返回纯文本：
  /// - 成功：单行 SMILES（可能首尾有空白）
  /// - 失败：空字符串、`INVALID`、或 JSON `{"smiles": "", "error": "..."}`
  static String _parseSmilesResponse(String raw) {
    var cleaned = raw.trim();
    if (cleaned.isEmpty) return '';

    // 尝试解析 JSON 响应（部分包装器可能返回 JSON）
    if (cleaned.startsWith('{')) {
      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map) {
          final smiles = decoded['smiles']?.toString().trim() ?? '';
          if (smiles.isNotEmpty) return _sanitizeSmiles(smiles);
          final error = decoded['error']?.toString();
          if (error != null && error.isNotEmpty) {
            return '';
          }
          return '';
        }
      } catch (_) {
        // 不是合法 JSON，按纯文本处理
      }
    }

    // 去掉代码块标记
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      final filtered = lines.where((l) => !l.startsWith('```')).join('\n');
      cleaned = filtered.trim();
    }

    // 去掉前缀 "SMILES:" 等
    cleaned = cleaned.replaceFirst(
      RegExp(r'^smiles[:：]\s*', caseSensitive: false),
      '',
    );

    // 只取第一行
    final newlineIdx = cleaned.indexOf('\n');
    if (newlineIdx > 0) {
      cleaned = cleaned.substring(0, newlineIdx).trim();
    }

    return _sanitizeSmiles(cleaned);
  }

  static String _sanitizeSmiles(String value) {
    var result = value.trim();
    if (result.isEmpty) return '';
    final upper = result.toUpperCase();
    if (upper == 'INVALID' ||
        upper == 'NONE' ||
        upper == 'NULL' ||
        upper == 'UNDEFINED') {
      return '';
    }
    return result;
  }
}

class _ParsedDataUri {
  const _ParsedDataUri({
    required this.bytes,
    required this.mimeType,
    required this.extension,
  });

  final List<int> bytes;
  final String mimeType;
  final String extension;
}

class DecimerException implements Exception {
  const DecimerException(this.message);
  final String message;

  @override
  String toString() => message;
}
