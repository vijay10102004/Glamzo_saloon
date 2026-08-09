import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/offers_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shell wrapper — unchanged public API, router still calls this
// ─────────────────────────────────────────────────────────────────────────────
class BottomNavShell extends ConsumerWidget {
  final Widget child;
  const BottomNavShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      _BottomNavShellBody(ref: ref, child: child);
}

class _BottomNavShellBody extends StatelessWidget {
  final Widget child;
  final WidgetRef ref;
  const _BottomNavShellBody({required this.child, required this.ref});

  /// 0 = Home · 1 = Queue · 2 = Alerts · 3 = Profile
  int _selectedIndex(String location) {
    if (location.startsWith('/home/queue'))         return 1;
    if (location.startsWith('/home/notifications')) return 2;
    if (location.startsWith('/home/profile'))       return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      extendBody: true,
      body: child,
      bottomNavigationBar: _PremiumNavBar(
        selectedIndex:   _selectedIndex(location),
        currentLocation: location,
        onBookNow: () {
          ref.read(selectedServicesProvider.notifier).state = [];
          context.push('/home/book-now');
        },
        onHome:    () => context.go('/home'),
        onQueue:   () => context.go('/home/queue'),
        onAlerts:  () => context.go('/home/notifications'),
        onProfile: () => context.go('/home/profile'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Nav Bar
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumNavBar extends StatefulWidget {
  final int          selectedIndex;
  final String       currentLocation;
  final VoidCallback onBookNow;
  final VoidCallback onHome;
  final VoidCallback onQueue;
  final VoidCallback onAlerts;
  final VoidCallback onProfile;

  const _PremiumNavBar({
    required this.selectedIndex,
    required this.currentLocation,
    required this.onBookNow,
    required this.onHome,
    required this.onQueue,
    required this.onAlerts,
    required this.onProfile,
  });

  @override
  State<_PremiumNavBar> createState() => _PremiumNavBarState();
}

class _PremiumNavBarState extends State<_PremiumNavBar>
    with SingleTickerProviderStateMixin {

  // Continuous shimmer sweep on the pill
  late final AnimationController _shimmerCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  late final Animation<double> _shimmerAnim = Tween<double>(
    begin: -1.0,
    end:    2.0,
  ).animate(CurvedAnimation(parent: _shimmerCtrl, curve: Curves.linear));

  // ── Single source of truth ─────────────────────────────────────────────────
  // The pill is shown ONLY on the exact /home route.
  // All sub-routes (/home/book-now, /home/trainer-select, etc.) return false
  // automatically — no per-screen code needed, future routes included.
  bool get _pillVisible => widget.currentLocation == '/home';

  // Pill width when fully open — nav height is 60 px, pill is 36 px tall
  static const double _pillWidth = 116.0;

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = _pillVisible;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1.0)),
        boxShadow: [
          BoxShadow(
            color:      AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 20,
            offset:     const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              // ── LEFT: Home + Queue — Expanded fills space when pill hides ──
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      icon:       Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label:      'Home',
                      selected:   widget.selectedIndex == 0,
                      onTap:      widget.onHome,
                    ),
                    _NavItem(
                      icon:       Icons.access_time_outlined,
                      activeIcon: Icons.access_time_filled_rounded,
                      label:      'Queue',
                      selected:   widget.selectedIndex == 1,
                      onTap:      widget.onQueue,
                    ),
                  ],
                ),
              ),

              // ── CENTER: AnimatedContainer collapses to 0 when pill hides ──
              // The two Expanded sides naturally fill the freed space with no
              // empty gap — zero extra layout code needed.
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve:    Curves.easeInOut,
                // Width toggles between full pill width and zero
                width: show ? _pillWidth : 0.0,
                // Clips the pill as the container shrinks — no overflow ever
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: show ? 1.0 : 0.0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 350),
                      scale:    show ? 1.0 : 0.6,
                      curve:    show ? Curves.elasticOut : Curves.easeInBack,
                      child: _BookNowPill(
                        shimmerAnim: _shimmerAnim,
                        onTap:       widget.onBookNow,
                      ),
                    ),
                  ),
                ),
              ),

              // ── RIGHT: Alerts + Profile — Expanded fills space when pill hides ──
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      icon:       Icons.notifications_outlined,
                      activeIcon: Icons.notifications_rounded,
                      label:      'Alerts',
                      selected:   widget.selectedIndex == 2,
                      onTap:      widget.onAlerts,
                    ),
                    _NavItem(
                      icon:       Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label:      'Profile',
                      selected:   widget.selectedIndex == 3,
                      onTap:      widget.onProfile,
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Book Now Pill  ✂  Book Now  ›
// Fixed intrinsic size — the parent AnimatedContainer handles show/hide width.
// ─────────────────────────────────────────────────────────────────────────────
class _BookNowPill extends StatelessWidget {
  final Animation<double> shimmerAnim;
  final VoidCallback       onTap;

  const _BookNowPill({required this.shimmerAnim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  110,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
           // colors: [Color(0xFFE8C040), Color(0xFFD4A017), Color(0xFF8B6510)],
         colors: [
  Color(0xFF8B6510), // dark gold
  Color(0xFFFFE08A), // shine
  Color(0xFFD4A017), // rich gold
],
            stops:  [0.0, 0.50, 1.0],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color:       const Color(0xFFD4A017).withValues(alpha: 0.50),
              blurRadius:  12,
              spreadRadius: 0,
              offset:      const Offset(0, 5),
            ),
            BoxShadow(
              color:      Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset:     const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Stack(
            alignment: Alignment.center,
            children: [

              // Top gloss highlight
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.30),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Sweeping shimmer
              AnimatedBuilder(
                animation: shimmerAnim,
                builder: (_, __) => Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(shimmerAnim.value, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.28),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ✂  Book Now  ›
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize:      MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.content_cut_rounded,
                    color: Colors.white,
                    size:  12,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Book Now',
                    style: AppTextStyles.btnLabel.copyWith(
                      fontSize:      12,
                      fontWeight:    FontWeight.w800,
                      letterSpacing: 0.2,
                      color:         const Color(0xFF4A3200),
                      shadows: [
                        Shadow(
                          color:      Colors.black.withValues(alpha: 0.20),
                          blurRadius: 3,
                          offset:     const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size:  14,
                  ),
                ],
              ),

            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Nav Item  (Home / Queue / Alerts / Profile)
// ─────────────────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData     icon;
  final IconData     activeIcon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:        selected ? AppColors.goldBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                selected ? activeIcon : icon,
                key:   ValueKey(selected),
                color: selected ? AppColors.gold : AppColors.text4,
                size:  23,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color:      selected ? AppColors.gold : AppColors.text4,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                fontSize:   10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
