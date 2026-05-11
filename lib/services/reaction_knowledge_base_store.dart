import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/reaction_completion_result.dart';

enum ImportDuplicateStrategy {
  overwrite,
  merge,
  skip,
}

class ReactionKnowledgeBaseStore {
  static const String _storageKey = 'reaction_knowledge_base_entries';

  Future<List<ReactionKnowledgeEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_storageKey) ?? const [];
    return rawList
        .map((item) {
          try {
            final data = jsonDecode(item);
            if (data is Map<String, dynamic>) {
              return ReactionKnowledgeEntry.fromJson(data);
            }
          } catch (_) {}
          return null;
        })
        .whereType<ReactionKnowledgeEntry>()
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  Future<void> saveAll(List<ReactionKnowledgeEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = entries.map((entry) => jsonEncode(entry.toJson())).toList();
    await prefs.setStringList(_storageKey, encoded);
  }

  Future<void> upsert(ReactionKnowledgeEntry entry) async {
    final items = await loadAll();
    items.removeWhere((item) => item.id == entry.id);
    items.add(entry);
    await saveAll(items);
  }

  Future<void> add(ReactionKnowledgeEntry entry) => upsert(entry);

  Future<void> upsertAll(List<ReactionKnowledgeEntry> entries) async {
    final current = await loadAll();
    final map = {for (final item in current) item.id: item};
    for (final entry in entries) {
      map[entry.id] = entry;
    }
    await saveAll(map.values.toList());
  }

  Future<void> remove(String id) async {
    final items = await loadAll();
    items.removeWhere((item) => item.id == id);
    await saveAll(items);
  }

  Future<void> removeMany(Iterable<String> ids) async {
    final idSet = ids.toSet();
    if (idSet.isEmpty) {
      return;
    }
    final items = await loadAll();
    items.removeWhere((item) => idSet.contains(item.id));
    await saveAll(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  Future<String> exportJson([List<ReactionKnowledgeEntry>? entries]) async {
    final exportEntries = entries ?? await loadAll();
    return jsonEncode({
      'version': 1,
      'entries': exportEntries.map((entry) => entry.toJson()).toList(),
    });
  }

  Future<int> importJson(
    String jsonText, {
    ImportDuplicateStrategy strategy = ImportDuplicateStrategy.merge,
  }) async {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 格式不正确');
    }
    final rawEntries = decoded['entries'];
    if (rawEntries is! List) {
      throw const FormatException('缺少 entries 字段');
    }

    final imported = rawEntries
        .whereType<Map>()
        .map((item) => ReactionKnowledgeEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .where((entry) => entry.id.isNotEmpty && entry.title.isNotEmpty)
        .toList();

    final current = await loadAll();
    final byId = <String, ReactionKnowledgeEntry>{
      for (final entry in current) entry.id: entry,
    };
    final bySemanticKey = <String, ReactionKnowledgeEntry>{
      for (final entry in current) _semanticKey(entry): entry,
    };

    var importedCount = 0;
    for (final entry in imported) {
      final existsById = byId.containsKey(entry.id);
      final semanticKey = _semanticKey(entry);
      final existsBySemantic = bySemanticKey.containsKey(semanticKey);
      final isDuplicate = existsById || existsBySemantic;

      if (!isDuplicate) {
        byId[entry.id] = entry;
        bySemanticKey[semanticKey] = entry;
        importedCount++;
        continue;
      }

      switch (strategy) {
        case ImportDuplicateStrategy.skip:
          continue;
        case ImportDuplicateStrategy.overwrite:
          final existing = existsById ? byId[entry.id] : bySemanticKey[semanticKey];
          if (existing != null) {
            byId.remove(existing.id);
            bySemanticKey.remove(_semanticKey(existing));
          }
          byId[entry.id] = entry;
          bySemanticKey[semanticKey] = entry;
          importedCount++;
          break;
        case ImportDuplicateStrategy.merge:
          final existing = existsById ? byId[entry.id] : bySemanticKey[semanticKey];
          if (existing == null) {
            byId[entry.id] = entry;
            bySemanticKey[semanticKey] = entry;
            importedCount++;
            break;
          }
          final merged = _mergeEntry(existing, entry);
          byId.remove(existing.id);
          bySemanticKey.remove(_semanticKey(existing));
          byId[merged.id] = merged;
          bySemanticKey[_semanticKey(merged)] = merged;
          importedCount++;
          break;
      }
    }

    await saveAll(byId.values.toList());
    return importedCount;
  }

  ReactionKnowledgeEntry _mergeEntry(
    ReactionKnowledgeEntry base,
    ReactionKnowledgeEntry incoming,
  ) {
    final keywordSet = <String>{...base.keywords, ...incoming.keywords};

    String pickText(String current, String candidate) {
      final currentText = current.trim();
      final candidateText = candidate.trim();
      if (candidateText.isEmpty) {
        return currentText;
      }
      if (currentText.isEmpty || candidateText.length > currentText.length) {
        return candidateText;
      }
      return currentText;
    }

    String mergeConditionField(String field) {
      return pickText(
        base.conditionFields[field] ?? '',
        incoming.conditionFields[field] ?? '',
      );
    }

    return ReactionKnowledgeEntry(
      id: base.id,
      title: pickText(base.title, incoming.title),
      keywords: keywordSet.toList(),
      completedEquation: pickText(base.completedEquation, incoming.completedEquation),
      conditionFields: {
        'temperature': mergeConditionField('temperature'),
        'catalyst': mergeConditionField('catalyst'),
        'solvent': mergeConditionField('solvent'),
        'other': mergeConditionField('other'),
      },
      sourceReference: pickText(base.sourceReference, incoming.sourceReference),
      explanation: pickText(base.explanation, incoming.explanation),
      embedding: incoming.embedding ?? base.embedding,
    );
  }

  String _semanticKey(ReactionKnowledgeEntry entry) {
    final title = entry.title.trim().toLowerCase();
    final equation = entry.completedEquation.trim().toLowerCase();
    return '$title|$equation';
  }
}