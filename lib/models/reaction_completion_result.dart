class ReactionKnowledgeEntry {
  const ReactionKnowledgeEntry({
    required this.id,
    required this.title,
    required this.keywords,
    required this.completedEquation,
    required this.conditionFields,
    required this.sourceReference,
    required this.explanation,
    this.embedding,
  });

  final String id;
  final String title;
  final List<String> keywords;
  final String completedEquation;
  final Map<String, String> conditionFields;
  final String sourceReference;
  final String explanation;
  final List<double>? embedding;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'keywords': keywords,
      'completedEquation': completedEquation,
      'conditionFields': conditionFields,
      'sourceReference': sourceReference,
      'explanation': explanation,
      'embedding': embedding,
    };
  }

  factory ReactionKnowledgeEntry.fromJson(Map<String, dynamic> json) {
    return ReactionKnowledgeEntry(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      keywords: _toStringList(json['keywords']),
      completedEquation: json['completedEquation']?.toString() ?? '',
      conditionFields: _toStringMap(json['conditionFields']),
      sourceReference: json['sourceReference']?.toString() ?? '',
      explanation: json['explanation']?.toString() ?? '',
      embedding: _toDoubleList(json['embedding']),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static Map<String, String> _toStringMap(dynamic value) {
    if (value is! Map) return const {};
    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key?.toString().trim() ?? '';
      final itemValue = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty) {
        result[key] = itemValue;
      }
    }
    return result;
  }

  static List<double>? _toDoubleList(dynamic value) {
    if (value is! List) return null;
    final result = value
        .map((item) => item is num ? item.toDouble() : double.tryParse(item?.toString() ?? ''))
        .whereType<double>()
        .toList();
    return result.isEmpty ? null : result;
  }
}

class ReactionCompletionResult {
  const ReactionCompletionResult({
    required this.query,
    required this.completedEquation,
    required this.conditionFields,
    required this.explanation,
    required this.confidence,
    required this.sourceReferences,
    required this.matchedKeywords,
    required this.candidateTitles,
    required this.usedModel,
  });

  final String query;
  final String completedEquation;
  final Map<String, String> conditionFields;
  final String explanation;
  final double confidence;
  final List<String> sourceReferences;
  final List<String> matchedKeywords;
  final List<String> candidateTitles;
  final bool usedModel;

  String get conditionSummary {
    final parts = <String>[];
    final temperature = conditionFields['temperature']?.trim() ?? '';
    final catalyst = conditionFields['catalyst']?.trim() ?? '';
    final solvent = conditionFields['solvent']?.trim() ?? '';
    final other = conditionFields['other']?.trim() ?? '';

    if (temperature.isNotEmpty) parts.add(temperature);
    if (catalyst.isNotEmpty) parts.add(catalyst);
    if (solvent.isNotEmpty) parts.add(solvent);
    if (other.isNotEmpty) parts.add(other);
    return parts.join(' · ');
  }
}