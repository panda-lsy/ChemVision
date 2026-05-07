class StructureResult {
  final String smiles;
  final String? resolvedName;
  final String? englishName;
  final String? chineseName;
  final String? svgString;
  final String molecularFormula;
  final double molecularWeight;
  final bool isValid;
  final double confidence;
  final String? message;
  final List<StructureCandidate> alternatives;

  const StructureResult({
    required this.smiles,
    this.resolvedName,
    this.englishName,
    this.chineseName,
    required this.molecularFormula,
    required this.molecularWeight,
    required this.isValid,
    required this.confidence,
    this.svgString,
    this.message,
    this.alternatives = const [],
  });

  factory StructureResult.invalid({String? message}) {
    return StructureResult(
      smiles: '',
      resolvedName: null,
      molecularFormula: '',
      molecularWeight: 0,
      isValid: false,
      confidence: 0,
      message: message,
      alternatives: const [],
    );
  }

  factory StructureResult.fromJson(Map<String, dynamic> json) {
    return StructureResult(
      smiles: (json['smiles'] as String?)?.trim() ?? '',
      resolvedName: (json['resolvedName'] as String?)?.trim(),
      englishName: (json['englishName'] as String?)?.trim(),
      chineseName: (json['chineseName'] as String?)?.trim(),
      svgString: json['svgString'] as String?,
      molecularFormula: (json['molecularFormula'] as String?)?.trim() ?? '',
      molecularWeight: _asDouble(json['molecularWeight']) ?? 0,
      isValid: json['isValid'] as bool? ?? false,
      confidence: _asDouble(json['confidence']) ?? 0,
      message: json['message'] as String?,
      alternatives: _decodeAlternatives(json['alternatives']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smiles': smiles,
      'resolvedName': resolvedName,
      'englishName': englishName,
      'chineseName': chineseName,
      'svgString': svgString,
      'molecularFormula': molecularFormula,
      'molecularWeight': molecularWeight,
      'isValid': isValid,
      'confidence': confidence,
      'message': message,
      'alternatives': alternatives.map((item) => item.toJson()).toList(),
    };
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static List<StructureCandidate> _decodeAlternatives(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final results = <StructureCandidate>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        results.add(StructureCandidate.fromJson(item));
      } else if (item is Map) {
        results.add(
          StructureCandidate.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        );
      }
    }
    return results;
  }
}

class StructureCandidate {
  final String smiles;
  final String? resolvedName;
  final String? englishName;
  final String? chineseName;
  final String molecularFormula;
  final double molecularWeight;
  final String? source;
  final double confidence;
  final String? svgString;

  const StructureCandidate({
    required this.smiles,
    this.resolvedName,
    this.englishName,
    this.chineseName,
    required this.molecularFormula,
    required this.molecularWeight,
    this.source,
    required this.confidence,
    this.svgString,
  });

  factory StructureCandidate.fromJson(Map<String, dynamic> json) {
    return StructureCandidate(
      smiles: (json['smiles'] as String?)?.trim() ?? '',
      resolvedName: (json['resolvedName'] as String?)?.trim(),
      englishName: (json['englishName'] as String?)?.trim(),
      chineseName: (json['chineseName'] as String?)?.trim(),
      molecularFormula: (json['molecularFormula'] as String?)?.trim() ?? '',
      molecularWeight: StructureResult._asDouble(json['molecularWeight']) ?? 0,
      source: (json['source'] as String?)?.trim(),
      confidence: StructureResult._asDouble(json['confidence']) ?? 0,
      svgString: json['svgString'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smiles': smiles,
      'resolvedName': resolvedName,
      'englishName': englishName,
      'chineseName': chineseName,
      'molecularFormula': molecularFormula,
      'molecularWeight': molecularWeight,
      'source': source,
      'confidence': confidence,
      'svgString': svgString,
    };
  }
}
