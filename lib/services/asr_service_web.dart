import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Web 端 ASR 服务（stub 实现）
///
/// Web 端暂不支持完整 ASR 流式识别（需要自定义 header 的 WebSocket），
/// 此实现保证编译通过，运行时由 AsrProvider 返回提示信息。
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
    debugPrint('[AsrService:Web] Web 端 ASR 连接暂不支持，需使用 HTTP API 替代方案');
    // Web 端浏览器 WebSocket 不支持自定义 Authorization header，
    // 且 ASR 服务使用 ws:// 协议，HTTPS 页面会因混合内容策略阻止。
    // 这里不建立连接，由 AsrProvider 检测状态后返回提示。
  }

  Future<void> sendAudio(Uint8List audioBytes) async {
    debugPrint('[AsrService:Web] Web 端暂不支持音频发送');
  }

  Future<void> close() async {
    try {
      _channel?.sink.close();
    } catch (_) {}
    await _subscription?.cancel();
    _channel = null;
    _subscription = null;
  }

  Future<void> dispose() async {
    await close();
    await _resultController.close();
  }
}
