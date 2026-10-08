import 'package:shared_preferences/shared_preferences.dart';

import 'bluelm_service.dart';
import 'ai_settings_store.dart';
import 'openai_compatible_client.dart';
import 'supabase_auth_service.dart';

/// 模型路由器
///
/// 根据设置自动选择云端 API 或端侧模型。
class ModelRouter {
  ModelRouter({
    OpenAiCompatibleClient? apiClient,
    BlueLmService? localService,
    AiSettingsStore? settingsStore,
  })  : _api = apiClient ?? OpenAiCompatibleClient(),
        _local = localService ?? BlueLmService(),
        _aiSettings = settingsStore ?? AiSettingsStore();

  final OpenAiCompatibleClient _api;
  final BlueLmService _local;
  final AiSettingsStore _aiSettings;

  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
    final settings = await _loadSettings();
    final useLocal = settings['useLocal'] == true;

    if (useLocal) {
      try {
        await _ensureLocalInit(settings);
        return await _local.generate(prompt);
      } catch (_) {
        // 端侧失败，回退云端
      }
    }

    final aiSettings = await _aiSettings.load();
    if (aiSettings.useChemVisionAi) {
      return SupabaseAuthService.instance.generateChemVisionAi(
        prompt: prompt,
      );
    }

    return await _api.generateText(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
    );
  }

  Future<String> generateMultimodal({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
    required String imageBase64,
  }) async {
    final aiSettings = await _aiSettings.load();
    if (aiSettings.useChemVisionAi) {
      return SupabaseAuthService.instance.generateChemVisionAi(
        prompt: prompt,
        imageDataUri: imageBase64,
      );
    }

    return await _api.generateMultimodal(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      imageBase64: imageBase64,
      baseUrl: baseUrl,
    );
  }

  Future<void> _ensureLocalInit(
    Map<String, dynamic> settings,
  ) async {
    if (!_local.isInitialized) {
      await _local.init(
        modelPath: settings['modelPath'] ?? '/sdcard/1225/1.7.0.4_1225_mtk9500',
      );
    }
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'useLocal': prefs.getBool('bluelm_use_local') ?? false,
        'modelPath': prefs.getString('bluelm_model_path') ??
            '/sdcard/1225/1.7.0.4_1225_mtk9500',
      };
    } catch (_) {
      return {'useLocal': false};
    }
  }
}
