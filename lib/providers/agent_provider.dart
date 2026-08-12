/// Agent Provider — Riverpod 状态管理集成
///
/// 暴露编排器能力给 UI 层:
/// - [runTask] 启动任务,实时推送进度
/// - [cancelTask] 取消当前任务
/// - [AgentControllerState] 持有当前任务、历史、错误状态
/// - 持久化历史会话([AgentSessionStore]),应用重启后可回看
/// - 多轮对话:同会话内的后续输入只调用 LLM,注入对话历史
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_session_record.dart';
import '../models/agent_task.dart';
import '../services/agent/agent_context.dart';
import '../services/agent/agent_orchestrator.dart';
import '../services/agent/tool_registry_factory.dart';
import '../services/agent_session_store.dart';
import 'learning_profile_provider.dart';

// agentOrchestratorProvider 已在 tool_registry_factory.dart 中定义(含 LearningRecordService 注入)

/// Agent 控制器状态
class AgentControllerState {
  const AgentControllerState({
    this.currentTask,
    this.history = const [],
    this.sessions = const [],
    this.error,
    this.isRunning = false,
    this.activeSessionId,
    this.messages = const [],
  });

  /// 当前执行中的任务(null 表示空闲)
  final AgentTask? currentTask;

  /// 当前会话内的内存历史(最近 50 条,含完整步骤,重启清空)
  final List<AgentTask> history;

  /// 持久化的历史会话记录(跨会话,从 Hive 加载,用于回看)
  final List<AgentSessionRecord> sessions;

  /// 错误信息(运行失败时)
  final String? error;

  /// 是否正在执行
  final bool isRunning;

  /// 当前活跃会话 ID(null 表示无活跃会话,点击"新对话"时清除)
  final String? activeSessionId;

  /// 当前会话的对话历史(用于多轮对话上下文注入)
  final List<AgentMessage> messages;

  /// 是否有活跃会话(可继续追问)
  bool get hasActiveSession => activeSessionId != null;

  AgentControllerState copyWith({
    AgentTask? currentTask,
    List<AgentTask>? history,
    List<AgentSessionRecord>? sessions,
    String? error,
    bool? isRunning,
    String? activeSessionId,
    List<AgentMessage>? messages,
    bool clearError = false,
    bool clearSession = false,
  }) {
    return AgentControllerState(
      currentTask: currentTask ?? this.currentTask,
      history: history ?? this.history,
      sessions: sessions ?? this.sessions,
      error: clearError ? null : (error ?? this.error),
      isRunning: isRunning ?? this.isRunning,
      activeSessionId:
          clearSession ? null : (activeSessionId ?? this.activeSessionId),
      messages: clearSession ? const [] : (messages ?? this.messages),
    );
  }
}

/// Agent 控制器
class AgentController extends StateNotifier<AgentControllerState> {
  AgentController(
    this._orchestrator,
    this._profileController,
    this._sessionStore,
  ) : super(const AgentControllerState()) {
    // 初始化时从 Hive 加载历史会话
    _loadSessions();
  }

  final AgentOrchestrator _orchestrator;
  final LearningProfileController _profileController;
  final AgentSessionStore _sessionStore;

  /// 从持久化存储加载历史会话列表
  void _loadSessions() {
    final sessions = _sessionStore.getAll();
    state = state.copyWith(sessions: sessions);
  }

  /// 启动 Agent 任务
  ///
  /// 多轮对话逻辑:
  /// - 如果有活跃会话(activeSessionId 不为 null)且无新图片 → 走多轮对话
  ///   (只调 LLM,注入之前的对话历史)
  /// - 否则 → 创建新会话(完整工具链)
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

    final stage =
        userStage ?? _profileController.state.profile?.stage ?? 'highschool';
    final profile = _profileController.state.profile;

    // 多轮对话:有活跃会话且无新图片 → 只调 LLM
    if (state.hasActiveSession && dataUri == null) {
      return _runFollowUp(userInput: userInput, stage: stage, profile: profile);
    }

