/// 错题本条目 — 收藏 Agent 辅导中的错题/薄弱知识点,便于复习
///
/// 来源:
/// - Agent 结果页"建议下一步 → 收藏到错题本"
/// - 手动从历史会话收藏
class ErrorBookItem {
  ErrorBookItem({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.knowledgePointIds = const [],
    this.smiles = '',
    this.compoundName = '',
    this.sourceSessionId,
    this.note = '',
    this.reviewed = false,
  });

  /// 唯一 ID(时间戳 base36)
  final String id;

  /// 标题(通常为任务结果标题或用户问题摘要)
  final String title;

  /// 内容(Agent 回答摘要或完整讲解,支持 Markdown)
  final String content;

  /// 创建时间
  final DateTime createdAt;

  /// 关联的知识点 ID 列表
  final List<String> knowledgePointIds;

  /// 关联的 SMILES(如有)
  final String smiles;

  /// 关联的化合物名(如有)
  final String compoundName;

  /// 来源会话 ID(可空,用于回溯)
  final String? sourceSessionId;

  /// 用户备注
  final String note;

  /// 是否已复习
  final bool reviewed;

  ErrorBookItem copyWith({
    String? title,
    String? content,
    List<String>? knowledgePointIds,
    String? smiles,
    String? compoundName,
    String? note,
    bool? reviewed,
  }) {
    return ErrorBookItem(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      knowledgePointIds: knowledgePointIds ?? this.knowledgePointIds,
      smiles: smiles ?? this.smiles,
      compoundName: compoundName ?? this.compoundName,
      sourceSessionId: sourceSessionId,
      note: note ?? this.note,
      reviewed: reviewed ?? this.reviewed,
    );
  }

  /// 预览文本(用于列表卡片)
  String get preview {
    if (content.isEmpty) return title;
    return content.length > 80 ? '${content.substring(0, 80)}...' : content;
  }
}
