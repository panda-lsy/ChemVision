import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/structure_result.dart';

class StructureCacheStore {
  static const String _prefix = 'structure_cache_';

  Future<StructureResult?> get(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(query);
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final result = StructureResult.fromJson(decoded);
        if (result.smiles.trim().isNotEmpty && result.isValid) {
          return result;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> set(String query, StructureResult result) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _buildKey(query);
    final payload = jsonEncode(result.toJson());
    await prefs.setString(key, payload);
  }

  String _buildKey(String query) {
    final normalized = query.trim().toLowerCase();
    final encoded = base64UrlEncode(utf8.encode(normalized));
    return '$_prefix$encoded';
  }
}
