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
}
