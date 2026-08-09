import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/offers_provider.dart';
import '../../models/loyalty_model.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    _progressAnim = CurvedAnimation(parent: _progressController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userModelAsync = ref.watch(userModelProvider);
    final loyaltyHistoryAsync = ref.watch(loyaltyHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: userModelAsync.when(
        data: (userModel) {
          final points = userModel?.loyaltyPoints ?? 0;
          final hasVoucher = userModel?.hasLoyaltyVoucher ?? false;
          final progress = (points / AppConstants.loyaltyRedemptionThreshold).clamp(0.0, 1.0);
          final remaining = (AppConstants.loyaltyRedemptionThreshold - points).clamp(0, AppConstants.loyaltyRedemptionThreshold);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Hero App Bar ──
              SliverAppBar(
                expandedHeight: 340,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.espresso,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    margin: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _LoyaltyHero(
                    points: points,
                    progress: progress,
                    hasVoucher: hasVoucher,
                    remaining: remaining,
                    progressAnim: _progressAnim,
                  ),
                ),
              ),

              // ── Voucher Card – show when points >= threshold OR voucher flag set ──
              if (hasVoucher || points >= AppConstants.loyaltyRedemptionThreshold)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _VoucherCard(
                      onRedeem: () => _redeemVoucher(context),
                    ),
                  ),
                ),

              // ── How It Works ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: _HowItWorks(),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('POINTS HISTORY',
                        style: AppTextStyles.eyebrow.copyWith(
                          color: AppColors.gold, letterSpacing: 3),
                        textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Earning & Redemption Log',
                        style: AppTextStyles.sectionTitle,
                        textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),

              // ── History List ──
              loyaltyHistoryAsync.when(
                data: (history) {
                  if (history.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.goldBg,
                                border: Border.all(color: AppColors.goldBorder),
                              ),
                              child: const Icon(Icons.history_rounded, color: AppColors.gold, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text('No history yet', style: AppTextStyles.sectionTitle),
                            const SizedBox(height: 8),
                            Text('Complete a booking to start earning points!',
                              style: AppTextStyles.body2, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _HistoryItem(txn: history[i]),
                      childCount: history.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Center(child: Text('Error: $e')),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _redeemVoucher(BuildContext context) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Text('Redeem Voucher', style: AppTextStyles.cardTitle),
          ],
        ),
        content: Text(
          'Redeem your ₹${AppConstants.loyaltyVoucherValue.toInt()} voucher?\n\n₹${AppConstants.loyaltyVoucherValue.toInt()} will be credited directly to your Wallet and can be used on any booking. ${AppConstants.loyaltyRedemptionThreshold} points will be deducted.',
          style: AppTextStyles.body2.copyWith(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
          ),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Redeem', style: AppTextStyles.label.copyWith(color: Colors.white)),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(firestoreServiceProvider).redeemLoyaltyVoucher(user.uid);
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: AppColors.sage, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('🎉 ₹200 credited to your Wallet! Use it on any booking.',
                    style: AppTextStyles.body2.copyWith(color: AppColors.ink)),
                ),
              ],
            ),
            backgroundColor: AppColors.sageBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.sageBorder),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.roseBg),
        );
      }
    }
  }
}

// ── Loyalty Hero (animated ring) ──
class _LoyaltyHero extends StatelessWidget {
  final int points;
  final double progress;
  final bool hasVoucher;
  final int remaining;
  final Animation<double> progressAnim;

