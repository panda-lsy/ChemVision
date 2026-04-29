import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AccentPill extends StatelessWidget {
  const AccentPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.aqua.withOpacity(0.4)),
        color: AppColors.aqua.withOpacity(0.15),
        boxShadow: [
          BoxShadow(
            color: AppColors.aqua.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFFBFF7EF),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
