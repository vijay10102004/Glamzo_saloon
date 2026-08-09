import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/offer_model.dart';

class ServiceSelectCard extends StatelessWidget {
  final OfferModel offer;
  final bool selected;
  final VoidCallback? onTap;

  const ServiceSelectCard({
    super.key,
    required this.offer,
    this.selected = false,
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
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 12, offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(offer.description,
                      style: AppTextStyles.body2,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('₹${offer.price.toInt()}',
                          style: AppTextStyles.price),
                      const SizedBox(width: 8),
                      Text('₹${offer.originalPrice.toInt()}',
                          style: AppTextStyles.caption.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.text4,
                          )),
                      const SizedBox(width: 8),
                      if (offer.discountPercent > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sageBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${offer.discountPercent}% off',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.sage,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.gold : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.gold : AppColors.border2,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
