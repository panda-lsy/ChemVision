import 'package:collection/collection.dart';

/// Agent 任务状态模型 — 代表一个完整的教育任务执行过程
///
/// 对应赛题 Agent 应用闭环要求:
///   1. 任务输入  2. 意图理解  3. 任务规划  4. 能力调用
///   5. 结果交付  6. 验证与反馈  7. 安全边界
///
/// 用于 Agent 对话主界面展示任务进度、多步骤执行状态。
class AgentTask {
  AgentTask({
    required this.id,
    required this.type,
    required this.userInput,
    required this.steps,
    required this.createdAt,
    this.status = AgentTaskStatus.pending,
    this.context = const {},
    this.result,
    this.error,
  });

  /// 任务 ID(时间戳 base36)
  final String id;

  /// 任务类型
  final AgentTaskType type;

  /// 任务状态
  final AgentTaskStatus status;

  /// 用户原始输入(图片字节路径/SMILES/名称/自由文本)
  final String userInput;

  /// 输入类型(用于 UI 展示)
  final Map<String, dynamic> context;

  /// 任务步骤列表
  final List<AgentStep> steps;

  /// 创建时间
  final DateTime createdAt;

  /// 最终结果(汇总)
  final AgentTaskResult? result;

  /// 失败原因
  final String? error;

  AgentTask copyWith({
    AgentTaskStatus? status,
    List<AgentStep>? steps,
    Map<String, dynamic>? context,
    AgentTaskResult? result,
    String? error,
  }) {
    return AgentTask(
      id: id,
      type: type,
      userInput: userInput,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      status: status ?? this.status,
      context: {...context ?? {}, ...this.context},
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }

  /// 当前执行步骤
  AgentStep? get currentStep =>
      steps.lastWhereOrNull((s) => s.status == AgentStepStatus.executing) ??
      steps.lastWhereOrNull((s) => s.status == AgentStepStatus.pending);

  /// 已完成步骤数
  int get completedStepCount =>
      steps.where((s) => s.status == AgentStepStatus.completed).length;

  /// 进度 0.0-1.0
  double get progress {
    if (steps.isEmpty) return 0;
    return completedStepCount / steps.length;
  }
}

/// Agent 任务类型
enum AgentTaskType {
  /// 作业辅导 — 拍照/绘制结构式,分步启发讲解(不直接给答案)
  homeworkTutor,

  /// 化合物讲解 — 扫描/绘制分子,讲解官能团/性质/反应/教材章节
  compoundExplain,

  /// 学情诊断 — 基于历史记录分析薄弱知识点,生成学情报告
  diagnosis,

  /// 个性化学习规划 — 基于学情诊断生成学习路径
  planning,

  /// 自由对话 — 多轮对话式学习陪伴
  chat,

  /// 错因分析 — 对比用户绘制 vs 标准结构,分析错误原因
  errorAnalysis,

  /// 同类题训练 — 基于官能团/知识点生成练习题
  practice,
}

/// 任务状态
enum AgentTaskStatus {
  pending,
  planning,
  executing,
  awaitingUser,
  completed,
  failed,
  cancelled,
}

/// Agent 任务步骤
class AgentStep {
  AgentStep({
    required this.id,
    required this.name,
    this.status = AgentStepStatus.pending,
    this.toolName,
    this.toolInput,
    this.toolOutput,
    this.result,
    this.description,
    this.startedAt,
    this.completedAt,
    this.error,
  });

  /// 步骤 ID,如 'ocr' 'pubchem' 'explain' 'diagnose'
  final String id;

  /// 步骤名称(用户可见)
  final String name;

  /// 步骤描述(用户可见,解释这一步做什么)
  final String? description;

  /// 步骤状态
  final AgentStepStatus status;

  /// 调用的工具名(如 'DECIMER' 'PubChem' 'LLM' 'KnowledgeBase')
  final String? toolName;

  /// 工具输入
  final Map<String, dynamic>? toolInput;

  /// 工具输出
  final Map<String, dynamic>? toolOutput;

  /// 步骤结果摘要(用户可见)
  final String? result;

  /// 开始时间
  final DateTime? startedAt;

  /// 完成时间
  final DateTime? completedAt;

  /// 错误信息
  final String? error;

  AgentStep copyWith({
    AgentStepStatus? status,
    Map<String, dynamic>? toolInput,
    Map<String, dynamic>? toolOutput,
    String? result,
    String? description,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return AgentStep(
      id: id,
      name: name,
      status: status ?? this.status,
      toolName: toolName,
      toolInput: toolInput ?? this.toolInput,
      toolOutput: toolOutput ?? this.toolOutput,
      result: result ?? this.result,
      description: description ?? this.description,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
    );
  }

  /// 耗时(秒)
  int get durationSeconds {
    if (startedAt == null) return 0;
    final end = completedAt ?? DateTime.now();
    return end.difference(startedAt!).inSeconds;
  }
}

enum AgentStepStatus {
  pending,
  executing,
  completed,
  failed,
  skipped,
}

/// Agent 任务最终结果
class AgentTaskResult {
  AgentTaskResult({
    required this.title,
    required this.summary,
    required this.sections,
    this.suggestedActions = const [],
    this.relatedKnowledgePoints = const [],
    this.safetyNotice,
  });

  /// 结果标题
  final String title;

  /// 摘要
  final String summary;

  /// 结构化分章节内容
  final List<AgentResultSection> sections;

  /// 建议的下一步操作
  final List<SuggestedAction> suggestedActions;

  /// 关联的知识点 ID
  final List<String> relatedKnowledgePoints;

  /// 安全边界提示(如不替代教师评价)
  final String? safetyNotice;
}

/// 结果分章节
class AgentResultSection {
  AgentResultSection({
    required this.title,
    required this.content,
    this.type = ResultSectionType.text,
    this.metadata,
  });

  final String title;
  final String content;
  final ResultSectionType type;
  final Map<String, dynamic>? metadata;
}

enum ResultSectionType {
  text,
  formula,
  reaction,
  knowledgeMap,
  recommendation,
  warning,
}

/// 建议操作
class SuggestedAction {
  SuggestedAction({
    required this.label,
    required this.actionType,
    this.payload,
  });

  final String label;
  final SuggestedActionType actionType;
  final Map<String, dynamic>? payload;
}

enum SuggestedActionType {
  practice,
  review,
  explainMore,
  diagnose,
  planLearning,
  saveFavorite,
}
