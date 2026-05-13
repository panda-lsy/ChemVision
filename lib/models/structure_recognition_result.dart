import 'structure_result.dart';

class StructureRecognitionResult {
  const StructureRecognitionResult({
    required this.recognizedSmiles,
    required this.completenessScore,
    required this.candidates,
    required this.isValid,
    this.imageBase64,
    this.errorMessage,
  });

  final String recognizedSmiles;
  final double completenessScore;
  final List<StructureCandidate> candidates;
  final bool isValid;
  final String? imageBase64;
  final String? errorMessage;

  factory StructureRecognitionResult.invalid({String? message}) {
    return StructureRecognitionResult(
      recognizedSmiles: '',
      completenessScore: 0,
      candidates: const [],
      isValid: false,
      errorMessage: message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recognizedSmiles': recognizedSmiles,
      'completenessScore': completenessScore,
      'candidates': candidates.map((c) => c.toJson()).toList(),
      'isValid': isValid,
      'errorMessage': errorMessage,
    };
  }

  factory StructureRecognitionResult.fromJson(Map<String, dynamic> json) {
    final rawCandidates = json['candidates'];
    final candidates = <StructureCandidate>[];
    if (rawCandidates is List) {
      for (final item in rawCandidates) {
        if (item is Map<String, dynamic>) {
          candidates.add(StructureCandidate.fromJson(item));
        } else if (item is Map) {
          candidates.add(StructureCandidate.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ));
        }
      }
    }
    return StructureRecognitionResult(
      recognizedSmiles: json['recognizedSmiles']?.toString() ?? '',
      completenessScore: _asDouble(json['completenessScore']) ?? 0,
      candidates: candidates,
      isValid: json['isValid'] as bool? ?? false,
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
