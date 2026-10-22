import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chemvision/models/agent_task.dart';
import 'package:chemvision/models/learning_profile.dart';
import 'package:chemvision/models/learning_record.dart';
import 'package:chemvision/providers/agent_provider.dart';
import 'package:chemvision/providers/learning_profile_provider.dart';
import 'package:chemvision/services/agent/agent_orchestrator.dart';
import 'package:chemvision/services/agent/agent_tool.dart';
import 'package:chemvision/services/agent/task_planner.dart';
import 'package:chemvision/services/learning_record_service.dart';
import 'package:chemvision/services/agent_session_store.dart';
import 'package:chemvision/services/user_service.dart';
import 'package:chemvision/services/real_structure_service.dart';
import 'package:chemvision/services/structure_cache_store.dart';
import 'package:chemvision/models/structure_result.dart';
import 'package:chemvision/utils/smiles_validator.dart';

class CallbackTool extends AgentTool {
  CallbackTool(String name, this.callback) : super(name, 'test fixture');
  final Future<ToolResult> Function(Map<String, dynamic>) callback;
  @override
  Future<ToolResult> invoke(Map<String, dynamic> params) => callback(params);
}

class RecordingService extends LearningRecordService {
  int practiceWrites = 0;
  final queries = <List<String>>[];
  @override
  List<LearningRecord> getAll() => [];
  @override
  Future<void> recordPractice({
    required String smiles,
    required String compoundName,
    required bool correct,
    List<String> knowledgePointIds = const [],
    String? notes,
  }) async => practiceWrites++;

  @override
  Future<void> recordQuery({
    required String smiles,
    required String compoundName,
    List<String> knowledgePointIds = const [],
  }) async => queries.add(knowledgePointIds);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('化学表示与缓存', () {
    for (final smiles in [
      'CCO',
      'c1ccccc1',
      'C(=O)O',
      '[Na+].[Cl-]',
      '[13CH4]',
      'C%12CCCCC%12',
    ]) {
      test('接受基础语法 $smiles', () {
        expect(SmilesValidator.validate(smiles).isValid, isTrue);
      });
    }
    for (final smiles in [
      '',
      'C(',
      'C1CC',
      'C==O',
      'C.',
      '[Invalid]',
      'C11',
      'C(=)O',
    ]) {
      test('拒绝明显语法错误 $smiles', () {
        expect(SmilesValidator.validate(smiles).isValid, isFalse);
      });
    }
    test('反向解析在发出网络请求前拒绝无效 SMILES', () async {
      final result = await NameToStructureService().reverseResolveName('C==O');
      expect(result.isValid, isFalse);
    });
    test('芳香原子大小写不同的 SMILES 不得命中同一缓存', () async {
      final store = StructureCacheStore();
      await store.set(
        'c1ccccc1',
        const StructureResult(
          smiles: 'c1ccccc1',
          molecularFormula: 'C6H6',
          molecularWeight: 78.11,
          isValid: true,
          confidence: 1,
        ),
        mode: 'reverse_smiles',
      );
      expect(await store.get('C1CCCCC1', mode: 'reverse_smiles'), isNull);
      expect(
        (await store.get('c1ccccc1', mode: 'reverse_smiles'))?.molecularFormula,
        'C6H6',
      );
    });
  });

  group('任务路由', () {
    const planner = TaskPlanner();
    test('带结构的出题请求进入练习流程', () {
      final parsed = planner.parseInput(userInput: '为这个结构出题', smiles: 'CCO');
      expect(parsed.taskType, AgentTaskType.practice);
      expect(planner.planFor(parsed).first.toolName, 'knowledge');
    });
    test('带图片的错因请求进入错因流程', () {
      expect(
        planner
            .parseInput(
              userInput: '请分析错因',
              dataUri: 'data:image/png;base64,AA==',
            )
            .taskType,
        AgentTaskType.errorAnalysis,
      );
    });
    test('普通图片仍进入作业辅导', () {
      expect(
        planner.parseInput(userInput: '请辅导', dataUri: 'image').taskType,
        AgentTaskType.homeworkTutor,
      );
    });
  });

