import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Branch / Location model
// ─────────────────────────────────────────────────────────────────────────────
class _BranchInfo {
  final String name;
  final String address;
  final String area;
  final String distance;
  final String timing;
  final String phoneNumber;
  final IconData icon;
  final List<Color> gradientColors;
  final List<String> amenities;

  const _BranchInfo({
    required this.name,
    required this.address,
    required this.area,
    required this.distance,
    required this.timing,
    required this.phoneNumber,
    required this.icon,
    required this.gradientColors,
    required this.amenities,
  });
}

const _branches = [
  _BranchInfo(
    name: 'Anna Nagar',
    address: '2nd Avenue, Anna Nagar',
    area: 'Chennai – 600 040',
    distance: '2.1 km away',
    timing: '9:00 AM – 9:00 PM',
    phoneNumber: '+91 90000 11111',
    icon: Icons.store_rounded,
    gradientColors: [Color(0xFF6E4B0E), Color(0xFFD4A017)],
    amenities: ['AC Salon', 'Parking', 'WiFi', 'Premium Products'],
  ),
  _BranchInfo(
    name: 'Kaalavasal',
    address: 'Main Road, Kaalavasal',
    area: 'Madurai – 625 016',
    distance: '3.5 km away',
    timing: '9:00 AM – 9:00 PM',
    phoneNumber: '+91 90000 22222',
    icon: Icons.storefront_rounded,
    gradientColors: [Color(0xFF1A4D6E), Color(0xFF1A9EBF)],
    amenities: ['AC Salon', 'Parking', 'WiFi', 'Bridal Package'],
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Location Select Screen
// ─────────────────────────────────────────────────────────────────────────────
class LocationSelectScreen extends ConsumerStatefulWidget {
  const LocationSelectScreen({super.key});

  @override
  ConsumerState<LocationSelectScreen> createState() =>
      _LocationSelectScreenState();
}

class _LocationSelectScreenState extends ConsumerState<LocationSelectScreen>
    with TickerProviderStateMixin {
  late AnimationController _headerAnim;
  late AnimationController _card1Anim;
  late AnimationController _card2Anim;

  String? _selectedBranch;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _card1Anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _card2Anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    Future.delayed(const Duration(milliseconds: 250),
        () => mounted ? _card1Anim.forward() : null);
    Future.delayed(const Duration(milliseconds: 380),
        () => mounted ? _card2Anim.forward() : null);

    // Pre-select whatever was previously chosen
    _selectedBranch = ref.read(selectedLocationProvider);
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _card1Anim.dispose();
    _card2Anim.dispose();
    super.dispose();
  }

  void _onBranchSelect(String branchName) {
    setState(() => _selectedBranch = branchName);
    ref.read(selectedLocationProvider.notifier).state = branchName;
  }

  void _onContinue() {
    if (_selectedBranch == null) return;
    // Clear previous trainer selection, then go to trainer selection
    ref.read(selectedTrainerProvider.notifier).state = null;
    context.push('/home/trainer-select-all');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Hero Header ──────────────────────────────────────────────────
          _buildHeader(),

          // ── Branch Cards ─────────────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
              physics: const BouncingScrollPhysics(),
              children: [
                _BranchCard(
                  branch: _branches[0],
                  isSelected: _selectedBranch == _branches[0].name,
                  animation: _card1Anim,
                  onTap: () => _onBranchSelect(_branches[0].name),
                ),
                const SizedBox(height: 16),
                _BranchCard(
                  branch: _branches[1],
                  isSelected: _selectedBranch == _branches[1].name,
                  animation: _card2Anim,
                  onTap: () => _onBranchSelect(_branches[1].name),
                ),
                const SizedBox(height: 24),

                // ── Info strip ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.goldBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.goldGradient,
                        ),
                        child: const Icon(Icons.info_outline_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your booking and preferences will be saved for the selected branch.',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.goldDeep,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ── Sticky Continue Button ───────────────────────────────────────────
      bottomNavigationBar: _selectedBranch != null
          ? _ContinueBar(
              selectedBranch: _selectedBranch!,
              onContinue: _onContinue,
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _headerAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut)),
        child: Container(
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
                              'CHOOSE BRANCH',
                              style: AppTextStyles.eyebrow.copyWith(
                                  color: AppColors.gold3, letterSpacing: 2.5),
                            ),
                            Text(
                              'Select Location',
                              style: AppTextStyles.display2
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Step progress indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(4, (i) {
                      // Steps: 0=Services, 1=Location (current), 2=Stylist, 3=Slot
                      final isDone = i < 1;
                      final isCurrent = i == 1;
                      return Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 4,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: (isDone || isCurrent)
                                      ? AppColors.gold
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            if (i < 3) const SizedBox(width: 4),
                          ],
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StepLabel(label: 'Services', isDone: true, isCurrent: false),
                      _StepLabel(label: 'Location', isDone: false, isCurrent: true),
                      _StepLabel(label: 'Stylist', isDone: false, isCurrent: false),
                      _StepLabel(label: 'Slot', isDone: false, isCurrent: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Label
// ─────────────────────────────────────────────────────────────────────────────
class _StepLabel extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isCurrent;
  const _StepLabel(
      {required this.label, required this.isDone, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        color: isCurrent
            ? AppColors.gold3
            : isDone
                ? AppColors.gold.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.35),
        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Branch Card
// ─────────────────────────────────────────────────────────────────────────────
class _BranchCard extends StatefulWidget {
  final _BranchInfo branch;
  final bool isSelected;
  final AnimationController animation;
  final VoidCallback onTap;

  const _BranchCard({
    required this.branch,
    required this.isSelected,
    required this.animation,
    required this.onTap,
  });

  @override
  State<_BranchCard> createState() => _BranchCardState();
}

class _BranchCardState extends State<_BranchCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _pressScale =
        Tween<double>(begin: 1.0, end: 0.975).animate(_pressCtrl);
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branch = widget.branch;

    return FadeTransition(
      opacity: widget.animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.18),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(parent: widget.animation, curve: Curves.easeOut),
        ),
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            widget.onTap();
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: ScaleTransition(
            scale: _pressScale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: widget.isSelected
                      ? AppColors.gold
                      : AppColors.border2,
                  width: widget.isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isSelected
                        ? AppColors.gold.withValues(alpha: 0.18)
                        : AppColors.ink.withValues(alpha: 0.06),
                    blurRadius: widget.isSelected ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ── Gradient Hero Top ──
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: branch.gradientColors,
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20)),
                    ),
                    child: Stack(
                      children: [
                        // Subtle pattern
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20)),
                            child: CustomPaint(
                              painter: _DotPatternPainter(
                                  color: Colors.white.withValues(alpha: 0.06)),
                            ),
                          ),
                        ),
                        // Store icon + branch name
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(branch.icon,
                                    color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      branch.name,
                                      style: AppTextStyles.display2.copyWith(
                                        color: Colors.white,
                                        fontSize: 22,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.18),
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.white,
                                              size: 10),
                                          const SizedBox(width: 3),
                                          Text(
                                            branch.distance,
                                            style:
                                                AppTextStyles.caption.copyWith(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Selection indicator
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.isSelected
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.2),
                                  border: Border.all(
                                    color: widget.isSelected
                                        ? Colors.white
                                        : Colors.white
                                            .withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: widget.isSelected
                                    ? Icon(
                                        Icons.check_rounded,
                                        color: branch.gradientColors.last,
                                        size: 16,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Details Body ──
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Address
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.place_rounded,
                                color: AppColors.gold, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(branch.address,
                                      style: AppTextStyles.body2.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      )),
                                  Text(branch.area,
                                      style: AppTextStyles.caption
                                          .copyWith(color: AppColors.text3)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 12),

                        // Timing + Phone
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      color: AppColors.gold, size: 14),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      branch.timing,
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.text2,
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                const Icon(Icons.call_rounded,
                                    color: AppColors.sage, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  branch.phoneNumber,
                                  style: AppTextStyles.caption.copyWith(
                                      color: AppColors.sage,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Amenity chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: branch.amenities.map((amenity) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.goldBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.goldBorder
                                        .withValues(alpha: 0.6)),
                              ),
                              child: Text(
                                amenity,
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.goldDeep,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }).toList(),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom Painter: dot pattern for card header
// ─────────────────────────────────────────────────────────────────────────────
class _DotPatternPainter extends CustomPainter {
  final Color color;
  const _DotPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// Continue Bar
// ─────────────────────────────────────────────────────────────────────────────
class _ContinueBar extends StatelessWidget {
  final String selectedBranch;
  final VoidCallback onContinue;

  const _ContinueBar({
    required this.selectedBranch,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Selected branch label
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Branch',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.text3, fontSize: 10),
                    ),
                    Text(
                      'Glamzo — $selectedBranch',
                      style: AppTextStyles.body2.copyWith(
                        color: AppColors.goldDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Continue button
            GestureDetector(
              onTap: onContinue,
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
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
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text('Choose Stylist', style: AppTextStyles.btnLabel),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.white, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
