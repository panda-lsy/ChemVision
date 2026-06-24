import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;

import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/structure_recognition_result.dart';
import '../models/structure_result.dart';
import '../utils/smiles_validator.dart';
import 'ai_settings_store.dart';
import 'model_router.dart';
import 'real_structure_service.dart';
import 'vivo_aigc_client.dart';

class ImageStructureService {
  ImageStructureService({
    VivoAigcClient? client,
    ModelRouter? router,
    PubChemClient? pubchemClient,
    AiSettingsStore? settingsStore,
  })  : _client = client ?? VivoAigcClient(),
        _router = router ?? ModelRouter(),
        _pubchem = pubchemClient ?? PubChemClient(),
        _settingsStore = settingsStore ?? AiSettingsStore();

  final VivoAigcClient _client;
  final ModelRouter _router;
  final PubChemClient _pubchem;
  final AiSettingsStore _settingsStore;
  static const _promptPath = 'assets/prompts/image_to_smiles.txt';
  static Future<String>? _promptCache;

  Future<StructureRecognitionResult> recognizeFromImage(
    String dataUri,
  ) async {
    final settings = await _settingsStore.load();
    // 端侧模型启用时跳过云端 API Key 校验
    final useLocal = await _isLocalModelEnabled();
    if (!useLocal && !kIsWeb && settings.apiKey.trim().isEmpty) {
      return StructureRecognitionResult.invalid(
        message: '请先在设置中配置 API Key',
      );
    }

    // Step 1: LLM recognition
    final prompt = await _loadPrompt();
    String response;
    try {
      response = await _router.generateMultimodal(
        apiKey: settings.apiKey,
        model: settings.textModel,
        prompt: prompt,
        imageBase64: dataUri,
        baseUrl: settings.baseUrl.isEmpty
            ? AppConfig.vivoAigcBaseUrl
            : settings.baseUrl,
      );
    } catch (e) {
      return StructureRecognitionResult.invalid(
        message: '图像识别请求失败: $e',
      );
    }

    final smiles = _parseSmilesFromResponse(response);
    if (smiles.isEmpty) {
      return StructureRecognitionResult.invalid(
        message: '未能从图像中识别出化学结构，请尝试更清晰的图片',
      );
    }

    // Step 2: Completeness scoring
    final report = SmilesValidator.validate(smiles);

    // Step 3: Similarity search if score is above threshold
    List<StructureCandidate> candidates = const [];
    if (report.completeness > 0.3) {
      try {
        candidates = await _pubchem.querySimilar(smiles);
      } catch (_) {
        // Similarity search failure is non-fatal
      }
    }

    return StructureRecognitionResult(
      recognizedSmiles: smiles,
      completenessScore: report.completeness,
      candidates: candidates,
      isValid: report.isValid,
    );
  }

  /// Convert a selected candidate into a StructureResult for ResultPage.
  StructureResult resolveToStructure(StructureCandidate candidate) {
    return StructureResult(
      smiles: candidate.smiles,
      resolvedName: candidate.resolvedName,
      englishName: candidate.englishName,
      chineseName: candidate.chineseName,
      molecularFormula: candidate.molecularFormula,
      molecularWeight: candidate.molecularWeight,
      isValid: true,
      confidence: candidate.confidence,
    );
  }

  Future<bool> _isLocalModelEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('bluelm_use_local') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<String> _loadPrompt() async {
    _promptCache ??= rootBundle.loadString(_promptPath);
    return _promptCache!;
  }

  static String _parseSmilesFromResponse(String text) {
    var cleaned = text.trim();
    // Strip code fences
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      final filtered = lines.where((l) => !l.startsWith('```')).join('\n');
      cleaned = filtered.trim();
    }
    // Strip leading label like "SMILES:"
    if (cleaned.toLowerCase().startsWith('smiles:')) {
      cleaned = cleaned.substring(7).trim();
    }
    // Take first line only
    final newlineIdx = cleaned.indexOf('\n');
    if (newlineIdx > 0) {
      cleaned = cleaned.substring(0, newlineIdx).trim();
    }
    if (cleaned.toUpperCase() == 'INVALID') return '';
    return cleaned;
  }
}
