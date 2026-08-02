/// 化学知识点 — 知识图谱节点
///
/// 对应中学/大学化学教材的章节知识点,用于:
/// - 化合物识别后关联教材章节
/// - 学情诊断时统计知识点掌握度
/// - 个性化学习路径生成
///
/// 参见 doc/GOAI/赛道文档.pdf AI+教育赛题:
///   "面向个性化学习与教学辅助的教育 Agent"
///   重点验证:个性化学习、作业辅导、学情诊断、教师备课和学习陪伴
class KnowledgePoint {
  const KnowledgePoint({
    required this.id,
    required this.name,
    required this.category,
    required this.stage,
    required this.chapter,
    required this.description,
    this.keywords = const [],
    this.relatedPointIds = const [],
    this.functionalGroups = const [],
    this.difficulty = 1,
  });

  /// 知识点 ID,如 'kp_organic_alkane'
  final String id;

  /// 知识点名称,如 '烷烃'
  final String name;

  /// 分类: organic(有机) / inorganic(无机) / physical(物理化学) /
  /// analytical(分析化学) / biochem(生物化学)
  final String category;

  /// 学段: middle(初中) / highschool(高中) / college(大学)
  final String stage;

  /// 所属章节,如 '必修二 第二章 烃'
  final String chapter;

  /// 知识点描述
  final String description;

  /// 关键词,用于从化合物名/SMILES/分子式匹配到知识点
  final List<String> keywords;

  /// 关联知识点 ID(前置/后置依赖)
  final List<String> relatedPointIds;

  /// 涉及的官能团 SMILES 模式(简化 SMARTS),如 'C-C' 'C=C' 'C=O' 'O-H' 'N'
  /// 用于从 SMILES 反查关联知识点
  final List<String> functionalGroups;

  /// 难度 1-5,影响学习路径排序
  final int difficulty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'stage': stage,
        'chapter': chapter,
        'description': description,
        'keywords': keywords,
        'relatedPointIds': relatedPointIds,
        'functionalGroups': functionalGroups,
        'difficulty': difficulty,
      };

  factory KnowledgePoint.fromJson(Map<String, dynamic> json) => KnowledgePoint(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        stage: json['stage'] as String,
        chapter: json['chapter'] as String,
        description: json['description'] as String,
        keywords: (json['keywords'] as List?)?.cast<String>() ?? const [],
        relatedPointIds:
            (json['relatedPointIds'] as List?)?.cast<String>() ?? const [],
        functionalGroups:
            (json['functionalGroups'] as List?)?.cast<String>() ?? const [],
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
      );
}
