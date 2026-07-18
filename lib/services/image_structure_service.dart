import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/structure_recognition_result.dart';
import '../models/structure_result.dart';
import '../utils/smiles_validator.dart';
import 'ai_settings_store.dart';
import 'decimer_client.dart';
import 'real_structure_service.dart';

/// 图像化学结构识别服务
///
/// 流程：图片 → DECIMER OCSR → SMILES → 完整度评分 → PubChem 相似搜索 → 候选列表
class ImageStructureService {
  ImageStructureService({
    DecimerClient? decimerClient,
    PubChemClient? pubchemClient,
    AiSettingsStore? settingsStore,
  })  : _decimer = decimerClient ?? DecimerClient(),
        _pubchem = pubchemClient ?? PubChemClient(),
        _settingsStore = settingsStore ?? AiSettingsStore();

  final DecimerClient _decimer;
  final PubChemClient _pubchem;
  final AiSettingsStore _settingsStore;

  Future<StructureRecognitionResult> recognizeFromImage(
    String dataUri,
  ) async {
    final settings = await _settingsStore.load();
    final endpoint = settings.ocsrEndpoint.trim();

    // Step 1: DECIMER OCSR
    String smiles;
    try {
      smiles = await _decimer.recognizeFromDataUri(
        dataUri: dataUri,
        endpoint: endpoint,
      );
    } on DecimerException catch (e) {
      return StructureRecognitionResult.invalid(message: e.message);
    } catch (e) {
      if (kIsWeb) {
        return StructureRecognitionResult.invalid(
          message: '图像识别请求失败：请确认已部署 Cloudflare Worker 代理。$e',
        );
      }
      return StructureRecognitionResult.invalid(
        message: '图像识别请求失败: $e',
      );
    }

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
}
