import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bookings_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../providers/offers_provider.dart';
import '../../models/booking_model.dart';
import '../../services/razorpay_service.dart';

class PayPendingScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;
  const PayPendingScreen({super.key, this.extra});

  @override
  ConsumerState<PayPendingScreen> createState() => _PayPendingScreenState();
}

class _PayPendingScreenState extends ConsumerState<PayPendingScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  bool _isProcessing = false;
  bool _paymentSuccess = false;
  bool _paymentInitiated = false;
  String? _transactionId;
  String _merchantTxnId = '';

  late AnimationController _successController;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  BookingModel? _currentBooking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
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
    WidgetsBinding.instance.removeObserver(this);
    _successController.dispose();
    super.dispose();
  }

  /// When user returns from UPI app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _paymentInitiated &&
        !_paymentSuccess &&
        _currentBooking != null &&
        mounted) {
      _paymentInitiated = false;
      _showUtrDialog(_currentBooking!);
    }
  }

  String? get _bookingId => widget.extra?['bookingId'] as String?;

  // ─────────────────────────────────────────────────────────────────────
  // Launch UPI for this pending booking
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _payNow(BookingModel booking) async {
    final user = ref.read(authServiceProvider).currentUser;
    final userModel = ref.read(userModelProvider).value;
    if (user == null) return;

    setState(() {
      _isProcessing = true;
      _currentBooking = booking;
    });

    try {
      _merchantTxnId = 'GLAMZO_PENDING_${user.uid}_${DateTime.now().millisecondsSinceEpoch}';

      final result = await RazorpayService.initiatePayment(
        amount: booking.amount,
        merchantTransactionId: _merchantTxnId,
        userId: user.uid,
        mobileNumber: userModel?.phone ?? '',
      );

      setState(() {
        _isProcessing = false;
        _paymentInitiated = result.success;
      });

      if (!result.success) {
        if (mounted) _showSnack('Could not open Razorpay. Please try again.', isError: true);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────
  // Show UTR verification dialog
  // ─────────────────────────────────────────────────────────────────────
  Future<void> _showUtrDialog(BookingModel booking) async {
    if (!mounted) return;
    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UtrDialog(
        amount: booking.amount,
        upiId: AppConstants.merchantName,
        onSubmit: (utr) async {
          Navigator.of(ctx).pop();
          await _submitUtr(booking, utr, user.uid);
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Future<void> _submitUtr(BookingModel booking, String utr, String uid) async {
    setState(() => _isProcessing = true);
    try {
      // Mark as pending_verification with UTR
      await ref.read(firestoreServiceProvider).claimPaymentWithUtr(
        bookingId: booking.id,
        utrNumber: utr,
        merchantTransactionId: _merchantTxnId,
      );

      _transactionId = _merchantTxnId;
      setState(() {
        _isProcessing = false;
        _paymentSuccess = true;
      });
      _successController.forward();
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) _showSnack('Error: $e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: isError ? AppColors.rose : AppColors.sage,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: AppTextStyles.body2.copyWith(color: AppColors.ink))),
          ],
        ),
        backgroundColor: AppColors.cardWhite,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isError ? AppColors.roseBorder : AppColors.sageBorder),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bid = _bookingId;
    if (bid == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.rose, size: 48),
              const SizedBox(height: 12),
              Text('Booking not found', style: AppTextStyles.sectionTitle),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/home/queue'),
                child: Text('Go to Queue', style: AppTextStyles.body2.copyWith(color: AppColors.gold)),
              ),
            ],
          ),
        ),
      );
    }

    final pendingAsync = ref.watch(pendingBookingsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: pendingAsync.when(
        data: (bookings) {
          final booking = bookings.where((b) => b.id == bid).firstOrNull;

          // Already confirmed or verified
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.sage, size: 64),
                  const SizedBox(height: 12),
                  Text('Booking Confirmed!', style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/home/queue'),
                    child: Text('View Queue', style: AppTextStyles.body2.copyWith(color: AppColors.gold)),
                  ),
                ],
              ),
            );
          }

          return Stack(
            children: [
              Container(
                height: 180,
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
                    // AppBar
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
                            child: Text(
                              _paymentSuccess ? 'Claim Submitted' : _getPendingTitle(booking),
                              style: AppTextStyles.display2.copyWith(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 40),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),

                    Expanded(
                      child: _paymentSuccess
                          ? _buildSuccessView()
                          : _buildPaymentView(booking),
                    ),

                    // Only show pay button for pending_payment (not pending_verification)
                    if (!_paymentSuccess && booking.status == 'pending_payment')
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        decoration: BoxDecoration(
                          color: AppColors.cardWhite,
                          border: const Border(top: BorderSide(color: AppColors.border)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.08),
                              blurRadius: 20, offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // UPI ID strip
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.account_balance_rounded,
                                    color: Color(0xFF0284C7), size: 14),
                                  const SizedBox(width: 6),
                                  Text('Pay to: ',
                                    style: AppTextStyles.caption.copyWith(color: const Color(0xFF075985))),
                                  Text(AppConstants.merchantName,
                                    style: AppTextStyles.label.copyWith(
                                      color: const Color(0xFF0284C7), fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            _PayButton(
                              label: 'Pay ₹${booking.amount.toInt()} via UPI',
                              isLoading: _isProcessing,
                              onPressed: () => _payNow(booking),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.gold)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _getPendingTitle(BookingModel b) {
    if (b.status == 'pending_verification') return 'Awaiting Verification';
    return 'Complete Payment';
  }

  Widget _buildPaymentView(BookingModel booking) {
    final isPendingVerification = booking.status == 'pending_verification';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      physics: const BouncingScrollPhysics(),
      children: [
        // Status banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPendingVerification
                ? const Color(0xFFFFF8E1)
                : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPendingVerification
                  ? const Color(0xFFFFE082)
                  : const Color(0xFFFFCC80),
              width: 1.5,
            ),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF9800).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFFFFCC80)),
              ),
              child: Icon(
                isPendingVerification
                    ? Icons.hourglass_top_rounded
                    : Icons.pending_actions_rounded,
                color: const Color(0xFFFF9800), size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPendingVerification ? 'Under Verification' : 'Payment Required',
                  style: const TextStyle(
                    color: Color(0xFF7A4F00), fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  isPendingVerification
                      ? 'UTR ${booking.utrNumber} submitted. Admin verifying — usually under 10 min.'
                      : 'Your slot is held. Complete payment to confirm.',
                  style: AppTextStyles.caption.copyWith(color: const Color(0xFF7A4F00)),
                ),
              ],
            )),
          ]),
        ),

        const SizedBox(height: 20),

        // Booking details
        _InfoCard(child: Column(children: [
          _Row(icon: Icons.spa_rounded, label: 'Service', value: booking.offerTitle),
          _Divider(),
          _Row(icon: Icons.person_rounded, label: 'Stylist', value: booking.trainerName),
          _Divider(),
          _Row(icon: Icons.calendar_month_rounded, label: 'Date',
            value: DateFormat('EEE, d MMM yyyy').format(booking.slotTime)),
          _Divider(),
          _Row(icon: Icons.access_time_rounded, label: 'Time',
            value: DateFormat('hh:mm a').format(booking.slotTime)),
        ])),

        const SizedBox(height: 16),

        _InfoCard(child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Amount Due', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700)),
            Text('₹${booking.amount.toInt()}',
              style: AppTextStyles.priceLarge.copyWith(fontSize: 28)),
          ],
        )),

        if (isPendingVerification) ...[
          const SizedBox(height: 16),
          // UTR submitted info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Text('Payment Claim Details',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 10),
                _InfoRow(label: 'UTR / Ref No.', value: booking.utrNumber.isEmpty ? '—' : booking.utrNumber),
                const SizedBox(height: 6),
                _InfoRow(label: 'Txn ID', value: booking.phonePeTransactionId.isEmpty
                    ? '—'
                    : booking.phonePeTransactionId.length > 24
                        ? '${booking.phonePeTransactionId.substring(0, 24)}…'
                        : booking.phonePeTransactionId),
                if (booking.paymentClaimedAt != null) ...[
                  const SizedBox(height: 6),
                  _InfoRow(label: 'Claimed At',
                    value: DateFormat('d MMM, hh:mm a').format(booking.paymentClaimedAt!)),
                ],
              ],
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          // UPI apps & instructions
          _InfoCard(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pay using any UPI app:',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _UpiChip(label: 'GPay', emoji: '🟢'),
                  _UpiChip(label: 'PhonePe', emoji: '💜'),
                  _UpiChip(label: 'Paytm', emoji: '🔵'),
                  _UpiChip(label: 'BHIM', emoji: '🟠'),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(children: [
                  const Icon(Icons.shield_rounded, color: Color(0xFFF9A825), size: 14),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'After paying, you\'ll be asked to enter your UTR for verification. '
                    'Your booking is confirmed once our team verifies receipt.',
                    style: AppTextStyles.caption.copyWith(color: const Color(0xFF7A5400)),
                  )),
                ]),
              ),
            ],
          )),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.goldBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(children: [
              const Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Complete payment to earn ${(booking.amount * AppConstants.loyaltyPointsPerRupee).toInt()} loyalty points',
                style: AppTextStyles.caption.copyWith(color: AppColors.goldDeep),
              )),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessView() {
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
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 24),
                    ],
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 28),
                Text('Payment Claim Submitted!', style: AppTextStyles.display2),
                const SizedBox(height: 10),
                Text(
                  'Our team will verify your UTR against PhonePe records and confirm your booking within 5–10 minutes.',
                  style: AppTextStyles.body2.copyWith(color: AppColors.text3),
                  textAlign: TextAlign.center,
                ),
                if (_transactionId != null) ...[
                  const SizedBox(height: 8),
                  Text('Ref: ${_transactionId!.length > 30 ? '${_transactionId!.substring(0, 30)}...' : _transactionId!}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                    textAlign: TextAlign.center),
                ],
                const SizedBox(height: 36),
                GestureDetector(
                  onTap: () => context.go('/home/queue'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 16),
                      ],
                    ),
                    child: Text('Track My Booking',
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

// ─────────────────────────────────────────────────────────────────────────────
// UTR Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _UtrDialog extends StatefulWidget {
  final double amount;
  final String upiId;
  final Future<void> Function(String utr) onSubmit;
  final VoidCallback onCancel;
  const _UtrDialog({
    required this.amount, required this.upiId,
    required this.onSubmit, required this.onCancel,
  });
  @override
  State<_UtrDialog> createState() => _UtrDialogState();
}

