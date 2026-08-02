/// 学习记录 — 扩展扫描/查询历史,增加学习维度
///
/// 与 ScanHistoryItem 关联(通过 scanHistoryId),记录用户的学习行为:
/// - 扫描识别某个分子
/// - 查询化合物的知识点
/// - 完成同类题练习
/// - 标记某个知识点已掌握
///
/// 用于学情诊断 Agent 统计知识点掌握度、识别薄弱点。
class LearningRecord {
  LearningRecord({
    required this.id,
    required this.scanHistoryId,
    required this.smiles,
    required this.compoundName,
    required this.action,
    required this.createdAt,
    this.knowledgePointIds = const [],
    this.notes,
    this.masteryDelta = 0,
  });

  /// 唯一 ID(时间戳 base36)
  final String id;

  /// 关联的 ScanHistoryItem.id(若来自扫描;查询类可为空字符串)
  final String scanHistoryId;

  /// 识别/查询的 SMILES
  final String smiles;

  /// 化合物名称
  final String compoundName;

  /// 学习行为类型
  final LearningAction action;

  /// 关联的知识点 ID 列表
  final List<String> knowledgePointIds;

  /// 创建时间
  final DateTime createdAt;

  /// 备注(如错因分析结论)
  final String? notes;

  /// 掌握度增量(-1.0 ~ +1.0),练习答对为正、答错为负
  final double masteryDelta;

  Map<String, dynamic> toJson() => {
        'id': id,
        'scanHistoryId': scanHistoryId,
        'smiles': smiles,
        'compoundName': compoundName,
        'action': action.name,
        'knowledgePointIds': knowledgePointIds,
        'createdAt': createdAt.toIso8601String(),
        'notes': notes,
        'masteryDelta': masteryDelta,
      };

  factory LearningRecord.fromJson(Map<String, dynamic> json) => LearningRecord(
        id: json['id'] as String,
        scanHistoryId: (json['scanHistoryId'] as String?) ?? '',
        smiles: json['smiles'] as String,
        compoundName: json['compoundName'] as String,
        action: LearningAction.values.firstWhere(
          (e) => e.name == json['action'],
          orElse: () => LearningAction.scan,
        ),
        knowledgePointIds:
            (json['knowledgePointIds'] as List?)?.cast<String>() ?? const [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        notes: json['notes'] as String?,
        masteryDelta: (json['masteryDelta'] as num?)?.toDouble() ?? 0,
      );

  /// 从扫描记录构造一条 scan 类型学习记录
  factory LearningRecord.fromScan({
    required String scanHistoryId,
    required String smiles,
    required String compoundName,
    List<String> knowledgePointIds = const [],
  }) {
    return LearningRecord(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      scanHistoryId: scanHistoryId,
      smiles: smiles,
      compoundName: compoundName,
      action: LearningAction.scan,
      createdAt: DateTime.now(),
      knowledgePointIds: knowledgePointIds,
    );
  }
}

/// 学习行为类型
enum LearningAction {
  /// 扫描识别分子
  scan,

  /// 查询化合物的知识点
  query,

  /// 完成同类题练习(答对)
  practice,

  /// 答错练习(错因记录)
  practiceWrong,

  /// 复习已学知识点
  review,

  /// 标记知识点已掌握
  mastered,
}
