import 'package:hive/hive.dart';

import '../models/edit_history_item.dart';

class EditHistoryService {
  static const _boxName = 'edit_history';
  static const _maxItems = 50;
  late Box<EditHistoryItem> _box;

  /// 初始化,userId 用作 box 名前缀实现多用户数据隔离
  Future<void> init({String userId = 'default'}) async {
    _box = await Hive.openBox<EditHistoryItem>('${userId}_$_boxName');
  }

  Future<void> add(EditHistoryItem item) async {
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

  List<EditHistoryItem> getAll() => _box.values.toList()
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
