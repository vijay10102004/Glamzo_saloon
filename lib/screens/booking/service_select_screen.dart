import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/service_model.dart';
import '../../models/offer_model.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../../widgets/booking/service_category_icon.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper: convert ServiceModel → OfferModel for the booking flow
// ─────────────────────────────────────────────────────────────────────────────
OfferModel serviceToOffer(ServiceModel service) => OfferModel(
      id: 'svc_${service.id}',
      title: service.name,
      description: service.description,
      price: service.price,
      originalPrice: service.price,
      imageUrl: service.imageUrl,
      trainerIds: const [],
      isActive: true,
      isPremium: false,
      serviceCategory: service.category,
    );

// ─────────────────────────────────────────────────────────────────────────────
// Service Select Screen
//
// Layout:
//   • Auto-rotating full-screen carousel (one slide per category)
//   • Each slide = one RANDOM service from that category WITH an image
//   • After a full rotation, re-randomises picks (stays image-only)
//   • Category chip strip + gender filter above the carousel
//   • Tapping a card opens trainer select
// ─────────────────────────────────────────────────────────────────────────────
class ServiceSelectScreen extends ConsumerStatefulWidget {
  const ServiceSelectScreen({super.key});

  @override
  ConsumerState<ServiceSelectScreen> createState() => _ServiceSelectScreenState();
}

