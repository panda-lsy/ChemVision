import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/learning_profile.dart';
import '../models/learning_record.dart';
import '../services/chemical_knowledge_base.dart';
import '../services/learning_record_service.dart';
import '../services/user_service.dart';

/// 学习记录服务 Provider(由 main.dart override 注入实例)
final learningRecordServiceProvider = Provider<LearningRecordService>((ref) {
  return LearningRecordService();
});

/// 学情画像状态
class LearningProfileState {
  const LearningProfileState({
    this.profile,
    this.isLoading = true,
  });

  final LearningProfile? profile;
  final bool isLoading;

  LearningProfileState copyWith({
    LearningProfile? profile,
    bool? isLoading,
  }) {
    return LearningProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 学情画像控制器 — 聚合学习记录,计算掌握度
///
/// 掌握度算法(简化版):
/// - 每次扫描/查询某知识点 → +0.05(接触但不深入)
/// - 练习答对 → +0.15(掌握度提升)
/// - 练习答错 → -0.10(暴露薄弱)
/// - 标记掌握 → 直接设为 0.95
/// - 掌握度范围 [0.0, 1.0]
class LearningProfileController
    extends StateNotifier<LearningProfileState> {
  LearningProfileController(this._service, this._userService)
      : super(const LearningProfileState()) {
    _rebuild();
  }

  final LearningRecordService _service;
  final UserService _userService;

  /// 重新计算学情画像
  void _rebuild() {
    final records = _service.getAll();
    final profile = _computeProfile(records);
    state = LearningProfileState(profile: profile, isLoading: false);
  }

  /// 从学习记录聚合画像
  LearningProfile _computeProfile(List<LearningRecord> records) {
    final mastery = <String, double>{};
    var totalScans = 0;
    var totalQueries = 0;
    var totalPractice = 0;
    var correctCount = 0;
    final activeDays = <String>{};

    for (final r in records) {
      final dayKey =
          '${r.createdAt.year}-${r.createdAt.month}-${r.createdAt.day}';
      activeDays.add(dayKey);

      switch (r.action) {
        case LearningAction.scan:
          totalScans++;
          break;
        case LearningAction.query:
          totalQueries++;
          break;
        case LearningAction.practice:
          totalPractice++;
          correctCount++;
          break;
        case LearningAction.practiceWrong:
          totalPractice++;
          break;
        case LearningAction.review:
          break;
        case LearningAction.mastered:
          break;
      }

      // 累计知识点掌握度
      for (final kpId in r.knowledgePointIds) {
        mastery[kpId] = (mastery[kpId] ?? 0) + r.masteryDelta;
      }
    }

    // clamp 到 [0, 1]
    final clamped = mastery.map((k, v) => MapEntry(k, v.clamp(0.0, 1.0)));

    // 连续学习天数(简化:有记录的不同日期数)
    final streak = activeDays.length;

    final firstRecord = records.isNotEmpty
        ? records.reduce((a, b) =>
            a.createdAt.isBefore(b.createdAt) ? a : b).createdAt
        : DateTime.now();

    return LearningProfile(
      userId: _userService.currentUserId,
      stage: _userService.currentUser?.stage ?? 'highschool',
      knowledgeMastery: clamped,
      totalScans: totalScans,
      totalQueries: totalQueries,
      totalPractice: totalPractice,
      correctCount: correctCount,
      lastActiveAt: records.isNotEmpty ? records.first.createdAt : DateTime.now(),
      createdAt: firstRecord,
      streakDays: streak,
      totalLearningDays: streak,
    );
  }

  /// 添加学习记录并刷新画像
  Future<void> addRecord(LearningRecord record) async {
    await _service.add(record);
    _rebuild();
  }

  /// 记录扫描并关联知识点
  Future<void> recordScan({
    required String scanHistoryId,
    required String smiles,
    required String compoundName,
    List<String> knowledgePointIds = const [],
  }) async {
    await _service.recordScan(
      scanHistoryId: scanHistoryId,
      smiles: smiles,
      compoundName: compoundName,
      knowledgePointIds: knowledgePointIds,
    );
    _rebuild();
  }

  /// 记录练习结果
  Future<void> recordPractice({
    required String smiles,
    required String compoundName,
    required bool correct,
    List<String> knowledgePointIds = const [],
    String? notes,
  }) async {
    await _service.recordPractice(
      smiles: smiles,
      compoundName: compoundName,
      correct: correct,
      knowledgePointIds: knowledgePointIds,
      notes: notes,
    );
    _rebuild();
  }

  /// 标记知识点已掌握
  Future<void> markMastered(String knowledgePointId) async {
    final record = LearningRecord(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      scanHistoryId: '',
      smiles: '',
      compoundName: '',
      action: LearningAction.mastered,
      createdAt: DateTime.now(),
      knowledgePointIds: [knowledgePointId],
      masteryDelta: 0.95,
    );
    await _service.add(record);
    _rebuild();
  }

  /// 刷新(从存储重新加载)
  void refresh() => _rebuild();

  /// 获取薄弱知识点的详细信息
  List<Map<String, dynamic>> weakPointsDetail() {
    final profile = state.profile;
    if (profile == null) return [];
    return profile.weakPoints.map((id) {
      final kp = ChemicalKnowledgeBase.pointMap[id];
      return {
        'id': id,
        'name': kp?.name ?? id,
        'mastery': profile.knowledgeMastery[id] ?? 0,
        'category': kp?.category ?? '',
        'chapter': kp?.chapter ?? '',
      };
    }).toList();
  }
}

final learningProfileControllerProvider = StateNotifierProvider<
    LearningProfileController, LearningProfileState>((ref) {
  final service = ref.watch(learningRecordServiceProvider);
  final userService = ref.watch(userServiceProvider);
  return LearningProfileController(service, userService);
}, dependencies: [learningRecordServiceProvider, userServiceProvider]);
