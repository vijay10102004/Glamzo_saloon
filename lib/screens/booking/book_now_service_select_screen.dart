import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/service_model.dart';
import '../../models/offer_model.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../../widgets/booking/service_category_icon.dart';

/// Converts a list of ServiceModels into a single combined OfferModel
/// so the existing trainer → slot → confirm flow works unchanged.
OfferModel servicesToOffer(List<ServiceModel> services) {
  final totalPrice = services.fold<double>(0, (sum, s) => sum + s.price);
  final names = services.map((s) => s.name).join(', ');
  final categories = services.map((s) => s.category).toSet().join(' · ');
  return OfferModel(
    id: 'multi_${services.map((s) => s.id).join('_')}',
    title: services.length == 1 ? services.first.name : '${services.length} Services',
    description: names,
    price: totalPrice,
    originalPrice: totalPrice,
    imageUrl: services.first.imageUrl,
    trainerIds: const [],
    isActive: true,
    isPremium: false,
    serviceCategory: categories,
  );
}

class BookNowServiceSelectScreen extends ConsumerStatefulWidget {
  const BookNowServiceSelectScreen({super.key});

  @override
  ConsumerState<BookNowServiceSelectScreen> createState() =>
      _BookNowServiceSelectScreenState();
}

class _BookNowServiceSelectScreenState
    extends ConsumerState<BookNowServiceSelectScreen>
    with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  // 'All' | 'Male' | 'Female'
  String _selectedGender = 'All';
  String _searchQuery = '';
  final _searchController = TextEditingController();
  late AnimationController _animController;

  static const _categories = [
    'All',
    'Threading',
    'Waxing',
    'Detan',
    'Head Massage',
    'Facial',
    'Manicure',
    'Pedicure',
    'Haircut',
    'Hair Coloring',
    'Color Highlights',
    'Hair Spa',
    'Hair & Scalp',
    'Keratin Treatment',
    'Straightening',
    'Smoothening',
    'Blow Dry',
    'Nano Plastia Treatment',
    'Botox Treatment',
    'Beard Design',
  ];

  static const _genders = ['All', 'Male', 'Female'];

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();

    // Clear any stale selections when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedServicesProvider.notifier).state = [];
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<ServiceModel> _filter(List<ServiceModel> all) {
    return all.where((s) {
      // Category filter
      final matchesCat =
          _selectedCategory == 'All' || s.category == _selectedCategory;
      // Search filter
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
      // Gender filter:
      //   Male   → Male + Both
      //   Female → Female + Both
      //   All    → everything
      final matchesGender = _selectedGender == 'All' ||
          (_selectedGender == 'Male' &&
              (s.genderPreference == GenderPreference.male ||
                  s.genderPreference == GenderPreference.both)) ||
          (_selectedGender == 'Female' &&
              (s.genderPreference == GenderPreference.female ||
                  s.genderPreference == GenderPreference.both));
      return matchesCat && matchesSearch && matchesGender;
    }).toList();
  }

  void _toggleService(ServiceModel svc, List<ServiceModel> selected) {
    final current = List<ServiceModel>.from(selected);
    final idx = current.indexWhere((s) => s.id == svc.id);
    if (idx >= 0) {
      current.removeAt(idx);
    } else {
      current.add(svc);
    }
    ref.read(selectedServicesProvider.notifier).state = current;
  }

  void _onContinue(List<ServiceModel> selected) {
    if (selected.isEmpty) return;
    // Build combined offer and store it
    final offer = servicesToOffer(selected);
    ref.read(selectedOfferProvider.notifier).state = offer;
    // Clear previous stylist selection
    ref.read(selectedTrainerProvider.notifier).state = null;
    // Navigate to location selection first
    context.push('/home/location-select');
  }

  @override
  Widget build(BuildContext context) {
    final servicesAsync = ref.watch(servicesProvider);
    final selected = ref.watch(selectedServicesProvider);

    final totalPrice = selected.fold<double>(0, (s, x) => s + x.price);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──
          Container(
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
                  // AppBar row
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
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
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
                                'SELECT SERVICES',
                                style: AppTextStyles.eyebrow.copyWith(
                                  color: AppColors.gold3, letterSpacing: 2.5,
                                ),
                              ),
                              Text(
                                'Select Services',
                                style: AppTextStyles.display2
                                    .copyWith(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        if (selected.isNotEmpty)
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.goldGradient,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${selected.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white.withValues(alpha: 0.12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: AppTextStyles.body2
                            .copyWith(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search services...',
                          hintStyle: AppTextStyles.body2
                              .copyWith(color: Colors.white38),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Colors.white54, size: 18),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white54, size: 16),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category chips
                  SizedBox(
                    height: 34,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) {
                        final cat = _categories[i];
                        final sel = cat == _selectedCategory;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: sel
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.1),
                              border: Border.all(
                                color: sel
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              cat,
                              style: AppTextStyles.caption.copyWith(
                                color: sel ? Colors.black : Colors.white70,
                                fontWeight: sel
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

                  // ── Gender filter chips ──
                  SizedBox(
                    height: 32,
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
                          onTap: () => setState(() => _selectedGender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
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
          ),

          // ── Hint row ──
          Container(
            color: AppColors.goldBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.gold, size: 14),
                const SizedBox(width: 8),
                Text(
                  'Tap services to select multiple',
                  style: AppTextStyles.caption.copyWith(
                      color: AppColors.goldDeep, fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Service list ──
          Expanded(
            child: servicesAsync.when(
              data: (services) {
                final filtered = _filter(services);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.spa_rounded,
                            color: AppColors.text4, size: 48),
                        const SizedBox(height: 12),
                        Text('No services found',
                            style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 6),
                        Text('Try a different search or category',
                            style: AppTextStyles.body2
                                .copyWith(color: AppColors.text3)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      16, 12, 16, selected.isEmpty ? 32 : 140),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final svc = filtered[i];
                    final isSelected =
                        selected.any((s) => s.id == svc.id);
                    return _ServiceCheckTile(
                      service: svc,
                      isSelected: isSelected,
                      onToggle: () => _toggleService(svc, selected),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 1.5),
              ),
              error: (e, _) => Center(
                child: Text('Error loading services',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.rose)),
              ),
            ),
          ),
        ],
      ),

      // ── Sticky bottom bar ──
      bottomNavigationBar: selected.isEmpty
          ? null
          : _BottomBar(
              selected: selected,
              totalPrice: totalPrice,
              onContinue: () => _onContinue(selected),
              onClear: () =>
                  ref.read(selectedServicesProvider.notifier).state = [],
            ),
    );
  }
}

// ── Service checkbox tile ──
class _ServiceCheckTile extends StatefulWidget {
  final ServiceModel service;
  final bool isSelected;
  final VoidCallback onToggle;
  const _ServiceCheckTile({
    required this.service,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  State<_ServiceCheckTile> createState() => _ServiceCheckTileState();
}

class _ServiceCheckTileState extends State<_ServiceCheckTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onToggle();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: widget.isSelected
                ? AppColors.goldBg
                : AppColors.cardWhite,
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.gold
                  : AppColors.border2,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? AppColors.gold.withValues(alpha: 0.12)
                    : AppColors.ink.withValues(alpha: 0.05),
                blurRadius: widget.isSelected ? 14 : 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Material icon — gold gradient circle, fills gold when selected
                ServiceCategoryIconWidget(
                  category: svc.category,
                  size: 52,
                  isSelected: widget.isSelected,
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: widget.isSelected
                                  ? AppColors.gold.withValues(alpha: 0.15)
                                  : AppColors.goldBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.goldBorder),
                            ),
                            child: Text(
                              svc.category,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.goldDeep,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          _GenderBadge(gender: svc.genderPreference),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        svc.name,
                        style: AppTextStyles.cardTitle
                            .copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                          Text(
                            '₹${svc.price.toInt()}',
                            style: AppTextStyles.price
                                .copyWith(fontSize: 15),
                          ),

                        ],
                      ),
                    ],
                  ),
                ),
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isSelected
                        ? AppColors.goldGradient
                        : null,
                    color: widget.isSelected ? null : Colors.transparent,
                    border: Border.all(
                      color: widget.isSelected
                          ? AppColors.gold
                          : AppColors.border2,
                      width: 1.5,
                    ),
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 8,
                            )
                          ]
                        : [],
                  ),
                  child: widget.isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottom bar ──
