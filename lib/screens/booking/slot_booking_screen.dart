import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../../providers/slots_provider.dart';
import '../../models/slot_model.dart';

class SlotBookingScreen extends ConsumerWidget {
  const SlotBookingScreen({super.key});

  /// Returns true if [slot] would collide with any already-booked slot
  /// given the [requiredMinutes] needed for all selected services.
  bool _hasCollision(SlotModel slot, List<SlotModel> allSlots, int requiredMinutes) {
    final proposedEnd =
        slot.startTime.add(Duration(minutes: requiredMinutes));
    for (final other in allSlots) {
      if (other.id == slot.id) continue;
      if (!other.isAvailable) {
        // other.startTime to other.startTime+30 (default slot size)
        final otherEnd =
            other.startTime.add(const Duration(minutes: 30));
        final overlaps = slot.startTime.isBefore(otherEnd) &&
            proposedEnd.isAfter(other.startTime);
        if (overlaps) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainer = ref.watch(selectedTrainerProvider);
    // Slot collision check uses a fixed 30-min window
    const requiredMinutes = 30;

    if (trainer == null) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: Text('No professional selected')),
      );
    }

    final selectedDate = ref.watch(selectedDateProvider);
    final selectedSlot = ref.watch(selectedSlotProvider);
    final branch       = ref.watch(selectedLocationProvider) ?? '';
    final slotsAsync = ref.watch(
      allSlotsProvider((trainerId: trainer.id, date: selectedDate, branch: branch)),
    );