class _UtrDialogState extends State<_UtrDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0D0B08), Color(0xFF2D1F04)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            ),
            child: Column(children: [
              const Icon(Icons.payment_rounded, color: AppColors.gold, size: 32),
              const SizedBox(height: 8),
              Text('Enter Your UPI Reference',
                style: AppTextStyles.display2.copyWith(color: Colors.white), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('You paid ₹${widget.amount.toInt()} to ${widget.upiId}',
                style: AppTextStyles.body2.copyWith(color: Colors.white70), textAlign: TextAlign.center),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('UPI Transaction Reference (UTR)',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Find it in your UPI app: Transaction History → this payment → Reference ID',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text3)),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ctrl,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 22,
                  style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.2),
                  decoration: InputDecoration(
                    hintText: 'e.g. 123456789012',
                    hintStyle: AppTextStyles.body2.copyWith(color: AppColors.text4),
                    prefixIcon: const Icon(Icons.receipt_rounded, color: AppColors.gold, size: 18),
                    counterText: '',
                    filled: true, fillColor: AppColors.bg2,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border2)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.5)),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.rose)),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.rose, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'Please enter your UTR';
                    if (val.length < 8) return 'UTR should be at least 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC80)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 14),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Your UTR will be verified against our bank statement. '
                      'False claims result in booking cancellation.',
                      style: AppTextStyles.caption.copyWith(color: const Color(0xFF7A3100)),
                    )),
                  ]),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _submitting ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _submitting = true);
                      await widget.onSubmit(_ctrl.text.trim());
                    }
                  },
                  child: Container(
                    width: double.infinity, height: 52,
                    decoration: BoxDecoration(
                      gradient: _submitting
                          ? const LinearGradient(colors: [Color(0xFFD9CEC0), Color(0xFFC8B9A5)])
                          : AppColors.goldGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _submitting ? [] : [
                        BoxShadow(color: AppColors.gold.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _submitting
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Text('Submit Payment Claim', style: AppTextStyles.btnLabel),
                          ]),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Container(
                    width: double.infinity, height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.bg2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: Text('Close', style: AppTextStyles.label.copyWith(color: AppColors.text3)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ──
class _UpiChip extends StatelessWidget {
  final String label;
  final String emoji;
  const _UpiChip({required this.label, required this.emoji});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(emoji, style: const TextStyle(fontSize: 18)),
    const SizedBox(height: 2),
    Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.text2, fontSize: 10)),
  ]);
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: AppColors.cardWhite,
      border: Border.all(color: AppColors.border2),
      boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: child,
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.goldBg,
          border: Border.all(color: AppColors.goldBorder.withValues(alpha: 0.6))),
        child: Icon(icon, color: AppColors.gold, size: 14),
      ),
      const SizedBox(width: 12),
      Text(label, style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
      const Spacer(),
      Flexible(child: Text(value,
        style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(children: [
    Text('$label: ', style: AppTextStyles.caption.copyWith(color: AppColors.text3)),
    Expanded(child: Text(value,
      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
  ]);
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 1, margin: const EdgeInsets.symmetric(vertical: 2), color: AppColors.border);
}

class _PayButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _PayButton({required this.label, required this.isLoading, this.onPressed});
  @override
  State<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends State<_PayButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            gradient: widget.isLoading
                ? const LinearGradient(colors: [Color(0xFFD9CEC0), Color(0xFFC8B9A5)])
                : AppColors.goldGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isLoading ? [] : [
              BoxShadow(color: AppColors.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.payments_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(widget.label, style: AppTextStyles.btnLabel),
                ]),
        ),
      ),
    );
  }
}
