import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/favorite_item.dart';
import '../utils/sdf_export.dart';

class FavoritesService {
  static const _boxName = 'favorites';
  late Box<FavoriteItem> _box;

  Future<void> init() async {
    _box = await Hive.openBox<FavoriteItem>(_boxName);
    debugPrint('[FavoritesService] 初始化完成，当前收藏数：${_box.length}');
  }

  Future<void> add(FavoriteItem item) async {
    // 去重：如果已存在相同 SMILES 的收藏，则更新而不是新增
    final existing = _box.values.firstWhere(
      (i) => i.structureResult.smiles == item.structureResult.smiles,
      orElse: () => item,
    );
    
    if (existing.id != item.id) {
      // 已存在相同结构，更新它（保留原 ID 和创建时间）
      final updated = FavoriteItem(
        id: existing.id,
        structureResult: item.structureResult,
        createdAt: existing.createdAt,
        category: item.category ?? existing.category,
        query: item.query,
      );
      await _box.put(existing.id, updated);
      debugPrint('[FavoritesService] 更新收藏：${updated.query}');
    } else {
      // 新收藏
      await _box.put(item.id, item);
      debugPrint('[FavoritesService] 添加新收藏：${item.query}');
    }
    
    // 确保数据立即持久化（特别是 Web 平台）
    await _box.flush();
    debugPrint('[FavoritesService] 数据已持久化，当前收藏数：${_box.length}');
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    // 确保数据立即持久化（特别是 Web 平台）
    await _box.flush();
  }

  FavoriteItem? get(String id) => _box.get(id);

  List<FavoriteItem> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<FavoriteItem> search(String query) {
    final q = query.toLowerCase();
    return getAll().where((item) {
      final r = item.structureResult;
      return r.resolvedName?.toLowerCase().contains(q) == true ||
          r.englishName?.toLowerCase().contains(q) == true ||
          r.chineseName?.toLowerCase().contains(q) == true ||
          r.molecularFormula.toLowerCase().contains(q) ||
          item.query.toLowerCase().contains(q);
    }).toList();
  }

  List<FavoriteItem> getByCategory(String category) {
    return getAll().where((item) => item.category == category).toList();
  }

  List<String> getAllCategories() {
    final cats = _box.values
        .map((item) => item.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return cats;
  }

  int get count => _box.length;

  String exportToSdf(List<FavoriteItem> items) {
    return SdfExportUtil.generateSdf(items);
  }

  String exportToMol(FavoriteItem item) {
    return SdfExportUtil.generateMolBlock(item.structureResult);
  }
}
