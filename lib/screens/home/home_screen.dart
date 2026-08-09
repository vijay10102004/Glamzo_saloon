import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../models/offer_model.dart';
import '../../models/service_model.dart';
import '../../models/trainer_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late AnimationController _bookBtnPulse;
  late Animation<double> _bookBtnScale;
  late AnimationController _bookBtnShimmer;
  late Animation<double> _bookBtnShimmerAnim;
  bool _bookingActive = false;
  bool _oneTimeOfferShown = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _headerController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);

    // Book Now button pulse animation
    _bookBtnPulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _bookBtnScale = Tween<double>(begin: 1.0, end: 1.025).animate(
      CurvedAnimation(parent: _bookBtnPulse, curve: Curves.easeInOut),
    );

    // Book Now shimmer sweep
    _bookBtnShimmer = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400),
    )..repeat();
    _bookBtnShimmerAnim = Tween<double>(begin: -2.0, end: 3.0).animate(
      CurvedAnimation(parent: _bookBtnShimmer, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _headerController.dispose();
    _bookBtnPulse.dispose();
    _bookBtnShimmer.dispose();
    super.dispose();
  }

  void _maybeShowOneTimeOffer(BuildContext context, userModel) {
    if (_oneTimeOfferShown) return;
    if (userModel == null) return;
    if (userModel.oneTimeOfferClaimed == true) return;
    _oneTimeOfferShown = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _showOneTimeOfferDialog(this.context);
    });
  }

  Future<void> _showOneTimeOfferDialog(BuildContext context) async {
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;
    if (!context.mounted) return;

    final claimed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _OneTimeOfferDialog(),
    );

    if (claimed == true) {
      try {
        await ref.read(firestoreServiceProvider).claimOneTimeOffer(uid: user.uid);
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: AppColors.sage, size: 18),
                  SizedBox(width: 10),
                  Text('₹100 credited to your Wallet!',selectionColor: Colors.black,),
                ],
              ),
              backgroundColor: const Color.fromARGB(255, 6, 17, 6),
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
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userModelProvider);
    final userModel = userAsync.value;

    // Watch the shared bookingActive provider so that tapping an offer card
    // or service card (which sets bookingActiveProvider = true) also hides
    // the hero Book Now button immediately.
    final bookingProviderActive = ref.watch(bookingActiveProvider);
    final anyBookingActive = _bookingActive || bookingProviderActive;

    if (userModel != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowOneTimeOffer(context, userModel);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Ã¢â€ â‚¬Ã¢â€ â‚¬ Hero Header Ã¢â€ â‚¬Ã¢â€ â‚¬
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFade,
              child: _HeroHeader(
                userModel: userModel,
                bookBtnScale: _bookBtnScale,
                bookBtnShimmerAnim: _bookBtnShimmerAnim,
                bookingActive: anyBookingActive,
                onBookTap: () {
                  setState(() => _bookingActive = true);
                  context.push('/home/book-now').then((_) {
                    if (mounted) setState(() => _bookingActive = false);
                  });
                },
              ),
            ),
          ),

          // Ã¢â€ â‚¬Ã¢â€ â‚¬ Search Bar Ã¢â€ â‚¬Ã¢â€ â‚¬
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: GestureDetector(
                onTap: () => context.push('/home/search'),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.07),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      const Icon(Icons.search_rounded, color: AppColors.text3, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'Search services, stylists...',
                        style: AppTextStyles.body2.copyWith(color: AppColors.text4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Premium Offers Big Carousel Ã¢â€â‚¬Ã¢â€â‚¬
          const SliverToBoxAdapter(child: _PremiumOffersSection()),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Services Medium Carousel Ã¢â€â‚¬Ã¢â€â‚¬
          const SliverToBoxAdapter(child: _ServicesSection()),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Stylists Ã¢â€â‚¬Ã¢â€â‚¬
          const SliverToBoxAdapter(child: _StylistsSection()),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Why Glamzo Features Ã¢â€â‚¬Ã¢â€â‚¬
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 36, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    label: 'WHY GLAMZO',
                  ),
                  SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _FeatureCard(icon: Icons.star_rounded,   label: 'Top\nProfessionals')),
                      SizedBox(width: 12),
                      Expanded(child: _FeatureCard(icon: Icons.timer_rounded,  label: 'Real-Time\nSlots')),
                      SizedBox(width: 12),
                      Expanded(child: _FeatureCard(icon: Icons.shield_rounded, label: 'Secure\nPayments')),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Loyalty CTA Ã¢â€â‚¬Ã¢â€â‚¬
          SliverToBoxAdapter(child: _LoyaltyCta()),

          // Ã¢â€â‚¬Ã¢â€â‚¬ Reviews Ã¢â€â‚¬Ã¢â€â‚¬
          const SliverToBoxAdapter(child: _ReviewsSection()),

          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Section Header
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onViewAll;

  const _SectionHeader({
    required this.icon,
    required this.label,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: AppColors.goldGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: AppTextStyles.eyebrow.copyWith(
            letterSpacing: 1.8,
            color: AppColors.ink,
            fontSize: 13,
          ),
        ),
        if (onViewAll != null) ...[
          const Spacer(),
          GestureDetector(
            onTap: onViewAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.goldBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.5)),
              ),
              child: Text(
                'View all',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.goldDeep,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// One-Time Offer Dialog
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _OneTimeOfferDialog extends StatelessWidget {
  const _OneTimeOfferDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1208), Color(0xFF2E1E0A)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70, height: 70,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome Gift!',
              style: AppTextStyles.display2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Claim ₹100 free wallet credit\nas a first-time welcome bonus.',
              style: AppTextStyles.body2.copyWith(color: const Color.fromARGB(255, 249, 246, 246), height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Claim ₹100 Now', style: AppTextStyles.btnLabel),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Maybe later',
                style: AppTextStyles.caption.copyWith(color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Hero Header  (cream background)
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _HeroHeader extends ConsumerWidget {
  final dynamic userModel;
  final Animation<double> bookBtnScale;
  final Animation<double> bookBtnShimmerAnim;
  final bool bookingActive;
  final VoidCallback onBookTap;

  const _HeroHeader({
    this.userModel,
    required this.bookBtnScale,
    required this.bookBtnShimmerAnim,
    required this.bookingActive,
    required this.onBookTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name   = (userModel?.name as String?)?.isNotEmpty == true
        ? (userModel!.name as String).split(' ').first
        : 'there';
    final wallet = (userModel?.walletBalance as double?) ?? 0.0;
    final points = (userModel?.loyaltyPoints as int?)   ?? 0;
    final screenW = MediaQuery.sizeOf(context).width;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFAF3E0), Color(0xFFEEDFBE)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Ã¢â€â‚¬Ã¢â€â‚¬ Top row Ã¢â€â‚¬Ã¢â€â‚¬
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $name', style: AppTextStyles.heroName),
                        const SizedBox(height: 3),
                        Text(
                          'Ready to look your best?',
                          style: AppTextStyles.body2.copyWith(
                            color: AppColors.text3, fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bell
                  Consumer(builder: (context, ref, _) {
                    return GestureDetector(
                      onTap: () => context.push('/home/notifications'),
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardWhite,
                          border: Border.all(color: AppColors.border, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.10),
                              blurRadius: 8, offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.ink2, size: 22,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 10),
                  // Avatar
                  GestureDetector(
                    onTap: () => context.push('/home/profile'),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.goldGradient,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.38),
                            blurRadius: 12, offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'G',
                        style: AppTextStyles.body1.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ── Wallet + Points cards ──
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/home/profile'),
                      child: _InfoCard(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Wallet',
                        value: '₹${wallet.toStringAsFixed(0)}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push('/home/loyalty'),
                      child: _InfoCard(
                        icon: Icons.stars_rounded,
                        label: 'Points',
                        value: '$points pts',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ── Book Your Appointment ─ Solid Gold Button ──
              // Visibility is controlled by bookingActive from the parent.
              // Immediately hidden when user taps any offer, service, or this button.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.12),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: bookingActive
                    ? const SizedBox.shrink(key: ValueKey('btn_hidden'))
                    : ScaleTransition(
                        key: const ValueKey('btn_visible'),
                        scale: bookBtnScale,
                        child: GestureDetector(
                          onTap: onBookTap,
                              child: Container(
                                width: double.infinity,
                                height: 62,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF6E4B0E),
    Color(0xFFFFE9A0),
    Color(0xFFD4A017),
  ],
  stops: [0.0, 0.48, 1.0],
),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFD4A017).withValues(alpha: 0.50),
                                      blurRadius: 18,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.14),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Subtle top gloss
                                      Positioned(
                                        top: 0, left: 0, right: 0,
                                        child: Container(
                                          height: 28,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.white.withValues(alpha: 0.18),
                                                Colors.white.withValues(alpha: 0.0),
                                              ],
                                            ),
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(18)),
                                          ),
                                        ),
                                      ),
                                      // Shimmer sweep
                                      AnimatedBuilder(
                                        animation: bookBtnShimmerAnim,
                                        builder: (_, __) => Positioned.fill(
                                          child: Transform.translate(
                                            offset: Offset(
                                                bookBtnShimmerAnim.value * screenW, 0),
                                            child: Container(
                                              width: 80,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.white.withValues(alpha: 0.0),
                                                    Colors.white.withValues(alpha: 0.25),
                                                    Colors.white.withValues(alpha: 0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Content row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Calendar icon circle
                                            Container(
                                              width: 42, height: 42,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(alpha: 0.25),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.50),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.calendar_today_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Text column
                                            Expanded(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Book Your Appointment',
                                                    style: AppTextStyles.btnLabel.copyWith(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w800,
                                                      letterSpacing: 0.1,
                                                      color: const Color(0xFF4A3200),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Tap to schedule your session',
                                                    style: AppTextStyles.caption.copyWith(
                                                      color: const Color(0xFF4A3200),
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            // Arrow circle
                                            Container(
                                              width: 36, height: 36,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white.withValues(alpha: 0.25),
                                                border: Border.all(
                                                  color: Colors.white.withValues(alpha: 0.50),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€ Reusable Info Card (Wallet / Points) â”€â”€
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.text3, fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
                Text(value,
                    style: AppTextStyles.body1.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Premium Offers  Ã¢â‚¬â€  BIG CARD AUTO-CAROUSEL
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _PremiumOffersSection extends ConsumerStatefulWidget {
  const _PremiumOffersSection();

  @override
  ConsumerState<_PremiumOffersSection> createState() =>
      _PremiumOffersSectionState();
}

class _PremiumOffersSectionState
    extends ConsumerState<_PremiumOffersSection> {
  // Full-width (no viewport fraction peek)
  late final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_current + 1) % count;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(premiumOffersProvider);
    return offersAsync.when(
      loading: () => const SizedBox(height: 8),
      error:   (_, __) => const SizedBox.shrink(),
      data: (offers) {
        if (offers.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _startTimer(offers.length));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _SectionHeader(
                icon: Icons.auto_awesome_rounded,
                label: 'PREMIUM OFFERS',
                onViewAll: () => context.push('/home/service-select'),
              ),
            ),

            // BIG full-width cards
            SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _ctrl,
                itemCount: offers.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _BigOfferCard(offer: offers[i]),
              ),
            ),

            // Dots
            if (offers.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _ctrl,
                    count: offers.length,
                    effect: WormEffect(
                      dotHeight: 8, dotWidth: 8,
                      spacing: 6,
                      activeDotColor: AppColors.gold,
                      dotColor: AppColors.goldBorder.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Big Offer Card (full-width, 260 h) Ã¢â€â‚¬Ã¢â€â‚¬
class _BigOfferCard extends ConsumerWidget {
  final OfferModel offer;
  const _BigOfferCard({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(bookingActiveProvider.notifier).state = true;
        ref.read(selectedOfferProvider.notifier).state = offer;
        // Defer navigation to next frame so the home screen rebuilds first
        // (hiding the Book Now button) before we push the new route.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.push('/home/location-select').then((_) {
              ref.read(bookingActiveProvider.notifier).state = false;
            });
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.18),
              blurRadius: 24, offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background
              offer.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: offer.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.heroGradient,
                        ),
                      ),
                      errorWidget: (_, __, ___) => _OfferPlaceholder(),
                    )
                  : _OfferPlaceholder(),

              // Gradient overlay Ã¢â‚¬â€ stronger at bottom
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.25, 0.55, 1.0],
                  ),
                ),
              ),

              // Ã¢â€â‚¬Ã¢â€â‚¬ Best Seller badge top-left Ã¢â€â‚¬Ã¢â€â‚¬
              Positioned(
                left: 16, top: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.93),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6, offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          color: AppColors.gold, size: 13),
                      const SizedBox(width: 5),
                      Text('Best Seller',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
              ),

              // Ã¢â€â‚¬Ã¢â€â‚¬ Discount badge top-right Ã¢â€â‚¬Ã¢â€â‚¬
              if (offer.discountPercent > 0)
                Positioned(
                  right: 16, top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.40),
                          blurRadius: 8, offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text('${offer.discountPercent}% OFF',
                        style: AppTextStyles.eyebrow.copyWith(
                          color: Colors.white,
                          letterSpacing: 0.8,
                          fontSize: 12,
                        )),
                  ),
                ),

              // Ã¢â€â‚¬Ã¢â€â‚¬ Bottom info Ã¢â€â‚¬Ã¢â€â‚¬
              Positioned(
                left: 16, right: 16, bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      offer.title,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: Colors.white, fontSize: 22,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Price block (Expanded so it never clips 4-digit amounts) ──
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '\u20B9${offer.price.toStringAsFixed(0)}',
                                    style: AppTextStyles.price.copyWith(
                                      color: AppColors.gold3, fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              if (offer.originalPrice > offer.price) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '\u20B9${offer.originalPrice.toStringAsFixed(0)}',
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white54,
                                        decoration: TextDecoration.lineThrough,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Tap-action hint — entire card is already tappable
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Select Stylist',
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 9,
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _OfferPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1E0E), Color(0xFF1C1208)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.local_offer_rounded, color: AppColors.gold, size: 56),
      ),
    );
  }
}

// ————————————————————————————————————————————————————————————————————————————
// Services  —   MEDIUM AUTO-CAROUSEL
// ————————————————————————————————————————————————————————————————————————————
class _ServicesSection extends ConsumerStatefulWidget {
  const _ServicesSection();

  @override
  ConsumerState<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends ConsumerState<_ServicesSection> {
  late final PageController _ctrl =
      PageController(viewportFraction: 0.68);
  int _current = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _startTimer(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % count;
      _ctrl.animateToPage(next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut);
    });
  }

  IconData _iconForService(String name) {
    final l = name.toLowerCase();
    if (l.contains('haircut') || (l.contains('hair') && l.contains('cut'))) return Icons.content_cut_rounded;
    if (l.contains('nano plastia') || l.contains('nano')) return Icons.science_rounded;
    if (l.contains('botox')) return Icons.medical_services_rounded;
    if (l.contains('beard')) return Icons.face_rounded;
    if (l.contains('hair')) return Icons.dry_rounded;
    if (l.contains('skin')) return Icons.face_retouching_natural_rounded;
    if (l.contains('nail')) return Icons.brush_rounded;
    if (l.contains('spa') || l.contains('relax')) return Icons.spa_rounded;
    if (l.contains('shave')) return Icons.face_rounded;
    if (l.contains('color') || l.contains('highlight')) return Icons.palette_rounded;
    if (l.contains('massage')) return Icons.self_improvement_rounded;
    if (l.contains('facial')) return Icons.face_retouching_natural_rounded;
    if (l.contains('keratin') || l.contains('smoothen') || l.contains('straighten')) return Icons.waves_rounded;
    if (l.contains('wax') || l.contains('thread')) return Icons.auto_fix_high_rounded;
    if (l.contains('manicure') || l.contains('pedicure')) return Icons.brush_rounded;
    return Icons.auto_fix_high_rounded;
  }

  /// Picks one random service per category — only services that have an image.
  /// Categories with zero images are excluded entirely.
  List<ServiceModel> _pickOnePerCategory(List<ServiceModel> all) {
    // Group by category, keeping only those with non-empty imageUrl
    final Map<String, List<ServiceModel>> groups = {};
    for (final s in all) {
      if (s.imageUrl.isEmpty) continue; // skip — no image
      groups.putIfAbsent(s.category, () => []).add(s);
    }
    // Pick one random entry from each category
    final result = <ServiceModel>[];
    for (final entries in groups.values) {
      entries.shuffle(); // random each build
      result.add(entries.first);
    }
    // Sort by category name for a stable order across carousel pages
    result.sort((a, b) => a.category.compareTo(b.category));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);
    return servicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (services) {
        // One random item per category — only those with an image
        final display = _pickOnePerCategory(services);
        if (display.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _startTimer(display.length));
        return Padding(
          padding: const EdgeInsets.only(top: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _SectionHeader(
                  icon: Icons.spa_rounded,
                  label: 'OUR SERVICES',
                  onViewAll: () => context.push('/home/book-now'),
                ),
              ),

              // Medium carousel  (viewportFraction 0.68 Ã¢â€ â€™ shows peeking sides)
              SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: display.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) => _ServiceMediumCard(
                    service: display[i],
                    icon: _iconForService(display[i].name),
                    isActive: i == _current,
                  ),
                ),
              ),

              // Dots
              if (display.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _ctrl,
                      count: display.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 7, dotWidth: 7,
                        expansionFactor: 3, spacing: 5,
                        activeDotColor: AppColors.gold,
                        dotColor: AppColors.goldBorder.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),

              // (Book Now button removed Ã¢â‚¬â€ lives in header only)
            ],
          ),
        );
      },
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Service Medium Card Ã¢â€â‚¬Ã¢â€â‚¬
class _ServiceMediumCard extends ConsumerWidget {
  final ServiceModel service;
  final IconData icon;
  final bool isActive;

