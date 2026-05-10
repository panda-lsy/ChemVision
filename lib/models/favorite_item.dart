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
}
