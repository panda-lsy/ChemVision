import 'reaction_equation.dart';

class ReactionFavoriteItem {
  ReactionFavoriteItem({
    required this.id,
    required this.equation,
    required this.createdAt,
    this.category,
    this.tags = const [],
    this.notes,
  });

  final String id;
  final ReactionEquation equation;
  final DateTime createdAt;
  final String? category;
  final List<String> tags;
  final String? notes;

  ReactionFavoriteItem copyWith({
    String? category,
    List<String>? tags,
    String? notes,
    bool clearCategory = false,
    bool clearNotes = false,
  }) {
    return ReactionFavoriteItem(
      id: id,
      equation: equation,
      createdAt: createdAt,
      category: clearCategory ? null : (category ?? this.category),
      tags: tags ?? this.tags,
      notes: clearNotes ? null : (notes ?? this.notes),
    );
  }

  factory ReactionFavoriteItem.fromEquation({
    required ReactionEquation equation,
    String? category,
  }) {
    return ReactionFavoriteItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      equation: equation,
      createdAt: DateTime.now(),
      category: category,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'equation': equation.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'category': category,
        'tags': tags,
        'notes': notes,
      };

  factory ReactionFavoriteItem.fromJson(Map<String, dynamic> json) =>
      ReactionFavoriteItem(
        id: json['id'] as String,
        equation: ReactionEquation.fromJson(
            json['equation'] as Map<String, dynamic>),
        createdAt: DateTime.parse(json['createdAt'] as String),
        category: json['category'] as String?,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        notes: json['notes'] as String?,
      );
}
