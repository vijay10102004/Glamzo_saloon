import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const QuickActionItem({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text2,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
