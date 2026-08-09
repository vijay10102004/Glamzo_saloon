import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/offers_provider.dart';
import '../../models/booking_model.dart';
import '../../models/slot_model.dart';

class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmedAsync  = ref.watch(confirmedBookingsProvider);
    final completedAsync  = ref.watch(completedBookingsProvider);
    final pendingAsync    = ref.watch(pendingBookingsProvider);
    final cancelledAsync  = ref.watch(cancelledBookingsProvider);

    // Derive counts from async values
    final confirmedList = confirmedAsync.value ?? [];
    final completedList = completedAsync.value ?? [];
    final pendingList   = pendingAsync.value ?? [];
    final cancelledList = cancelledAsync.value ?? [];

    // Split confirmed into upcoming vs past (for display sections)
    final now = DateTime.now();
    final upcomingConfirmed = confirmedList.where((b) => b.slotTime.isAfter(now)).toList();
    final pastConfirmed     = confirmedList.where((b) => !b.slotTime.isAfter(now)).toList();

    // History tab = completed bookings + cancelled bookings, sorted newest first
    final historyList = [...completedList, ...cancelledList]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.espresso,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => context.go('/home'),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.home_rounded, color: Colors.white, size: 18),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _QueueHero(
                upcomingCount: upcomingConfirmed.length,
                pendingCount: pendingList.length,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: _GoldTabBar(
                controller: _tabController,
                confirmedCount: confirmedList.length,
                pendingCount: pendingList.length,
                historyCount: historyList.length,
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            // ── Tab 1: Confirmed (upcoming + past awaiting completion) ──
            confirmedAsync.when(
              data: (_) {
                if (confirmedList.isEmpty) {
                  return const _EmptyTab(
                    icon: Icons.calendar_today_rounded,
                    title: 'No confirmed bookings',
                    subtitle: 'Your confirmed appointments appear here.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // Upcoming section
                    if (upcomingConfirmed.isNotEmpty) ...[
                      const _SectionHeader(label: 'UPCOMING', color: AppColors.sage),
                      const SizedBox(height: 8),
                      ...upcomingConfirmed.map((b) => _BookingCard(
                        booking: b,
                        cardType: _CardType.confirmed,
                      )),
                    ],
                    // Past-slot confirmed (admin hasn't marked completed yet)
                    if (pastConfirmed.isNotEmpty) ...[
                      if (upcomingConfirmed.isNotEmpty) const SizedBox(height: 8),
                      const _SectionHeader(label: 'AWAITING COMPLETION', color: AppColors.gold),
                      const SizedBox(height: 8),
                      ...pastConfirmed.map((b) => _BookingCard(
                        booking: b,
                        cardType: _CardType.confirmed,
                      )),
                    ],
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => _ErrorWidget(message: '$e'),
            ),

            // ── Tab 2: Pending Payment ──
            pendingAsync.when(
              data: (_) {
                if (pendingList.isEmpty) {
                  return const _EmptyTab(
                    icon: Icons.pending_outlined,
                    title: 'No pending payments',
                    subtitle: 'Bookings awaiting payment will appear here.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: pendingList.length,
                  itemBuilder: (_, i) => _BookingCard(
                    booking: pendingList[i],
                    cardType: _CardType.pending,
                    onPayNow: () => context.push(
                      '/home/pay-pending',
                      extra: {'bookingId': pendingList[i].id, 'amount': pendingList[i].amount},
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => _ErrorWidget(message: '$e'),
            ),

            // ── Tab 3: History (completed + cancelled) ──
            completedAsync.when(
              data: (_) => cancelledAsync.when(
                data: (_) {
                  if (historyList.isEmpty) {
                    return const _EmptyTab(
                      icon: Icons.history_rounded,
                      title: 'No history yet',
                      subtitle: 'Completed and cancelled bookings appear here.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    physics: const BouncingScrollPhysics(),
                    itemCount: historyList.length,
                    itemBuilder: (_, i) => _BookingCard(
                      booking: historyList[i],
                      cardType: _CardType.history,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
                error: (e, _) => _ErrorWidget(message: '$e'),
              ),
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, _) => _ErrorWidget(message: '$e'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Queue Hero ──
class _QueueHero extends StatelessWidget {
  final int upcomingCount;
  final int pendingCount;
  const _QueueHero({required this.upcomingCount, required this.pendingCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D0B08), Color(0xFF1C1208), Color(0xFF2E1E0A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20, right: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppColors.gold.withValues(alpha: 0.12), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('MY QUEUE',
                  style: AppTextStyles.eyebrow.copyWith(
                    color: AppColors.gold3, letterSpacing: 3),
                  textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Your Bookings',
                  style: AppTextStyles.display2.copyWith(color: Colors.white),
                  textAlign: TextAlign.center),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HeroBadge(count: upcomingCount, label: 'upcoming', color: AppColors.sage),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 10),
                      _HeroBadge(count: pendingCount, label: 'pending', color: AppColors.gold),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _HeroBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$count',
            style: AppTextStyles.display2.copyWith(color: color, fontSize: 24)),
          Text(label, style: AppTextStyles.caption.copyWith(color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ── Gold Tab Bar (3 tabs) ──
class _GoldTabBar extends StatelessWidget {
  final TabController controller;
  final int confirmedCount;
  final int pendingCount;
  final int historyCount;
  const _GoldTabBar({
    required this.controller,
    required this.confirmedCount,
    required this.pendingCount,
    required this.historyCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 6),
        ],
      ),
      child: TabBar(
        controller: controller,
        labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 11),
        unselectedLabelStyle: AppTextStyles.label.copyWith(fontSize: 11),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.text3,
        indicator: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 8)],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        tabs: [
          Tab(text: 'Confirmed ($confirmedCount)'),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Pending', style: TextStyle(fontSize: 11)),
                if (pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.rose,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$pendingCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            ),
          ),
          Tab(text: 'History ($historyCount)'),
        ],
      ),
    );
  }
}

// ── Empty Tab ──
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.goldBg,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: [BoxShadow(color: AppColors.gold.withValues(alpha: 0.12), blurRadius: 20)],
              ),
              child: Icon(icon, size: 36, color: AppColors.gold),
            ),
            const SizedBox(height: 24),
            Text(title, style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.body2, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Error Widget ──
class _ErrorWidget extends StatelessWidget {
  final String message;
  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.roseBg,
              border: Border.all(color: AppColors.roseBorder),
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 32),
          ),
          const SizedBox(height: 12),
          Text('Unable to load bookings', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text(message, style: AppTextStyles.body2, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Section Header ──
class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  const _SectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.eyebrow.copyWith(
              color: color,
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum _CardType { confirmed, pending, history }

// ── Booking Card ──
class _BookingCard extends ConsumerStatefulWidget {
  final BookingModel booking;
  final _CardType cardType;
  final VoidCallback? onPayNow;
  const _BookingCard({
    required this.booking,
    required this.cardType,
    this.onPayNow,
  });

  @override
  ConsumerState<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends ConsumerState<_BookingCard> with SingleTickerProviderStateMixin {
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

  Color get _statusColor {
    switch (widget.booking.status) {
      case 'confirmed': return AppColors.sage;
      case 'completed': return AppColors.gold;
      case 'cancelled': return AppColors.rose;
      case 'pending_payment': return const Color(0xFFFF9800);
      default: return AppColors.text3;
    }
  }

  Color get _statusBg {
    switch (widget.booking.status) {
      case 'confirmed': return AppColors.sageBg;
      case 'completed': return AppColors.goldBg;
      case 'cancelled': return AppColors.roseBg;
      case 'pending_payment': return const Color(0xFFFFF3E0);
      default: return AppColors.bg2;
    }
  }

  Color get _statusBorder {
    switch (widget.booking.status) {
      case 'confirmed': return AppColors.sageBorder;
      case 'completed': return AppColors.goldBorder;
      case 'cancelled': return AppColors.roseBorder;
      case 'pending_payment': return const Color(0xFFFFCC80);
      default: return AppColors.border;
    }
  }

  IconData get _statusIcon {
    switch (widget.booking.status) {
      case 'confirmed': return Icons.check_circle_rounded;
      case 'completed': return Icons.star_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      case 'pending_payment': return Icons.pending_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  String get _statusLabel {
    switch (widget.booking.status) {
      case 'pending_payment': return 'Payment Due';
      default: return widget.booking.status[0].toUpperCase() + widget.booking.status.substring(1);
    }
  }

  /// Show Add Review button for completed bookings not yet reviewed
  bool get _canReview =>
      widget.cardType == _CardType.history &&
      widget.booking.status == 'completed' &&
      !widget.booking.reviewSubmitted;

  /// Show Reschedule button for confirmed bookings within the next 24 hours
  bool get _canReschedule {
    if (widget.cardType != _CardType.confirmed) return false;
    if (widget.booking.status != 'confirmed') return false;
    final now = DateTime.now();
    final diff = widget.booking.slotTime.difference(now);
    return !diff.isNegative && diff.inHours <= 24;
  }

  void _showRescheduleSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RescheduleBottomSheet(
        booking: widget.booking,
        onSuccess: () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, d MMM yyyy').format(widget.booking.slotTime);
    final time = DateFormat('hh:mm a').format(widget.booking.slotTime);
    final isPending = widget.cardType == _CardType.pending;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isPending ? const Color(0xFFFFFBF0) : AppColors.cardWhite,
            border: Border.all(
              color: isPending ? const Color(0xFFFFCC80) : AppColors.border2,
              width: isPending ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPending
                    ? const Color(0xFFFF9800).withValues(alpha: 0.12)
                    : AppColors.ink.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top accent bar
              Container(
                height: 3,
                decoration: BoxDecoration(
                  color: _statusColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.goldBg,
                            border: Border.all(color: AppColors.goldBorder),
                          ),
                          child: const Icon(Icons.spa_rounded, color: AppColors.gold, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.booking.offerTitle,
                                style: AppTextStyles.cardTitle.copyWith(fontSize: 16),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'with ${widget.booking.trainerName}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_statusIcon, size: 11, color: _statusColor),
                              const SizedBox(width: 4),
                              Text(_statusLabel,
                                style: AppTextStyles.caption.copyWith(
                                  color: _statusColor, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Date / time / amount row
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.calendar_today_outlined, color: AppColors.gold, size: 16),
                                const SizedBox(height: 4),
                                Text(date,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.text2),
                                  textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: AppColors.border),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.access_time_rounded, color: AppColors.gold, size: 16),
                                const SizedBox(height: 4),
                                Text(time,
                                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                                  textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 36, color: AppColors.border),
                          Expanded(
                            child: Column(
                              children: [
                                const Icon(Icons.currency_rupee_rounded, color: AppColors.gold, size: 16),
                                const SizedBox(height: 4),
                                Text('₹${widget.booking.amount.toInt()}',
                                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                                  textAlign: TextAlign.center),
                                if (widget.cardType == _CardType.confirmed)
                                  Text('paid',
                                    style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.text4),
                                    textAlign: TextAlign.center),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Pending: Pay Now Button ──
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF9800), size: 16),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Payment pending — complete to confirm your slot',
                                style: TextStyle(color: Color(0xFF7A4F00), fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: widget.onPayNow,
                        child: Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 10),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phonelink_ring_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Pay ₹${widget.booking.amount.toInt()} Now',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── History: Loyalty points earned ──
                    if (widget.cardType == _CardType.history &&
                        widget.booking.loyaltyPointsEarned > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.goldBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.workspace_premium_rounded,
                              color: AppColors.gold, size: 14),
                            const SizedBox(width: 8),
                            Text('+${widget.booking.loyaltyPointsEarned} loyalty points earned',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.goldDeep, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],

                    // ── Transaction ID (confirmed/completed) ──
                    if (widget.booking.phonePeTransactionId.isNotEmpty &&
                        widget.cardType != _CardType.pending) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.sageBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.sageBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: AppColors.sage, size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Txn: ${widget.booking.phonePeTransactionId.length > 28 ? '${widget.booking.phonePeTransactionId.substring(0, 28)}...' : widget.booking.phonePeTransactionId}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.sage),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Add Review Button (completed, not yet reviewed) ──
                    if (_canReview) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => context.push('/home/add-review', extra: widget.booking),
                        child: Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 10),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text('⭐ Add Your Review',
                                style: AppTextStyles.label.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],

                    // ── Reschedule Button (confirmed, within 24 h of slot time) ──
                    if (_canReschedule) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD54F)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.access_time_filled_rounded,
                              color: Color(0xFFF57F17), size: 14),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text('Your appointment is coming up soon',
                                style: TextStyle(color: Color(0xFF7A4F00), fontSize: 11)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _showRescheduleSheet(context),
                        child: Container(
                          width: double.infinity,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.schedule_send_rounded,
                                color: Color(0xFFF57F17), size: 18),
                              const SizedBox(width: 8),
                              Text('🔄 Reschedule Appointment',
                                style: AppTextStyles.label.copyWith(
                                  color: const Color(0xFFF57F17),
                                  fontWeight: FontWeight.w800,
                                )),
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Reschedule Bottom Sheet ──
class _RescheduleBottomSheet extends ConsumerStatefulWidget {
  final BookingModel booking;
  final VoidCallback onSuccess;
  const _RescheduleBottomSheet({required this.booking, required this.onSuccess});

  @override
  ConsumerState<_RescheduleBottomSheet> createState() => _RescheduleBottomSheetState();
}

class _RescheduleBottomSheetState extends ConsumerState<_RescheduleBottomSheet> {
  List<SlotModel> _slots = [];
  bool _loading = true;
  bool _rescheduling = false;
  String? _error;
  SlotModel? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    try {
      final slots = await ref
          .read(firestoreServiceProvider)
          .getAvailableSlotsForReschedule(widget.booking.trainerId);
      if (mounted) setState(() { _slots = slots; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _confirm() async {
    if (_selectedSlot == null) return;
    setState(() => _rescheduling = true);
    try {
      await ref.read(firestoreServiceProvider).rescheduleBooking(
        bookingId: widget.booking.id,
        oldSlotId: widget.booking.slotId,
        newSlotId: _selectedSlot!.id,
        newSlotTime: _selectedSlot!.startTime,
      );
      widget.onSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppColors.sage, size: 16),
              SizedBox(width: 8),
              Text('Booking rescheduled successfully!'),
            ]),
            backgroundColor: const Color.fromARGB(0, 20, 21, 20),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color.fromARGB(0, 11, 11, 11))),
          ),
        );
      }
    } catch (e) {
      setState(() => _rescheduling = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.rose,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20, right: 20, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.goldBg,
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: const Icon(Icons.schedule_send_rounded, color: AppColors.gold, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reschedule Appointment',
                      style: AppTextStyles.sectionTitle.copyWith(fontSize: 16)),
                    Text('with ${widget.booking.trainerName}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.text3)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Text('AVAILABLE SLOTS',
            style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold, letterSpacing: 2)),
          const SizedBox(height: 12),

          // Slots
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.gold),
            ))
          else if (_error != null)
            Center(
              child: Text('Could not load slots: $_error',
                style: AppTextStyles.body2.copyWith(color: AppColors.rose)),
            )
          else if (_slots.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.roseBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.roseBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_busy_rounded, color: AppColors.rose, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text('No available slots for ${widget.booking.trainerName} right now.',
                    style: AppTextStyles.body2.copyWith(color: AppColors.rose))),
                ],
              ),
            )
          else
            SizedBox(
              height: 160,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 3.0, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _slots.length,
                itemBuilder: (_, i) {
                  final slot = _slots[i];
                  final isSelected = _selectedSlot?.id == slot.id;
                  final dateStr = DateFormat('EEE, d MMM').format(slot.startTime);
                  final timeStr = DateFormat('hh:mm a').format(slot.startTime);
                  return GestureDetector(
                    onTap: () => setState(() => _selectedSlot = slot),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected ? AppColors.goldBg : AppColors.cardWhite,
                        border: Border.all(
                          color: isSelected ? AppColors.gold : AppColors.border2,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(color: AppColors.gold.withValues(alpha: 0.2), blurRadius: 8),
                        ] : [],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(timeStr,
                            style: AppTextStyles.body1.copyWith(
                              fontWeight: FontWeight.w700, fontSize: 13,
                              color: isSelected ? AppColors.goldDeep : AppColors.ink)),
                          Text(dateStr,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: isSelected ? AppColors.gold : AppColors.text3)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 20),

          // Confirm button
          GestureDetector(
            onTap: (_selectedSlot == null || _rescheduling) ? null : _confirm,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: (_selectedSlot == null || _rescheduling)
                    ? const LinearGradient(colors: [Color(0xFFD9CEC0), Color(0xFFC8B9A5)])
                    : AppColors.goldGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: (_selectedSlot == null || _rescheduling)
                    ? [] : [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 14)],
              ),
              alignment: Alignment.center,
              child: _rescheduling
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          _selectedSlot == null
                              ? 'Select a Slot'
                              : 'Confirm Reschedule',
                          style: AppTextStyles.btnLabel,
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
