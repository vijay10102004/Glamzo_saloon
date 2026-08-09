import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class ServiceMiniCard extends StatelessWidget {
  final String emoji;
  final String name;
  final String price;
  final String duration;
  final Color bgColor;
  final VoidCallback? onTap;

  const ServiceMiniCard({
    super.key,
    required this.emoji,
    required this.name,
    required this.price,
    required this.duration,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const Spacer(),
            Text(name,
                style: AppTextStyles.cardTitle.copyWith(fontSize: 14)),
            const SizedBox(height: 4),
            Text(price, style: AppTextStyles.price),
            const SizedBox(height: 2),
            Text(duration,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3)),
          ],
        ),
      ),
    );
  }
}
