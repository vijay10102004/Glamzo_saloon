import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class StylistChip extends StatelessWidget {
  final String name;
  final String role;
  final String initials;
  final double rating;
  final bool online;
  final Color color1;
  final Color color2;
  final VoidCallback? onTap;

  const StylistChip({
    super.key,
    required this.name,
    required this.role,
    required this.initials,
    required this.rating,
    required this.online,
    required this.color1,
    required this.color2,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color1, color2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials,
                        style: AppTextStyles.body1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                if (online)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(name,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(role,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.text3, fontSize: 9),
                textAlign: TextAlign.center,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded,
                    size: 10, color: AppColors.gold),
                const SizedBox(width: 2),
                Text(rating.toStringAsFixed(1),
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.goldDeep,
                        fontWeight: FontWeight.w600,
                        fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