  const _LoyaltyHero({
    required this.points,
    required this.progress,
    required this.hasVoucher,
    required this.remaining,
    required this.progressAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0B08), Color(0xFF0D0B08), Color(0xFF1C1208)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Decorative glow orb – top-right corner
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.14), Colors.transparent],
                ),
              ),
            ),
          ),
          // Second glow orb – bottom-left for depth
          Positioned(
            bottom: -60, left: -40,
            child: Container(
              width: 180, height: 180,
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
                  // ── Eyebrow label ──
                  Text(
                    'GLAMZO REWARDS',
                    style: AppTextStyles.eyebrow.copyWith(
                      color: AppColors.gold3, letterSpacing: 3, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  // ── Title ──
                  Text(
                    'Your Loyalty Points',
                    style: AppTextStyles.display2.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  // ── Animated Ring Progress ──
                  AnimatedBuilder(
                    animation: progressAnim,
                    builder: (_, __) => CustomPaint(
                      size: const Size(180, 180),
                      painter: _RingPainter(
                        progress: progress * progressAnim.value,
                        hasVoucher: hasVoucher,
                      ),
                      child: SizedBox(
                        width: 180, height: 180,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                color: hasVoucher ? AppColors.gold3 : AppColors.gold,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$points',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                'points',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6)),
                                textAlign: TextAlign.center,
                              ),
                              if (hasVoucher)
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.goldGradient,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹200 Voucher Ready!',
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── Bottom status message ──
                  if (!hasVoucher && points < AppConstants.loyaltyRedemptionThreshold)
                    Text(
                      '$remaining more points to unlock ₹200 voucher',
                      style: AppTextStyles.body2.copyWith(
                        color: Colors.white.withValues(alpha: 0.7)),
                      textAlign: TextAlign.center,
                    ),
                  if (points >= AppConstants.loyaltyRedemptionThreshold && !hasVoucher)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '₹200 Voucher Unlocked! Tap below to redeem',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                        textAlign: TextAlign.center,
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

// ── Ring Painter ──
class _RingPainter extends CustomPainter {
  final double progress;
  final bool hasVoucher;
  const _RingPainter({required this.progress, required this.hasVoucher});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 14;
    final strokeWidth = 12.0;

    // Background track
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: hasVoucher
          ? [const Color(0xFFFFD700), const Color(0xFFFFA500), const Color(0xFFFFD700)]
          : [const Color(0xFFC8A96E), const Color(0xFFE8C87A), const Color(0xFFC8A96E)],
      stops: const [0.0, 0.5, 1.0],
    );
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.hasVoucher != hasVoucher;
}

// ── Voucher Card ──
class _VoucherCard extends StatelessWidget {
  final VoidCallback onRedeem;
  const _VoucherCard({required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D0B08), Color(0xFF1C1208)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.gold.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
              boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 12)],
            ),
            child: const Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('🎉 ₹200 Voucher Unlocked!',
                  style: AppTextStyles.cardTitle.copyWith(color: AppColors.gold3)),
                const SizedBox(height: 3),
                Text('Auto-applies on your next booking',
                  style: AppTextStyles.caption.copyWith(color: AppColors.gold3.withValues(alpha: 0.7))),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRedeem,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Use Now',
                style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── How It Works ──
class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.cardWhite,
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldBg2,
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: const Icon(Icons.help_outline_rounded, color: AppColors.gold, size: 16),
              ),
              const SizedBox(width: 12),
              Text('How Rewards Work',
                style: AppTextStyles.cardTitle.copyWith(color: AppColors.goldDeep)),
            ],
          ),
          const SizedBox(height: 16),
          _HowToRow(
            icon: Icons.currency_rupee_rounded,
            text: '₹1 spent = ${AppConstants.loyaltyPointsPerRupee} loyalty point',
          ),
          const SizedBox(height: 10),
          _HowToRow(
            icon: Icons.workspace_premium_rounded,
            text: '${AppConstants.loyaltyRedemptionThreshold} points = ₹${AppConstants.loyaltyVoucherValue.toInt()} discount voucher',
          ),
          const SizedBox(height: 10),
          _HowToRow(
            icon: Icons.auto_awesome,
            text: 'Voucher is auto-applied at checkout',
          ),
          const SizedBox(height: 10),
          _HowToRow(
            icon: Icons.timer_outlined,
            text: 'Points credited immediately after payment',
          ),
        ],
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HowToRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.goldBg,
          border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.6)),
        ),
        child: Icon(icon, color: AppColors.gold, size: 13),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(text, style: AppTextStyles.body2.copyWith(color: AppColors.text2))),
    ],
  );
}

// ── History Item ──
class _HistoryItem extends StatelessWidget {
  final LoyaltyTransaction txn;
  const _HistoryItem({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isEarned = txn.type == 'earned';
    final color = isEarned ? AppColors.sage : AppColors.rose;
    final bg = isEarned ? AppColors.sageBg : AppColors.roseBg;
    final border = isEarned ? AppColors.sageBorder : AppColors.roseBorder;
    final sign = isEarned ? '+' : '-';
    final absPoints = txn.points.abs();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.cardWhite,
          border: Border.all(color: AppColors.border2),
          boxShadow: [
            BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bg,
                border: Border.all(color: border),
              ),
              child: Icon(
                isEarned ? Icons.add_rounded : Icons.remove_rounded,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(txn.description,
                    style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMM yyyy • hh:mm a').format(txn.createdAt),
                    style: AppTextStyles.caption.copyWith(color: AppColors.text4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Text(
                '$sign$absPoints pts',
                style: AppTextStyles.label.copyWith(
                  color: color, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
