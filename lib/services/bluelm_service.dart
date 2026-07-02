import 'package:flutter/services.dart';

/// BlueLM 端侧大模型服务
///
/// 通过 Flutter MethodChannel 与 Android 原生 LlmManager 通信。
/// 仅在 Android arm64 设备上可用。
class BlueLmService {
  static const _channel = MethodChannel('com.chemvision/bluelm');
  bool _initialized = false;

  /// 初始化端侧模型
  Future<bool> init({
    String modelPath = '/sdcard/1225/1.7.0.4_1225_mtk9500',
    int nCtx = 2048,
    int nThreads = 4,
    int npuPower = 100,
  }) async {
    try {
      final result = await _channel.invokeMethod<int>('init', {
        'modelPath': modelPath,
        'nCtx': nCtx,
        'nThreads': nThreads,
        'npuPower': npuPower,
      });
      _initialized = result == 0;
      return _initialized;
    } catch (e) {
      _initialized = false;
      return false;
    }
  }

  bool get isInitialized => _initialized;

  /// 纯文本推理
  Future<String> generate(String prompt) async {
    if (!_initialized) throw Exception('BlueLM 未初始化');
    try {
      final result = await _channel.invokeMethod<String>('generate', {
        'prompt': '[|Human|]:$prompt\n[|AI|]:',
      });
      return result ?? '';
    } catch (e) {
      throw Exception('BlueLM 推理失败: $e');
    }
  }

  /// 中断当前推理
  Future<void> interrupt() async {
    try {
      await _channel.invokeMethod<void>('interrupt');
    } catch (_) {}
  }

  /// 释放资源
  Future<void> release() async {
    try {
      await _channel.invokeMethod<void>('release');
      _initialized = false;
    } catch (_) {}
  }
}
