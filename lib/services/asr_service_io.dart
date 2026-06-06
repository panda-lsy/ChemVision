import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class AsrService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final StreamController<String> _resultController =
      StreamController<String>.broadcast();

  Stream<String> get results => _resultController.stream;

  Future<void> connect({
    required String apiKey,
    required String requestId,
  }) async {
    final userId = _generateUuid();
    final now = DateTime.now().millisecondsSinceEpoch.toString();

    final params = {
      'client_version': 'unknown',
      'package': 'unknown',
      'sdk_version': 'unknown',
      'user_id': userId,
      'android_version': 'unknown',
      'system_time': now,
      'net_type': '1',
      'engineid': 'shortasrinput',
      'requestId': requestId,
    };

    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final url = 'ws://api-ai.vivo.com.cn/asr/v2?$query';

    try {
      // WebSocket 连接需要 Authorization header，使用 IOWebSocketChannel
      final ioWebSocket = IOWebSocketChannel.connect(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      );
      _channel = ioWebSocket;

      // Wait for connection to be ready
      await _channel!.ready;

      // Send handshake
      final handshake = jsonEncode({
        'type': 'started',
        'request_id': requestId,
        'asr_info': {
          'end_vad_time': -1,
          'audio_type': 'pcm',
          'chinese2digital': 1,
          'punctuation': 1,
        },
      });
      _channel!.sink.add(handshake);

      // Listen for results
      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message),
        onError: (error) {
          debugPrint('[AsrService] WebSocket error: $error');
          _resultController.addError('连接错误: $error');
        },
        onDone: () {
          debugPrint('[AsrService] WebSocket closed');
        },
      );
    } catch (e) {
      throw Exception('ASR 连接失败: $e');
    }
  }

  void _handleMessage(dynamic message) {
    if (message is! String) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(message) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[AsrService] Invalid JSON: $message');
      return;
    }

    final action = data['action'] as String?;
    final code = data['code'] as int?;

    if (action == 'started') {
      if (code != 0) {
        final desc = data['desc'] ?? '握手失败';
        _resultController.addError('ASR 错误: $desc');
      }
      return;
    }

    if (action == 'error') {
      final desc = data['desc'] ?? '识别错误';
      _resultController.addError('ASR 错误: $desc');
      return;
    }

    if (action == 'result' && code == 0) {
      final resultData = data['data'];
      if (resultData is Map<String, dynamic>) {
        final text = resultData['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _resultController.add(text);
        }
      }
    }
  }

  Future<void> sendAudio(Uint8List audioBytes) async {
    final sink = _channel?.sink;
    if (sink == null) return;

    // Send in 64ms chunks (2048 bytes at 16kHz/16bit)
    const chunkSize = 2048;
    for (var i = 0; i < audioBytes.length; i += chunkSize) {
      final end = (i + chunkSize < audioBytes.length)
          ? i + chunkSize
          : audioBytes.length;
      sink.add(audioBytes.sublist(i, end));
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    // Send end marker
    sink.add(utf8.encode('--end--'));
  }

  Future<void> close() async {
    try {
      _channel?.sink.add(utf8.encode('--close--'));
    } catch (_) {}
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }

  Future<void> dispose() async {
    await close();
    await _resultController.close();
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    const chars = '0123456789abcdef';
    String hex(int seed, int length) {
      var value = seed;
      return List.generate(length, (_) {
        value = value * 9301 + 49297;
        return chars[value % 16];
      }).join();
    }

    return '${hex(random, 8)}-${hex(random + 1, 4)}-${hex(random + 2, 4)}-${hex(random + 3, 4)}-${hex(random + 4, 12)}';
  }
}
