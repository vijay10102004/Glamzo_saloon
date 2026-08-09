import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class DateChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback? onTap;

  const DateChip({
    super.key,
    required this.date,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(date);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldGradient : null,
          color: selected ? null : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    blurRadius: 8, offset: const Offset(0, 3),
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Text(
              DateFormat('EEE').format(date).toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                color: selected ? Colors.white70 : AppColors.text3,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('d').format(date),
              style: AppTextStyles.body1.copyWith(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isToday)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4, height: 4,
                decoration: BoxDecoration(
                  color: selected ? Colors.white70 : AppColors.gold,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
