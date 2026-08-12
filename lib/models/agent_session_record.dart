import 'agent_task.dart';

/// Agent 会话记录 — 持久化的简化任务快照(用于历史回看)
///
/// 与完整 [AgentTask] 的区别:
/// - 只保留用户回看所需的核心字段(用户输入 + 最终结果 + 安全提示)
/// - 不存储中间步骤的 toolInput/toolOutput(那些是执行期调试用的,体积大)
/// - 嵌套结构扁平化,便于 Hive 序列化
///
/// 设计动机:AgentTask 模型嵌套深(含 AgentStep/AgentTaskResult/Map/enum),
/// 写完整 TypeAdapter 繁琐;回看场景只需"用户问了什么 + Agent 答了什么"。
class AgentSessionRecord {
  AgentSessionRecord({
    required this.id,
    required this.type,
    required this.status,
    required this.userInput,
    required this.createdAt,
    this.resultTitle,
    this.resultSummary,
    this.sections = const [],
    this.safetyNotice,
    this.error,
    this.relatedKnowledgePointIds = const [],
  });

  /// 任务 ID(与 AgentTask.id 一致,时间戳 base36)
  final String id;

  /// 任务类型
  final AgentTaskType type;

  /// 任务最终状态(只持久化终态:completed/failed/cancelled)
  final AgentTaskStatus status;

  /// 用户原始输入
  final String userInput;

  /// 创建时间
  final DateTime createdAt;

  /// 结果标题
  final String? resultTitle;

  /// 结果摘要
  final String? resultSummary;

  /// 结果分章节(扁平化存储)
  final List<AgentSessionSection> sections;

  /// 安全提示
  final String? safetyNotice;

  /// 失败原因(仅 status=failed 时有值)
  final String? error;

  /// 关联知识点 ID
  final List<String> relatedKnowledgePointIds;

  /// 从完整 AgentTask 转换为持久化记录
  factory AgentSessionRecord.fromTask(AgentTask task) {
    final result = task.result;
    return AgentSessionRecord(
      id: task.id,
      type: task.type,
      status: task.status,
      userInput: task.userInput,
      createdAt: task.createdAt,
      resultTitle: result?.title,
      resultSummary: result?.summary,
      sections: result?.sections
              .map((s) => AgentSessionSection(
                    title: s.title,
                    content: s.content,
                    typeName: s.type.name,
                  ))
              .toList() ??
          const [],
      safetyNotice: result?.safetyNotice,
      error: task.error,
      relatedKnowledgePointIds:
          result?.relatedKnowledgePoints ?? const [],
    );
  }

  /// 任务类型中文标签(用于 UI 展示)
  String get typeLabel => switch (type) {
        AgentTaskType.homeworkTutor => '作业辅导',
        AgentTaskType.compoundExplain => '化合物讲解',
        AgentTaskType.diagnosis => '学情诊断',
        AgentTaskType.planning => '学习规划',
        AgentTaskType.practice => '同类题训练',
        AgentTaskType.errorAnalysis => '错因分析',
        AgentTaskType.chat => '自由对话',
      };

  /// 状态中文标签
  String get statusLabel => switch (status) {
        AgentTaskStatus.completed => '已完成',
        AgentTaskStatus.failed => '失败',
        AgentTaskStatus.cancelled => '已取消',
        AgentTaskStatus.pending => '待执行',
        AgentTaskStatus.planning => '规划中',
        AgentTaskStatus.executing => '执行中',
        AgentTaskStatus.awaitingUser => '等待用户',
      };

  /// 首行预览(用于历史列表卡片)
  String get preview {
    final s = resultSummary;
    if (s != null && s.isNotEmpty) {
      return s.length > 80 ? '${s.substring(0, 80)}...' : s;
    }
    if (error != null && error!.isNotEmpty) {
      return error!.length > 80
          ? '${error!.substring(0, 80)}...'
          : error!;
    }
    return userInput;
  }
}

/// 会话结果分章节(扁平化,便于 Hive 序列化)
class AgentSessionSection {
  const AgentSessionSection({
    required this.title,
    required this.content,
    required this.typeName,
  });

  final String title;
  final String content;

  /// ResultSectionType 的 name(避免存 enum)
  final String typeName;

  /// 还原为 ResultSectionType
  ResultSectionType get type => ResultSectionType.values.firstWhere(
        (e) => e.name == typeName,
        orElse: () => ResultSectionType.text,
      );
}
