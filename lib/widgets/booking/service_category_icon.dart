import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

// ── Category → Material Icon mapping ──────────────────────────────────────────
// UI-only mapping: keeps ServiceModel.icon (emoji) untouched in Firestore.
// Fallback to Icons.spa for any unknown category.
IconData serviceCategoryIcon(String category) {
  switch (category) {
    case 'Threading':              return Icons.remove_red_eye_rounded;
    case 'Waxing':                  return Icons.spa_rounded;
    case 'Bleach':                  return Icons.auto_awesome_rounded;
    case 'Head Massage':            return Icons.self_improvement_rounded;
    case 'Facial':                  return Icons.face_retouching_natural_rounded;
    case 'Manicure':                return Icons.back_hand_rounded;
    case 'Pedicure':                return Icons.accessibility_new_rounded;
    case 'Haircut':                 return Icons.content_cut_rounded;
    case 'Hair Coloring':           return Icons.brush_rounded;
    case 'Color Highlights':        return Icons.palette_rounded;
    case 'Hair Spa':                return Icons.water_drop_rounded;
    case 'Hair & Scalp':            return Icons.health_and_safety_rounded;
    case 'Keratin Treatment':       return Icons.diamond_rounded;
    case 'Straightening':           return Icons.straighten_rounded;
    case 'Smoothening':             return Icons.blur_on_rounded;
    case 'Blow Dry':                return Icons.air_rounded;
    case 'Nano Plastia Treatment':  return Icons.science_rounded;
    case 'Botox Treatment':         return Icons.medical_services_rounded;
    case 'Beard Design':            return Icons.face_rounded;
    default:                        return Icons.spa_rounded;
  }
}

// ── Reusable circular icon widget used by both service tile types ─────────────
class ServiceCategoryIconWidget extends StatelessWidget {
  final String category;
  final double size;
  final bool isSelected;

  const ServiceCategoryIconWidget({
    super.key,
    required this.category,
    this.size = 58,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = serviceCategoryIcon(category);
    final double iconSize = size * 0.40;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Gradient background for premium gold look
        gradient: isSelected
            ? AppColors.goldGradient
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFBF2DC), Color(0xFFF5E4B8)],
              ),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.goldBorder,
          width: isSelected ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: isSelected ? 0.35 : 0.18),
            blurRadius: isSelected ? 14 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: isSelected ? Colors.white : AppColors.goldDeep,
        ),
      ),
    );
  }
}
