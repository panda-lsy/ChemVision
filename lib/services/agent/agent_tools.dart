/// Agent 具体工具实现 — 封装 OCSR/PubChem/知识库/LLM 为统一接口
///
/// 工具是 Agent 与外部世界交互的"手":
/// - OcsrTool: 图片 → SMILES(化学结构识别)
/// - PubChemTool: SMILES → 化合物名/分子式/分子量(信息查询)
/// - KnowledgeBaseTool: SMILES/名称 → 教材知识点(知识增强)
/// - LlmTool: 提示词 → 文本生成(讲解/诊断/规划)
///
/// 对应赛题"能力调用"环节,工具结果经编排器汇总后交付给用户。
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../ai_settings_store.dart';
import '../chemical_knowledge_base.dart';
import '../image_structure_service.dart';
import '../model_router.dart';
import '../real_structure_service.dart';
import 'agent_tool.dart';

/// OCSR 工具 — 图片 → SMILES
///
/// 参数:
///   dataUri (String, 必填) — data:image/...;base64,... 格式
/// 返回:
///   smiles, completeness, isValid, candidates[]
class OcsrTool extends AgentTool {
  OcsrTool(this._service) : super('ocsr', '化学结构图像识别:图片 → SMILES');

  final ImageStructureService _service;

  @override
  Future<ToolResult> invoke(Map<String, dynamic> params) async {
    final dataUri = params['dataUri']?.toString() ?? '';
    if (dataUri.isEmpty) {
      return ToolResult.failure('缺少图片数据 dataUri');
    }
    final result = await _service.recognizeFromImage(dataUri);
    if (!result.isValid) {
      return ToolResult.failure(
        result.errorMessage ?? '未能从图像识别化学结构',
      );
    }
    return ToolResult.success({
      'smiles': result.recognizedSmiles,
      'completeness': result.completenessScore,
      'isValid': result.isValid,
      'candidates': result.candidates
          .map((c) => {
                'smiles': c.smiles,
                'name': c.resolvedName ?? '',
                'englishName': c.englishName ?? '',
                'chineseName': c.chineseName ?? '',
                'formula': c.molecularFormula,
                'weight': c.molecularWeight,
                'confidence': c.confidence,
              })
          .toList(),
    }, summary: '识别 SMILES: ${result.recognizedSmiles}');
  }
}

/// PubChem 查询工具 — SMILES → 化合物信息
///
/// 参数:
///   smiles (String, 必填)
/// 返回:
///   canonicalSmiles, name, englishName, chineseName, formula, weight
class PubChemTool extends AgentTool {
  PubChemTool(this._service)
      : super('pubchem', '化合物信息查询:SMILES → 名称/分子式/分子量');

  final NameToStructureService _service;

  @override
  Future<ToolResult> invoke(Map<String, dynamic> params) async {
    final smiles = params['smiles']?.toString() ?? '';
    if (smiles.isEmpty) {
      return ToolResult.failure('缺少 SMILES 参数');
    }
    final result = await _service.reverseResolveName(smiles);
    if (!result.isValid) {
      return ToolResult.failure(result.message ?? 'PubChem 查询失败');
    }
    return ToolResult.success({
      'canonicalSmiles': result.smiles,
      'name': result.resolvedName ?? '',
      'englishName': result.englishName ?? '',
      'chineseName': result.chineseName ?? '',
      'formula': result.molecularFormula,
      'weight': result.molecularWeight,
      'confidence': result.confidence,
    }, summary: '化合物: ${result.chineseName ?? result.englishName ?? result.resolvedName ?? smiles}');
  }
}

/// 知识库工具 — SMILES/名称 → 教材知识点
///
/// 参数:
///   smiles (String, 可选) — 按 SMILES 匹配(基于官能团)
///   name (String, 可选) — 按名称匹配(基于关键词)
///   kpId (String, 可选) — 直接按 ID 查询
/// 返回:
///   points[]: id, name, category, stage, chapter, description, difficulty
class KnowledgeBaseTool extends AgentTool {
  const KnowledgeBaseTool()
      : super('knowledge', '化学知识图谱:SMILES/名称 → 教材知识点');

