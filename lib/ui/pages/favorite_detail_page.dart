import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/favorite_item.dart';
import '../../providers/favorites_provider.dart';
import '../../theme/app_colors.dart';
import '../widgets/accent_pill.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/glass_panel.dart';
import '../widgets/primary_button.dart';
import '../widgets/structure_view.dart';
import '../widgets/structure_view_controller.dart';

class FavoriteDetailPage extends ConsumerStatefulWidget {
  const FavoriteDetailPage({super.key, required this.item});

  final FavoriteItem item;

  @override
  ConsumerState<FavoriteDetailPage> createState() =>
      _FavoriteDetailPageState();
}

class _FavoriteDetailPageState extends ConsumerState<FavoriteDetailPage> {
  StructureViewController? _controller;

  @override
  Widget build(BuildContext context) {
    final r = widget.item.structureResult;
    final displayName = _displayName(
        r.resolvedName, r.englishName, r.chineseName);

    return AppScaffold(
      scroll: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('ChemVISION',
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              const AccentPill(label: '收藏详情'),
            ],
          ),
          const SizedBox(height: 18),
          Text(widget.item.query,
              style: Theme.of(context).textTheme.headlineMedium),
          if (displayName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('标准名称 $displayName',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          // 结构式渲染卡片 - 只显示渲染视口
          GlassPanel(
            padding: EdgeInsets.zero,
            radius: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = (constraints.maxWidth * 0.7)
                      .clamp(400.0, 700.0)
                      .toDouble();
                  return SizedBox(
                    height: height,
                    width: double.infinity,
                    child: StructureView(
                      smiles: r.smiles,
                      readOnly: true,
                      compact: true,
                      onControllerReady: (c) => _controller = c,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          // 分子信息 - 显示在卡片下方
          GlassPanel(
            padding: const EdgeInsets.all(16),
            radius: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.molecularFormula.isNotEmpty)
                  Text(
                    r.molecularFormula,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFF9F3DD),
                        fontWeight: FontWeight.w700),
                  ),
                if (r.molecularWeight > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    '分子量 ${r.molecularWeight.toStringAsFixed(2)} g/mol',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.glass,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(
                    'SMILES: ${r.smiles}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(
                          color: Colors.white.withOpacity(0.25)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('返回'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: PrimaryButton(
                    label: '删除收藏',
                    onPressed: () {
                      ref
                          .read(favoritesControllerProvider.notifier)
                          .delete(widget.item.id);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _displayName(String? resolved, String? en, String? zh) {
    if (en != null && en.isNotEmpty && zh != null && zh.isNotEmpty) {
      return '$en（$zh）';
    }
    if (en != null && en.isNotEmpty) return en;
    if (zh != null && zh.isNotEmpty) return zh;
    return resolved ?? '';
  }
}
