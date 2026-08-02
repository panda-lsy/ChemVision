/// Agent 工具注册表工厂 + 编排器 Provider — 依赖注入
///
/// 在 main.dart 初始化后,通过 Riverpod Provider 注入:
/// - ToolRegistry: OCSR/PubChem/知识库/LLM 工具
/// - AgentOrchestrator: 编排器(含 LearningRecordService 闭环)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai_settings_store.dart';
import '../image_structure_service.dart';
import '../model_router.dart';
import '../real_structure_service.dart';
import '../../providers/learning_profile_provider.dart';
import 'agent_orchestrator.dart';
import 'agent_tool.dart';
import 'agent_tools.dart';
import 'task_planner.dart';

/// 工具注册表 Provider — 由 main.dart override 注入(或用默认实例)
final agentToolRegistryProvider = Provider<ToolRegistry>((ref) {
  return ToolRegistryFactory.createDefault();
});

/// Agent 编排器 Provider
///
/// 注入:
/// - ToolRegistry: 工具集
/// - LearningRecordService: 学习记录服务(形成"扫描→记录→画像→诊断"闭环)
/// - TaskPlanner: 任务规划器
final agentOrchestratorProvider = Provider<AgentOrchestrator>((ref) {
  final registry = ref.watch(agentToolRegistryProvider);
  final recordService = ref.watch(learningRecordServiceProvider);
  return AgentOrchestrator(
    registry: registry,
    recordService: recordService,
    planner: const TaskPlanner(),
  );
}, dependencies: [
  agentToolRegistryProvider,
  learningRecordServiceProvider,
]);

/// 工具注册表工厂
class ToolRegistryFactory {
  /// 构造包含全部内置工具的注册表
  static ToolRegistry createDefault({
    ImageStructureService? imageService,
    NameToStructureService? structureService,
    AiSettingsStore? settingsStore,
    ModelRouter? router,
  }) {
    return ToolRegistry([
      OcsrTool(imageService ?? ImageStructureService()),
      PubChemTool(structureService ?? NameToStructureService()),
      const KnowledgeBaseTool(),
      LlmTool(
        settingsStore: settingsStore ?? AiSettingsStore(),
        router: router ?? ModelRouter(),
      ),
    ]);
  }
}
