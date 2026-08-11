/// Agent 编排器核心 — 状态机驱动,按序执行步骤,聚合结果
///
/// 对应赛题 Agent 应用闭环完整链路:
///   1. 任务输入(parseInput)
///   2. 意图理解(TaskPlanner.parseInput)
///   3. 任务规划(planFor)
///   4. 能力调用(ToolRegistry.invoke)
///   5. 结果交付(aggregateResult)
///   6. 验证与反馈(learning_record_service 持久化)
///   7. 安全边界(safetyNotice)
///
/// 引擎设计:
/// - 步骤间通过 @slot.field 引用上一步结果
/// - 步骤失败时按严重性决定中止/降级
/// - 通过 onProgress 回调实时推送状态(供 UI 展示进度)
library;

import 'package:flutter/foundation.dart';

import '../../models/agent_task.dart';
import '../../models/learning_profile.dart';
import '../learning_record_service.dart';
import 'agent_context.dart';
import 'agent_tool.dart';
import 'task_planner.dart';

/// 编排进度回调
///
/// [task] 为当前任务快照(含各步骤状态)。
typedef AgentProgressCallback = void Function(AgentTask task);

/// Agent 编排器
class AgentOrchestrator {
  AgentOrchestrator({
    required ToolRegistry registry,
    LearningRecordService? recordService,
    TaskPlanner? planner,
  })  : _registry = registry,
        _recordService = recordService,
        _planner = planner ?? const TaskPlanner();

  final ToolRegistry _registry;
  final LearningRecordService? _recordService;
  final TaskPlanner _planner;

  /// 活跃会话的上下文映射(key: taskId/sessionId, value: AgentContext)
  /// 用于多轮对话:后续追问时复用之前的工具结果和对话历史
  final Map<String, AgentContext> _sessions = {};

  /// 执行一个完整任务
  ///
  /// [userInput] 用户原始输入(文本)
  /// [dataUri] 可选的图片(作业辅导)
  /// [smiles] 可选的 SMILES(化合物讲解)
  /// [name] 可选的化合物名
  /// [userStage] 用户学段:middle/highschool/college
  /// [profile] 可选的学情画像(诊断/规划任务使用)
  /// [onProgress] 进度回调(每次步骤状态变化触发)
  Future<AgentTask> run({
    required String userInput,
    String? dataUri,
    String? smiles,
    String? name,
    String userStage = 'highschool',
    LearningProfile? profile,
    AgentProgressCallback? onProgress,
  }) async {
    // 1. 解析输入 + 规划步骤
    final parsed = _planner.parseInput(
      userInput: userInput,
      dataUri: dataUri,
      smiles: smiles,
      name: name,
    );

    final taskId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final steps = _planner.planFor(parsed);

    // 2. 构造任务对象
    var task = AgentTask(
      id: taskId,
      type: parsed.taskType,
      userInput: userInput,
      steps: steps,
      createdAt: DateTime.now(),
      status: AgentTaskStatus.executing,
      context: {
        'userStage': userStage,
        if (dataUri != null) 'hasImage': true,
        if (smiles != null) 'inputSmiles': smiles,
        if (name != null) 'inputName': name,
      },
    );

    // 3. 构造上下文
    final context = AgentContext(
      taskId: taskId,
      taskType: parsed.taskType,
      userStage: userStage,
    )..profile = profile;
    context.currentTask = task;
    context.addUserMessage(userInput);

    // 保存上下文到会话映射(供多轮追问使用)
    _sessions[taskId] = context;

    onProgress?.call(task);

    // 4. 顺序执行步骤
    for (var i = 0; i < task.steps.length; i++) {
      if (task.status == AgentTaskStatus.cancelled) break;

      final step = task.steps[i];
      final executingStep = step.copyWith(
        status: AgentStepStatus.executing,
        startedAt: DateTime.now(),
      );
      task = _replaceStep(task, i, executingStep);
      onProgress?.call(task);

      // 解析 @slot.field 引用并调用工具
      final resolvedInput = _resolveReferences(step.toolInput, context);
      final result = await _registry.invoke(
        step.toolName ?? 'llm',
        resolvedInput,
      );

      // 更新步骤
      final completedStep = executingStep.copyWith(
        status: result.ok ? AgentStepStatus.completed : AgentStepStatus.failed,
        toolOutput: result.data,
        result: result.summary ?? (result.ok ? '完成' : result.error),
        error: result.ok ? null : result.error,
        completedAt: DateTime.now(),
        toolInput: resolvedInput,
      );
      task = _replaceStep(task, i, completedStep);
      onProgress?.call(task);

      // 存储结果到上下文(供后续步骤和结果聚合使用)
      if (result.ok) {
        context.setToolResult(step.id, result.data);
      } else {
        // 失败处理:核心步骤(ocr)失败则中止;LLM 失败中止;其他降级
        if (_isCriticalStep(step.id) || step.toolName == 'llm') {
          task = task.copyWith(
            status: AgentTaskStatus.failed,
            error: '步骤「${step.name}」失败: ${result.error ?? "未知错误"}',
          );
          onProgress?.call(task);
          return task;
        }
        if (kDebugMode) {
          debugPrint('[Agent] 步骤 ${step.id} 失败,降级继续: ${result.error}');
        }
      }
    }

    // 5. 聚合最终结果
    if (task.status != AgentTaskStatus.cancelled) {
      final aggregated = _aggregateResult(task, context);
      task = task.copyWith(
        status: AgentTaskStatus.completed,
        result: aggregated,
      );
      context.addAssistantMessage(aggregated.summary,
          metadata: {'type': 'final_result'});

      // 6. 写入学习记录(反馈到学情画像,形成闭环)
      await _recordLearning(task, context);
    }

    onProgress?.call(task);
    return task;
  }

