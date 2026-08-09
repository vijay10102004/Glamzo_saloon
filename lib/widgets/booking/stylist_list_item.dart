import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/trainer_model.dart';

class StylistListItem extends StatelessWidget {
  final TrainerModel trainer;
  final bool selected;
  final String? nextSlot;
  final VoidCallback? onTap;

  const StylistListItem({
    super.key,
    required this.trainer,
    this.selected = false,
    this.nextSlot,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.goldBg : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.goldBorder : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border2,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  trainer.name.isNotEmpty
                      ? trainer.name[0].toUpperCase()
                      : '?',
                  style: AppTextStyles.body1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trainer.name, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 3),
                  Text(trainer.specialties.join(' · '),
                      style: AppTextStyles.body2,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 12, color: AppColors.gold),
                      const SizedBox(width: 3),
                      Text(trainer.rating.toStringAsFixed(1),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.goldDeep,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('(${trainer.totalReviews})',
                          style: AppTextStyles.caption),
                      if (nextSlot != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 4, height: 4,
                          decoration: const BoxDecoration(
                            color: AppColors.text4,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('Next: $nextSlot',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.sage)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.gold, size: 22),
          ],
        ),
      ),
    );
  }
}
