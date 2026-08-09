import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class GlamzoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final bool hasShadow;
  final VoidCallback? onTap;

  const GlamzoCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.hasShadow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color ?? AppColors.cardWhite,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: card);
    }
    return card;
  }
}
