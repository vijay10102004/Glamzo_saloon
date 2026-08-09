import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class BottomNavShell extends StatelessWidget {
  final Widget child;
  const BottomNavShell({super.key, required this.child});

  int _idx(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/home/queue')) return 1;
    if (loc.startsWith('/home/notifications')) return 2;
    if (loc.startsWith('/home/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _idx(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        height: 76,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border))),
        child: Row(children: [
          _Tab(icon: Icons.home_outlined, activeIcon: Icons.home,
            label: 'Home', active: idx == 0,
            onTap: () => context.go('/home')),
          _Tab(icon: Icons.access_time_outlined, activeIcon: Icons.access_time,
            label: 'Queue', active: idx == 1, badge: '1',
            onTap: () => context.go('/home/queue')),
          _Tab(icon: Icons.notifications_outlined, activeIcon: Icons.notifications,
            label: 'Alerts', active: idx == 2, badge: '3',
            onTap: () => context.go('/home/notifications')),
          _Tab(icon: Icons.person_outline, activeIcon: Icons.person,
            label: 'Profile', active: idx == 3,
            onTap: () => context.go('/home/profile')),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool active;
  final String? badge;
  final VoidCallback onTap;
  const _Tab({required this.icon, required this.activeIcon,
    required this.label, required this.active, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: active ? AppColors.goldGradient : null,
              borderRadius: BorderRadius.circular(8),
              boxShadow: active ? [BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 12, offset: const Offset(0, 4))] : null,
            ),
            child: Icon(active ? activeIcon : icon,
              color: active ? Colors.white : AppColors.text4, size: 16),
          ),
          if (badge != null) Positioned(top: -4, right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.rose, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5)),
              child: Text(badge!, style: const TextStyle(
                color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            )),
        ]),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(
          color: active ? AppColors.gold : AppColors.text4,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
      ]),
    ),
  );
}