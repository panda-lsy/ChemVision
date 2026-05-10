import 'package:hive/hive.dart';

/// 搜索历史服务
class SearchHistoryService {
  static const String _boxName = 'search_history';
  Box<String>? _box;
  bool _initialized = false;

  /// 确保初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _box = await Hive.openBox<String>(_boxName);
      _initialized = true;
    }
  }

  /// 初始化（可选，会在首次使用时自动初始化）
  Future<void> init() async {
    await _ensureInitialized();
  }

  /// 添加搜索记录
  Future<void> add(String query) async {
    await _ensureInitialized();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    // 移除已存在的相同记录
    await remove(trimmed);

    // 添加到开头
    await _box!.put(0, trimmed);

    // 移动其他记录
    final existing = getAll();
    for (var i = 0; i < existing.length; i++) {
      if (existing[i] != trimmed) {
        await _box!.put(i + 1, existing[i]);
      }
    }

    // 限制最多保存 20 条
    if (_box!.length > 20) {
      await _box!.deleteAt(_box!.length - 1);
    }
  }

  /// 删除搜索记录
  Future<void> remove(String query) async {
    await _ensureInitialized();
    final index = _box!.values.toList().indexOf(query);
    if (index != -1) {
      await _box!.deleteAt(index);
    }
  }

  /// 清空所有记录
  Future<void> clear() async {
    await _ensureInitialized();
    await _box!.clear();
  }

  /// 获取所有记录
  List<String> getAll() {
    if (!_initialized || _box == null) {
      return [];
    }
    return _box!.values.toList();
  }

  /// 获取记录数量
  int get count {
    if (!_initialized || _box == null) {
      return 0;
    }
    return _box!.length;
  }
}
