import 'structure_result.dart';

class FavoriteItem {
  final String id;
  final StructureResult structureResult;
  final DateTime createdAt;
  final String? category;
  final String query;

  const FavoriteItem({
    required this.id,
    required this.structureResult,
    required this.createdAt,
    this.category,
    required this.query,
  });

  factory FavoriteItem.fromResult({
    required StructureResult result,
    required String query,
    String? category,
  }) {
    return FavoriteItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      structureResult: result,
      createdAt: DateTime.now(),
      category: category,
      query: query,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'structureResult': structureResult.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'category': category,
        'query': query,
      };

  factory FavoriteItem.fromJson(Map<String, dynamic> json) => FavoriteItem(
        id: json['id'] as String,
        structureResult: StructureResult.fromJson(
            json['structureResult'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        category: json['category'] as String?,
        query: json['query'] as String,
      );
}
