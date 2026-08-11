import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../models/error_book_item.dart';

/// 错题本服务 — Hive 持久化错题收藏
class ErrorBookService {
  static const _boxName = 'error_book';
  static const _maxItems = 100;

  Box<ErrorBookItem>? _box;

  /// 初始化,userId 用作 box 名前缀实现多用户数据隔离
  Future<void> init({String userId = 'default'}) async {
    _box = await Hive.openBox<ErrorBookItem>('${userId}_$_boxName');
    if (kDebugMode) {
      debugPrint('[ErrorBookService] 已加载(userId=$userId) ${_box!.length} 条错题');
    }
  }

  bool get isInitialized => _box != null;

  Future<void> add(ErrorBookItem item) async {
    final box = _box;
    if (box == null) return;
    await box.put(item.id, item);
    if (box.length > _maxItems) {
      final sorted = getAll();
      for (var i = _maxItems; i < sorted.length; i++) {
        await box.delete(sorted[i].id);
      }
    }
    await box.flush();
  }

  List<ErrorBookItem> getAll() {
    final box = _box;
    if (box == null) return const [];
    final list = box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  ErrorBookItem? getById(String id) => _box?.get(id);

  Future<void> update(ErrorBookItem item) async {
    await _box?.put(item.id, item);
    await _box?.flush();
  }

  Future<void> delete(String id) async {
    await _box?.delete(id);
    await _box?.flush();
  }

  Future<void> clearAll() async {
    await _box?.clear();
    await _box?.flush();
  }
}

/// Provider — 由 main.dart override 注入实例
final errorBookServiceProvider = Provider<ErrorBookService>((ref) {
  return ErrorBookService();
});
