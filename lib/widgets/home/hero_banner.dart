import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class HeroBanner extends StatelessWidget {
  const HeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 200,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circles
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 30, bottom: -30,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Gold accent top-left line
          Positioned(
            left: 24, top: 24,
            child: Container(
              width: 32, height: 2,
              color: AppColors.gold.withValues(alpha: 0.6),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('PREMIUM SALON', style: AppTextStyles.eyebrow.copyWith(
                  color: AppColors.gold3.withValues(alpha: 0.8),
                  letterSpacing: 3,
                )),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(
                      text: 'Elevate Your\n',
                      style: AppTextStyles.heroName.copyWith(fontSize: 24),
                    ),
                    TextSpan(
                      text: 'Style Story',
                      style: AppTextStyles.heroNameItalic.copyWith(fontSize: 24),
                    ),
                  ]),
                ),
                const Spacer(),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/home/trainer-select'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: AppColors.goldGradient,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text('Book Now',
                            style: AppTextStyles.btnLabel.copyWith(
                                fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.go('/home/queue'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Live Queue',
                            style: AppTextStyles.caption.copyWith(
                                color: Colors.white70,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
