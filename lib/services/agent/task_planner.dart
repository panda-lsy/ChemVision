/// Agent 任务规划器 — 按任务类型生成步骤计划
///
/// 对应赛题 Agent 应用闭环中的"3. 任务规划":
/// 根据用户输入和任务类型,生成有序的执行步骤列表。
/// 每个步骤绑定一个工具调用,编排器按序执行。
///
/// 步骤设计原则:
/// - 步骤间通过 AgentContext.toolResults 传递数据
/// - 每步失败时编排器决定是否中止或降级
/// - homeworkTutor:不直接给答案,分步启发(符合教育伦理)
import '../../models/agent_task.dart';

/// 用户输入解析结果
class ParsedInput {
  const ParsedInput({
    required this.taskType,
    required this.userInput,
    this.dataUri,
    this.smiles,
    this.name,
  });

  final AgentTaskType taskType;
  final String userInput;

  /// 图片 data URI(作业辅导/扫描任务)
  final String? dataUri;

  /// 用户直接提供的 SMILES(化合物讲解)
  final String? smiles;

  /// 用户提供的化合物名称
  final String? name;
}

/// 任务规划器
class TaskPlanner {
  const TaskPlanner();

  /// 解析用户输入,推断任务类型
  ///
  /// 推断规则:
  /// - 含 dataUri(图片) → homeworkTutor(作业拍照辅导)
  /// - 含 SMILES 字符串 → compoundExplain(化合物讲解)
  /// - 含"诊断""学情""薄弱"等关键词 → diagnosis
  /// - 含"规划""计划""学习路径"等 → planning
  /// - 含"练习""做题""同类题"等 → practice
  /// - 其余 → chat(自由对话)
  ParsedInput parseInput({
    required String userInput,
    String? dataUri,
    String? smiles,
    String? name,
  }) {
    final lower = userInput.toLowerCase();
    AgentTaskType type = AgentTaskType.chat;

    if (dataUri != null && dataUri.isNotEmpty) {
      type = AgentTaskType.homeworkTutor;
    } else if (smiles != null && smiles.trim().isNotEmpty) {
      type = AgentTaskType.compoundExplain;
    } else if (lower.contains('诊断') ||
        lower.contains('学情') ||
        lower.contains('薄弱') ||
        lower.contains('掌握') ||
        lower.contains('诊断报告')) {
      type = AgentTaskType.diagnosis;
    } else if (lower.contains('规划') ||
        lower.contains('计划') ||
        lower.contains('学习路径') ||
        lower.contains('学习方案') ||
        lower.contains('怎么学')) {
      type = AgentTaskType.planning;
    } else if (lower.contains('练习') ||
        lower.contains('做题') ||
        lower.contains('同类题') ||
        lower.contains('出题')) {
      type = AgentTaskType.practice;
    } else if (name != null && name.trim().isNotEmpty) {
      type = AgentTaskType.compoundExplain;
    }

    return ParsedInput(
      taskType: type,
      userInput: userInput,
      dataUri: dataUri,
      smiles: smiles,
      name: name,
    );
  }

  /// 按任务类型生成步骤计划
  ///
  /// 返回的步骤已绑定 toolName 和 toolInput(初步),
  /// 编排器执行时会注入上一步结果(如 OCSR 得到的 SMILES)。
  List<AgentStep> planFor(ParsedInput input) {
    switch (input.taskType) {
      case AgentTaskType.homeworkTutor:
        return _planHomework(input);
      case AgentTaskType.compoundExplain:
        return _planCompoundExplain(input);
      case AgentTaskType.diagnosis:
        return _planDiagnosis(input);
      case AgentTaskType.planning:
        return _planLearning(input);
      case AgentTaskType.practice:
        return _planPractice(input);
      case AgentTaskType.errorAnalysis:
        return _planErrorAnalysis(input);
      case AgentTaskType.chat:
        return _planChat(input);
    }
  }

