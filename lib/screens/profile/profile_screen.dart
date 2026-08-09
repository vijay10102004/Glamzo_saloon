import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../core/constants/app_constants.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authServiceProvider).currentUser;
    final email = user?.email ?? 'Guest';
    // Try to use saved name from Firestore; fall back to email prefix
    final userModelAsync = ref.watch(userModelProvider);
    final savedName = userModelAsync.value?.name ?? '';
    final String displayName;
    if (savedName.isNotEmpty) {
      final first = savedName.trim().split(' ').first;
      displayName = first[0].toUpperCase() + first.substring(1);
    } else {
      final emailPrefix = email.split('@').first.split('.').first;
      displayName = emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
    }
    final walletBalance = userModelAsync.value?.walletBalance ?? 0.0;
    final loyaltyPoints = userModelAsync.value?.loyaltyPoints ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Espresso Hero ──
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.espresso,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHero(displayName: displayName, email: email),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Wallet & Rewards Card ──
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF100E09), Color(0xFF1E1409), Color(0xFF2A1A08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppColors.goldBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // ── Wallet Balance Row ──
                      GestureDetector(
                        onTap: () => context.push('/home/loyalty'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                          child: Row(
                            children: [
                              // Icon badge
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.goldGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_rounded,
                                  color: Colors.white, size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Label + value
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Available Wallet Balance',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.gold3.withValues(alpha: 0.85),
                                        letterSpacing: 0.4,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '₹${walletBalance.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                        height: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Usable on any booking',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tap affordance
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: AppColors.goldBorder.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppColors.gold3, size: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Gold Divider ──
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Container(
                          height: 1,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.goldBorder.withValues(alpha: 0.6),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Glamzo Rewards Points Row ──
                      GestureDetector(
                        onTap: () => context.push('/home/loyalty'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          child: Row(
                            children: [
                              // Icon badge
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  border: Border.all(
                                    color: AppColors.goldBorder.withValues(alpha: 0.6)),
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  color: AppColors.gold3, size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              // Label + value
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Glamzo Rewards Points',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.gold3.withValues(alpha: 0.85),
                                        letterSpacing: 0.4,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '$loyaltyPoints',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                            height: 1.1,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'pts',
                                          style: AppTextStyles.body2.copyWith(
                                            color: AppColors.gold3.withValues(alpha: 0.7),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Earn ₹200 voucher at 10,000 pts',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Tap affordance
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.gold.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: AppColors.goldBorder.withValues(alpha: 0.4)),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: AppColors.gold3, size: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Account Section ──
                _SectionLabel(label: 'ACCOUNT'),
                const SizedBox(height: 10),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.history_rounded,
                      label: 'Booking History',
                      onTap: () => context.push('/home/queue'),
                    ),
                    _MenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notifications',
                      onTap: () => context.push('/home/notifications'),
                    ),
                    _MenuItem(
                      icon: Icons.payment_rounded,
                      label: 'Payment Methods',
                      subtitle: 'UPI · Google Pay · PhonePe',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Salon Info ──
                _SectionLabel(label: 'SALON INFO'),
                const SizedBox(height: 10),
                _InfoCard(),

                const SizedBox(height: 20),

                // ── App Section ──
                _SectionLabel(label: 'APP'),
                const SizedBox(height: 10),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Help & Support',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Privacy Policy',
                      onTap: () {},
                    ),
                    _MenuItem(
                      icon: Icons.info_outline_rounded,
                      label: 'App Version',
                      subtitle: '1.0.0',
                      onTap: null,
                      showArrow: false,
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Logout ──
                GestureDetector(
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.roseBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.roseBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, color: AppColors.rose, size: 18),
                        const SizedBox(width: 10),
                        Text('Sign Out',
                          style: AppTextStyles.body1.copyWith(
                            color: AppColors.rose, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                // ── Bottom safe-area spacer ──
                // Accounts for system nav bar + extra breathing room
                // so Sign Out is never clipped on any device.
                Builder(
                  builder: (ctx) {
                    final bottomInset = MediaQuery.of(ctx).padding.bottom;
                    return SizedBox(height: bottomInset + 48);
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Profile Hero ──
class _ProfileHero extends StatelessWidget {
  final String displayName;
  final String email;
  const _ProfileHero({required this.displayName, required this.email});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0B08), Color(0xFF1C1208), Color(0xFF2E1E0A)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative glow orb – top-right
          Positioned(
            top: -30, right: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.14), Colors.transparent],
                ),
              ),
            ),
          ),
          // Decorative glow orb – bottom-left for depth
          Positioned(
            bottom: -50, left: -30,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.07), Colors.transparent],
                ),
              ),
            ),
          ),
          // All content — perfectly centered vertically & horizontally
          Center(
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Avatar ──
                  Container(
                    width: 84, height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ── Display Name ──
                  Text(
                    displayName,
                    style: AppTextStyles.display2.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  // ── Email ──
                  Text(
                    email,
                    style: AppTextStyles.body2.copyWith(
                      color: Colors.white.withValues(alpha: 0.6)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // ── Premium Member Badge ──
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.goldBorder.withValues(alpha: 0.55)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.gold3, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'Premium Member',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: AppColors.gold3,
                            fontSize: 9,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ──
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold, letterSpacing: 2.5),
  );
}

// ── Menu Card ──
class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              _MenuItemTile(item: e.value),
              if (!isLast) Container(height: 1, color: AppColors.border, margin: const EdgeInsets.only(left: 54)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool showArrow;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.showArrow = true,
  });
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: AppColors.goldBg,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldBg,
                border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.5)),
              ),
              child: Icon(item.icon, color: AppColors.gold, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: AppTextStyles.body1),
                  if (item.subtitle != null)
                    Text(item.subtitle!, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (item.showArrow)
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.text4),
          ],
        ),
      ),
    );
  }
}

// ── Info Card ──
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(icon: Icons.location_on_outlined, label: AppConstants.salonAddress),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.phone_outlined, label: AppConstants.salonPhone),
          const SizedBox(height: 12),
          _InfoRow(icon: Icons.phonelink_ring_outlined, label: 'Payments via PhonePe'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.goldBg,
            border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.5)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 15),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTextStyles.body2),
        ),
      ],
    );
  }
}
