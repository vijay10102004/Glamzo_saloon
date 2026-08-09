import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/slot_model.dart';

class TimeSlotChip extends StatelessWidget {
  final SlotModel slot;
  final bool selected;
  final VoidCallback? onTap;

  const TimeSlotChip({
    super.key,
    required this.slot,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = slot.isAvailable;
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.goldGradient : null,
          color: selected
              ? null
              : isAvailable
                  ? AppColors.cardWhite
                  : AppColors.surface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.gold
                : isAvailable
                    ? AppColors.border
                    : AppColors.border2,
          ),
        ),
        child: Text(
          DateFormat('hh:mm a').format(slot.startTime),
          style: AppTextStyles.label.copyWith(
            color: selected
                ? Colors.white
                : isAvailable
                    ? AppColors.ink
                    : AppColors.text4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
