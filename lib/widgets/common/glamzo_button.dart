import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class GlamzoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool outlined;
  final Color? color;

  const GlamzoButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.outlined = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null && !isLoading;
    return GestureDetector(
      onTap: isLoading || isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: outlined || isDisabled
              ? null
              : (color != null
                  ? null
                  : AppColors.goldGradient),
          color: outlined
              ? Colors.transparent
              : (isDisabled
                  ? AppColors.border2
                  : (color)),
          border: outlined
              ? Border.all(color: AppColors.gold, width: 1.5)
              : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: outlined || isDisabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  label,
                  style: outlined
                      ? AppTextStyles.btnLabel.copyWith(color: AppColors.gold)
                      : AppTextStyles.btnLabel,
                ),
        ),
      ),
    );
  }
}
