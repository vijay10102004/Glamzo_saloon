import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/service_model.dart';
import '../../models/trainer_model.dart';


import '../../providers/search_provider.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../booking/service_select_screen.dart' show serviceToOffer;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TabController _tabController;
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _tabController = TabController(length: 2, vsync: this);
    final q = ref.read(searchQueryProvider);
    _searchController = TextEditingController(text: q);
    _searchController.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priceRange = ref.watch(priceRangeProvider);
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final allCategories = ref.watch(serviceCategoriesProvider);
    final filteredServices = ref.watch(filteredServicesProvider);
    final filteredTrainers = ref.watch(filteredTrainersProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Dark Header ──
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
                children: [
                  // AppBar Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            ref.read(searchQueryProvider.notifier).state = '';
                            context.pop();
                          },
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
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Colors.white.withValues(alpha: 0.12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: AppTextStyles.body2.copyWith(color: Colors.white),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Search services, stylists...',
                                hintStyle: AppTextStyles.body2
                                    .copyWith(color: Colors.white.withValues(alpha: 0.45)),
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: AppColors.gold, size: 20),
                                suffixIcon: query.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          ref.read(searchQueryProvider.notifier).state = '';
                                        },
                                        child: const Icon(Icons.close_rounded,
                                            color: Colors.white54, size: 18),
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Filter button
                        GestureDetector(
                          onTap: () => setState(() => _showFilters = !_showFilters),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: _showFilters
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.12),
                              border: Border.all(
                                color: _showFilters
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: _showFilters ? Colors.black : Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Filters Panel ──
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _showFilters
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Price Range
                                Text(
                                  'PRICE RANGE',
                                  style: AppTextStyles.eyebrow.copyWith(
                                    color: AppColors.gold3, letterSpacing: 2, fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      '₹${priceRange.start.toInt()}',
                                      style: AppTextStyles.label
                                          .copyWith(color: Colors.white70, fontSize: 12),
                                    ),
                                    Expanded(
                                      child: _PriceRangeSlider(
                                        range: priceRange,
                                        onChanged: (v) {
                                          ref.read(priceRangeProvider.notifier).state = v;
                                        },
                                      ),
                                    ),
                                    Text(
                                      '₹${priceRange.end.toInt()}',
                                      style: AppTextStyles.label
                                          .copyWith(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Category chips
                                if (allCategories.isNotEmpty) ...[
                                  Text(
                                    'CATEGORY',
                                    style: AppTextStyles.eyebrow.copyWith(
                                      color: AppColors.gold3, letterSpacing: 2, fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: allCategories.map((cat) {
                                      final isSelected = selectedCategories.contains(cat);
                                      return GestureDetector(
                                        onTap: () {
                                          final updated = Set<String>.from(selectedCategories);
                                          if (isSelected) {
                                            updated.remove(cat);
                                          } else {
                                            updated.add(cat);
                                          }
                                          ref
                                              .read(selectedCategoriesProvider.notifier)
                                              .state = updated;
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            color: isSelected
                                                ? AppColors.gold
                                                : Colors.white.withValues(alpha: 0.1),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppColors.gold
                                                  : Colors.white.withValues(alpha: 0.2),
                                            ),
                                          ),
                                          child: Text(
                                            cat,
                                            style: AppTextStyles.caption.copyWith(
                                              color: isSelected ? Colors.black : Colors.white70,
                                              fontWeight: isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 8),
                                  // Reset filters
                                  GestureDetector(
                                    onTap: () {
                                      ref.read(priceRangeProvider.notifier).state =
                                          const RangeValues(0, 5000);
                                      ref.read(selectedCategoriesProvider.notifier).state = {};
                                    },
                                    child: Text(
                                      'Reset Filters',
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.rose, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Tabs ──
                  TabBar(
                    controller: _tabController,
                    labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    unselectedLabelStyle: AppTextStyles.label,
                    labelColor: AppColors.gold,
                    unselectedLabelColor: Colors.white54,
                    indicatorColor: AppColors.gold,
                    indicatorWeight: 2,
                    tabs: const [
                      Tab(text: 'Services'),
                      Tab(text: 'Stylists'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Body ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Services Tab
                _buildServicesTab(filteredServices),
                // Stylists Tab
                _buildStylistsTab(filteredTrainers),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesTab(AsyncValue<List<ServiceModel>> filteredServices) {
    final query = ref.watch(searchQueryProvider);
    final selectedCategories = ref.watch(selectedCategoriesProvider);
    final priceRange = ref.watch(priceRangeProvider);
    final isFilterActive = query.isNotEmpty ||
        selectedCategories.isNotEmpty ||
        priceRange.start > 0 ||
        priceRange.end < 5000;

    return filteredServices.when(
      data: (services) {
        if (!isFilterActive) return _buildEmptySearch();
        if (services.isEmpty) return _buildNoResults();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const BouncingScrollPhysics(),
          itemCount: services.length,
          itemBuilder: (ctx, i) => _ServiceResultCard(
            service: services[i],
            onBookTap: () => _bookService(services[i]),
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 1.5),
      ),
      error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.body2)),
    );
  }

  Widget _buildStylistsTab(AsyncValue<List<TrainerModel>> filteredTrainers) {
    final query = ref.watch(searchQueryProvider);
    return filteredTrainers.when(
      data: (trainers) {
        if (query.isEmpty) return _buildEmptySearch();
        if (trainers.isEmpty) return _buildNoResults();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          physics: const BouncingScrollPhysics(),
          itemCount: trainers.length,
          itemBuilder: (ctx, i) => _StylistResultCard(
            trainer: trainers[i],
            onTap: () {
              // Pre-select trainer, then let user pick a service
              ref.read(selectedTrainerProvider.notifier).state = trainers[i];
              context.push('/home/service-select');
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 1.5),
      ),
      error: (e, _) => Center(child: Text('Error: $e', style: AppTextStyles.body2)),
    );
  }

  /// User tapped "Book" on a specific service card — set it as the selected
  /// offer and jump straight to trainer selection (skipping service-select).
  void _bookService(ServiceModel service) {
    final offer = serviceToOffer(service);
    ref.read(selectedOfferProvider.notifier).state = offer;
    context.push('/home/trainer-select-all');
  }

  Widget _buildEmptySearch() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldBg,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: const Icon(Icons.search_rounded, color: AppColors.gold, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Search for a service', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Text(
            'Try "Haircut", "Facial", or "Keratin"',
            style: AppTextStyles.body2.copyWith(color: AppColors.text3),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off_rounded, color: AppColors.text4, size: 56),
          const SizedBox(height: 16),
          Text('No results found', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          Text(
            'Try a different search or adjust filters',
            style: AppTextStyles.body2.copyWith(color: AppColors.text3),
          ),
        ],
      ),
    );
  }
}

// ── Price Range Slider (uses RangeSlider material widget) ──
class _PriceRangeSlider extends StatelessWidget {
  final RangeValues range;
  final ValueChanged<RangeValues> onChanged;
  const _PriceRangeSlider({required this.range, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
        thumbColor: AppColors.gold,
        overlayColor: AppColors.gold.withValues(alpha: 0.2),
        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 8),
        trackHeight: 3,
      ),
      child: RangeSlider(
        values: range,
        min: 0,
        max: 5000,
        divisions: 50,
        onChanged: (v) => onChanged(v),
      ),
    );
  }

}

// ── Service Result Card ──
class _ServiceResultCard extends StatelessWidget {
  final ServiceModel service;
  final VoidCallback onBookTap;
  const _ServiceResultCard({required this.service, required this.onBookTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.cardWhite,
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon area
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.goldBg2,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Center(
                child: Text(service.icon, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.goldBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Text(
                          service.category,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.goldDeep, fontSize: 10, fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(service.name,
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${service.price.toInt()}',
                        style: AppTextStyles.price.copyWith(fontSize: 16),
                      ),

                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onBookTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8),
                  ],
                ),
                child: Text(
                  'Book',
                  style: AppTextStyles.label.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stylist Result Card ──
class _StylistResultCard extends StatelessWidget {
  final TrainerModel trainer;
  final VoidCallback onTap;
  const _StylistResultCard({required this.trainer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: AppColors.cardWhite,
          border: Border.all(color: AppColors.border2),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                  boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 10)],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: CircleAvatar(
                    backgroundColor: AppColors.bg2,
                    backgroundImage: trainer.photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(trainer.photoUrl)
                        : null,
                    child: trainer.photoUrl.isEmpty
                        ? Text(
                            trainer.name[0].toUpperCase(),
                            style: AppTextStyles.sectionTitle.copyWith(color: AppColors.gold),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trainer.name,
                        style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      trainer.specialties.join(' · '),
                      style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: AppColors.gold, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          '${trainer.rating}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.goldDeep, fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.sageBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.sageBorder),
                          ),
                          child: Text('Available',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.sage, fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
