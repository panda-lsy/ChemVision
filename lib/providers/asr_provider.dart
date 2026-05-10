import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

// 条件导入：只在非 Web 平台使用 dart:io 和 path_provider
import 'dart:io' if (dart.library.html) 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/ai_settings_store.dart';
import '../services/asr_service.dart';

enum AsrStatus { idle, recording, processing, done, error }

class AsrState {
  const AsrState({
    this.status = AsrStatus.idle,
    this.partialText = '',
    this.finalText,
    this.error,
    this.elapsedSeconds = 0,
  });

  final AsrStatus status;
  final String partialText;
  final String? finalText;
  final String? error;
  final int elapsedSeconds;

  AsrState copyWith({
    AsrStatus? status,
    String? partialText,
    String? finalText,
    String? error,
    int? elapsedSeconds,
    bool clearError = false,
    bool clearFinal = false,
  }) {
    return AsrState(
      status: status ?? this.status,
      partialText: partialText ?? this.partialText,
      finalText: clearFinal ? null : (finalText ?? this.finalText),
      error: clearError ? null : (error ?? this.error),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

class AsrController extends StateNotifier<AsrState> {
  AsrController() : super(const AsrState());

  final AudioRecorder _recorder = AudioRecorder();
  AsrService? _asrService;
  StreamSubscription<String>? _resultSubscription;
  Timer? _timer;
  String? _filePath;

  Future<bool> checkPermission() async {
    if (kIsWeb) {
      debugPrint('[ASR] Web 平台：跳过权限检查');
      return true;
    }
    
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;
      final result = await Permission.microphone.request();
      return result.isGranted;
    } catch (e) {
      debugPrint('[ASR] 权限检查失败：$e');
      return false;
    }
  }

  Future<void> init() async {
    if (!kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        _filePath = '${dir.path}/asr_recording.wav';
        debugPrint('[ASR] 录音文件路径：$_filePath');
      } catch (e) {
        debugPrint('[ASR] 获取临时目录失败：$e');
        _filePath = 'asr_recording.wav';
      }
    } else {
      debugPrint('[ASR] Web 平台：使用内存录音');
    }
  }

  Future<void> start() async {
    state = state.copyWith(
      status: AsrStatus.recording,
      partialText: '',
      clearFinal: true,
      clearError: true,
      elapsedSeconds: 0,
    );

    // Start recording
    if (kIsWeb) {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: 'asr_recording.wav',
      );
    } else {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _filePath!,
      );
    }

    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    // Connect ASR service
    try {
      final settings = await AiSettingsStore().load();
      final apiKey = settings.apiKey;
      if (apiKey.isEmpty) {
        state = state.copyWith(
          status: AsrStatus.error,
          error: '请先配置 API Key',
        );
        return;
      }

      final requestId = _generateUuid();
      _asrService = AsrService();

      _resultSubscription = _asrService!.results.listen(
        (text) {
          state = state.copyWith(partialText: text);
        },
        onError: (error) {
          state = state.copyWith(
            status: AsrStatus.error,
            error: '$error',
          );
        },
      );

      await _asrService!.connect(
        apiKey: apiKey,
        requestId: requestId,
      );
    } catch (e) {
      state = state.copyWith(
        status: AsrStatus.error,
        error: 'ASR 连接失败: $e',
      );
    }
  }

  Future<String?> stop() async {
    debugPrint('[ASR] 停止录音...');
    _timer?.cancel();
    debugPrint('[ASR] 计时器已停止');

    state = state.copyWith(status: AsrStatus.processing);
    debugPrint('[ASR] 状态：处理中');

    try {
      // Stop recording
      final path = await _recorder.stop();
      debugPrint('[ASR] 录音已停止，路径：$path');

      if (path != null && !kIsWeb) {
        try {
          // Web 平台不使用 File API
          if (!kIsWeb) {
            final file = File(path);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              debugPrint('[ASR] 音频文件大小：${bytes.length} bytes');
              await _asrService?.sendAudio(bytes);
              debugPrint('[ASR] 音频数据已发送');
            } else {
              debugPrint('[ASR] 警告：音频文件不存在');
            }
          }
        } catch (e) {
          debugPrint('[ASR] 发送音频失败：$e');
        }
      } else if (kIsWeb) {
        debugPrint('[ASR] Web ASR: 音频处理待实现');
        // Web 平台暂时不发送音频，仅显示提示
        state = state.copyWith(
          status: AsrStatus.done,
          finalText: 'Web 端录音功能待完善',
          error: null,
        );
        return 'Web 端录音功能待完善';
      }

      // 等待 ASR 结果（带超时，最多 3 秒）
      debugPrint('[ASR] 开始等待识别结果...');
      final stopwatch = Stopwatch()..start();
      while (stopwatch.elapsedMilliseconds < 3000) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        // 只要有部分结果就认为成功
        if (state.partialText.isNotEmpty || state.status == AsrStatus.done) {
          debugPrint('[ASR] 在 ${stopwatch.elapsedMilliseconds}ms 后收到结果');
          break;
        }
      }
      stopwatch.stop();
      debugPrint('[ASR] 等待结束，耗时：${stopwatch.elapsedMilliseconds}ms');

      // 关闭 ASR 服务
      await _asrService?.close();
      debugPrint('[ASR] ASR 服务已关闭');

      // 确保状态更新为 done
      final text = state.partialText.isNotEmpty 
          ? state.partialText 
          : (state.finalText ?? '');
      
      debugPrint('[ASR] 最终识别结果：" $text"');
      
      state = state.copyWith(
        status: AsrStatus.done, // 即使出错也设置为 done，避免黑屏
        finalText: text,
        error: text.isEmpty ? '未识别到内容' : null,
      );

      return text.isNotEmpty ? text : null;
    } catch (e) {
      debugPrint('[ASR] 停止录音异常：$e');
      state = state.copyWith(
        status: AsrStatus.done, // 即使出错也设置为 done，避免黑屏
        error: '录音处理失败：$e',
      );
      return null;
    }
  }

  Future<void> cancel() async {
    _timer?.cancel();
    await _resultSubscription?.cancel();
    await _recorder.stop();
    await _asrService?.close();
    state = const AsrState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _resultSubscription?.cancel();
    _recorder.dispose();
    _asrService?.dispose();
    super.dispose();
  }

  String _generateUuid() {
    final random = DateTime.now().microsecondsSinceEpoch;
    const chars = '0123456789abcdef';
    String hex(int seed, int length) {
      var value = seed;
      return List.generate(length, (_) {
        value = (value * 9301 + 49297) % 233280;
        return chars[value % 16];
      }).join();
    }

    return '${hex(random, 8)}-${hex(random + 1, 4)}-${hex(random + 2, 4)}-${hex(random + 3, 4)}-${hex(random + 4, 12)}';
  }
}

final asrControllerProvider =
    StateNotifierProvider<AsrController, AsrState>((ref) {
  return AsrController();
});
