import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class QuickTag extends StatelessWidget {
  const QuickTag({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
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
