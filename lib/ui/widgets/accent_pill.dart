import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AccentPill extends StatelessWidget {
  const AccentPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        isDark ? AppColors.aqua.withValues(alpha: 0.4) : AppColors.dayBluePrimary;
    final fillColor = isDark
        ? AppColors.aqua.withValues(alpha: 0.15)
        : AppColors.dayBluePrimary.withValues(alpha: 0.12);
    final textColor = isDark ? const Color(0xFFBFF7EF) : AppColors.dayBluePrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
        color: fillColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.aqua.withValues(alpha: 0.2)
                : AppColors.dayBluePrimary.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
