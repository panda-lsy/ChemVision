/// 应用用户模型 — 支持多用户切换,数据按用户隔离
///
/// 每个用户拥有独立的收藏/历史/学情数据,通过 [id] 作为 box 名前缀实现隔离。
class AppUser {
  const AppUser({
    required this.id,
    required this.nickname,
    required this.stage,
    required this.createdAt,
    this.avatarPath,
  });

  /// 用户唯一 ID(用作 Hive box 名前缀)
  final String id;

  /// 昵称
  final String nickname;

  /// 学段: middle / highschool / college / research
  final String stage;

  /// 头像本地路径(可为空,使用默认头像)
  final String? avatarPath;

  /// 创建时间
  final DateTime createdAt;

  /// 学段的中文显示名
  String get stageLabel => switch (stage) {
        'middle' => '初中',
        'highschool' => '高中',
        'college' => '大学本科/研究生/博士',
        'research' => '科研工作',
        _ => stage,
      };

  /// 学段的简短显示名(用于空间受限的 UI)
  String get stageShort => switch (stage) {
        'middle' => '初中',
        'highschool' => '高中',
        'college' => '大学',
        'research' => '科研',
        _ => stage,
      };

  AppUser copyWith({
    String? nickname,
    String? stage,
    String? avatarPath,
  }) {
    return AppUser(
      id: id,
      nickname: nickname ?? this.nickname,
      stage: stage ?? this.stage,
      avatarPath: avatarPath ?? this.avatarPath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'stage': stage,
        'avatarPath': avatarPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      stage: json['stage'] as String,
      avatarPath: json['avatarPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  String toString() => 'AppUser($nickname, $stageLabel)';
}
