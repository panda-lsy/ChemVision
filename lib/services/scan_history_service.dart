import 'package:hive/hive.dart';

import '../models/scan_history_item.dart';

/// 扫描历史服务 — 持久化 OCSR 识别记录(含原图)
class ScanHistoryService {
  static const _boxName = 'scan_history';
  static const _maxItems = 30;
  late Box<ScanHistoryItem> _box;

  Future<void> init() async {
    _box = await Hive.openBox<ScanHistoryItem>(_boxName);
  }

  Future<void> add(ScanHistoryItem item) async {
    await _box.put(item.id, item);
    // 超出上限时删除最旧的
    if (_box.length > _maxItems) {
      final sorted = getAll();
      for (var i = _maxItems; i < sorted.length; i++) {
        await _box.delete(sorted[i].id);
      }
    }
    await _box.flush();
  }

  List<ScanHistoryItem> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> delete(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _box.flush();
  }

  int get count => _box.length;
}
