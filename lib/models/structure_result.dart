class StructureResult {
  final String smiles;
  final String? resolvedName;
  final String? svgString;
  final String molecularFormula;
  final double molecularWeight;
  final bool isValid;
  final double confidence;
  final String? message;

  const StructureResult({
    required this.smiles,
    this.resolvedName,
    required this.molecularFormula,
    required this.molecularWeight,
    required this.isValid,
    required this.confidence,
    this.svgString,
    this.message,
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
    );
  }

  factory StructureResult.fromJson(Map<String, dynamic> json) {
    return StructureResult(
      smiles: (json['smiles'] as String?)?.trim() ?? '',
      resolvedName: (json['resolvedName'] as String?)?.trim(),
      svgString: json['svgString'] as String?,
      molecularFormula: (json['molecularFormula'] as String?)?.trim() ?? '',
      molecularWeight: _asDouble(json['molecularWeight']) ?? 0,
      isValid: json['isValid'] as bool? ?? false,
      confidence: _asDouble(json['confidence']) ?? 0,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'smiles': smiles,
      'resolvedName': resolvedName,
      'svgString': svgString,
      'molecularFormula': molecularFormula,
      'molecularWeight': molecularWeight,
      'isValid': isValid,
      'confidence': confidence,
      'message': message,
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
}
