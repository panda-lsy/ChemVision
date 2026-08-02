/// Agent Provider — Riverpod 状态管理集成
///
/// 暴露编排器能力给 UI 层:
/// - [runTask] 启动任务,实时推送进度
/// - [cancelTask] 取消当前任务
/// - [AgentControllerState] 持有当前任务、历史、错误状态
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_task.dart';
import '../services/agent/agent_orchestrator.dart';
import '../services/agent/tool_registry_factory.dart';
import 'learning_profile_provider.dart';

// agentOrchestratorProvider 已在 tool_registry_factory.dart 中定义(含 LearningRecordService 注入)

/// Agent 控制器状态
class AgentControllerState {
  const AgentControllerState({
    this.currentTask,
    this.history = const [],
    this.error,
    this.isRunning = false,
  });

  /// 当前执行中的任务(null 表示空闲)
  final AgentTask? currentTask;

  /// 历史完成任务(最近 50 条)
  final List<AgentTask> history;

  /// 错误信息(运行失败时)
  final String? error;

  /// 是否正在执行
  final bool isRunning;

  AgentControllerState copyWith({
    AgentTask? currentTask,
    List<AgentTask>? history,
    String? error,
    bool? isRunning,
    bool clearError = false,
  }) {
    return AgentControllerState(
      currentTask: currentTask ?? this.currentTask,
      history: history ?? this.history,
      error: clearError ? null : (error ?? this.error),
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Agent 控制器
class AgentController extends StateNotifier<AgentControllerState> {
  AgentController(this._orchestrator, this._profileController)
      : super(const AgentControllerState());

  final AgentOrchestrator _orchestrator;
  final LearningProfileController _profileController;

  /// 启动 Agent 任务
  ///
  /// [userInput] 用户文本输入
  /// [dataUri] 可选图片(作业辅导)
  /// [smiles] 可选 SMILES
  /// [name] 可选化合物名
  Future<AgentTask> runTask({
    required String userInput,
    String? dataUri,
    String? smiles,
    String? name,
    String? userStage,
  }) async {
    if (state.isRunning) {
      return state.currentTask ??
          AgentTask(
            id: '',
            type: AgentTaskType.chat,
            userInput: userInput,
            steps: const [],
            createdAt: DateTime.now(),
            status: AgentTaskStatus.failed,
            error: '已有任务在执行中',
          );
    }

    // 从学情画像读取学段
    final stage = userStage ?? _profileController.state.profile?.stage ?? 'highschool';
    final profile = _profileController.state.profile;

    state = state.copyWith(
      isRunning: true,
      currentTask: null,
      clearError: true,
    );

    try {
      final task = await _orchestrator.run(
        userInput: userInput,
        dataUri: dataUri,
        smiles: smiles,
        name: name,
        userStage: stage,
        profile: profile,
        onProgress: (t) {
          state = state.copyWith(currentTask: t);
        },
      );

      // 加入历史
      final newHistory = [task, ...state.history].take(50).toList();
      state = state.copyWith(
        currentTask: task,
        history: newHistory,
        isRunning: false,
      );

      // 任务完成后刷新学情画像(闭环:扫描/练习记录 → 画像更新)
      _profileController.refresh();

      return task;
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: '任务执行失败: $e',
      );
      rethrow;
    }
  }

  /// 取消当前任务
  void cancelTask() {
    final current = state.currentTask;
    if (current == null) return;
    final cancelled = _orchestrator.cancel(current);
    state = state.copyWith(
      currentTask: cancelled,
      isRunning: false,
    );
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 清空当前任务(用于 UI 返回)
  void clearCurrent() {
    state = state.copyWith(currentTask: null, clearError: true);
  }
}

/// Agent 控制器 Provider
final agentControllerProvider =
    StateNotifierProvider<AgentController, AgentControllerState>((ref) {
  final orchestrator = ref.watch(agentOrchestratorProvider);
  final profileController =
      ref.watch(learningProfileControllerProvider.notifier);
  return AgentController(orchestrator, profileController);
}, dependencies: [
  agentOrchestratorProvider,
  learningProfileControllerProvider,
]);
