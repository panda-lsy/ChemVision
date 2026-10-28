import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as speech;

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
  }) => AsrState(
    status: status ?? this.status,
    partialText: partialText ?? this.partialText,
    finalText: finalText ?? this.finalText,
    error: error ?? this.error,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
  );
}

/// Platform recognition can use a system or browser service and may be online.
/// The interface keeps session handling testable without accessing a microphone.
abstract interface class SpeechRecognitionBackend {
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  });
  Future<void> listen({required void Function(String, bool) onResult});
  Future<void> stop();
  Future<void> cancel();
}

class SystemSpeechRecognitionBackend implements SpeechRecognitionBackend {
  SystemSpeechRecognitionBackend._();
  static final SystemSpeechRecognitionBackend instance =
      SystemSpeechRecognitionBackend._();

  final speech.SpeechToText _speech = speech.SpeechToText();
  void Function(String)? _onStatus;
  void Function(String)? _onError;

  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) {
    _onStatus = onStatus;
    _onError = onError;
    return _speech.initialize(
      onStatus: (status) => _onStatus?.call(status),
      onError: (error) => _onError?.call(error.errorMsg),
      options: [speech.SpeechToText.androidNoBluetooth],
    );
  }

  @override
  Future<void> listen({required void Function(String, bool) onResult}) async {
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: speech.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: speech.ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

class AsrController extends StateNotifier<AsrState> {
  AsrController({
    SpeechRecognitionBackend? backend,
    this.finalResultTimeout = const Duration(seconds: 4),
    this.maxDuration = const Duration(seconds: 30),
  }) : _backend = backend ?? SystemSpeechRecognitionBackend.instance,
       super(const AsrState());

  final SpeechRecognitionBackend _backend;
  final Duration finalResultTimeout;
  final Duration maxDuration;
  bool _initialized = false;
  bool _active = false;
  bool _starting = false;
  int _generation = 0;
  Timer? _timer;
  Timer? _maxTimer;
  Timer? _finalTimer;
  Completer<String?>? _completion;

  Future<bool> start() async {
    if (_active || _starting) return false;
    _starting = true;
    final generation = ++_generation;
    state = const AsrState(status: AsrStatus.processing);
    try {
      _initialized = await _backend.initialize(
        onStatus: _handleStatus,
        onError: _handleError,
      );
      if (!mounted || generation != _generation) return false;
      if (!_initialized) {
        state = const AsrState(
          status: AsrStatus.error,
          error: '语音识别不可用，请检查麦克风权限和系统或浏览器的语音服务。',
        );
        return false;
      }
      _completion = Completer<String?>();
      _active = true;
      state = const AsrState(status: AsrStatus.recording);
      await _backend.listen(
        onResult: (text, isFinal) {
          if (!mounted || !_active || generation != _generation) return;
          state = state.copyWith(partialText: text);
          if (isFinal) _finish(text);
        },
      );
      if (!mounted || generation != _generation) return false;
      if (!_active) return state.status == AsrStatus.done;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _active) {
          state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
        }
      });
      // A backend may return without issuing a start/end event; never leave
      // the microphone UI running indefinitely in that case.
      _maxTimer = Timer(maxDuration, () => unawaited(stop()));
      return true;
    } catch (_) {
      if (mounted && generation == _generation) {
        _fail('无法启动语音识别，请检查系统语音服务和麦克风权限。');
      }
      if (_initialized) {
        try {
          await _backend.cancel().timeout(finalResultTimeout);
        } catch (_) {}
      }
      return false;
    } finally {
      if (generation == _generation) _starting = false;
    }
  }

  void _handleStatus(String status) {
    if (!mounted || !_active) return;
    if (status == 'notListening') {
      _timer?.cancel();
      state = state.copyWith(status: AsrStatus.processing);
      _scheduleFinalFallback();
    } else if (status == 'done') {
      _finish(state.partialText);
    }
  }

  void _handleError(String error) {
    if (!mounted || !_active) return;
    final message = switch (error) {
      'error_no_match' || 'error_speech_timeout' => '没有听清，请再试一次。',
      'error_network' || 'error_network_timeout' => '语音服务网络不可用，请检查网络后重试。',
      'error_permission' ||
      'error_insufficient_permissions' => '请在设备或浏览器设置中允许麦克风和语音识别权限。',
      _ => '语音识别暂不可用，请检查设备或浏览器的语音服务。',
    };
    _fail(message);
    unawaited(_backend.cancel().catchError((_) {}));
  }

  void _scheduleFinalFallback() {
    _finalTimer?.cancel();
    _finalTimer = Timer(finalResultTimeout, () {
      if (mounted && _active) _finish(state.partialText);
    });
  }

  Future<String?> stop() async {
    if (!_active) return state.finalText;
    final completion = _completion!;
    state = state.copyWith(status: AsrStatus.processing);
    _timer?.cancel();
    _maxTimer?.cancel();
    _scheduleFinalFallback();
    try {
      await _backend.stop().timeout(finalResultTimeout);
    } catch (_) {
      if (mounted && _active) _fail('结束语音识别失败，请重试。');
    }
    return completion.future;
  }

  void _finish(String text) {
    if (!_active) return;
    final result = text.trim();
    if (result.isEmpty) {
      _fail('没有识别到语音，请再试一次。');
      return;
    }
    _active = false;
    _cancelTimers();
    state = state.copyWith(status: AsrStatus.done, finalText: result);
    if (!(_completion?.isCompleted ?? true)) _completion!.complete(result);
  }

  void _fail(String message) {
    _active = false;
    _cancelTimers();
    if (mounted) state = AsrState(status: AsrStatus.error, error: message);
    if (!(_completion?.isCompleted ?? true)) _completion!.complete(null);
  }

  void _cancelTimers() {
    _timer?.cancel();
    _maxTimer?.cancel();
    _finalTimer?.cancel();
  }

  Future<void> cancel() async {
    ++_generation;
    _active = false;
    _starting = false;
    _cancelTimers();
    if (!(_completion?.isCompleted ?? true)) _completion!.complete(null);
    if (mounted) state = const AsrState();
    if (_initialized) {
      try {
        await _backend.cancel().timeout(finalResultTimeout);
      } catch (_) {
        // Closing the sheet should remain safe when a platform service fails.
      }
    }
  }

  @override
  void dispose() {
    ++_generation;
    _active = false;
    _cancelTimers();
    if (!(_completion?.isCompleted ?? true)) _completion!.complete(null);
    if (_initialized) unawaited(_backend.cancel().catchError((_) {}));
    super.dispose();
  }
}

final asrControllerProvider = StateNotifierProvider<AsrController, AsrState>(
  (ref) => AsrController(),
);