  /// 按任务类型写入学习记录
  ///
  /// 闭环设计:
  /// - homeworkTutor / compoundExplain: 记录 scan + query 行为
  ///   (用户通过 Agent 接触了该化合物和知识点)
  /// - practice: 记录 practice 行为(默认答对,UI 后续可让用户标记对错)
  /// - errorAnalysis: 记录 practiceWrong(暴露薄弱点)
  /// - diagnosis / planning / chat: 不直接产生学习记录
  Future<void> _recordLearning(
      AgentTask task, AgentContext context) async {
    final service = _recordService;
    if (service == null) return;

    try {
      switch (task.type) {
        case AgentTaskType.homeworkTutor:
        case AgentTaskType.compoundExplain:
          await _recordCompoundInteraction(task, context, service);
          break;
        case AgentTaskType.practice:
          await _recordPracticeResult(task, context, service, correct: true);
          break;
        case AgentTaskType.errorAnalysis:
          await _recordPracticeResult(task, context, service, correct: false);
          break;
        case AgentTaskType.diagnosis:
        case AgentTaskType.planning:
        case AgentTaskType.chat:
          // 这些任务不直接产生知识点级别的学习记录
          break;
      }
    } catch (e) {
      // 记录失败不影响任务交付
      if (kDebugMode) {
        debugPrint('[Agent] 学习记录写入失败: $e');
      }
    }
  }

  /// 记录化合物交互(扫描/查询行为)
  ///
  /// 从工具结果中提取 SMILES、化合物名、知识点 ID。
  /// 优先用 OCSR 结果(作业辅导),否则用 PubChem 结果(化合物讲解)。
  Future<void> _recordCompoundInteraction(
    AgentTask task,
    AgentContext context,
    LearningRecordService service,
  ) async {
    final ocrData = context.getToolResult('ocr');
    final pubchemData = context.getToolResult('pubchem');
    final knowledgeData = context.getToolResult('knowledge');

    final smiles = (ocrData?['smiles'] as String?)?.isNotEmpty == true
        ? ocrData!['smiles'] as String
        : (pubchemData?['canonicalSmiles'] as String?) ?? '';
    if (smiles.isEmpty) return;

    final compoundName = (pubchemData?['chineseName'] as String?)?.isNotEmpty == true
        ? pubchemData!['chineseName'] as String
        : (pubchemData?['englishName'] as String?)?.isNotEmpty == true
            ? pubchemData!['englishName'] as String
            : (pubchemData?['name'] as String?) ?? '';

    // 从知识图谱结果提取知识点 ID
    final kpIds = <String>[];
    final points = knowledgeData?['points'];
    if (points is List) {
      for (final p in points) {
        if (p is Map && p['id'] is String) {
          kpIds.add(p['id'] as String);
        }
      }
    }

    // 作业辅导:记录 scan 行为;化合物讲解(用户主动查询):记录 query 行为
    if (task.type == AgentTaskType.homeworkTutor) {
      await service.recordScan(
        scanHistoryId: task.id,
        smiles: smiles,
        compoundName: compoundName,
        knowledgePointIds: kpIds,
      );
    } else {
      await service.recordQuery(
        smiles: smiles,
        compoundName: compoundName,
        knowledgePointIds: kpIds,
      );
    }

    if (kDebugMode) {
      debugPrint(
          '[Agent] 记录 ${task.type.name}: $compoundName ($smiles), kp=${kpIds.length}');
    }
  }

