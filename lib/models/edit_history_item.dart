/// 编辑历史记录
class EditHistoryItem {
  EditHistoryItem({
    required this.id,
    required this.smiles,
    this.name,
    required this.isReaction,
    required this.createdAt,
  });

  final String id;
  final String smiles;
  final String? name;
  final bool isReaction;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'smiles': smiles,
        'name': name,
        'isReaction': isReaction,
        'createdAt': createdAt.toIso8601String(),
      };

  factory EditHistoryItem.fromJson(Map<String, dynamic> json) =>
      EditHistoryItem(
        id: json['id'] as String,
        smiles: json['smiles'] as String,
        name: json['name'] as String?,
        isReaction: json['isReaction'] as bool,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// 检测 SMILES 是否为反应式（含 > 分隔符）
  static bool isReactionSmiles(String smiles) {
    return smiles.contains('>') || smiles.contains('>>');
  }

  factory EditHistoryItem.fromSmiles(String smiles, {String? name}) {
    return EditHistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      smiles: smiles,
      name: name,
      isReaction: isReactionSmiles(smiles),
      createdAt: DateTime.now(),
    );
  }
}