  const _ServiceMediumCard({
    required this.service,
    required this.icon,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(bookingActiveProvider.notifier).state = true;
        ref.read(selectedServicesProvider.notifier).state = [service];
        // Defer navigation to next frame so the home screen rebuilds first
        // (hiding the Book Now button) before we push the new route.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.push('/home/location-select').then((_) {
              ref.read(bookingActiveProvider.notifier).state = false;
            });
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: EdgeInsets.fromLTRB(
          8,
          isActive ? 0 : 14,    // active card rises up
          8,
          isActive ? 0 : 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isActive
                ? AppColors.goldBorder.withValues(alpha: 0.7)
                : AppColors.border,
            width: isActive ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.gold.withValues(alpha: 0.22)
                  : AppColors.gold.withValues(alpha: 0.06),
              blurRadius: isActive ? 24 : 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image or icon
              service.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: service.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ServiceCardBg(icon: icon),
                      errorWidget: (_, __, ___) => _ServiceCardBg(icon: icon),
                    )
                  : _ServiceCardBg(icon: icon),

              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.40, 1.0],
                  ),
                ),
              ),

              // Info at bottom
              Positioned(
                left: 14, right: 14, bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      style: AppTextStyles.cardTitle.copyWith(
                        color: Colors.white, fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (service.price > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\u20B9${service.price.toStringAsFixed(0)}',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],

                      ],
                    ),
                  ],
                ),
              ),

              // Active indicator ring
              if (isActive)
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.goldGradient,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCardBg extends StatelessWidget {
  final IconData icon;
  const _ServiceCardBg({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF0E8D0), Color(0xFFE0D0A8)],
        ),
      ),
      child: Icon(icon, color: AppColors.gold.withValues(alpha: 0.40), size: 64),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Stylists Section
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _StylistsSection extends ConsumerWidget {
  const _StylistsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(allTrainersStreamProvider);
    return trainersAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (trainers) {
        if (trainers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _SectionHeader(
                  icon: Icons.people_alt_rounded,
                  label: 'OUR STYLISTS',
                  onViewAll: () => context.push('/home/trainer-select-all'),
                ),
              ),
              SizedBox(
                height: 168,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: trainers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, i) => _StylistCard(trainer: trainers[i]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StylistCard extends ConsumerWidget {
  final TrainerModel trainer;
  const _StylistCard({required this.trainer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(bookingActiveProvider.notifier).state = true;
        ref.read(selectedTrainerProvider.notifier).state = trainer;
        // Defer navigation so the home screen rebuilds first (hiding the
        // hero Book Now button) before the new route is pushed.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.push('/home/book-now').then((_) {
              ref.read(bookingActiveProvider.notifier).state = false;
            });
          }
        });
      },
      child: SizedBox(
        width: 110,
        child: Column(
          children: [
            Container(
              width: 86, height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.22),
                    blurRadius: 12, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: trainer.photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: trainer.photoUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: AppColors.bg2),
                        errorWidget: (_, __, ___) =>
                            _TrainerInitial(name: trainer.name),
                      )
                    : _TrainerInitial(name: trainer.name),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              trainer.name,
              style: AppTextStyles.body2.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.gold, size: 13),
                const SizedBox(width: 2),
                Text(trainer.rating.toStringAsFixed(1),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    )),
              ],
            ),
            if (trainer.badges.isNotEmpty) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trainer.badges.first,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrainerInitial extends StatelessWidget {
  final String name;
  const _TrainerInitial({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.goldGradient),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'S',
        style: AppTextStyles.display2.copyWith(color: Colors.white),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Feature Card
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 14, offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.goldGradient,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.text2,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Loyalty CTA
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _LoyaltyCta extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userModelProvider);
    final points    = userAsync.value?.loyaltyPoints ?? 0;
    final hasVoucher = userAsync.value?.hasLoyaltyVoucher ?? false;

    return GestureDetector(
      onTap: () => context.push('/home/loyalty'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 36, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1208), Color(0xFF3A2008)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: AppColors.goldBorder.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18, offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
              ),
              child: const Icon(Icons.stars_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVoucher ? 'Voucher Ready!' : 'Glamzo Rewards',
                    style: AppTextStyles.body1.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hasVoucher
                        ? 'You have a ₹200 voucher to redeem!'
                        : '$points pts  •  Earn ₹200 voucher at 10,000 pts',
                    style: AppTextStyles.caption.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.20),
              ),
              child: const Icon(Icons.chevron_right_rounded,
                  color: AppColors.gold, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
// Reviews Carousel
// Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _ReviewsSection extends ConsumerStatefulWidget {
  const _ReviewsSection();

  @override
  ConsumerState<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<_ReviewsSection> {
  late final PageController _pc;
  Timer? _timer;
  int _cur = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController(viewportFraction: 0.90);
  }

  void _startAutoScroll(int count) {
    _timer?.cancel();
    if (count <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_cur + 1) % count;
      _pc.animateToPage(next,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(publishedReviewsProvider);
    return reviewsAsync.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (reviews) {
        if (reviews.isEmpty) return const SizedBox.shrink();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _startAutoScroll(reviews.length));

        return Padding(
          padding: const EdgeInsets.only(top: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: Row(
                  children: [
                    _SectionHeader(icon: Icons.format_quote_rounded,
                        label: 'WHAT CLIENTS SAY'),
                    Spacer(),
                    _StarRow(count: 5, size: 14),
                  ],
                ),
              ),
              SizedBox(
                height: 215,
                child: PageView.builder(
                  controller: _pc,
                  itemCount: reviews.length,
                  onPageChanged: (i) => setState(() => _cur = i),
                  itemBuilder: (_, i) => _ReviewCard(review: reviews[i]),
                ),
              ),
              if (reviews.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: _pc,
                      count: reviews.length,
                      effect: ExpandingDotsEffect(
                        dotHeight: 7, dotWidth: 7,
                        expansionFactor: 3, spacing: 5,
                        activeDotColor: AppColors.gold,
                        dotColor:
                            AppColors.goldBorder.withValues(alpha: 0.30),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final name = (review['customerName'] as String?)?.isNotEmpty == true
        ? review['customerName'] as String
        : (review['name'] as String? ?? 'Customer');
    final stylist  = review['stylistName'] as String? ?? '';
    final feedback = (review['reviewText'] as String?)?.isNotEmpty == true
        ? review['reviewText'] as String
        : (review['feedback'] as String? ?? '');
    final rating  = (review['rating'] as num?)?.toInt() ?? 5;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.cardWhite,
        border: Border.all(
          color: AppColors.goldBorder.withValues(alpha: 0.38),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.09),
            blurRadius: 18, spreadRadius: 1, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.format_quote_rounded,
                    color: Colors.white, size: 16),
              ),
              const Spacer(),
              _StarRow(count: rating, size: 15),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              feedback.isNotEmpty ? '"$feedback"' : '',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.text2,
                height: 1.6,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.goldBorder.withValues(alpha: 0.0),
                AppColors.goldBorder.withValues(alpha: 0.5),
                AppColors.goldBorder.withValues(alpha: 0.0),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                alignment: Alignment.center,
                child: Text(initial,
                    style: AppTextStyles.body1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: AppTextStyles.body1.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (stylist.isNotEmpty)
                      Row(children: [
                        const Icon(Icons.content_cut_rounded,
                            size: 10, color: AppColors.gold),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(stylist,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Ã¢â€â‚¬Ã¢â€â‚¬ Star Row Ã¢â€â‚¬Ã¢â€â‚¬
class _StarRow extends StatelessWidget {
  final int count;
  final double size;
  const _StarRow({required this.count, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(
        i < count ? Icons.star_rounded : Icons.star_outline_rounded,
        color: AppColors.gold, size: size,
      )),
    );
  }
}