  /// 记录练习结果(practice / errorAnalysis)
  Future<void> _recordPracticeResult(
    AgentTask task,
    AgentContext context,
    LearningRecordService service, {
    required bool correct,
  }) async {
    final ocrData = context.getToolResult('ocr');
    final knowledgeData = context.getToolResult('knowledge');

    final smiles = (ocrData?['smiles'] as String?) ?? '';
    final kpIds = <String>[];
    final points = knowledgeData?['points'];
    if (points is List) {
      for (final p in points) {
        if (p is Map && p['id'] is String) {
          kpIds.add(p['id'] as String);
        }
      }
    }

    await service.recordPractice(
      smiles: smiles,
      compoundName: '',
      correct: correct,
      knowledgePointIds: kpIds,
      notes: task.userInput,
    );

    if (kDebugMode) {
      debugPrint('[Agent] 记录练习: correct=$correct, kp=${kpIds.length}');
    }
  }

  /// 取消任务(供 UI 取消按钮调用)
  AgentTask cancel(AgentTask task) {
    return task.copyWith(status: AgentTaskStatus.cancelled);
  }

  /// 多轮追问:只调 LLM,注入之前的对话历史和工具结果
  ///
  /// 与 [run] 的区别:
  /// - 不重新执行 OCSR/PubChem/Knowledge 工具链
  /// - 复用之前会话的 AgentContext(含工具结果和对话历史)
  /// - 只执行一个 LLM 步骤,把用户的新问题 + 上下文传给 LLM
  Future<AgentTask> runFollowUp({
    required String userInput,
    required String sessionId,
    required List<AgentMessage> previousMessages,
    required AgentTaskType taskType,
    String userStage = 'highschool',
    LearningProfile? profile,
    AgentProgressCallback? onProgress,
  }) async {
    // 获取或创建上下文
    var context = _sessions[sessionId];
    if (context == null) {
      // 会话上下文已丢失(可能被清理),从消息列表恢复
      context = AgentContext(
        taskId: sessionId,
        taskType: taskType,
        userStage: userStage,
      )..profile = profile;
      for (final msg in previousMessages) {
        context.messages.add(msg);
      }
      _sessions[sessionId] = context;
    }

    // 构造追问任务(只有一个 LLM 步骤)
    final followUpId =
        '${sessionId}_f${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final followUpStep = AgentStep(
      id: 'followup_llm',
      name: '回答追问',
      toolName: 'llm',
      toolInput: {
        'prompt': userInput,
        'context': context.buildLlmContext(focusSlot: ''),
        'taskType': taskType.name,
        'isFollowUp': true,
      },
    );

    var task = AgentTask(
      id: followUpId,
      type: taskType,
      userInput: userInput,
      steps: [followUpStep],
      createdAt: DateTime.now(),
      status: AgentTaskStatus.executing,
      context: {
        'userStage': userStage,
        'isFollowUp': true,
        'sessionId': sessionId,
      },
    );

    context.currentTask = task;
    context.addUserMessage(userInput);

    onProgress?.call(task);

