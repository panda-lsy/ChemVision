import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/learning_record.dart';

/// 学习记录服务 — 持久化用户学习行为,供学情诊断 Agent 使用
///
/// 记录类型:扫描(scan)、查询(query)、练习(practice/practiceWrong)、
/// 复习(review)、标记掌握(mastered)。
///
/// 对应赛题: "学情诊断 Agent:基于练习记录...识别学生知识薄弱点,
///           生成学情分析报告和改进建议"
class LearningRecordService {
  static const _boxName = 'learning_records';
  static const _maxItems = 500;
  late Box<LearningRecord> _box;

  Future<void> init() async {
    _box = await Hive.openBox<LearningRecord>(_boxName);
  }

  Future<void> add(LearningRecord record) async {
    await _box.put(record.id, record);
    if (_box.length > _maxItems) {
      // 保留最新的 _maxItems 条
      final sorted = getAll();
      for (var i = _maxItems; i < sorted.length; i++) {
        await _box.delete(sorted[i].id);
      }
    }
    await _box.flush();
  }

  /// 从扫描识别快速记录一条 scan 类型
  Future<void> recordScan({
    required String scanHistoryId,
    required String smiles,
    required String compoundName,
    List<String> knowledgePointIds = const [],
  }) async {
    final record = LearningRecord.fromScan(
      scanHistoryId: scanHistoryId,
      smiles: smiles,
      compoundName: compoundName,
      knowledgePointIds: knowledgePointIds,
    );
    await add(record);
  }

  /// 记录练习结果(影响掌握度)
  Future<void> recordPractice({
    required String smiles,
    required String compoundName,
    required bool correct,
    List<String> knowledgePointIds = const [],
    String? notes,
  }) async {
    final record = LearningRecord(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      scanHistoryId: '',
      smiles: smiles,
      compoundName: compoundName,
      action: correct ? LearningAction.practice : LearningAction.practiceWrong,
      createdAt: DateTime.now(),
      knowledgePointIds: knowledgePointIds,
      notes: notes,
      masteryDelta: correct ? 0.15 : -0.1,
    );
    await add(record);
  }

  /// 记录查询行为
  Future<void> recordQuery({
    required String smiles,
    required String compoundName,
    List<String> knowledgePointIds = const [],
  }) async {
    final record = LearningRecord(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      scanHistoryId: '',
      smiles: smiles,
      compoundName: compoundName,
      action: LearningAction.query,
      createdAt: DateTime.now(),
      knowledgePointIds: knowledgePointIds,
    );
    await add(record);
  }

  List<LearningRecord> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// 按知识点 ID 聚合记录
  Map<String, List<LearningRecord>> byKnowledgePoint() {
    final result = <String, List<LearningRecord>>{};
    for (final r in getAll()) {
      for (final kpId in r.knowledgePointIds) {
        result.putIfAbsent(kpId, () => []).add(r);
      }
    }
    return result;
  }

  /// 获取某时间段内的记录
  List<LearningRecord> inRange(DateTime start, DateTime end) =>
      getAll().where((r) =>
          !r.createdAt.isBefore(start) && !r.createdAt.isAfter(end)).toList();

  /// 按行为类型过滤
  List<LearningRecord> byAction(LearningAction action) =>
      getAll().where((r) => r.action == action).toList();

  Future<void> delete(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _box.flush();
  }

  int get count => _box.length;

  /// 调试输出
  void debugDump() {
    if (!kDebugMode) return;
    final all = getAll();
    debugPrint('[$runtimeType] 共 ${all.length} 条记录');
    for (final r in all.take(10)) {
      debugPrint(
          '  ${r.createdAt} | ${r.action.name} | ${r.compoundName} | kp=${r.knowledgePointIds}');
    }
  }
}
