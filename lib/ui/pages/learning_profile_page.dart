/// 学情画像详情页 — 雷达图 + 统计卡 + 薄弱知识点列表
///
/// 对应赛题"学情诊断 Agent"可视化要求:
/// 展示用户当前的学习画像,包括:
/// - 知识点掌握度雷达图(按化学分类聚合)
/// - 学习统计(扫描/查询/练习/正确率/连续天数)
/// - 薄弱知识点清单(掌握度 < 0.6,按掌握度升序)
/// - 已掌握知识点数量
///
/// 入口:AgentPage 学情诊断快捷入口,或在 Agent 完成诊断后查看详情。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/knowledge_point.dart';
import '../../models/learning_profile.dart';
import '../../providers/learning_profile_provider.dart';
import '../../services/chemical_knowledge_base.dart';
import '../../theme/app_colors.dart';
import '../widgets/agent/mastery_radar_chart.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';

class LearningProfilePage extends ConsumerWidget {
  const LearningProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(learningProfileControllerProvider);

    return AppScaffold(
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.profile == null
              ? _buildEmpty(isDark)
              : _buildContent(context, state.profile!, isDark, ref),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 56,
              color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无学习记录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '进行若干次扫描识别或练习后,即可生成学情画像',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    LearningProfile profile,
    bool isDark,
    WidgetRef ref,
  ) {
    final masteryByCategory = profile.masteryByCategory(
      ChemicalKnowledgeBase.pointMap,
    );

    // 雷达图数据:按化学分类聚合掌握度
    final radarEntries = _buildRadarEntries(masteryByCategory);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // 标题
        Row(
          children: [
            Text(
              '学情画像',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.dayTextPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: Icon(
                Icons.refresh,
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.dayTextSecondary,
                size: 20,
              ),
              onPressed: () => ref
                  .read(learningProfileControllerProvider.notifier)
                  .refresh(),
              tooltip: '刷新',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${_stageLabel(profile.stage)} · 最近活跃 ${_formatDate(profile.lastActiveAt)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
          ),
        ),
        const SizedBox(height: 20),

        // 雷达图卡片
        GlassPanel(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          radius: 20,
          child: Column(
            children: [
              Text(
                '知识点掌握度分布',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              if (radarEntries.length < 3)
                _buildRadarEmpty(isDark, profile.knowledgeMastery.length)
              else
                Center(
                  child: MasteryRadarChart(
                    entries: radarEntries,
                    size: 280,
                  ),
                ),
              const SizedBox(height: 12),
              _buildLegend(isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 统计卡片网格
        _buildStatsGrid(profile, isDark),
        const SizedBox(height: 16),

        // 薄弱知识点列表
        _buildWeakPointsList(profile, isDark),
        const SizedBox(height: 16),

        // 已掌握与学习中知识点
        _buildProgressList(profile, isDark),
      ],
    );
  }

  List<RadarEntry> _buildRadarEntries(Map<String, double> masteryByCategory) {
    final categoryLabels = {
      'organic': '有机化学',
      'inorganic': '无机化学',
      'physical': '物理化学',
      'analytical': '分析化学',
      'biochem': '生物化学',
    };
    final entries = <RadarEntry>[];
    masteryByCategory.forEach((cat, value) {
      final label = categoryLabels[cat] ?? cat;
      final count = _countByCategory(cat);
      entries.add(RadarEntry(
        label: label,
        value: value,
        subtitle: '${(value * 100).round()}% · $count 个',
      ));
    });
    // 至少返回所有分类(包括掌握度为 0 的)以构成完整雷达
    for (final cat in categoryLabels.keys) {
      if (!masteryByCategory.containsKey(cat)) {
        entries.add(RadarEntry(
          label: categoryLabels[cat]!,
          value: 0,
          subtitle: '0% · ${_countByCategory(cat)} 个',
        ));
      }
    }
    return entries;
  }

  int _countByCategory(String category) {
    return ChemicalKnowledgeBase.allPoints
        .where((kp) => kp.category == category)
        .length;
  }

  Widget _buildRadarEmpty(bool isDark, int totalKps) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.radar,
            size: 48,
            color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
          ),
          const SizedBox(height: 12),
          Text(
            totalKps == 0
                ? '尚无学习记录,无法生成雷达图'
                : '已涉及 $totalKps 个知识点,需跨 3 个以上分类才显示雷达图',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondary
                  : AppColors.dayTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(bool isDark) {
    final items = [
      _LegendItem(
          color: isDark ? AppColors.lime : const Color(0xFF3D8E3D),
          label: '已掌握 ≥80%'),
      _LegendItem(
          color: isDark ? AppColors.amber : const Color(0xFFE07B00),
          label: '学习中 60-80%'),
      const _LegendItem(
          color: Color(0xFFEF5350), label: '薄弱 <60%'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: items
          .map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: e.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    e.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondary
                          : AppColors.dayTextSecondary,
                    ),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Widget _buildStatsGrid(LearningProfile profile, bool isDark) {
    final accuracy = (profile.accuracy * 100).round();
    final stats = [
      _StatItem(
        icon: Icons.camera_alt_outlined,
        label: '扫描识别',
        value: '${profile.totalScans}',
        color: isDark ? AppColors.aqua : AppColors.dayBlueAccent,
      ),
      _StatItem(
        icon: Icons.search,
        label: '化合物查询',
        value: '${profile.totalQueries}',
        color: isDark ? AppColors.aquaLight : AppColors.dayBluePrimary,
      ),
      _StatItem(
        icon: Icons.quiz_outlined,
        label: '练习题数',
        value: '${profile.totalPractice}',
        color: isDark ? AppColors.amber : const Color(0xFFE07B00),
      ),
      _StatItem(
        icon: Icons.check_circle_outline,
        label: '正确率',
        value: '$accuracy%',
        color: accuracy >= 70
            ? (isDark ? AppColors.lime : const Color(0xFF3D8E3D))
            : const Color(0xFFEF5350),
      ),
      _StatItem(
        icon: Icons.local_fire_department_outlined,
        label: '连续学习',
        value: '${profile.streakDays} 天',
        color: const Color(0xFFFF7043),
      ),
      _StatItem(
        icon: Icons.school,
        label: '已掌握',
        value: '${profile.masteredPoints.length}',
        color: isDark ? AppColors.lime : const Color(0xFF3D8E3D),
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.1,
      children: stats
          .map((s) => _StatCard(stat: s, isDark: isDark))
          .toList(),
    );
  }

  Widget _buildWeakPointsList(LearningProfile profile, bool isDark) {
    final weakPoints = profile.weakPoints;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: Color(0xFFEF5350),
              ),
              const SizedBox(width: 6),
              Text(
                '薄弱知识点',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${weakPoints.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (weakPoints.isEmpty)
            _buildEmptyListHint(
              '暂无薄弱知识点,继续保持!',
              isDark,
            )
          else
            ...weakPoints.map((id) {
              final kp = ChemicalKnowledgeBase.pointMap[id];
              final mastery = profile.knowledgeMastery[id] ?? 0;
              return _KnowledgePointTile(
                kp: kp,
                kpId: id,
                mastery: mastery,
                isWeak: true,
                isDark: isDark,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProgressList(LearningProfile profile, bool isDark) {
    final learning = profile.learningPoints;
    final mastered = profile.masteredPoints;

    return GlassPanel(
      padding: const EdgeInsets.all(16),
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 18,
                color: isDark ? AppColors.aqua : AppColors.dayBluePrimary,
              ),
              const SizedBox(width: 6),
              Text(
                '学习进展',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.dayTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (learning.isEmpty && mastered.isEmpty)
            _buildEmptyListHint('继续学习以积累进度', isDark)
          else ...[
            if (learning.isNotEmpty) ...[
              _buildSectionLabel('学习中(60%-80%)', const Color(0xFFE07B00)),
              const SizedBox(height: 6),
              ...learning.map((id) {
                final kp = ChemicalKnowledgeBase.pointMap[id];
                final mastery = profile.knowledgeMastery[id] ?? 0;
                return _KnowledgePointTile(
                  kp: kp,
                  kpId: id,
                  mastery: mastery,
                  isWeak: false,
                  isDark: isDark,
                );
              }),
              const SizedBox(height: 12),
            ],
            if (mastered.isNotEmpty) ...[
              _buildSectionLabel('已掌握(≥80%)', const Color(0xFF3D8E3D)),
              const SizedBox(height: 6),
              ...mastered.map((id) {
                final kp = ChemicalKnowledgeBase.pointMap[id];
                final mastery = profile.knowledgeMastery[id] ?? 0;
                return _KnowledgePointTile(
                  kp: kp,
                  kpId: id,
                  mastery: mastery,
                  isWeak: false,
                  isDark: isDark,
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildEmptyListHint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
          ),
        ),
      ),
    );
  }

  String _stageLabel(String stage) {
    switch (stage) {
      case 'middle':
        return '初中';
      case 'highschool':
        return '高中';
      case 'college':
        return '大学';
      default:
        return stage;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inHours < 1) return '刚刚';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat, required this.isDark});

  final _StatItem stat;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      radius: 14,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(stat.icon, size: 18, color: stat.color),
          const SizedBox(height: 4),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.dayTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textMuted
                  : AppColors.dayTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _KnowledgePointTile extends StatelessWidget {
  const _KnowledgePointTile({
    required this.kp,
    required this.kpId,
    required this.mastery,
    required this.isWeak,
    required this.isDark,
  });

  final KnowledgePoint? kp;
  final String kpId;
  final double mastery;
  final bool isWeak;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final name = kp?.name ?? kpId;
    final chapter = kp?.chapter ?? '未知章节';
    final masteryPercent = (mastery * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 掌握度圆环
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: mastery,
                  strokeWidth: 3,
                  backgroundColor: isDark
                      ? Colors.white12
                      : const Color(0x223D77DE),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isWeak
                        ? const Color(0xFFEF5350)
                        : (mastery >= 0.8
                            ? (isDark
                                ? AppColors.lime
                                : const Color(0xFF3D8E3D))
                            : (isDark
                                ? AppColors.amber
                                : const Color(0xFFE07B00))),
                  ),
                ),
                Text(
                  '$masteryPercent%',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.dayTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.dayTextPrimary,
                        ),
                      ),
                    ),
                    if (kp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.aqua : AppColors.dayBluePrimary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '难度 ${kp!.difficulty}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? AppColors.aquaLight
                                : AppColors.dayBluePrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  chapter,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textMuted
                        : AppColors.dayTextMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem {
  const _LegendItem({required this.color, required this.label});
  final Color color;
  final String label;
}
