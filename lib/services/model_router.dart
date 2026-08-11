import 'package:shared_preferences/shared_preferences.dart';

import 'bluelm_service.dart';
import 'vivo_aigc_client.dart';

/// 模型路由器
///
/// 根据设置自动选择云端 API 或端侧模型。
class ModelRouter {
  ModelRouter({
    VivoAigcClient? cloudClient,
    BlueLmService? localService,
  })  : _cloud = cloudClient ?? VivoAigcClient(),
        _local = localService ?? BlueLmService();

  final VivoAigcClient _cloud;
  final BlueLmService _local;

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

    // 云端
    if (apiKey.isNotEmpty) {
      return await _cloud.generateText(
        apiKey: apiKey, model: model, prompt: prompt, baseUrl: baseUrl,
      );
    }

    // 云端无 Key，强制尝试端侧
    if (!useLocal) {
      try {
        await _ensureLocalInit(settings);
        return await _local.generate(prompt);
      } catch (_) {}
    }

    return await _cloud.generateText(
      apiKey: apiKey, model: model, prompt: prompt, baseUrl: baseUrl,
    );
  }

  Future<String> generateMultimodal({
    required String apiKey,
    required String model,
    required String prompt,
    required String baseUrl,
    required String imageBase64,
  }) async {
    return await _cloud.generateMultimodal(
      apiKey: apiKey, model: model, prompt: prompt,
      imageBase64: imageBase64, baseUrl: baseUrl,
    );
  }

  Future<void> _ensureLocalInit(Map<String, dynamic> settings,
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
