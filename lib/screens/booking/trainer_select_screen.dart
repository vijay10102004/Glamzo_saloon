import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';

class TrainerSelectScreen extends ConsumerWidget {
  const TrainerSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(selectedOfferProvider);
    if (offer == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('No offer selected')),
      );
    }

    final trainersAsync = ref.watch(trainersForOfferProvider(offer.trainerIds));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero AppBar ──
          SliverAppBar(
            expandedHeight: 160,
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
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D0B08), Color(0xFF1C1208), Color(0xFF2E1E0A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(72, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'STEP 2 OF 3',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: AppColors.gold3, letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Choose Your Expert',
                          style: AppTextStyles.display2.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Service Banner ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.goldBg2,
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: const Icon(Icons.spa_rounded, color: AppColors.gold, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.title,
                            style: AppTextStyles.cardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            offer.description,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${offer.price.toInt()}', style: AppTextStyles.price),
                        Text('service fee', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Section Label ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                'AVAILABLE PROFESSIONALS',
                style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold, letterSpacing: 2.5),
              ),
            ),
          ),

          // ── Trainer List ──
          trainersAsync.when(
            data: (trainers) {
              if (trainers.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        const Icon(Icons.person_off_rounded, color: AppColors.text4, size: 48),
                        const SizedBox(height: 12),
                        Text('No professionals available', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 6),
                        Text('Check back soon for updates.', style: AppTextStyles.body2),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _TrainerCard(
                      trainer: trainers[index],
                      onTap: () {
                        ref.read(selectedTrainerProvider.notifier).state = trainers[index];
                        context.push('/home/slot-booking');
                      },
                    ),
                    childCount: trainers.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),
            ),
            error: (e, _) => SliverToBoxAdapter(
              child: Center(child: Text('Error: $e', style: AppTextStyles.body2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerCard extends StatefulWidget {
  final dynamic trainer;
  final VoidCallback onTap;
  const _TrainerCard({required this.trainer, required this.onTap});

  @override
  State<_TrainerCard> createState() => _TrainerCardState();
}

class _TrainerCardState extends State<_TrainerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainer = widget.trainer;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) { _controller.reverse(); widget.onTap(); },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
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
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Avatar with gold ring
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.25), blurRadius: 12),
                    ],
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

                const SizedBox(width: 16),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              trainer.name,
                              style: AppTextStyles.cardTitle.copyWith(fontSize: 18),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.goldBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.goldBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.gold, size: 12),
                                const SizedBox(width: 3),
                                Text(
                                  '${trainer.rating}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.goldDeep, fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trainer.specialties.join(' · '),
                        style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _TagChip(label: '${trainer.totalReviews} reviews'),
                          const SizedBox(width: 8),
                          const _TagChip(label: 'Available', isGreen: true),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool isGreen;
  const _TagChip({required this.label, this.isGreen = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isGreen ? AppColors.sageBg : AppColors.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isGreen ? AppColors.sageBorder : AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: isGreen ? AppColors.sage : AppColors.text3,
          fontSize: 10,
        ),
      ),
    );
  }
}
