import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/offers_provider.dart';

class AddReviewScreen extends ConsumerStatefulWidget {
  final BookingModel booking;
  const AddReviewScreen({super.key, required this.booking});

  @override
  ConsumerState<AddReviewScreen> createState() => _AddReviewScreenState();
}

class _AddReviewScreenState extends ConsumerState<AddReviewScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _feedbackCtrl;
  int _rating = 5;
  bool _isSubmitting = false;
  bool _submitted = false;

  late AnimationController _successController;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    final userModel = ref.read(userModelProvider).value;
    _nameCtrl = TextEditingController(text: userModel?.name ?? '');
    _phoneCtrl = TextEditingController(text: userModel?.phone ?? '');
    _feedbackCtrl = TextEditingController();

    _successController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700),
    );
    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: const Interval(0, 0.5)),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _feedbackCtrl.dispose();
    _successController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    try {
      final fs = ref.read(firestoreServiceProvider);

      // Submit review to Firestore
      await fs.submitReview(
        userId: user.uid,
        customerName: _nameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        stylistId: widget.booking.trainerId,
        stylistName: widget.booking.trainerName,
        rating: _rating.toDouble(),
        reviewText: _feedbackCtrl.text.trim(),
        bookingId: widget.booking.id,
      );

      // Mark booking as reviewed so the button disappears
      await fs.markBookingReviewed(widget.booking.id);

      setState(() {
        _isSubmitting = false;
        _submitted = true;
      });
      _successController.forward();
    } catch (e) {
      setState(() => _isSubmitting = false);
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // Top espresso gradient strip
          Container(
            height: 220,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D0B08), Color(0xFF1C1208)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── AppBar ──
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
                      Expanded(
                        child: Text(
                          'Add Review',
                          style: AppTextStyles.display2.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                Expanded(
                  child: _submitted ? _buildSuccess() : _buildForm(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Booking summary card ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D0B08), Color(0xFF1C1208)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: [
                  BoxShadow(color: AppColors.gold.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.2),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: const Icon(Icons.spa_rounded, color: AppColors.gold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.booking.offerTitle,
                            style: AppTextStyles.cardTitle.copyWith(color: Colors.white, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text('with ${widget.booking.trainerName}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.gold3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Star Rating ──
            _SectionLabel(label: 'YOUR RATING'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.cardWhite,
                border: Border.all(color: AppColors.border2),
                boxShadow: [
                  BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < _rating;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        filled ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: filled ? AppColors.gold : AppColors.text4,
                        size: filled ? 40 : 34,
                      ),
                    ),
                  );
                }),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _rating == 5 ? '✨ Excellent!' :
                  _rating == 4 ? '👍 Very Good!' :
                  _rating == 3 ? '😊 Good' :
                  _rating == 2 ? '😐 Fair' : '😔 Poor',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Name ──
            _SectionLabel(label: 'YOUR NAME'),
            const SizedBox(height: 8),
            _StyledTextField(
              controller: _nameCtrl,
              hintText: 'Enter your name',
              icon: Icons.person_rounded,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),

            const SizedBox(height: 16),

            // ── Phone ──
            _SectionLabel(label: 'PHONE NUMBER'),
            const SizedBox(height: 8),
            _StyledTextField(
              controller: _phoneCtrl,
              hintText: 'Enter your phone number',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Phone is required';
                if (v.trim().length < 10) return 'Enter a valid phone number';
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Stylist (read-only) ──
            _SectionLabel(label: 'STYLIST'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.goldBg,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.content_cut_rounded, color: AppColors.gold, size: 18),
                  const SizedBox(width: 12),
                  Text(widget.booking.trainerName,
                      style: AppTextStyles.body1.copyWith(
                          color: AppColors.goldDeep, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldBg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: Text('Your Stylist',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.gold, fontSize: 10)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Feedback ──
            _SectionLabel(label: 'FEEDBACK'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.cardWhite,
                border: Border.all(color: AppColors.border2),
                boxShadow: [
                  BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: TextFormField(
                controller: _feedbackCtrl,
                maxLines: 5,
                minLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Please write your feedback' : null,
                style: AppTextStyles.body1.copyWith(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Share your experience with ${widget.booking.trainerName}...',
                  hintStyle: AppTextStyles.body2.copyWith(color: AppColors.text4),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // ── Submit Button ──
            GestureDetector(
              onTap: _isSubmitting ? null : _submitReview,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _isSubmitting
                      ? const LinearGradient(colors: [Color(0xFFD9CEC0), Color(0xFFC8B9A5)])
                      : AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isSubmitting
                      ? []
                      : [BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 16, offset: const Offset(0, 4))],
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Text('Submit Review', style: AppTextStyles.btnLabel),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: ScaleTransition(
        scale: _successScale,
        child: FadeTransition(
          opacity: _successOpacity,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 28),
                    ],
                  ),
                  child: const Icon(Icons.star_rounded, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 28),
                Text('Thank You! 🙏',
                    style: AppTextStyles.display2.copyWith(color: AppColors.ink),
                    textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'Your review has been submitted.\n',
                  style: AppTextStyles.body2.copyWith(color: AppColors.text3, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.goldBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.gold, size: 14),
                      const SizedBox(width: 8),
                      Text('Published',
                          style: AppTextStyles.caption.copyWith(color: AppColors.goldDeep)),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 16),
                      ],
                    ),
                    child: Text('Back to Bookings',
                        style: AppTextStyles.btnLabel.copyWith(color: Colors.black)),
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

// ── Helpers ──

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyles.eyebrow.copyWith(color: AppColors.gold, letterSpacing: 2.5),
  );
}

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _StyledTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.cardWhite,
        border: Border.all(color: AppColors.border2),
        boxShadow: [
          BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: AppTextStyles.body1.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body2.copyWith(color: AppColors.text4),
          prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