  @override
  Future<ToolResult> invoke(Map<String, dynamic> params) async {
    final smiles = params['smiles']?.toString() ?? '';
    final name = params['name']?.toString() ?? '';
    final kpId = params['kpId']?.toString() ?? '';
    final kpIds = params['kpIds'];

    // 0. 按 ID 列表批量查询(用于学情诊断的薄弱点详情)
    if (kpIds is List && kpIds.isNotEmpty) {
      final points = <Map<String, dynamic>>[];
      for (final id in kpIds) {
        final kp = ChemicalKnowledgeBase.pointMap[id.toString()];
        if (kp != null) points.add(_serializeKp(kp));
      }
      if (points.isEmpty) {
        return ToolResult.success({'points': const []},
            summary: '薄弱点无对应预置知识点');
      }
      return ToolResult.success({
        'points': points,
      }, summary: '加载 ${points.length} 个薄弱知识点');
    }

    // 1. 按 ID 直接查询
    if (kpId.isNotEmpty) {
      final kp = ChemicalKnowledgeBase.pointMap[kpId];
      if (kp == null) {
        return ToolResult.failure('未找到知识点: $kpId');
      }
      return ToolResult.success({
        'points': [_serializeKp(kp)],
        'related': kp.relatedPointIds
            .map((id) => ChemicalKnowledgeBase.pointMap[id])
            .where((k) => k != null)
            .map((k) => _serializeKp(k!))
            .toList(),
      }, summary: '知识点: ${kp.name} (${kp.chapter})');
    }

    // 2. 按 SMILES 匹配
    if (smiles.isNotEmpty) {
      final matched = ChemicalKnowledgeBase.matchBySmiles(smiles);
      if (matched.isEmpty) {
        return ToolResult.success({'points': const []},
            summary: 'SMILES 未匹配到预置知识点');
      }
      return ToolResult.success({
        'points': matched.map(_serializeKp).toList(),
      }, summary: '匹配知识点: ${matched.map((k) => k.name).join(", ")}');
    }

    // 3. 按名称匹配
    if (name.isNotEmpty) {
      final matched = ChemicalKnowledgeBase.matchByName(name);
      if (matched.isEmpty) {
        return ToolResult.success({'points': const []},
            summary: '名称未匹配到预置知识点');
      }
      return ToolResult.success({
        'points': matched.map(_serializeKp).toList(),
      }, summary: '匹配知识点: ${matched.map((k) => k.name).join(", ")}');
    }

    return ToolResult.failure('请提供 smiles / name / kpId / kpIds 之一');
  }

  Map<String, dynamic> _serializeKp(kp) => {
        'id': kp.id,
        'name': kp.name,
        'category': kp.category,
        'stage': kp.stage,
        'chapter': kp.chapter,
        'description': kp.description,
        'difficulty': kp.difficulty,
        'relatedPointIds': kp.relatedPointIds,
      };
}

/// LLM 工具 — 提示词 → 文本生成
///
/// 参数:
///   prompt (String, 必填) — 完整提示词(已注入上下文)
///   templateAsset (String, 可选) — assets/prompts/ 下的模板文件名,内含 {{...}} 占位符
///   variables (Map, 可选) — 模板占位符替换值
///   maxTokens (int, 可选, 默认 1500)
/// 返回:
///   text (String)
class LlmTool extends AgentTool {
  LlmTool({
    required AiSettingsStore settingsStore,
    required ModelRouter router,
  })  : _settingsStore = settingsStore,
        _router = router,
        super('llm', '大模型文本生成:提示词 → 讲解/诊断/规划');

  final AiSettingsStore _settingsStore;
  final ModelRouter _router;

  @override
  Future<ToolResult> invoke(Map<String, dynamic> params) async {
    var prompt = params['prompt']?.toString() ?? '';
    final templateAsset = params['templateAsset']?.toString() ?? '';

    // 将除控制字段外的所有参数转为模板变量(编排器已通过 @slot.field 注入数据)
    final variables = <String, String>{};
    for (final entry in params.entries) {
      if (entry.key == 'templateAsset' ||
          entry.key == 'maxTokens' ||
          entry.key == 'prompt') {
        continue;
      }
      variables[entry.key] = _stringify(entry.value);
    }

    // 加载提示词模板并替换变量
    if (templateAsset.isNotEmpty) {
      try {
        final template = await rootBundle
            .loadString('assets/prompts/$templateAsset');
        prompt = _applyTemplate(template, variables);
      } catch (e) {
        return ToolResult.failure('加载提示词模板失败: $templateAsset ($e)');
      }
    }

    if (prompt.trim().isEmpty) {
      return ToolResult.failure('提示词为空');
    }

    final settings = await _settingsStore.load();
    final apiKey = settings.apiKey.trim();
    final model = settings.textModel.trim();
    final baseUrl = settings.baseUrl;

    // 端侧模型可无 Key,ModelRouter 内部处理
    if (apiKey.isEmpty && model.isEmpty) {
      return ToolResult.failure('请先在设置中配置 AI 模型');
    }

    final text = await _router.generateText(
      apiKey: apiKey,
      model: model,
      prompt: prompt,
      baseUrl: baseUrl,
    );

    if (text.trim().isEmpty) {
      return ToolResult.failure('模型未返回内容');
    }

    return ToolResult.success({
      'text': text.trim(),
    }, summary: '生成文本 ${text.trim().length} 字符');
  }

  /// 简易模板替换:{{key}} → value
  String _applyTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }

  /// 将任意值转为字符串(List/Map 转 JSON)
  String _stringify(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num || value is bool) return value.toString();
    if (value is List || value is Map) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return value.toString();
  }
}