  group('Agent 编排与证据真实性（工具桩，无远程 AI）', () {
    test('诊断模型获得画像摘要，不含用户标识', () async {
      Map<String, dynamic>? llmInput;
      final registry = ToolRegistry([
        CallbackTool(
          'knowledge',
          (p) async => ToolResult.success({'points': []}),
        ),
        CallbackTool('llm', (p) async {
          llmInput = p;
          return ToolResult.success({'text': '测试诊断文本'});
        }),
      ]);
      final profile = LearningProfile.empty().copyWith(
        knowledgeMastery: {'kp_organic_alcohol': 0.25},
        totalPractice: 2,
        correctCount: 1,
      );
      final result = await AgentOrchestrator(
        registry: registry,
      ).run(userInput: '学情诊断', profile: profile);
      expect(result.status, AgentTaskStatus.completed);
      final summary = jsonDecode(llmInput!['masterySummary'] as String) as Map;
      expect(summary['knowledgeMastery']['kp_organic_alcohol'], 0.25);
      expect(summary['totalPractice'], 2);
      expect(summary.containsKey('userId'), isFalse);
    });

    test('生成练习题不等于答对，不写入虚假答题记录', () async {
      final records = RecordingService();
      final registry = ToolRegistry([
        CallbackTool(
          'llm',
          (p) async => ToolResult.success({'text': '请写出乙醇的官能团。'}),
        ),
      ]);
      final result = await AgentOrchestrator(
        registry: registry,
        recordService: records,
      ).run(userInput: '请出题');
      expect(result.status, AgentTaskStatus.completed);
      expect(records.practiceWrites, 0);
    });

    test('结构查询→知识点→讲解→真实查询记录', () async {
      final records = RecordingService();
      final calls = <String>[];
      final registry = ToolRegistry([
        CallbackTool('pubchem', (p) async {
          calls.add('pubchem');
          expect(p['smiles'], 'CCO');
          return ToolResult.success({
            'canonicalSmiles': 'CCO',
            'englishName': 'ethanol',
            'formula': 'C2H6O',
          });
        }),
        CallbackTool('knowledge', (p) async {
          calls.add('knowledge');
          expect(p['smiles'], 'CCO');
          return ToolResult.success({
            'points': [
              {'id': 'kp_organic_alcohol', 'name': '醇', 'chapter': '测试章节'},
            ],
          });
        }),
        CallbackTool('llm', (p) async {
          calls.add('llm');
          expect(p['compoundInfo'], contains('ethanol'));
          expect(p['knowledgePoints'], contains('kp_organic_alcohol'));
          return ToolResult.success({'text': '乙醇含羟基。测试桩输出，不代表模型评测。'});
        }),
      ]);
      final result = await AgentOrchestrator(
        registry: registry,
        recordService: records,
      ).run(userInput: '讲解乙醇', smiles: 'CCO');
      expect(calls, ['pubchem', 'knowledge', 'llm']);
      expect(result.status, AgentTaskStatus.completed);
      expect(records.queries.single, ['kp_organic_alcohol']);
      expect(result.result!.safetyNotice, isNotEmpty);
    });

    test('OCSR 失败中止，不能向模型传递虚构结构', () async {
      var llmCalls = 0;
      final registry = ToolRegistry([
        CallbackTool('ocsr', (p) async => ToolResult.failure('测试识别失败')),
        CallbackTool('llm', (p) async {
          llmCalls++;
          return ToolResult.success({'text': '不应执行'});
        }),
      ]);
      final result = await AgentOrchestrator(
        registry: registry,
      ).run(userInput: '辅导', dataUri: 'image');
      expect(result.status, AgentTaskStatus.failed);
      expect(llmCalls, 0);
    });
    test('LLM 失败不能标记成功', () async {
      final result = await AgentOrchestrator(
        registry: ToolRegistry([
          CallbackTool('llm', (p) async => ToolResult.failure('测试上游不可用')),
        ]),
      ).run(userInput: '你好');
      expect(result.status, AgentTaskStatus.failed);
      expect(result.result, isNull);
    });
    test('已有会话后选择新结构仍执行完整工具链，普通追问复用上下文', () async {
      final records = RecordingService();
      final profile = LearningProfileController(records, UserService());
      var chemistryCalls = 0;
      final registry = ToolRegistry([
        CallbackTool('pubchem', (p) async {
          chemistryCalls++;
          return ToolResult.success({'canonicalSmiles': p['smiles']});
        }),
        CallbackTool(
          'knowledge',
          (p) async => ToolResult.success({'points': []}),
        ),
        CallbackTool('llm', (p) async => ToolResult.success({'text': '测试回答'})),
      ]);
      final controller = AgentController(
        AgentOrchestrator(registry: registry),
        profile,
        AgentSessionStore(),
      );
      addTearDown(controller.dispose);
      addTearDown(profile.dispose);
      await controller.runTask(userInput: '你好');
      expect(controller.state.hasActiveSession, isTrue);
      await controller.runTask(userInput: '讲解此结构', smiles: 'CCO');
      expect(controller.state.currentTask!.type, AgentTaskType.compoundExplain);
      expect(chemistryCalls, 1);
      await controller.runTask(userInput: '继续解释');
      expect(chemistryCalls, 1);
    });
  });
}
