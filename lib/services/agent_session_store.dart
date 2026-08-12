import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/agent_session_record.dart';
import '../models/agent_task.dart';

/// Agent 会话存储服务 — Hive 持久化历史对话
///
/// 设计参考 [ScanHistoryService]:
/// - 以 taskId 为 key 存储 [AgentSessionRecord]
/// - 最多保留 [_maxRecords] 条,超出时删最旧的
/// - 仅持久化终态(completed/failed/cancelled),执行中状态不写入
class AgentSessionStore {
  static const _boxName = 'agent_sessions';
  static const _maxRecords = 50;

  Box<AgentSessionRecord>? _box;

  /// 初始化,userId 用作 box 名前缀实现多用户数据隔离
  ///
  /// 如果 box 中存在旧版本/损坏数据,自动清理后重建空 box。
  Future<void> init({String userId = 'default'}) async {
    final boxName = '${userId}_$_boxName';
    try {
      _box = await Hive.openBox<AgentSessionRecord>(boxName);
      // 触发一次 values 读取,检测是否有损坏记录
      _box!.values.toList();
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] 已加载(userId=$userId) ${_box!.length} 条历史会话');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] 打开 box 失败,清理重建: $e');
      }
      // 损坏数据:删除 box 后重建
      await Hive.deleteBoxFromDisk(boxName);
      _box = await Hive.openBox<AgentSessionRecord>(boxName);
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] 已重建空 box(userId=$userId)');
      }
    }
  }

  bool get isInitialized => _box != null;

  /// 保存一条会话记录(任务完成后调用)
  ///
  /// 仅当任务处于终态时才写入,避免把执行中的中间态持久化。
  Future<void> save(AgentTask task) async {
    final box = _box;
    if (box == null) {
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] save 失败: box 未初始化');
      }
      return;
    }
    if (!_isTerminal(task.status)) return;

    try {
      final record = AgentSessionRecord.fromTask(task);
      await box.put(record.id, record);

      // 超出上限时删除最旧的
      if (box.length > _maxRecords) {
        final sorted = getAll();
        for (var i = _maxRecords; i < sorted.length; i++) {
          await box.delete(sorted[i].id);
        }
      }
      await box.flush();

      if (kDebugMode) {
        debugPrint(
            '[AgentSessionStore] 已保存会话 ${record.id} (${record.typeLabel})');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] save 异常: $e\n$st');
      }
    }
  }

  /// 追问合并到已有会话记录(同一条历史记录)
  ///
  /// 将追问的 Q&A 作为新 section 追加到原记录,
  /// 同时更新 userInput 包含所有追问问题。
  Future<void> saveFollowUp({
    required String sessionId,
    required AgentTask followUpTask,
  }) async {
    final box = _box;
    if (box == null) {
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] saveFollowUp 失败: box 未初始化');
      }
      return;
    }
    if (!_isTerminal(followUpTask.status)) return;

    try {
      final existing = box.get(sessionId);
      if (existing == null) {
        // 原记录不存在,直接保存为新记录
        await save(followUpTask);
        return;
      }

      final followUpRecord = AgentSessionRecord.fromTask(followUpTask);

      // 把追问结果拼成一个 section
      final followUpContent = followUpRecord.sections.isNotEmpty
          ? followUpRecord.sections
              .map((s) => '### ${s.title}\n${s.content}')
              .join('\n\n')
          : (followUpRecord.resultSummary ?? '');

      final updatedSections = [
        ...existing.sections,
        AgentSessionSection(
          title: '追问: ${followUpTask.userInput}',
          content: followUpContent,
          typeName: 'text',
        ),
      ];

      final updated = AgentSessionRecord(
        id: sessionId,
        type: existing.type,
        status: followUpTask.status,
        userInput: '${existing.userInput}\n\n[追问] ${followUpTask.userInput}',
        createdAt: existing.createdAt,
        resultTitle: followUpRecord.resultTitle ?? existing.resultTitle,
        resultSummary: followUpRecord.resultSummary ?? existing.resultSummary,
        sections: updatedSections,
        safetyNotice: followUpRecord.safetyNotice ?? existing.safetyNotice,
        error: followUpRecord.error,
        relatedKnowledgePointIds: {
          ...existing.relatedKnowledgePointIds,
          ...followUpRecord.relatedKnowledgePointIds,
        }.toList(),
      );

      await box.put(sessionId, updated);
      await box.flush();

      if (kDebugMode) {
        debugPrint('[AgentSessionStore] 追问已合并到会话 $sessionId');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AgentSessionStore] saveFollowUp 异常: $e\n$st');
      }
    }
  }

  /// 读取全部历史(按时间倒序)
  List<AgentSessionRecord> getAll() {
    final box = _box;
    if (box == null) return const [];
    final list = box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// 按 ID 单条查询(用于回看详情)
  AgentSessionRecord? getById(String id) => _box?.get(id);

  /// 删除单条
  Future<void> delete(String id) async {
    await _box?.delete(id);
    await _box?.flush();
  }

  /// 清空全部历史
  Future<void> clearAll() async {
    await _box?.clear();
    await _box?.flush();
  }

  /// 是否为终态(可安全持久化)
  bool _isTerminal(AgentTaskStatus status) =>
      status == AgentTaskStatus.completed ||
      status == AgentTaskStatus.failed ||
      status == AgentTaskStatus.cancelled;
}

/// Provider — 由 main.dart override 注入实例
final agentSessionStoreProvider = Provider<AgentSessionStore>((ref) {
  return AgentSessionStore();
});
