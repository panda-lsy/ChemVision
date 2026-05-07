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
    return InputChip(
      label: Text(label),
      onPressed: onTap,
      onDeleted: onDelete,
      deleteIcon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
      backgroundColor: AppColors.glass,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
      side: BorderSide(color: Colors.white.withOpacity(0.1)),
      shape: const StadiumBorder(),
    );
  }
}
