/// 反应方程式数据模型
///
/// 用于反应编辑器和反应收藏。
class ReactionEquation {
  ReactionEquation({
    this.title = '',
    this.reactants = const [],
    this.products = const [],
    this.conditions = const {},
    this.arrowType = ArrowType.forward,
    this.rxnData,
    this.svgString,
  });

  String title;
  List<ReactionMolecule> reactants;
  List<ReactionMolecule> products;
  Map<String, String> conditions;
  ArrowType arrowType;
  String? rxnData;
  String? svgString;

  ReactionEquation copyWith({
    String? title,
    List<ReactionMolecule>? reactants,
    List<ReactionMolecule>? products,
    Map<String, String>? conditions,
    ArrowType? arrowType,
    String? rxnData,
    String? svgString,
    bool clearRxn = false,
    bool clearSvg = false,
  }) {
    return ReactionEquation(
      title: title ?? this.title,
      reactants: reactants ?? this.reactants,
      products: products ?? this.products,
      conditions: conditions ?? this.conditions,
      arrowType: arrowType ?? this.arrowType,
      rxnData: clearRxn ? null : (rxnData ?? this.rxnData),
      svgString: clearSvg ? null : (svgString ?? this.svgString),
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'reactants': reactants.map((m) => m.toJson()).toList(),
        'products': products.map((m) => m.toJson()).toList(),
        'conditions': conditions,
        'arrowType': arrowType.index,
        'rxnData': rxnData,
        'svgString': svgString,
      };

  factory ReactionEquation.fromJson(Map<String, dynamic> json) {
    return ReactionEquation(
      title: json['title']?.toString() ?? '',
      reactants: (json['reactants'] as List?)
              ?.map((m) =>
                  ReactionMolecule.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      products: (json['products'] as List?)
              ?.map((m) =>
                  ReactionMolecule.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
      conditions: (json['conditions'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          const {},
      arrowType: ArrowType.values[json['arrowType'] as int? ?? 0],
      rxnData: json['rxnData'] as String?,
      svgString: json['svgString'] as String?,
    );
  }

  /// 条件摘要文本
  String get conditionSummary {
    final parts = <String>[];
    final temperature = conditions['temperature']?.trim() ?? '';
    final catalyst = conditions['catalyst']?.trim() ?? '';
    final solvent = conditions['solvent']?.trim() ?? '';
    final other = conditions['other']?.trim() ?? '';
    if (temperature.isNotEmpty) parts.add(temperature);
    if (catalyst.isNotEmpty) parts.add(catalyst);
    if (solvent.isNotEmpty) parts.add(solvent);
    if (other.isNotEmpty) parts.add(other);
    return parts.join(' · ');
  }
}

class ReactionMolecule {
  ReactionMolecule({
    required this.smiles,
    this.name,
    this.svgString,
  });

  String smiles;
  String? name;
  String? svgString;

  Map<String, dynamic> toJson() => {
        'smiles': smiles,
        'name': name,
        'svgString': svgString,
      };

  factory ReactionMolecule.fromJson(Map<String, dynamic> json) {
    return ReactionMolecule(
      smiles: json['smiles']?.toString() ?? '',
      name: json['name'] as String?,
      svgString: json['svgString'] as String?,
    );
  }
}

enum ArrowType {
  forward, // → 单向
  reversible, // ⇌ 可逆
  equilibrium, // ⇋ 平衡
}