class _ServiceSelectScreenState extends ConsumerState<ServiceSelectScreen>
    with SingleTickerProviderStateMixin {

  // ── Filters ──────────────────────────────────────────────────────────────
  String _selectedCategory = 'All';
  String _selectedGender   = 'All';

  static const _categories = [
    'All', 'Threading', 'Waxing', 'Detan', 'Head Massage', 'Facial',
    'Manicure', 'Pedicure', 'Haircut', 'Hair Coloring', 'Color Highlights',
    'Hair Spa', 'Hair & Scalp', 'Keratin Treatment', 'Straightening',
    'Smoothening', 'Blow Dry', 'Nano Plastia Treatment', 'Botox Treatment',
    'Beard Design',
  ];
  static const _genders = ['All', 'Male', 'Female'];

  // ── Carousel state ────────────────────────────────────────────────────────
  late PageController _pageController;
  Timer?  _autoScrollTimer;
  int     _currentPage   = 0;

  // Cached random picks: category → service (only those with images)
  final Map<String, ServiceModel> _randomPicks = {};
  final _rng = Random();

  // How many full carousel rotations have completed (re-randomises on each)
  int _rotationsCompleted = 0;


  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _pageController = PageController(viewportFraction: 0.88);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build the list of carousel slides from loaded services.
  // One random service (with image) per category that has a matching service.
  // If a category has no services with images, skip it.
  // ─────────────────────────────────────────────────────────────────────────
  List<ServiceModel> _buildCarouselSlides(
      List<ServiceModel> all, bool forceRefresh) {
    // Filter by gender first
    final genderFiltered = _applyGenderFilter(all);

    // For each visible category (or "All"), pick one random image-service
    final slides = <ServiceModel>[];

    if (_selectedCategory == 'All') {
      // One random service per unique category (with image)
      final byCategory = <String, List<ServiceModel>>{};
      for (final s in genderFiltered) {
        if (s.imageUrl.trim().isNotEmpty) {
          byCategory.putIfAbsent(s.category, () => []).add(s);
        }
      }
      for (final entry in byCategory.entries) {
        final cat   = entry.key;
        final svcs  = entry.value;
        if (svcs.isEmpty) continue;

        if (forceRefresh || !_randomPicks.containsKey(cat)) {
          _randomPicks[cat] = svcs[_rng.nextInt(svcs.length)];
        }
        slides.add(_randomPicks[cat]!);
      }
    } else {
      // Only selected category — pick one random with image
      final matching = genderFiltered
          .where((s) =>
              s.category == _selectedCategory &&
              s.imageUrl.trim().isNotEmpty)
          .toList();
      if (matching.isNotEmpty) {
        final key = _selectedCategory;
        if (forceRefresh || !_randomPicks.containsKey(key)) {
          _randomPicks[key] = matching[_rng.nextInt(matching.length)];
        }
        slides.add(_randomPicks[key]!);
      }
    }

    return slides;
  }

  List<ServiceModel> _applyGenderFilter(List<ServiceModel> all) {
    if (_selectedGender == 'All') return all;
    return all.where((s) {
      if (_selectedGender == 'Male') {
        return s.genderPreference == GenderPreference.male ||
            s.genderPreference == GenderPreference.both;
      } else {
        return s.genderPreference == GenderPreference.female ||
            s.genderPreference == GenderPreference.both;
      }
    }).toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Start (or restart) auto-scroll timer
  // ─────────────────────────────────────────────────────────────────────────
  void _startAutoScroll(List<ServiceModel> slides) {
    _autoScrollTimer?.cancel();
    if (slides.length <= 1) return;

    // Short 3.2 s interval — feels snappy, not rushed
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (!mounted || !_pageController.hasClients) return;

      final next = _currentPage + 1;

      if (next >= slides.length) {
        // ── Completed one full rotation ──────────────────────────────────
        _rotationsCompleted++;
        debugPrint('🔄 Carousel rotation #$_rotationsCompleted complete — re-randomising picks');
        // Instantly jump back to page 0 (no animation — feels like restart)
        _pageController.jumpToPage(0);
        setState(() {
          _currentPage = 0;
          // Re-randomise on next _buildCarouselSlides call
          _randomPicks.clear();
        });
      } else {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onFilterChanged() {
    _autoScrollTimer?.cancel();
    _randomPicks.clear();
    setState(() => _currentPage = 0);
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
  }

  void _onServiceTapped(ServiceModel service) {
    final offer = serviceToOffer(service);
    ref.read(selectedOfferProvider.notifier).state  = offer;
    ref.read(selectedTrainerProvider.notifier).state = null;
    context.push('/home/location-select');
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Dark gradient header ───────────────────────────────────────
          _buildHeader(),

          // ── Carousel body ─────────────────────────────────────────────
          Expanded(
            child: servicesAsync.when(
              // Minimal skeleton shimmer while loading
              loading: () => _buildShimmer(),
              error: (e, _) => _buildError(),
              data: (allServices) {
                final slides = _buildCarouselSlides(allServices, false);

                // Kick off auto-scroll whenever slides update
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startAutoScroll(slides);
                });

                if (slides.isEmpty) return _buildEmpty();

                return Column(
                  children: [
                    const SizedBox(height: 16),

                    // ── Page indicator dots ──────────────────────────────
                    _buildDots(slides.length),

                    const SizedBox(height: 14),

                    // ── Carousel ─────────────────────────────────────────
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: slides.length,
                        itemBuilder: (ctx, i) => _ServiceCarouselCard(
                          service: slides[i],
                          isActive: i == _currentPage,
                          onTap: () => _onServiceTapped(slides[i]),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── "Browse all services" bottom chip ─────────────────
                    _buildBrowseAllChip(allServices),

                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header (dark gradient + filters) ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0B08), Color(0xFF1C1208), Color(0xFF2E1E0A)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back + title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.15),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STEP 1 OF 3',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: AppColors.gold3, letterSpacing: 2.5,
                          ),
                        ),
                        Text(
                          'Choose a Service',
                          style: AppTextStyles.display2
                              .copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Step dots
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: List.generate(3, (i) {
                  final active = i == 0;
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: active ? 28 : 8,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: active
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.25),
                    ),
                  );
                }),
              ),
            ),

            // ── Category filter strip ──────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 8),
                physics: const BouncingScrollPhysics(),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat      = _categories[i];
                  final selected = cat == _selectedCategory;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      _onFilterChanged();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: selected
                            ? AppColors.gold
                            : Colors.white.withValues(alpha: 0.1),
                        border: Border.all(
                          color: selected
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: AppTextStyles.caption.copyWith(
                          color: selected ? Colors.black : Colors.white70,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Gender filter strip ────────────────────────────────────
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 16, right: 8),
                physics: const BouncingScrollPhysics(),
                children: _genders.map((g) {
                  final sel = g == _selectedGender;
                  final IconData icon = g == 'Male'
                      ? Icons.male_rounded
                      : g == 'Female'
                          ? Icons.female_rounded
                          : Icons.people_rounded;
                  final Color activeColor = g == 'Male'
                      ? const Color(0xFF5B9BF5)
                      : g == 'Female'
                          ? const Color(0xFFF575A8)
                          : AppColors.gold;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedGender = g);
                      _onFilterChanged();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: sel
                            ? activeColor.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(
                          color: sel
                              ? activeColor
                              : Colors.white.withValues(alpha: 0.15),
                          width: sel ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon,
                              size: 13,
                              color: sel ? activeColor : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            g,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: sel ? activeColor : Colors.white60,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  // ── Indicator dots ────────────────────────────────────────────────────────
  Widget _buildDots(int count) {
    return SizedBox(
      height: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == _currentPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width:  active ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: active
                  ? AppColors.gold
                  : AppColors.gold.withValues(alpha: 0.25),
            ),
          );
        }),
      ),
    );
  }

  // ── "Browse all" bottom chip ───────────────────────────────────────────────
  Widget _buildBrowseAllChip(List<ServiceModel> all) {
    final total = _applyGenderFilter(all)
        .where((s) => _selectedCategory == 'All' ||
            s.category == _selectedCategory)
        .length;
    return GestureDetector(
      onTap: () => _showAllServicesSheet(all),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppColors.goldBorder),
          color: AppColors.goldBg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grid_view_rounded,
                color: AppColors.goldDeep, size: 16),
            const SizedBox(width: 8),
            Text(
              'Browse all $total services',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.goldDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: AppColors.goldDeep, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Full list bottom sheet ────────────────────────────────────────────────
  void _showAllServicesSheet(List<ServiceModel> all) {
    final filtered = _applyGenderFilter(all).where((s) {
      return _selectedCategory == 'All' || s.category == _selectedCategory;
    }).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text('All Services',
                        style: AppTextStyles.sectionTitle),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.goldBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                        '${filtered.length} services',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.goldDeep,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ServiceListTile(
                    service: filtered[i],
                    onTap: () {
                      Navigator.pop(ctx);
                      _onServiceTapped(filtered[i]);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Loading shimmer ───────────────────────────────────────────────────────
  Widget _buildShimmer() {
    return Column(
      children: [
        const SizedBox(height: 28),
        // Shimmer dot row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == 0 ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          )),
        ),
        const SizedBox(height: 18),
        // Shimmer card
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ShimmerCard(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.spa_rounded, color: AppColors.text4, size: 52),
            const SizedBox(height: 12),
            Text('No services with images found',
                style: AppTextStyles.sectionTitle),
            const SizedBox(height: 6),
            Text('Try "All" category or a different gender filter',
                style: AppTextStyles.body2
                    .copyWith(color: AppColors.text3)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Text('Error loading services',
            style: AppTextStyles.body2.copyWith(color: AppColors.rose)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Carousel Card — full-bleed image with gradient overlay
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceCarouselCard extends StatefulWidget {
  final ServiceModel service;
  final bool         isActive;
  final VoidCallback onTap;
  const _ServiceCarouselCard({
    required this.service,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ServiceCarouselCard> createState() => _ServiceCarouselCardState();
}

class _ServiceCarouselCardState extends State<_ServiceCarouselCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim =
        Tween<double>(begin: 1.0, end: 0.96).animate(_pressCtrl);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    return AnimatedScale(
      scale: widget.isActive ? 1.0 : 0.94,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp:   (_) { _pressCtrl.reverse(); widget.onTap(); },
        onTapCancel: () => _pressCtrl.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: widget.isActive ? 0.22 : 0.06),
                  blurRadius: widget.isActive ? 28 : 10,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Service image ──
                  CachedNetworkImage(
                    imageUrl: svc.imageUrl,
                    fit: BoxFit.cover,
                    // Very short fade-in — feels instant
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholderFadeInDuration: Duration.zero,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF1A1208),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 1.5,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1A1208),
                      child: const Icon(Icons.spa_rounded,
                          color: AppColors.gold, size: 64),
                    ),
                  ),

                  // ── Gradient overlay (bottom → transparent) ──
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.35, 1.0],
                        colors: [Colors.transparent, Color(0xE6000000)],
                      ),
                    ),
                  ),

                  // ── Top-left category badge ──
                  Positioned(
                    top: 18,
                    left: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(svc.icon,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            svc.category,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.gold3,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Top-right gender badge ──
                  Positioned(
                    top: 18,
                    right: 18,
                    child: _GenderBadgeCard(gender: svc.genderPreference),
                  ),

                  // ── Bottom info bar ──
                  Positioned(
                    left: 0, right: 0, bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Service name + description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  svc.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (svc.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    svc.description,
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.72),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      '₹${svc.price.toInt()}',
                                      style: AppTextStyles.priceLarge
                                          .copyWith(fontSize: 26),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${svc.durationMinutes} min',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Book button
                          const SizedBox(width: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.45),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Book',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Active glow border ──
                  if (widget.isActive)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            width: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact list tile — used inside the "Browse all" bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceListTile extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onTap;
  const _ServiceListTile({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final svc = service;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border2),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon/image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: svc.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: svc.imageUrl,
                      width: 56, height: 56,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 120),
                      placeholderFadeInDuration: Duration.zero,
                      placeholder: (_, __) => ServiceCategoryIconWidget(
                          category: svc.category, size: 56),
                      errorWidget: (_, __, ___) => ServiceCategoryIconWidget(
                          category: svc.category, size: 56),
                    )
                  : ServiceCategoryIconWidget(
                      category: svc.category, size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          svc.name,
                          style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _GenderBadgeCard(gender: svc.genderPreference),
                    ],
                  ),
                  if (svc.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      svc.description,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('₹${svc.price.toInt()}',
                          style: AppTextStyles.price.copyWith(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('· ${svc.durationMinutes} min',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.text3)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.goldGradient,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.28),
                      blurRadius: 8)
                ],
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder card
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Color.lerp(
            const Color(0xFF1A1208),
            const Color(0xFF2E2010),
            _anim.value,
          ),
        ),
        child: Stack(
          children: [
            // Bottom shimmer text blocks
            Positioned(
              left: 20, right: 20, bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 26, width: 180,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14, width: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: _anim.value * 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gender badge — compact pill for cards
// ─────────────────────────────────────────────────────────────────────────────
class _GenderBadgeCard extends StatelessWidget {
  final GenderPreference gender;
  const _GenderBadgeCard({required this.gender});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    switch (gender) {
      case GenderPreference.male:
        bg = const Color(0xFF1A3A6B).withValues(alpha: 0.85);
        fg = const Color(0xFF90CAF9);
        label = '♂';
        break;
      case GenderPreference.female:
        bg = const Color(0xFF6B1A3A).withValues(alpha: 0.85);
        fg = const Color(0xFFF48FB1);
        label = '♀';
        break;
      case GenderPreference.both:
        bg = Colors.black.withValues(alpha: 0.5);
        fg = Colors.white60;
        label = '⚥';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}