    // 执行唯一的 LLM 步骤
    final step = task.steps[0];
    final executingStep = step.copyWith(
      status: AgentStepStatus.executing,
      startedAt: DateTime.now(),
    );
    task = _replaceStep(task, 0, executingStep);
    onProgress?.call(task);

    final resolvedInput = _resolveReferences(step.toolInput, context);
    final result = await _registry.invoke('llm', resolvedInput);

    final completedStep = executingStep.copyWith(
      status: result.ok ? AgentStepStatus.completed : AgentStepStatus.failed,
      toolOutput: result.data,
      result: result.ok ? '完成' : (result.error ?? '失败'),
      error: result.ok ? null : result.error,
      completedAt: DateTime.now(),
      toolInput: resolvedInput,
    );
    task = _replaceStep(task, 0, completedStep);

    if (!result.ok) {
      task = task.copyWith(
        status: AgentTaskStatus.failed,
        error: '追问失败: ${result.error ?? "未知错误"}',
      );
      onProgress?.call(task);
      return task;
    }

    // 聚合结果
    final aggregated = _aggregateFollowUpResult(task, context, taskType);
    task = task.copyWith(
      status: AgentTaskStatus.completed,
      result: aggregated,
    );
    context.addAssistantMessage(aggregated.summary,
        metadata: {'type': 'followup_result'});

