import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class QuickTag extends StatelessWidget {
  const QuickTag({
    super.key,
    required this.label,
    required this.onTap,
    this.onDelete,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputChip(
      label: Text(label),
      onPressed: onTap,
      onDeleted: onDelete,
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: isDark ? AppColors.textMuted : AppColors.dayTextMuted,
      ),
      backgroundColor: isDark ? AppColors.glass : AppColors.dayGlass,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isDark ? AppColors.textSecondary : AppColors.dayTextSecondary,
            fontWeight: FontWeight.w600,
          ),
      side: BorderSide(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : AppColors.dayBluePrimary.withValues(alpha: 0.25),
      ),
      shape: const StadiumBorder(),
    );
  }
}
