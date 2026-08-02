import 'knowledge_point.dart';

/// 学情画像 — 记录用户的学习状态与知识掌握度
///
/// 由学情诊断 Agent 基于学习记录(LearningRecord)聚合生成,
/// 用于个性化学习路径推荐与学情报告展示。
///
/// 对应赛题: "学情诊断 Agent:基于练习记录、测试结果、课堂表现或模拟数据,
///            识别学生知识薄弱点,生成学情分析报告和改进建议"
class LearningProfile {
  LearningProfile({
    required this.userId,
    required this.stage,
    required this.knowledgeMastery,
    required this.totalScans,
    required this.totalQueries,
    required this.totalPractice,
    required this.correctCount,
    required this.lastActiveAt,
    required this.createdAt,
    this.streakDays = 1,
    this.totalLearningDays = 1,
  });

  /// 用户 ID(本地生成,持久化)
  final String userId;

  /// 学段: middle / highschool / college
  final String stage;

  /// 知识点 ID -> 掌握度(0.0~1.0)
  /// 掌握度算法:见 KnowledgeMasteryCalculator
  final Map<String, double> knowledgeMastery;

  /// 总扫描次数
  final int totalScans;

  /// 总查询次数
  final int totalQueries;

  /// 总练习次数
  final int totalPractice;

  /// 答对次数
  final int correctCount;

  /// 最后活跃时间
  final DateTime lastActiveAt;

  /// 创建时间(首次使用)
  final DateTime createdAt;

  /// 连续学习天数
  final int streakDays;

  /// 累计学习天数
  final int totalLearningDays;

  /// 薄弱知识点(掌握度 < 0.6)
  List<String> get weakPoints => knowledgeMastery.entries
      .where((e) => e.value < 0.6)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) =>
        (knowledgeMastery[a] ?? 0).compareTo(knowledgeMastery[b] ?? 0));

  /// 已掌握知识点(掌握度 >= 0.8)
  List<String> get masteredPoints => knowledgeMastery.entries
      .where((e) => e.value >= 0.8)
      .map((e) => e.key)
      .toList();

  /// 学习中知识点(0.6 <= 掌握度 < 0.8)
  List<String> get learningPoints => knowledgeMastery.entries
      .where((e) => e.value >= 0.6 && e.value < 0.8)
      .map((e) => e.key)
      .toList();

  /// 练习正确率
  double get accuracy =>
      totalPractice == 0 ? 0 : correctCount / totalPractice;

  /// 按分类统计掌握度分布
  Map<String, double> masteryByCategory(
      Map<String, KnowledgePoint> knowledgeBase) {
    final result = <String, List<double>>{};
    knowledgeMastery.forEach((kpId, mastery) {
      final kp = knowledgeBase[kpId];
      if (kp == null) return;
      result.putIfAbsent(kp.category, () => []).add(mastery);
    });
    return result.map((cat, list) => MapEntry(cat, list.isEmpty
        ? 0.0
        : list.reduce((a, b) => a + b) / list.length));
  }

  LearningProfile copyWith({
    String? userId,
    String? stage,
    Map<String, double>? knowledgeMastery,
    int? totalScans,
    int? totalQueries,
    int? totalPractice,
    int? correctCount,
    DateTime? lastActiveAt,
    DateTime? createdAt,
    int? streakDays,
    int? totalLearningDays,
  }) {
    return LearningProfile(
      userId: userId ?? this.userId,
      stage: stage ?? this.stage,
      knowledgeMastery: knowledgeMastery ?? this.knowledgeMastery,
      totalScans: totalScans ?? this.totalScans,
      totalQueries: totalQueries ?? this.totalQueries,
      totalPractice: totalPractice ?? this.totalPractice,
      correctCount: correctCount ?? this.correctCount,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      createdAt: createdAt ?? this.createdAt,
      streakDays: streakDays ?? this.streakDays,
      totalLearningDays: totalLearningDays ?? this.totalLearningDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'stage': stage,
        'knowledgeMastery': knowledgeMastery,
        'totalScans': totalScans,
        'totalQueries': totalQueries,
        'totalPractice': totalPractice,
        'correctCount': correctCount,
        'lastActiveAt': lastActiveAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'streakDays': streakDays,
        'totalLearningDays': totalLearningDays,
      };

  factory LearningProfile.fromJson(Map<String, dynamic> json) {
    return LearningProfile(
      userId: json['userId'] as String,
      stage: (json['stage'] as String?) ?? 'highschool',
      knowledgeMastery:
          ((json['knowledgeMastery'] as Map?) ?? {}).map((k, v) =>
              MapEntry(k.toString(), (v as num).toDouble())),
      totalScans: (json['totalScans'] as num?)?.toInt() ?? 0,
      totalQueries: (json['totalQueries'] as num?)?.toInt() ?? 0,
      totalPractice: (json['totalPractice'] as num?)?.toInt() ?? 0,
      correctCount: (json['correctCount'] as num?)?.toInt() ?? 0,
      lastActiveAt: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String)
          : DateTime.now(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      streakDays: (json['streakDays'] as num?)?.toInt() ?? 1,
      totalLearningDays:
          (json['totalLearningDays'] as num?)?.toInt() ?? 1,
    );
  }

  /// 空画像(首次使用)
  factory LearningProfile.empty({String? stage}) {
    final now = DateTime.now();
    return LearningProfile(
      userId: 'local_${now.millisecondsSinceEpoch.toRadixString(36)}',
      stage: stage ?? 'highschool',
      knowledgeMastery: {},
      totalScans: 0,
      totalQueries: 0,
      totalPractice: 0,
      correctCount: 0,
      lastActiveAt: now,
      createdAt: now,
    );
  }
}
