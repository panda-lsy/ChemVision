import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chemvision/providers/asr_provider.dart';
import 'package:chemvision/services/ai_settings_store.dart';

class FakeSpeechBackend implements SpeechRecognitionBackend {
  bool available = true;
  bool failListen = false;
  int listenCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  late void Function(String) status;
  late void Function(String) error;
  late void Function(String, bool) result;

  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) async {
    status = onStatus;
    error = onError;
    return available;
  }

  @override
  Future<void> listen({required void Function(String, bool) onResult}) async {
    listenCalls++;
    result = onResult;
    if (failListen) throw StateError('fake platform failure');
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeSpeechBackend backend;
  late AsrController controller;

  setUp(() {
    backend = FakeSpeechBackend();
    controller = AsrController(
      backend: backend,
      finalResultTimeout: const Duration(milliseconds: 30),
      maxDuration: const Duration(seconds: 10),
    );
  });

  tearDown(() => controller.dispose());

  test('服务不可用时不开始录音并显示原因', () async {
    backend.available = false;
    expect(await controller.start(), isFalse);
    expect(backend.listenCalls, 0);
    expect(controller.state.status, AsrStatus.error);
    expect(controller.state.error, contains('语音识别不可用'));
  });

  test('识别结果与自动结束正确传回，不依赖旧厂商密钥', () async {
    expect(await controller.start(), isTrue);
    expect(controller.state.status, AsrStatus.recording);
    backend.result('苯甲', false);
    expect(controller.state.partialText, '苯甲');
    backend.result('苯甲酸', true);
    expect(controller.state.status, AsrStatus.done);
    expect(controller.state.finalText, '苯甲酸');
  });

  test('手动完成会等待最后结果，而不是提前返回部分结果', () async {
    await controller.start();
    backend.result('甲', false);
    final result = controller.stop();
    expect(controller.state.status, AsrStatus.processing);
    backend.result('甲醇', true);
    expect(await result, '甲醇');
    expect(backend.stopCalls, 1);
  });

  test('系统停止监听后仍等待迟到的最终结果', () async {
    await controller.start();
    backend.status('notListening');
    expect(controller.state.status, AsrStatus.processing);
    backend.result('乙醇', true);
    expect(controller.state.finalText, '乙醇');
  });

  test('空结果超时会报告失败，不把占位文字作为识别结果', () async {
    await controller.start();
    expect(await controller.stop(), isNull);
    expect(controller.state.status, AsrStatus.error);
    expect(controller.state.finalText, isNull);
  });

  test('取消后忽略迟到的识别回调', () async {
    await controller.start();
    final oldCallback = backend.result;
    await controller.cancel();
    oldCallback('不应返回', true);
    expect(controller.state.status, AsrStatus.idle);
    expect(controller.state.finalText, isNull);
    expect(backend.cancelCalls, 1);
  });

  test('服务错误不会被误报为识别成功', () async {
    await controller.start();
    backend.error('error_network');
    expect(controller.state.status, AsrStatus.error);
    expect(controller.state.error, contains('网络'));
    expect(controller.state.finalText, isNull);
  });

  test('启动监听失败时清理服务并显示错误', () async {
    backend.failListen = true;
    expect(await controller.start(), isFalse);
    expect(controller.state.status, AsrStatus.error);
    expect(backend.cancelCalls, 1);
  });

  test('保存其他设置时不删除历史语音密钥', () async {
    SharedPreferences.setMockInitialValues({'asr_api_key': 'old-fixture'});
    final store = AiSettingsStore();
    final settings = await store.load();
    await store.save(settings);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('asr_api_key'), 'old-fixture');
  });
}
