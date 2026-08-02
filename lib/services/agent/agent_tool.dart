/// Agent 工具层 — 统一抽象各能力(OCSR/PubChem/知识库/LLM)为可调用工具
///
/// 对应赛题 Agent 应用闭环中的"4. 能力调用":
/// 工具是 Agent 的"手",负责与外部世界交互、获取结构化数据。
/// 编排器通过 ToolRegistry 按名称查找并调用工具,实现解耦。
import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 工具调用结果
///
/// [ok] 为 true 时 [data] 可用;为 false 时 [error] 描述失败原因。
/// [data] 为结构化数据,供后续步骤或 LLM 使用。
class ToolResult {
  const ToolResult({
    required this.ok,
    this.data = const {},
    this.error,
    this.summary,
  });

  final bool ok;
  final Map<String, dynamic> data;
  final String? error;

  /// 人类可读摘要(写入 AgentStep.result 供 UI 展示)
  final String? summary;

  factory ToolResult.success(Map<String, dynamic> data, {String? summary}) {
    return ToolResult(ok: true, data: data, summary: summary);
  }

  factory ToolResult.failure(String error) {
    return ToolResult(ok: false, error: error, summary: '失败: $error');
  }

  @override
  String toString() => ok ? 'ToolResult($summary)' : 'ToolResult.error($error)';
}

/// Agent 工具抽象
///
/// 每个工具实现 [invoke],接收参数 Map,返回 [ToolResult]。
/// 工具应是幂等且无状态的(状态由 AgentContext 持有)。
abstract class AgentTool {
  const AgentTool(this.name, this.description);

  /// 工具唯一名称,如 'ocsr' 'pubchem' 'knowledge' 'llm'
  final String name;

  /// 工具描述(供 LLM 或规划器理解用途)
  final String description;

  /// 执行工具
  ///
  /// [params] 由编排器根据 AgentStep.toolInput 注入,工具自行解析。
  Future<ToolResult> invoke(Map<String, dynamic> params);

  /// 将结果数据序列化为紧凑 JSON(用于写入 LLM 上下文)
  static String encodeForLlm(Map<String, dynamic> data) {
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}

/// 工具注册表 — 按 name 查找工具
class ToolRegistry {
  ToolRegistry(List<AgentTool> tools)
      : _map = {for (final t in tools) t.name: t};

  final Map<String, AgentTool> _map;

  AgentTool? get(String name) => _map[name];

  List<AgentTool> get all => _map.values.toList(growable: false);

  /// 调用工具(找不到返回失败结果)
  Future<ToolResult> invoke(String name, Map<String, dynamic> params) async {
    final tool = _map[name];
    if (tool == null) {
      return ToolResult.failure('未注册工具: $name');
    }
    try {
      final result = await tool.invoke(params);
      if (kDebugMode) {
        debugPrint('[AgentTool] $name => ${result.ok ? "ok" : "fail"}');
      }
      return result;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AgentTool] $name 异常: $e\n$st');
      }
      return ToolResult.failure('工具 $name 执行异常: $e');
    }
  }
}
