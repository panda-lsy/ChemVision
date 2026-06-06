import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../models/reaction_favorite_item.dart';

class ReactionFavoritesService {
  static const _boxName = 'reaction_favorites';
  late Box<ReactionFavoriteItem> _box;

  Future<void> init() async {
    _box = await Hive.openBox<ReactionFavoriteItem>(_boxName);
    debugPrint('[ReactionFavoritesService] 初始化完成，当前数：${_box.length}');
  }

  Future<void> add(ReactionFavoriteItem item) async {
    await _box.put(item.id, item);
    await _box.flush();
  }

  Future<void> update(ReactionFavoriteItem item) async {
    await _box.put(item.id, item);
    await _box.flush();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    await _box.flush();
  }

  ReactionFavoriteItem? get(String id) => _box.get(id);

  List<ReactionFavoriteItem> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<ReactionFavoriteItem> search(String query) {
    final q = query.toLowerCase();
    return getAll().where((item) {
      final eq = item.equation;
      return eq.title.toLowerCase().contains(q) ||
          eq.conditionSummary.toLowerCase().contains(q) ||
          item.tags.any((t) => t.toLowerCase().contains(q)) ||
          (item.notes?.toLowerCase().contains(q) == true);
    }).toList();
  }

  List<String> getAllCategories() {
    return _box.values
        .map((item) => item.category)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
  }

  List<String> getAllTags() {
    return _box.values
        .expand((item) => item.tags)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  int get count => _box.length;

  String exportToJson() {
    final items = getAll();
    return jsonEncode(items.map((i) => i.toJson()).toList());
  }

  Future<void> clearAll() async {
    await _box.clear();
    await _box.flush();
  }
}