    onProgress?.call(task);
    return task;
  }

  /// 聚合追问结果(简化版,只有 LLM 文本)
  AgentTaskResult _aggregateFollowUpResult(
    AgentTask task,
    AgentContext context,
    AgentTaskType taskType,
  ) {
    final llmResult = context.getToolResult('explain');
    // 追问的 LLM 结果在 followup_llm 步骤中
    final followUpData = task.steps.isNotEmpty
        ? task.steps.last.toolOutput
        : null;
    final llmText = (followUpData?['text'] as String?) ??
        (llmResult?['text'] as String?) ??
        '';

    final title = _taskTitle(taskType);

    final sections = <AgentResultSection>[];
    if (llmText.isNotEmpty) {
      sections.add(AgentResultSection(
        title: '回答',
        content: llmText,
        type: _sectionTypeForTask(taskType),
      ));
    }

    return AgentTaskResult(
      title: title,
      summary: llmText.isNotEmpty
          ? (llmText.length > 120
              ? '${llmText.substring(0, 120)}...'
              : llmText)
          : '已回复',
      sections: sections,
      suggestedActions: const [],
      safetyNotice: _safetyNotice(taskType),
    );
  }

  /// 获取指定会话的对话消息列表(供 AgentController 注入多轮上下文)
  List<AgentMessage> getSessionMessages(String sessionId) {
    final context = _sessions[sessionId];
    if (context == null) return const [];
    return List.unmodifiable(context.messages);
  }

  /// 解析 toolInput 中的 @slot.field 引用
  ///
  /// 例如 {'smiles': '@ocr.smiles'} → 从 context.getToolResult('ocr')['smiles'] 取值
  /// 支持嵌套字段 '@pubchem.chineseName'
  Map<String, dynamic> _resolveReferences(
    Map<String, dynamic>? input,
    AgentContext context,
  ) {
    if (input == null) return {};
    final resolved = <String, dynamic>{};
    for (final entry in input.entries) {
      resolved[entry.key] = _resolveValue(entry.value, context);
    }
    return resolved;
  }

  dynamic _resolveValue(dynamic value, AgentContext context) {
    if (value is String && value.startsWith('@')) {
      // 格式: @slot.field.subfield
      final parts = value.substring(1).split('.');
      if (parts.isEmpty) return value;
      final slot = parts.first;
      // 特殊槽位:@profile.xxx
      if (slot == 'profile') {
        return _resolveProfilePath(parts.skip(1).toList(), context);
      }
      // 特殊槽位:@userInput / @userStage / @taskId / @taskType
      if (slot == 'userInput') return context.currentTask?.userInput ?? '';
      if (slot == 'userStage') return context.userStage;
      if (slot == 'taskId') return context.taskId;
      if (slot == 'taskType') return context.taskType.name;
      // @slot (无子路径) 返回整个工具结果 JSON
      final data = context.getToolResult(slot);
      if (data == null) return '';
      if (parts.length == 1) {
        return AgentTool.encodeForLlm(data);
      }
      return _resolvePath(parts.skip(1).toList(), data);
    }
    return value;
  }

  dynamic _resolvePath(List<String> path, Map<String, dynamic> data) {
    dynamic current = data;
    for (final key in path) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else if (current is Map) {
        current = current[key];
      } else {
        return '';
      }
      if (current == null) return '';
    }
    return current;
  }

  dynamic _resolveProfilePath(List<String> path, AgentContext context) {
    final profile = context.profile;
    if (profile == null) return '';
    if (path.isEmpty) return '';
    final key = path.first;
    switch (key) {
      case 'weakPoints':
        return profile.weakPoints;
      case 'totalScans':
        return profile.totalScans;
      case 'totalQueries':
        return profile.totalQueries;
      case 'totalPractice':
        return profile.totalPractice;
      case 'correctCount':
        return profile.correctCount;
      case 'streakDays':
        return profile.streakDays;
      case 'masteryCount':
        return profile.knowledgeMastery.length;
      default:
        return '';
    }
  }

  /// 是否核心步骤(失败必须中止)
  bool _isCriticalStep(String stepId) =>
      stepId == 'ocr' || stepId == 'pubchem_by_name';

  /// 聚合最终结果
  AgentTaskResult _aggregateResult(AgentTask task, AgentContext context) {
    final title = _taskTitle(task.type);

    // LLM 步骤的文本作为主体内容
    final llmResult = context.getToolResult('explain');
    final llmText = (llmResult?['text'] as String?) ?? '';

    final sections = <AgentResultSection>[];

    // 工具结果摘要(化合物信息)
    final pubchem = context.getToolResult('pubchem');
    if (pubchem != null && pubchem.isNotEmpty) {
      sections.add(AgentResultSection(
        title: '化合物信息',
        content: _formatCompoundInfo(pubchem),
        type: ResultSectionType.formula,
        metadata: pubchem,
      ));
    }

    // 知识点关联
    final knowledge = context.getToolResult('knowledge');
    if (knowledge != null && knowledge.isNotEmpty) {
      final points = knowledge['points'];
      if (points is List && points.isNotEmpty) {
        sections.add(AgentResultSection(
          title: '教材知识点',
          content: _formatKnowledgePoints(points),
          type: ResultSectionType.knowledgeMap,
          metadata: knowledge,
        ));
      }
    }

    // LLM 生成的讲解
    if (llmText.isNotEmpty) {
      sections.add(AgentResultSection(
        title: title,
        content: llmText,
        type: _sectionTypeForTask(task.type),
      ));
    }

    // 关联的知识点 ID
    final kpIds = <String>[];
    final points = knowledge?['points'];
    if (points is List) {
      for (final p in points) {
        if (p is Map && p['id'] is String) {
          kpIds.add(p['id'] as String);
        }
      }
    }

    return AgentTaskResult(
      title: title,
      summary: llmText.isNotEmpty
          ? (llmText.length > 120
              ? '${llmText.substring(0, 120)}...'
              : llmText)
          : _defaultSummary(task.type),
      sections: sections,
      relatedKnowledgePoints: kpIds,
      suggestedActions: _suggestedActions(task.type, kpIds),
      safetyNotice: _safetyNotice(task.type),
    );
  }

  String _taskTitle(AgentTaskType type) => switch (type) {
        AgentTaskType.homeworkTutor => '作业辅导',
        AgentTaskType.compoundExplain => '化合物讲解',
        AgentTaskType.diagnosis => '学情诊断报告',
        AgentTaskType.planning => '个性化学习规划',
        AgentTaskType.practice => '同类题训练',
        AgentTaskType.errorAnalysis => '错因分析',
        AgentTaskType.chat => '学习对话',
      };

  String _defaultSummary(AgentTaskType type) => switch (type) {
        AgentTaskType.homeworkTutor => '已完成分步启发讲解',
        AgentTaskType.compoundExplain => '已完成化合物讲解',
        AgentTaskType.diagnosis => '已生成学情报告',
        AgentTaskType.planning => '已生成学习规划',
        AgentTaskType.practice => '已生成练习题',
        AgentTaskType.errorAnalysis => '已完成错因分析',
        AgentTaskType.chat => '已回复',
      };

  ResultSectionType _sectionTypeForTask(AgentTaskType type) => switch (type) {
        AgentTaskType.diagnosis => ResultSectionType.recommendation,
        AgentTaskType.planning => ResultSectionType.recommendation,
        AgentTaskType.errorAnalysis => ResultSectionType.warning,
        _ => ResultSectionType.text,
      };

  String _formatCompoundInfo(Map<String, dynamic> data) {
    final name = data['chineseName'] ?? data['englishName'] ?? data['name'];
    final formula = data['formula'] ?? '';
    final weight = data['weight'];
    final smiles = data['canonicalSmiles'] ?? '';
    final parts = <String>[];
    if (name != null && name.toString().isNotEmpty) parts.add('名称: $name');
    if (formula.toString().isNotEmpty) parts.add('分子式: $formula');
    if (weight != null) parts.add('分子量: $weight');
    if (smiles.toString().isNotEmpty) parts.add('SMILES: $smiles');
    return parts.join('\n');
  }

  String _formatKnowledgePoints(List points) {
    final buffer = StringBuffer();
    for (final p in points) {
      if (p is Map) {
        buffer.writeln('• ${p['name']} — ${p['chapter']}');
        buffer.writeln('  ${p['description']}');
      }
    }
    return buffer.toString().trim();
  }

  List<SuggestedAction> _suggestedActions(
      AgentTaskType type, List<String> kpIds) {
    final actions = <SuggestedAction>[];
    switch (type) {
      case AgentTaskType.homeworkTutor:
      case AgentTaskType.compoundExplain:
        actions.add(SuggestedAction(
          label: '生成同类练习题',
          actionType: SuggestedActionType.practice,
          payload: {'knowledgePointIds': kpIds},
        ));
        actions.add(SuggestedAction(
          label: '查看学情诊断',
          actionType: SuggestedActionType.diagnose,
        ));
        break;
      case AgentTaskType.diagnosis:
        actions.add(SuggestedAction(
          label: '生成学习规划',
          actionType: SuggestedActionType.planLearning,
          payload: {'knowledgePointIds': kpIds},
        ));
        actions.add(SuggestedAction(
          label: '开始薄弱点复习',
          actionType: SuggestedActionType.review,
          payload: {'knowledgePointIds': kpIds},
        ));
        break;
      case AgentTaskType.planning:
        actions.add(SuggestedAction(
          label: '开始按计划学习',
          actionType: SuggestedActionType.review,
          payload: {'knowledgePointIds': kpIds},
        ));
        break;
      case AgentTaskType.practice:
        actions.add(SuggestedAction(
          label: '再来一组练习',
          actionType: SuggestedActionType.practice,
          payload: {'knowledgePointIds': kpIds},
        ));
        break;
      case AgentTaskType.errorAnalysis:
      case AgentTaskType.chat:
        break;
    }
    if (kpIds.isNotEmpty) {
      actions.add(SuggestedAction(
        label: '收藏到错题本',
        actionType: SuggestedActionType.saveFavorite,
        payload: {'knowledgePointIds': kpIds},
      ));
    }
    return actions;
  }

  String _safetyNotice(AgentTaskType type) {
    switch (type) {
      case AgentTaskType.homeworkTutor:
        return '本工具提供学习启发,不替代教师批改。请结合课堂讲解理解知识点。';
      case AgentTaskType.diagnosis:
        return '学情诊断基于本地学习记录,仅供参考,正式评价请咨询任课教师。';
      case AgentTaskType.planning:
        return '学习规划为建议性方案,请结合实际课程安排和个人进度调整。';
      default:
        return '本内容由 AI 生成,请核实关键信息。';
    }
  }

  /// 替换步骤并保留不可变任务状态
  AgentTask _replaceStep(AgentTask task, int index, AgentStep newStep) {
    final newSteps = List<AgentStep>.from(task.steps);
    newSteps[index] = newStep;
    return task.copyWith(steps: newSteps);
  }
}