  /// 作业辅导:拍照 → OCSR → PubChem → 知识点匹配 → 分步启发讲解
  ///
  /// 教育伦理:不直接给最终答案,引导用户思考官能团/反应类型。
  List<AgentStep> _planHomework(ParsedInput input) => [
        AgentStep(
          id: 'ocr',
          name: '识别化学结构',
          description: '从图片中识别 SMILES',
          toolName: 'ocsr',
          toolInput: {'dataUri': input.dataUri ?? ''},
        ),
        AgentStep(
          id: 'pubchem',
          name: '查询化合物信息',
          description: '从 PubChem 获取名称、分子式',
          toolName: 'pubchem',
          toolInput: const {'smiles': '@ocr.smiles'},
        ),
        AgentStep(
          id: 'knowledge',
          name: '匹配教材知识点',
          description: '关联官能团到教材章节',
          toolName: 'knowledge',
          toolInput: const {'smiles': '@ocr.smiles'},
        ),
        AgentStep(
          id: 'explain',
          name: '分步启发讲解',
          description: '不直接给答案,引导思考官能团和反应',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_homework_tutor.txt',
            'smiles': '@ocr.smiles',
            'compoundInfo': '@pubchem',
            'knowledgePoints': '@knowledge',
            'userInput': '@userInput',
            'userStage': '@userStage',
          },
        ),
      ];

  /// 化合物讲解:SMILES/名称 → PubChem → 知识点 → 讲解
  List<AgentStep> _planCompoundExplain(ParsedInput input) {
    final hasSmiles = input.smiles != null && input.smiles!.trim().isNotEmpty;
    return [
      if (!hasSmiles)
        AgentStep(
          id: 'pubchem_by_name',
          name: '按名称查询化合物',
          description: '从 PubChem 解析名称为 SMILES',
          toolName: 'pubchem',
          toolInput: {'smiles': input.name ?? ''},
        ),
      AgentStep(
        id: 'pubchem',
        name: '查询化合物详情',
        description: '获取分子式、分子量、IUPAC 名',
        toolName: 'pubchem',
        toolInput: {
          'smiles': hasSmiles ? input.smiles! : '@pubchem_by_name.canonicalSmiles',
        },
      ),
      AgentStep(
        id: 'knowledge',
        name: '匹配教材知识点',
        description: '关联官能团到教材章节',
        toolName: 'knowledge',
        toolInput: {
          'smiles': hasSmiles ? input.smiles! : '@pubchem_by_name.canonicalSmiles',
        },
      ),
      AgentStep(
        id: 'explain',
        name: '生成讲解',
        description: '讲解官能团、性质、反应、教材章节',
        toolName: 'llm',
        toolInput: const {
          'templateAsset': 'agent_compound_explain.txt',
          'compoundInfo': '@pubchem',
          'knowledgePoints': '@knowledge',
          'userInput': '@userInput',
          'userStage': '@userStage',
        },
      ),
    ];
  }

  /// 学情诊断:加载画像 → 分析薄弱点 → 生成报告
  List<AgentStep> _planDiagnosis(ParsedInput input) => [
        AgentStep(
          id: 'knowledge',
          name: '加载薄弱知识点',
          description: '从历史学习记录聚合掌握度并查详情',
          toolName: 'knowledge',
          toolInput: const {'kpIds': '@profile.weakPoints'},
        ),
        AgentStep(
          id: 'explain',
          name: '生成学情报告',
          description: '分析薄弱知识点、提出改进建议',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_diagnosis.txt',
            'knowledgePoints': '@knowledge',
            'masterySummary': '@profile',
            'totalScans': '@profile.totalScans',
            'totalPractice': '@profile.totalPractice',
            'correctCount': '@profile.correctCount',
            'streakDays': '@profile.streakDays',
            'userStage': '@userStage',
          },
        ),
      ];

  /// 个性化学习规划:基于学情生成学习路径
  List<AgentStep> _planLearning(ParsedInput input) => [
        AgentStep(
          id: 'knowledge',
          name: '加载薄弱知识点',
          description: '识别已掌握与薄弱知识点并查详情',
          toolName: 'knowledge',
          toolInput: const {'kpIds': '@profile.weakPoints'},
        ),
        AgentStep(
          id: 'explain',
          name: '生成学习规划',
          description: '基于薄弱点生成学习路径和优先级',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_planning.txt',
            'knowledgePoints': '@knowledge',
            'masterySummary': '@profile',
            'userStage': '@userStage',
          },
        ),
      ];

  /// 同类题训练:基于官能团生成练习题
  List<AgentStep> _planPractice(ParsedInput input) => [
        if (input.smiles != null && input.smiles!.isNotEmpty)
          AgentStep(
            id: 'knowledge',
            name: '匹配知识点',
            description: '识别相关官能团和教材章节',
            toolName: 'knowledge',
            toolInput: {'smiles': input.smiles},
          ),
        AgentStep(
          id: 'explain',
          name: '生成练习题',
          description: '基于知识点生成同类练习题',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_practice.txt',
            'knowledgePoints': '@knowledge',
            'userInput': '@userInput',
            'userStage': '@userStage',
          },
        ),
      ];

  /// 错因分析:对比用户绘制 vs 标准结构
  List<AgentStep> _planErrorAnalysis(ParsedInput input) => [
        AgentStep(
          id: 'ocr',
          name: '识别用户绘制',
          description: '从用户拍照/绘制中识别 SMILES',
          toolName: 'ocsr',
          toolInput: {'dataUri': input.dataUri ?? ''},
        ),
        AgentStep(
          id: 'knowledge',
          name: '匹配标准知识点',
          description: '关联到教材章节作为对比基准',
          toolName: 'knowledge',
          toolInput: const {'smiles': '@ocr.smiles'},
        ),
        AgentStep(
          id: 'explain',
          name: '分析错因',
          description: '对比标准结构,定位错误官能团',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_error_analysis.txt',
            'smiles': '@ocr.smiles',
            'knowledgePoints': '@knowledge',
            'userInput': '@userInput',
            'userStage': '@userStage',
          },
        ),
      ];

  /// 自由对话:直接调用 LLM
  List<AgentStep> _planChat(ParsedInput input) => [
        AgentStep(
          id: 'explain',
          name: '生成回复',
          description: '多轮对话式学习陪伴',
          toolName: 'llm',
          toolInput: const {
            'templateAsset': 'agent_chat.txt',
            'userInput': '@userInput',
            'userStage': '@userStage',
          },
        ),
      ];
}
