import 'dart:typed_data';

/// 扫描历史记录项 — 保存 OCSR 识别结果与原图,用于对照记忆
class ScanHistoryItem {
  ScanHistoryItem({
    required this.id,
    required this.imageBytes,
    required this.recognizedSmiles,
    required this.completenessScore,
    this.resolvedName,
    this.englishName,
    this.chineseName,
    this.molecularFormula = '',
    this.molecularWeight = 0,
    required this.createdAt,
  });

  /// 唯一 ID(时间戳 base36)
  final String id;

  /// 原图字节(PNG/JPEG),用于在历史页对照显示
  final Uint8List imageBytes;

  /// DECIMER 识别出的 SMILES
  final String recognizedSmiles;

  /// 完整度评分(0.0 ~ 1.0)
  final double completenessScore;

  /// 反查得到的标准名称(可空)
  final String? resolvedName;

  /// 英文名(可空)
  final String? englishName;

  /// 中文名(可空)
  final String? chineseName;

  /// 分子式
  final String molecularFormula;

  /// 分子量
  final double molecularWeight;

  /// 创建时间
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'imageBytes': imageBytes,
        'recognizedSmiles': recognizedSmiles,
        'completenessScore': completenessScore,
        'resolvedName': resolvedName,
        'englishName': englishName,
        'chineseName': chineseName,
        'molecularFormula': molecularFormula,
        'molecularWeight': molecularWeight,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) => ScanHistoryItem(
        id: json['id'] as String,
        imageBytes: json['imageBytes'] as Uint8List,
        recognizedSmiles: json['recognizedSmiles'] as String,
        completenessScore: (json['completenessScore'] as num).toDouble(),
        resolvedName: json['resolvedName'] as String?,
        englishName: json['englishName'] as String?,
        chineseName: json['chineseName'] as String?,
        molecularFormula: (json['molecularFormula'] as String?) ?? '',
        molecularWeight: (json['molecularWeight'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  /// 从 OCSR 结果构造
  factory ScanHistoryItem.fromRecognition({
    required Uint8List imageBytes,
    required String recognizedSmiles,
    required double completenessScore,
    String? resolvedName,
    String? englishName,
    String? chineseName,
    String molecularFormula = '',
    double molecularWeight = 0,
  }) {
    return ScanHistoryItem(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      imageBytes: imageBytes,
      recognizedSmiles: recognizedSmiles,
      completenessScore: completenessScore,
      resolvedName: resolvedName,
      englishName: englishName,
      chineseName: chineseName,
      molecularFormula: molecularFormula,
      molecularWeight: molecularWeight,
      createdAt: DateTime.now(),
    );
  }

  /// 显示用的主名称:优先英文名,其次反查名,最后兜底 SMILES
  String get displayName {
    final en = englishName ?? '';
    final zh = chineseName ?? '';
    if (en.isNotEmpty && zh.isNotEmpty) return '$en（$zh）';
    if (en.isNotEmpty) return en;
    if (zh.isNotEmpty) return zh;
    return resolvedName?.isNotEmpty == true ? resolvedName! : recognizedSmiles;
  }
}
