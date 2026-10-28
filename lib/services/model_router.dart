import 'ai_settings_store.dart';
import 'openai_compatible_client.dart';
import 'supabase_auth_service.dart';

/// 模型路由器
///
/// 根据设置选择托管 AI 或 OpenAI 兼容 API。
class ModelRouter {
  ModelRouter({
    OpenAiCompatibleClient? apiClient,
    AiSettingsStore? settingsStore,
  })  : _api = apiClient ?? OpenAiCompatibleClient(),
        _aiSettings = settingsStore ?? AiSettingsStore();

  final OpenAiCompatibleClient _api;
  final AiSettingsStore _aiSettings;

  Future<String> generateText({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
  }) async {
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

}
