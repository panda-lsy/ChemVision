import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.fontSize});

  final String label;
  final VoidCallback? onPressed;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeGradient = isDark
        ? const LinearGradient(
            colors: [AppColors.aqua, Color(0xFF9EF5D2)],
          )
        : const LinearGradient(
            colors: [AppColors.dayBluePrimary, AppColors.dayBlueAccent],
          );
    final activeText = isDark ? AppColors.ink : Colors.white;
    final shadowColor = isDark
        ? AppColors.aqua.withValues(alpha: 0.35)
        : AppColors.dayBluePrimary.withValues(alpha: 0.32);
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: enabled
              ? activeGradient
              : LinearGradient(
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ]
                      : [
                          AppColors.dayBluePrimary.withValues(alpha: 0.10),
                          AppColors.dayBluePrimary.withValues(alpha: 0.06),
                        ],
                ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: enabled
                            ? activeText
                            : (isDark
                                ? AppColors.textMuted
                                : AppColors.dayTextMuted),
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
