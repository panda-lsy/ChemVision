/// Agent 上下文管理器 — 会话历史、任务状态、工具结果中转
///
/// 对应赛题 Agent 应用闭环中的"上下文管理":
/// - 跨步骤数据传递(上一步识别的 SMILES 供下一步查询)
/// - 多轮对话历史(支持追问、修正)
/// - 用户画像注入(学段决定讲解深度)
///
/// 上下文是编排器的"记忆",在单次任务执行生命周期内累积。
import '../../models/agent_task.dart';
import '../../models/learning_profile.dart';
import 'agent_tool.dart';

/// 单轮对话消息
class AgentMessage {
  const AgentMessage({
    required this.role,
    required this.content,
    this.timestamp,
    this.metadata,
  });

  /// 角色: user / assistant / system / tool
  final String role;
  final String content;
  final DateTime? timestamp;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp?.toIso8601String(),
        'metadata': metadata,
      };
}

/// Agent 执行上下文
///
/// 一个上下文实例对应一次任务执行;多轮追问通过 [messages] 累积。
class AgentContext {
  AgentContext({
    required this.taskId,
    required this.taskType,
    required this.userStage,
  });

  final String taskId;
  final AgentTaskType taskType;

  /// 用户学段: middle / highschool / college(决定讲解深度)
  String userStage;

  /// 工具结果槽位:键为步骤 ID(如 'ocr' 'pubchem' 'knowledge' 'llm')
  /// 值为该步骤的 ToolResult.data
  final Map<String, Map<String, dynamic>> _toolResults = {};

  /// 会话消息列表(按时间顺序)
  final List<AgentMessage> messages = [];

  /// 当前任务对象(随执行更新)
  AgentTask? currentTask;

  /// 关联的学情画像(学情诊断/学习规划任务使用)
  LearningProfile? profile;

  /// 存储工具结果到指定槽位
  void setToolResult(String slot, Map<String, dynamic> data) {
    _toolResults[slot] = data;
  }

  /// 读取工具结果槽位
  Map<String, dynamic>? getToolResult(String slot) => _toolResults[slot];

  /// 读取槽位数据并转 JSON 字符串(供 LLM 上下文注入)
  /// 找不到槽位时返回 [fallback]。
  String toolResultAsJson(String slot, {String fallback = ''}) {
    final data = _toolResults[slot];
    if (data == null) return fallback;
    return AgentTool.encodeForLlm(data);
  }

  /// 添加用户消息
  void addUserMessage(String content, {Map<String, dynamic>? metadata}) {
    messages.add(AgentMessage(
      role: 'user',
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加助手消息
  void addAssistantMessage(String content, {Map<String, dynamic>? metadata}) {
    messages.add(AgentMessage(
      role: 'assistant',
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 添加系统消息(如工具状态)
  void addSystemMessage(String content, {Map<String, dynamic>? metadata}) {
    messages.add(AgentMessage(
      role: 'system',
      content: content,
      timestamp: DateTime.now(),
      metadata: metadata,
    ));
  }

  /// 构造对话历史文本(供 LLM 多轮上下文)
  /// 最多保留最近 [maxMessages] 条避免超长。
  String historyText({int maxMessages = 10}) {
    if (messages.isEmpty) return '';
    final slice = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    final buffer = StringBuffer();
    for (final m in slice) {
      final label = switch (m.role) {
        'user' => '用户',
        'assistant' => '助手',
        'system' => '系统',
        'tool' => '工具',
        _ => m.role,
      };
      buffer.writeln('[$label] ${m.content}');
    }
    return buffer.toString();
  }

  /// 转为可注入 LLM 的上下文摘要(学段 + 工具结果 + 历史)
  String buildLlmContext({
    required String focusSlot,
    int maxHistory = 8,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# 用户学段');
    buffer.writeln(userStage);
    buffer.writeln();
    if (profile != null) {
      buffer.writeln('# 学情画像');
      buffer.writeln('已掌握知识点: ${profile!.knowledgeMastery.length}');
      buffer.writeln(
          '薄弱知识点: ${profile!.weakPoints.length} 个');
      buffer.writeln();
    }
    final history = historyText(maxMessages: maxHistory);
    if (history.isNotEmpty) {
      buffer.writeln('# 对话历史');
      buffer.writeln(history);
      buffer.writeln();
    }
    final toolJson = toolResultAsJson(focusSlot);
    if (toolJson.isNotEmpty) {
      buffer.writeln('# 当前步骤工具结果');
      buffer.writeln(toolJson);
    }
    return buffer.toString();
  }

  /// 清空工具结果槽位(开始新任务时)
  void clearToolResults() => _toolResults.clear();

  /// 导入 lib/services/agent/agent_tool.dart 的工具编码方法
  static String encodeForLlm(Map<String, dynamic> data) =>
      AgentTool.encodeForLlm(data);
}