    final today = DateTime.now();
    final dates = List.generate(14, (i) => today.add(Duration(days: i)));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Espresso Hero Top ──
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
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text('STEP 3 OF 4',
                                style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold3, letterSpacing: 2)),
                              Text('Select a Slot',
                                style: AppTextStyles.display2.copyWith(color: Colors.white)),
                              if (branch.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.location_on_rounded, color: AppColors.gold3, size: 10),
                                      const SizedBox(width: 4),
                                      Text(branch,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.gold3, fontSize: 10, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trainer chip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white.withValues(alpha: 0.1),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42, height: 42,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.goldGradient,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(1.5),
                              child: CircleAvatar(
                                backgroundColor: AppColors.bg2,
                                backgroundImage: trainer.photoUrl.isNotEmpty
                                    ? NetworkImage(trainer.photoUrl)
                                    : null,
                                child: trainer.photoUrl.isEmpty
                                    ? Text(trainer.name[0],
                                        style: AppTextStyles.body1.copyWith(
                                          color: AppColors.gold, fontWeight: FontWeight.w700))
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(trainer.name,
                                  style: AppTextStyles.body1.copyWith(
                                    fontWeight: FontWeight.w700, color: Colors.white)),
                                Text(trainer.specialties.join(' · '),
                                  style: AppTextStyles.caption.copyWith(
                                    color: Colors.white.withValues(alpha: 0.6))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.gold3, size: 12),
                                const SizedBox(width: 3),
                                Text('${trainer.rating}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.gold3, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date strip
                  SizedBox(
                    height: 82,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: dates.length,
                      itemBuilder: (context, i) {
                        final date = dates[i];
                        final isSelected = selectedDate.year == date.year &&
                            selectedDate.month == date.month &&
                            selectedDate.day == date.day;
                        final isToday = i == 0;

                        return GestureDetector(
                          onTap: () {
                            ref.read(selectedDateProvider.notifier).state = date;
                            ref.read(selectedSlotProvider.notifier).state = null;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.only(right: 10),
                            width: 58,
                            decoration: BoxDecoration(
                              gradient: isSelected ? AppColors.goldGradient : null,
                              color: isSelected ? null : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(
                                      color: AppColors.gold.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    )]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isToday && !isSelected)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 2),
                                    width: 4, height: 4,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.gold3,
                                    ),
                                  ),
                                Text(
                                  DateFormat('EEE').format(date),
                                  style: AppTextStyles.caption.copyWith(
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('d').format(date),
                                  style: AppTextStyles.sectionTitle.copyWith(
                                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Legend ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                _Legend(color: AppColors.gold, label: 'Available'),
                const SizedBox(width: 16),
                _Legend(color: AppColors.border2, label: 'Booked'),
                const SizedBox(width: 16),
                _Legend(color: AppColors.goldDeep, label: 'Selected'),
              ],
            ),
          ),

          // ── Slot Grid ──
          Expanded(
            child: slotsAsync.when(
              data: (rawSlots) {
                // Filter out past slots when the selected date is today
                final now = DateTime.now();
                final isToday = selectedDate.year == now.year &&
                    selectedDate.month == now.month &&
                    selectedDate.day == now.day;
                final slots = isToday
                    ? rawSlots
                        .where((s) => s.startTime.isAfter(now))
                        .toList()
                    : rawSlots;

                if (slots.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.cardWhite,
                            border: Border.all(color: AppColors.border2),
                            boxShadow: [
                              BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 8),
                            ],
                          ),
                          child: const Icon(Icons.event_busy_rounded, size: 32, color: AppColors.text4),
                        ),
                        const SizedBox(height: 16),
                        Text('No slots on this day', style: AppTextStyles.sectionTitle),
                        const SizedBox(height: 6),
                        Text('Pick another date', style: AppTextStyles.body2),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.0,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, i) {
                    final slot = slots[i];
                    // Collision check: is this slot free for the required duration?
                    final collision = _hasCollision(slot, slots, requiredMinutes);
                    final isEffectivelyAvailable =
                        slot.isAvailable && !collision;
                    return _SlotTile(
                      slot: slot,
                      isSelected: selectedSlot?.id == slot.id,
                      isCollision: collision,
                      onTap: isEffectivelyAvailable
                          ? () => ref.read(selectedSlotProvider.notifier).state = slot
                          : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
              error: (e, st) => Center(child: Text('Error: $e', style: AppTextStyles.body2)),
            ),
          ),
        ],
      ),

      // ── Bottom CTA ──
      bottomNavigationBar: selectedSlot != null
          ? SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                border: const Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.goldBg,
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: const Icon(Icons.access_time_rounded, color: AppColors.gold, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${DateFormat('EEE, d MMM').format(selectedSlot.startTime)} at ${DateFormat('hh:mm a').format(selectedSlot.startTime)}',
                        style: AppTextStyles.body2.copyWith(color: AppColors.goldDeep, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.push('/home/booking-confirm'),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text('Continue to Booking', style: AppTextStyles.btnLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          : null,
    );
  }
}

// ── Slot Tile ──
class _SlotTile extends StatefulWidget {
  final SlotModel slot;
  final bool isSelected;
  final bool isCollision;
  final VoidCallback? onTap;
  const _SlotTile({
    required this.slot,
    required this.isSelected,
    this.isCollision = false,
    this.onTap,
  });

  @override
  State<_SlotTile> createState() => _SlotTileState();
}

class _SlotTileState extends State<_SlotTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBooked = !widget.slot.isAvailable;
    final timeStr = DateFormat('hh:mm a').format(widget.slot.startTime);

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null ? (_) { _controller.reverse(); widget.onTap!(); } : null,
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: widget.isSelected ? AppColors.goldGradient : null,
            color: widget.isSelected
                ? null
                : widget.isCollision
                    ? AppColors.rose.withValues(alpha: 0.08)
                    : isBooked
                        ? AppColors.bg3
                        : AppColors.cardWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.gold
                  : widget.isCollision
                      ? AppColors.rose.withValues(alpha: 0.4)
                      : isBooked
                          ? AppColors.border
                          : AppColors.border2,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 2))]
                : isBooked
                    ? []
                    : [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 4)],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isSelected && !isBooked)
                Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(bottom: 3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                ),
              Text(
                timeStr,
                style: AppTextStyles.label.copyWith(
                  color: widget.isSelected
                      ? Colors.white
                      : widget.isCollision
                          ? AppColors.rose.withValues(alpha: 0.7)
                          : isBooked
                              ? AppColors.text4
                              : AppColors.ink,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              if (isBooked)
                Text(
                  'BOOKED',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.text4,
                    fontSize: 7,
                    letterSpacing: 1,
                  ),
                ),
              if (widget.isCollision && !isBooked)
                Text(
                  'OVERLAP',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.rose.withValues(alpha: 0.7),
                    fontSize: 7,
                    letterSpacing: 1,
                  ),
                ),
              if (widget.isSelected && !isBooked)
                Text(
                  '✓',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Legend ──
class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.text3)),
      ],
    );
  }
}
