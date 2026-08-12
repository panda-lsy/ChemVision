import 'package:hive/hive.dart';

/// 搜索历史服务
class SearchHistoryService {
  static const String _boxName = 'search_history';
  Box<String>? _box;
  bool _initialized = false;
  String _userId = 'default';

  /// 确保初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _box = await Hive.openBox<String>('${_userId}_$_boxName');
      _initialized = true;
    }
  }

  /// 初始化,userId 用作 box 名前缀实现多用户数据隔离
  Future<void> init({String userId = 'default'}) async {
    _userId = userId;
    _initialized = false;
    await _ensureInitialized();
  }

  Future<void> _writeAll(List<String> items) async {
    await _ensureInitialized();
    await _box!.clear();
    for (var i = 0; i < items.length; i++) {
      await _box!.put(i, items[i]);
    }
  }

  /// 添加搜索记录
  Future<List<String>> add(String query) async {
    await _ensureInitialized();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return getAll();

    final items = getAll();
    items.removeWhere((item) => item == trimmed);
    items.insert(0, trimmed);
    if (items.length > 20) {
      items.removeRange(20, items.length);
    }

    await _writeAll(items);
    return items;
  }

  /// 删除搜索记录
  Future<List<String>> remove(String query) async {
    await _ensureInitialized();
    final items = getAll()..removeWhere((item) => item == query);
    await _writeAll(items);
    return items;
  }

  /// 清空所有记录
  Future<List<String>> clear() async {
    await _ensureInitialized();
    await _box!.clear();
    return const [];
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