    // 新会话:完整工具链
    return _runNewTask(
      userInput: userInput,
      dataUri: dataUri,
      smiles: smiles,
      name: name,
      stage: stage,
      profile: profile,
    );
  }

  /// 新会话:执行完整工具链
  Future<AgentTask> _runNewTask({
    required String userInput,
    String? dataUri,
    String? smiles,
    String? name,
    required String stage,
    required dynamic profile,
  }) async {
    // 立即把用户输入显示到对话区(AI 回答加载前先看到自己的提问)
    final userPreviewMsg = AgentMessage(
      role: 'user',
      content: userInput,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      isRunning: true,
      currentTask: null,
      clearError: true,
      messages: [...state.messages, userPreviewMsg],
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

      // 加入内存历史
      final newHistory = [task, ...state.history].take(50).toList();

      // 从任务中提取对话消息(用于多轮对话,覆盖预览消息)
      final messages = _orchestrator.getSessionMessages(task.id);

      state = state.copyWith(
        currentTask: task,
        history: newHistory,
        isRunning: false,
        activeSessionId: task.id,
        messages: messages,
      );

      // 持久化到 Hive(仅终态任务)
      await _sessionStore.save(task);
      _loadSessions();

      // 任务完成后刷新学情画像
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

  /// 多轮对话:只调 LLM,注入对话历史
  Future<AgentTask> _runFollowUp({
    required String userInput,
    required String stage,
    required dynamic profile,
  }) async {
    // 立即把追问输入显示到对话区
    final userPreviewMsg = AgentMessage(
      role: 'user',
      content: userInput,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      isRunning: true,
      clearError: true,
      messages: [...state.messages, userPreviewMsg],
    );

    try {
      final task = await _orchestrator.runFollowUp(
        userInput: userInput,
        sessionId: state.activeSessionId!,
        previousMessages: state.messages,
        taskType: state.currentTask?.type ?? AgentTaskType.chat,
        userStage: stage,
        profile: profile,
        onProgress: (t) {
          state = state.copyWith(currentTask: t);
        },
      );

      // 更新对话历史(覆盖预览消息)
      final messages = _orchestrator.getSessionMessages(state.activeSessionId!);

      final newHistory = [task, ...state.history].take(50).toList();
      state = state.copyWith(
        currentTask: task,
        history: newHistory,
        isRunning: false,
        messages: messages,
      );

      // 持久化:追问合并到已有会话记录(同一条历史)
      await _sessionStore.saveFollowUp(
        sessionId: state.activeSessionId!,
        followUpTask: task,
      );
      _loadSessions();

      _profileController.refresh();

      return task;
    } catch (e) {
      state = state.copyWith(
        isRunning: false,
        error: '追问失败: $e',
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
    _sessionStore.save(cancelled).then((_) => _loadSessions());
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 清空当前任务(用于 UI 返回)
  /// 同时结束活跃会话(清除对话历史)
  void clearCurrent() {
    state = state.copyWith(
      currentTask: null,
      clearError: true,
      clearSession: true,
    );
  }

  /// 删除单条历史会话
  Future<void> deleteSession(String id) async {
    await _sessionStore.delete(id);
    _loadSessions();
  }

  /// 清空全部历史会话
  Future<void> clearAllSessions() async {
    await _sessionStore.clearAll();
    _loadSessions();
  }

  /// 按 ID 查询历史会话详情
  AgentSessionRecord? getSessionById(String id) =>
      _sessionStore.getById(id);

  /// 加载历史会话继续对话(恢复活跃会话)
  ///
  /// 完整还原对话内容:
  /// - 用户原始输入(含追问,以 [追问] 标记分隔)
  /// - 助手回复(优先用 sections 拼接完整内容,缺省时回退到 resultSummary)
  void resumeSession(AgentSessionRecord session) {
    final messages = <AgentMessage>[];

    // 拆分 userInput 中的原问与追问
    // (saveFollowUp 将 userInput 存为 "原问题\n\n[追问] 问题2\n\n[追问] 问题3")
    final userInputParts = session.userInput
        .split(RegExp(r'\n\n\[追问\]\s*'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // 1. 用户原问消息
    if (userInputParts.isNotEmpty) {
      messages.add(AgentMessage(
        role: 'user',
        content: userInputParts.first.trim(),
        timestamp: session.createdAt,
      ));
    }

    // 2. 助手原始回复(由 sections 拼接完整 Markdown,保证历史对话原样显示)
    final assistantContent = _buildAssistantContentFromSession(session);
    if (assistantContent.isNotEmpty) {
      messages.add(AgentMessage(
        role: 'assistant',
        content: assistantContent,
        timestamp: session.createdAt,
      ));
    }

    // 3. 追问的成对消息(用 sections 的"追问:"标题匹配)
    // sections 顺序:原始 sections + 追问 sections(标题以"追问: "开头)
    final followUpSections = session.sections
        .where((s) => s.title.startsWith('追问:'))
        .toList();
    for (var i = 0; i < followUpSections.length; i++) {
      // 对应 userInputParts[i+1] 为该追问的输入
      if (i + 1 < userInputParts.length) {
        messages.add(AgentMessage(
          role: 'user',
          content: userInputParts[i + 1].trim(),
          timestamp: session.createdAt.add(Duration(seconds: i + 1)),
        ));
      }
      messages.add(AgentMessage(
        role: 'assistant',
        content: followUpSections[i].content,
        timestamp: session.createdAt.add(Duration(seconds: i + 1)),
      ));
    }

    state = state.copyWith(
      activeSessionId: session.id,
      messages: messages,
      currentTask: null,
      clearError: true,
    );
  }

  /// 从 session 构造助手回复 Markdown 文本
  ///
  /// 优先用 sections 拼接(包含 ### 标题和正文),回退到 resultSummary。
  /// 跳过"追问:" 标题的 section(那些作为独立追问消息渲染)。
  String _buildAssistantContentFromSession(AgentSessionRecord session) {
    final originalSections = session.sections
        .where((s) => !s.title.startsWith('追问:'))
        .toList();
    if (originalSections.isNotEmpty) {
      return originalSections
          .map((s) => '### ${s.title}\n${s.content}')
          .join('\n\n');
    }
    return session.resultSummary ?? '';
  }
}

/// Agent 控制器 Provider
final agentControllerProvider =
    StateNotifierProvider<AgentController, AgentControllerState>((ref) {
  final orchestrator = ref.watch(agentOrchestratorProvider);
  final profileController =
      ref.watch(learningProfileControllerProvider.notifier);
  final sessionStore = ref.watch(agentSessionStoreProvider);
  return AgentController(orchestrator, profileController, sessionStore);
}, dependencies: [
  agentOrchestratorProvider,
  learningProfileControllerProvider,
  agentSessionStoreProvider,
]);