class _BottomBar extends StatelessWidget {
  final List<ServiceModel> selected;
  final double totalPrice;
  final VoidCallback onContinue;
  final VoidCallback onClear;
  const _BottomBar({
    required this.selected,
    required this.totalPrice,
    required this.onContinue,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected services summary row
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: selected.take(3).map((s) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.goldBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                        s.name,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.goldDeep,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList()
                  ..addAll(selected.length > 3
                      ? [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.bg2,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border2),
                            ),
                            child: Text(
                              '+${selected.length - 3} more',
                              style: AppTextStyles.caption.copyWith(
                                  color: AppColors.text3, fontSize: 10),
                            ),
                          )
                        ]
                      : []),
                ),
              ),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.bg2,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.text3, size: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Price + Duration + Continue button
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${totalPrice.toInt()}',
                    style: AppTextStyles.price.copyWith(fontSize: 20),
                  ),
                  Text(
                    '${selected.length} service${selected.length > 1 ? 's' : ''} selected',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.text3, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: onContinue,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_search_rounded,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Choose Stylist',
                            style: AppTextStyles.btnLabel),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Gender badge pill ──
class _GenderBadge extends StatelessWidget {
  final GenderPreference gender;
  const _GenderBadge({required this.gender});

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color textColor;
    final String label;

    switch (gender) {
      case GenderPreference.male:
        bgColor   = const Color(0xFFDEEBFF);
        textColor = const Color(0xFF1A6FD4);
        label     = '♂ Male';
        break;
      case GenderPreference.female:
        bgColor   = const Color(0xFFFFE4F0);
        textColor = const Color(0xFFBF2F75);
        label     = '♀ Female';
        break;
      case GenderPreference.both:
        bgColor   = AppColors.bg2;
        textColor = AppColors.text3;
        label     = '⚥ Both';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: textColor,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
