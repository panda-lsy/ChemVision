import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chemvision/services/ai_settings_store.dart';
import 'package:chemvision/services/model_router.dart';
import 'package:chemvision/services/openai_compatible_client.dart';
import 'package:chemvision/services/real_structure_service.dart';

class _SettingsStore extends AiSettingsStore {
  _SettingsStore(this.settings);
  final AiSettings settings;

  @override
  Future<AiSettings> load() async => settings;
}

class _ApiClient extends OpenAiCompatibleClient {
  Map<String, String>? lastTextRequest;
  Map<String, String>? lastImageRequest;

  @override
  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
    lastTextRequest = {
      'apiKey': apiKey,
      'model': model,
      'prompt': prompt,
      'baseUrl': baseUrl,
    };
    return '云端测试回复';
  }

  @override
  Future<String> generateMultimodal({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
    required String imageBase64,
  }) async {
    lastImageRequest = {
      'apiKey': apiKey,
      'model': model,
      'prompt': prompt,
      'baseUrl': baseUrl,
      'imageBase64': imageBase64,
    };
    return '图像测试回复';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // This is the preference key from the former on-device mode. It may remain
  // on existing devices; routing must ignore it without deleting user data.
  final legacyLocalModeKey = ['blue', 'lm', 'use', 'local'].join('_');

  setUp(
    () => SharedPreferences.setMockInitialValues({legacyLocalModeKey: true}),
  );

  test('旧端侧开关为真时，自带 API 仍收到完整文本请求', () async {
    const settings = AiSettings(
      apiKey: '',
      textModel: 'fixture-model',
      baseUrl: 'http://127.0.0.1:8787/v1',
      ocsrEndpoint: '',
      useChemVisionAi: false,
    );
    final client = _ApiClient();
    final router = ModelRouter(
      apiClient: client,
      settingsStore: _SettingsStore(settings),
    );
    final result = await router.generateText(
      apiKey: settings.apiKey,
      model: settings.textModel,
      prompt: '测试问题',
      baseUrl: settings.baseUrl,
    );
    expect(result, '云端测试回复');
    expect(client.lastTextRequest, {
      'apiKey': '',
      'model': 'fixture-model',
      'prompt': '测试问题',
      'baseUrl': 'http://127.0.0.1:8787/v1',
    });
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(legacyLocalModeKey), isTrue);
  });

  test('旧端侧开关不能绕过自带 API 的模型配置检查', () async {
    final service = NameToStructureService(
      settingsStore: _SettingsStore(
        const AiSettings(
          apiKey: '',
          textModel: '',
          baseUrl: 'http://127.0.0.1:8787/v1',
          ocsrEndpoint: '',
          useChemVisionAi: false,
        ),
      ),
    );
    final result = await service.generateStructure('苯甲酸');
    expect(result.isValid, isFalse);
    expect(result.message, '请先在设置中配置模型');
  });

  test('选择托管 AI 时不会错误调用自带 API', () async {
    final client = _ApiClient();
    final router = ModelRouter(
      apiClient: client,
      settingsStore: _SettingsStore(
        const AiSettings(
          apiKey: 'fixture-key',
          textModel: 'fixture-model',
          baseUrl: 'https://example.invalid/v1',
          ocsrEndpoint: '',
          useChemVisionAi: true,
        ),
      ),
    );
    await expectLater(
      router.generateText(
        apiKey: 'fixture-key',
        model: 'fixture-model',
        prompt: '测试问题',
        baseUrl: 'https://example.invalid/v1',
      ),
      throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('登录')),
      ),
    );
    expect(client.lastTextRequest, isNull);
  });

  test('自带 API 多模态路径保留图片和其他参数', () async {
    const settings = AiSettings(
      apiKey: 'fixture-key',
      textModel: 'fixture-model',
      baseUrl: 'https://example.invalid/v1',
      ocsrEndpoint: '',
      useChemVisionAi: false,
    );
    final client = _ApiClient();
    final router = ModelRouter(
      apiClient: client,
      settingsStore: _SettingsStore(settings),
    );
    final result = await router.generateMultimodal(
      apiKey: settings.apiKey,
      model: settings.textModel,
      prompt: '测试图像',
      baseUrl: settings.baseUrl,
      imageBase64: 'data:image/png;base64,AA==',
    );
    expect(result, '图像测试回复');
    expect(
      client.lastImageRequest!['imageBase64'],
      'data:image/png;base64,AA==',
    );
    expect(client.lastImageRequest!['baseUrl'], settings.baseUrl);
  });
}
