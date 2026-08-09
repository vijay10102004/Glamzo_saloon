import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/offers_provider.dart';
import '../../providers/trainers_provider.dart';
import '../../providers/slots_provider.dart';
import '../../providers/loyalty_provider.dart';
import '../../models/booking_model.dart';
import '../../services/razorpay_service.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;
  const BookingConfirmScreen({super.key, this.extra});

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // ── State ──────────────────────────────────────────────────────────────
  bool   _isProcessing   = false;
  bool   _paymentOpened  = false;   // PG checkout was launched
  bool   _isVerifying    = false;   // Checking status with Razorpay API
  bool   _paymentSuccess = false;
  bool   _paymentFailed  = false;
  bool   _useWallet      = false;

  String? _bookingId;
  String  _merchantTxnId   = '';
  String  _razorpayTxnId   = '';
  String  _failureMessage  = '';
  double  _walletUsed      = 0;
  double  _pgAmount        = 0;

  late AnimationController _successController;
  late AnimationController _pulseController;
  late Animation<double>   _successScale;
  late Animation<double>   _successOpacity;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    _successController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _successScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _successController, curve: Curves.elasticOut));
    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _successController, curve: const Interval(0, 0.5)));
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _successController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── App resumed after PhonePe checkout ────────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _paymentOpened &&
        !_paymentSuccess &&
        !_isVerifying &&
        mounted) {
      _paymentOpened = false;
      _verifyPaymentStatus();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Reserve slot + launch Razorpay checkout
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initiatePayment() async {
    final offer     = ref.read(selectedOfferProvider);
    final trainer   = ref.read(selectedTrainerProvider);
    final slot      = ref.read(selectedSlotProvider);
    final user      = ref.read(authServiceProvider).currentUser;
    final userModel = ref.read(userModelProvider).value;
    final branch    = ref.read(selectedLocationProvider) ?? '';

    if (offer == null || trainer == null || slot == null || user == null) return;

    setState(() => _isProcessing = true);
    try {
      // ── Calculate amounts ──────────────────────────────────────────────
      final hasVoucher  = userModel?.hasLoyaltyVoucher ?? false;
      final baseAmount  = hasVoucher
          ? (offer.price - AppConstants.loyaltyVoucherValue).clamp(0.0, double.infinity)
          : offer.price;
      final walletBal   = userModel?.walletBalance ?? 0.0;
      double walletUsed = 0.0;
      double pgAmount   = baseAmount;

      if (_useWallet && walletBal > 0) {
        walletUsed = walletBal >= baseAmount ? baseAmount : walletBal;
        pgAmount   = (baseAmount - walletUsed).clamp(0.0, double.infinity);
      }

      // ── Deduct wallet first (atomic) ───────────────────────────────────
      if (walletUsed > 0) {
        await ref.read(firestoreServiceProvider).deductWalletBalance(
          uid: user.uid,
          amount: walletUsed,
          reason: 'Booking payment: ${offer.title}',
        );
      }

      // ── Reserve slot + create pending booking ──────────────────────────
      final booking = BookingModel(
        id: '',
        userId: user.uid,
        offerId: offer.id,
        offerTitle: offer.title,
        trainerId: trainer.id,
        trainerName: trainer.name,
        slotId: slot.id,
        slotTime: slot.startTime,
        amount: baseAmount,
        branch: branch,
        status: AppConstants.statusPendingPayment,
        loyaltyPointsEarned:
            (baseAmount * AppConstants.loyaltyPointsPerRupee).toInt(),
        loyaltyVoucherApplied: hasVoucher,
        createdAt: DateTime.now(),
      );

      _bookingId = await ref
          .read(firestoreServiceProvider)
          .createPendingBooking(booking);

      _walletUsed = walletUsed;
      _pgAmount   = pgAmount;

      // ── Wallet covers everything? Confirm immediately ──────────────────
      if (pgAmount <= 0) {
        await _autoConfirmBooking(
          uid: user.uid,
          offerTitle: offer.title,
          baseAmount: baseAmount,
          hasVoucher: hasVoucher,
          pgTxnId: 'WALLET_${DateTime.now().millisecondsSinceEpoch}',
        );
        return;
      }

      // ── Build merchant transaction ID ──────────────────────────────────
      _merchantTxnId =
          'GLAMZO${user.uid.substring(0, 6).toUpperCase()}${DateTime.now().millisecondsSinceEpoch}';

      // ── Launch Razorpay PG checkout ──────────────────────────────────────
      final result = await RazorpayService.initiatePayment(
        amount: pgAmount,
        merchantTransactionId: _merchantTxnId,
        userId: user.uid,
        mobileNumber: userModel?.phone ?? '',
      );

      setState(() {
        _isProcessing  = false;
        _paymentOpened = result.success;
      });

      if (!result.success) {
        await _rollback(user.uid, walletUsed);
        _showSnack('Could not open Razorpay: ${result.message}', isError: true);
      }
    } on Exception catch (e) {
      setState(() => _isProcessing = false);
      final msg = e.toString();
      if (msg.contains('no longer available') || msg.contains('Slot')) {
        _showSnack('⚠️ Slot just got booked! Please pick another time.',
            isError: true);
        if (mounted) context.pop();
      } else {
        _showSnack('Error: $msg', isError: true);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Verify payment via Razorpay Status API (auto, no admin needed)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _verifyPaymentStatus() async {
    if (_bookingId == null || !mounted) return;

    final user      = ref.read(authServiceProvider).currentUser;
    final offer     = ref.read(selectedOfferProvider);
    final userModel = ref.read(userModelProvider).value;
    if (user == null) return;

    setState(() => _isVerifying = true);

    // Retry with exponential back-off: 2s → 4s → 8s → 16s
    final statusResult = await RazorpayService.checkStatusWithRetry(
      merchantTransactionId: _merchantTxnId,
      maxRetries: 4,
      initialDelay: const Duration(seconds: 2),
    );

    if (!mounted) return;

    if (statusResult.isSuccess) {
      // ✅ PAYMENT CONFIRMED BY RAZORPAY — auto-confirm booking
      _razorpayTxnId = statusResult.transactionId ?? _merchantTxnId;
      await _autoConfirmBooking(
        uid: user.uid,
        offerTitle: offer?.title ?? '',
        baseAmount: _pgAmount + _walletUsed,
        hasVoucher: userModel?.hasLoyaltyVoucher ?? false,
        pgTxnId: _razorpayTxnId,
      );
    } else if (statusResult.isFailed) {
      // ❌ PAYMENT FAILED — rollback slot + wallet
      setState(() { _isVerifying = false; _paymentFailed = true; });
      _failureMessage = statusResult.message;
      await _rollback(user.uid, _walletUsed);
    } else {
      // ⏳ Still pending — let user choose to retry or cancel
      setState(() => _isVerifying = false);
      _showPendingOptions();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Auto-confirm booking after PhonePe confirms payment
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _autoConfirmBooking({
    required String uid,
    required String offerTitle,
    required double baseAmount,
    required bool hasVoucher,
    required String pgTxnId,
  }) async {
    try {
      final firestoreService = ref.read(firestoreServiceProvider);
      final slot = ref.read(selectedSlotProvider);

      // Update booking: pending_payment → confirmed + PG txn ID
      await firestoreService.autoConfirmBookingAfterPayment(
        bookingId: _bookingId!,
        slotId: slot?.id ?? '',
        uid: uid,
        pgTransactionId: pgTxnId,
        pointsToAward: (baseAmount * AppConstants.loyaltyPointsPerRupee).toInt(),
        offerTitle: offerTitle,
      );

      if (hasVoucher) {
        await firestoreService.redeemLoyaltyVoucher(uid);
      }

      setState(() {
        _isVerifying   = false;
        _isProcessing  = false;
        _paymentSuccess = true;
      });
      _successController.forward();
    } catch (e) {
      setState(() => _isVerifying = false);
      _showSnack('Booking confirmation error: $e', isError: true);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Rollback: cancel booking + free slot + refund wallet
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _rollback(String uid, double walletRefund) async {
    if (_bookingId == null) return;
    try {
      await ref.read(firestoreServiceProvider).cancelPendingBooking(
        bookingId: _bookingId!,
        slotId: ref.read(selectedSlotProvider)!.id,
        uid: uid,
        walletRefundAmount: walletRefund,
      );
    } catch (_) {}
    _bookingId = null;
  }

  void _showPendingOptions() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.hourglass_top_rounded, color: Color(0xFFFF9800)),
          const SizedBox(width: 10),
          Text('Payment Pending', style: AppTextStyles.sectionTitle),
        ]),
        content: Text(
          'Razorpay has not confirmed your payment yet.\n\n'
          'If you completed the payment, tap "Check Again". '
          'If you cancelled, tap "Cancel Booking".',
          style: AppTextStyles.body2.copyWith(color: AppColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _verifyPaymentStatus();
            },
            child: Text('Check Again',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.gold, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(authServiceProvider).currentUser;
              if (user != null) await _rollback(user.uid, _walletUsed);
              if (mounted) setState(() => _paymentFailed = false);
              _showSnack('Booking cancelled. Slot released.', isError: false);
            },
            child: Text('Cancel Booking',
                style: AppTextStyles.label.copyWith(color: AppColors.rose)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color: isError ? AppColors.rose : AppColors.sage,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: AppTextStyles.body2.copyWith(color: AppColors.ink))),
      ]),
      backgroundColor: AppColors.cardWhite,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: isError ? AppColors.roseBorder : AppColors.sageBorder),
      ),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final offer     = ref.watch(selectedOfferProvider);
    final trainer   = ref.watch(selectedTrainerProvider);
    final slot      = ref.watch(selectedSlotProvider);
    final userModel = ref.watch(userModelProvider).value;

    if (offer == null || trainer == null || slot == null) {
      return const Scaffold(
          backgroundColor: AppColors.bg,
          body: Center(child: Text('Missing booking details')));
    }

    final hasVoucher   = userModel?.hasLoyaltyVoucher ?? false;
    final walletBal    = userModel?.walletBalance ?? 0.0;
    final loyaltyPts   = userModel?.loyaltyPoints ?? 0;
    final baseAmount   = hasVoucher
        ? (offer.price - AppConstants.loyaltyVoucherValue).clamp(0.0, double.infinity)
        : offer.price;
    final walletUsed   = (_useWallet && walletBal > 0)
        ? (walletBal >= baseAmount ? baseAmount : walletBal)
        : 0.0;
    final finalAmount  = (baseAmount - walletUsed).clamp(0.0, double.infinity);
    final pointsToEarn = (baseAmount * AppConstants.loyaltyPointsPerRupee).toInt();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        Container(
          height: 200,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D0B08), Color(0xFF1C1208)],
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            // ── AppBar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
                Expanded(
                  child: Text('Order Summary',
                      style: AppTextStyles.display2
                          .copyWith(color: Colors.white),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(width: 40),
              ]),
            ),
            const SizedBox(height: 4),

            // ── Body ──
            Expanded(
              child: _isVerifying
                  ? _buildVerifyingView()
                  : _paymentSuccess
                      ? _buildSuccessView()
                      : _paymentFailed
                          ? _buildFailedView()
                          : _buildOrderSummary(
                              offer: offer,
                              trainer: trainer,
                              slot: slot,
                              userModel: userModel,
                              hasVoucher: hasVoucher,
                              walletBal: walletBal,
                              loyaltyPts: loyaltyPts,
                              baseAmount: baseAmount,
                              walletUsed: walletUsed,
                              finalAmount: finalAmount,
                              pointsToEarn: pointsToEarn,
                            ),
            ),

            // ── Pay Button ──
            if (!_paymentSuccess && !_isVerifying && !_paymentFailed)
              _buildPayButton(
                baseAmount: baseAmount,
                walletUsed: walletUsed,
                finalAmount: finalAmount,
                loyaltyPts: loyaltyPts,
                hasVoucher: hasVoucher,
              ),
          ]),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER SUMMARY
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOrderSummary({
    required offer,
    required trainer,
    required slot,
    required userModel,
    required bool hasVoucher,
    required double walletBal,
    required int loyaltyPts,
    required double baseAmount,
    required double walletUsed,
    required double finalAmount,
    required int pointsToEarn,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Service details ──
        _SectionLabel(label: 'SERVICE DETAILS'),
        const SizedBox(height: 8),
        _Card(child: Column(children: [
          Builder(builder: (ctx) {
            final selectedServices = ref.watch(selectedServicesProvider);
            if (selectedServices.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.layers_rounded, color: AppColors.gold, size: 16),
                    const SizedBox(width: 8),
                    Text('Services (${selectedServices.length})',
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.text3, fontWeight: FontWeight.w600)),
                  ]),
                  const SizedBox(height: 8),
                  ...selectedServices.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Text(s.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(s.name,
                              style: AppTextStyles.body2
                                  .copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text('₹${s.price.toInt()}',
                          style: AppTextStyles.label.copyWith(
                              color: AppColors.goldDeep,
                              fontWeight: FontWeight.w700)),
                    ]),
                  )),
                  _RowDivider(),
                ],
              );
            }
            return Column(children: [
              _DetailRow(
                  icon: Icons.spa_rounded,
                  label: 'Service',
                  value: offer.title,
                  iconColor: AppColors.gold),
              _RowDivider(),
            ]);
          }),
          _DetailRow(
              icon: Icons.person_rounded,
              label: 'Professional',
              value: trainer.name,
              iconColor: AppColors.gold),
          _RowDivider(),
          _DetailRow(
              icon: Icons.calendar_month_rounded,
              label: 'Date',
              value: DateFormat('EEE, d MMM yyyy').format(slot.startTime),
              iconColor: AppColors.gold),
          _RowDivider(),
          _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: DateFormat('hh:mm a').format(slot.startTime),
              iconColor: AppColors.gold),
        ])),

        const SizedBox(height: 16),

        // ── Loyalty voucher ──
        if (hasVoucher) ...[
          _SectionLabel(label: 'LOYALTY REWARD'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF0D0B08), Color(0xFF1C1208)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.2),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppColors.gold3, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('₹200 Loyalty Voucher Applied! 🎉',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.gold3)),
                    Text('Your reward discount is auto-applied',
                        style: AppTextStyles.caption.copyWith(
                            color:
                                AppColors.gold3.withValues(alpha: 0.7))),
                  ])),
              Text('-₹${AppConstants.loyaltyVoucherValue.toInt()}',
                  style: AppTextStyles.priceLarge
                      .copyWith(color: AppColors.gold3, fontSize: 18)),
            ]),
          ),
          const SizedBox(height: 16),
        ],

        // ── Price breakdown ──
        _SectionLabel(label: 'PAYMENT BREAKDOWN'),
        const SizedBox(height: 8),
        _Card(child: Column(children: [
          _PriceRow(
              label: 'Service Price',
              value: '₹${offer.price.toInt()}',
              valueColor: AppColors.text2),
          if (hasVoucher) ...[
            const SizedBox(height: 8),
            _PriceRow(
                label: 'Loyalty Discount',
                value: '-₹${AppConstants.loyaltyVoucherValue.toInt()}',
                valueColor: AppColors.sage),
          ],
          if (walletUsed > 0) ...[
            const SizedBox(height: 8),
            _PriceRow(
                label: 'Glamzo Wallet',
                value: '-₹${walletUsed.toInt()}',
                valueColor: AppColors.sage),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Total Due',
                style: AppTextStyles.body1
                    .copyWith(fontWeight: FontWeight.w700)),
            Text('₹${finalAmount.toInt()}',
                style: AppTextStyles.priceLarge.copyWith(fontSize: 24)),
          ]),
        ])),

        const SizedBox(height: 16),

        // ── Wallet toggle ──
        _SectionLabel(label: 'GLAMZO WALLET'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: walletBal > 0 ? AppColors.sageBg : AppColors.bg2,
            border: Border.all(
                color: walletBal > 0
                    ? AppColors.sageBorder
                    : AppColors.border),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: walletBal > 0
                    ? AppColors.sage.withValues(alpha: 0.15)
                    : AppColors.border,
                border: Border.all(
                    color: walletBal > 0
                        ? AppColors.sageBorder
                        : AppColors.border),
              ),
              child: Icon(Icons.account_balance_wallet_rounded,
                  color: walletBal > 0 ? AppColors.sage : AppColors.text4,
                  size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              Text('Wallet Balance: ₹${walletBal.toInt()}',
                  style: AppTextStyles.label.copyWith(
                      color: walletBal > 0
                          ? AppColors.sage
                          : AppColors.text3,
                      fontWeight: FontWeight.w700)),
              Text(
                walletBal > 0
                    ? _useWallet
                        ? 'Using ₹${walletUsed.toInt()} from wallet'
                        : 'Tap to use wallet for this booking'
                    : 'No wallet balance available',
                style: AppTextStyles.caption.copyWith(
                    color: walletBal > 0
                        ? AppColors.sage.withValues(alpha: 0.8)
                        : AppColors.text4),
              ),
            ])),
            if (walletBal > 0)
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _useWallet,
                  onChanged: (v) => setState(() => _useWallet = v),
                  activeThumbColor: AppColors.sage,
                  activeTrackColor: AppColors.sageBg,
                  inactiveThumbColor: AppColors.text4,
                  inactiveTrackColor: AppColors.border,
                ),
              ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Points to earn ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.goldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Row(children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColors.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(
                    "You'll earn $pointsToEarn loyalty points for this booking",
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.goldDeep))),
            Text('+$pointsToEarn pts',
                style: AppTextStyles.label.copyWith(
                    color: AppColors.goldDeep, fontWeight: FontWeight.w700)),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Payment methods supported ──
        _SectionLabel(label: 'ACCEPTED PAYMENT METHODS'),
        const SizedBox(height: 8),
        _Card(
          accentColor: AppColors.goldBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.goldBg2,
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: const Icon(Icons.payments_rounded,
                      color: AppColors.gold, size: 16),
                ),
                const SizedBox(width: 12),
                Text('Razorpay Secure Checkout',
                    style: AppTextStyles.cardTitle
                        .copyWith(color: AppColors.goldDeep)),
              ]),
              const SizedBox(height: 14),

              // Payment method grid
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PayMethodChip(label: 'PhonePe', emoji: '💜'),
                      _PayMethodChip(label: 'GPay', emoji: '🟢'),
                      _PayMethodChip(label: 'Paytm', emoji: '🔵'),
                      _PayMethodChip(label: 'BHIM', emoji: '🟠'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                      height: 1,
                      color: AppColors.border.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _PayMethodChip(label: 'Visa/MC', emoji: '💳'),
                      _PayMethodChip(label: 'RuPay', emoji: '🇮🇳'),
                      _PayMethodChip(label: 'NetBank', emoji: '🏦'),
                      _PayMethodChip(label: 'All UPI', emoji: '⚡'),
                    ],
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // Secure badge
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.sageBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.verified_user_rounded,
                      color: AppColors.sage, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Secured by Razorpay Payment Gateway. '
                    'Payment auto-confirmed — no manual steps needed.',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.sage),
                  )),
                ]),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PAY BUTTON BOTTOM BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPayButton({
    required double baseAmount,
    required double walletUsed,
    required double finalAmount,
    required int loyaltyPts,
    required bool hasVoucher,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (loyaltyPts > 0 && !hasVoucher)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColors.gold, size: 14),
              const SizedBox(width: 6),
              Text(
                  '$loyaltyPts pts — ${10000 - loyaltyPts} more to ₹200 voucher',
                  style: AppTextStyles.caption.copyWith(color: AppColors.text3)),
            ]),
          ),

        // Partial wallet breakdown
        if (_useWallet && walletUsed > 0 && finalAmount > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.sageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.sageBorder),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.sage, size: 14),
              const SizedBox(width: 6),
              Text(
                'Wallet: ₹${walletUsed.toInt()}  +  Razorpay: ₹${finalAmount.toInt()}',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.sage, fontWeight: FontWeight.w600),
              ),
            ]),
          ),

        // PhonePe secure badge strip
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF90CAF9)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('💳', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text('Secured by Razorpay Payment Gateway',
                style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.w600)),
          ]),
        ),

        // CTA
        _PrimaryButton(
          label: finalAmount <= 0
              ? 'Pay ₹${baseAmount.toInt()} via Wallet'
              : 'Pay ₹${finalAmount.toInt()} via Razorpay',
          icon: finalAmount <= 0
              ? Icons.account_balance_wallet_rounded
              : Icons.payments_rounded,
          isLoading: _isProcessing,
          isWallet: finalAmount <= 0,
          onPressed: _initiatePayment,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERIFYING VIEW (spinner while checking PhonePe status API)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVerifyingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              width: 96, height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF528FF0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.4),
                      blurRadius: 24),
                ],
              ),
              child: const Icon(Icons.payments_rounded,
                  color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 28),
          Text('Confirming Payment…',
              style: AppTextStyles.display2.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Verifying with Razorpay servers.\nThis takes just a few seconds.',
            style: AppTextStyles.body2.copyWith(color: AppColors.text3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          const SizedBox(
            width: 32, height: 32,
            child: CircularProgressIndicator(
                color: Color(0xFF1565C0), strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text('Do NOT close the app',
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.rose, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SUCCESS VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Center(
      child: ScaleTransition(
        scale: _successScale,
        child: FadeTransition(
          opacity: _successOpacity,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.sage.withValues(alpha: 0.5),
                        blurRadius: 28),
                  ],
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 28),
              Text('Booking Confirmed! 🎉',
                  style: AppTextStyles.display2.copyWith(color: AppColors.ink),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Payment verified by Razorpay.\nYour slot is now locked in.',
                style: AppTextStyles.body2.copyWith(color: AppColors.text3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.sageBorder),
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.verified_user_rounded,
                        color: AppColors.sage, size: 16),
                    const SizedBox(width: 6),
                    Text('Payment Auto-Confirmed by Razorpay',
                        style: const TextStyle(
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ]),
                  if (_razorpayTxnId.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Txn ID: ${_razorpayTxnId.length > 26 ? '${_razorpayTxnId.substring(0, 26)}…' : _razorpayTxnId}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.sage),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ]),
              ),
              if (_walletUsed > 0) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.sageBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.sageBorder),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.account_balance_wallet_rounded,
                        color: AppColors.sage, size: 14),
                    const SizedBox(width: 8),
                    Text(
                        '₹${_walletUsed.toInt()} paid via Glamzo Wallet',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.sage)),
                  ]),
                ),
              ],
              const SizedBox(height: 36),
              GestureDetector(
                onTap: () => context.go('/home/queue'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          blurRadius: 16),
                    ],
                  ),
                  child: Text('View My Booking',
                      style: AppTextStyles.btnLabel
                          .copyWith(color: Colors.black)),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => context.go('/home'),
                child: Text('Back to Home',
                    style: AppTextStyles.body2
                        .copyWith(color: AppColors.text3)),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FAILED VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFailedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 96, height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.rose.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.roseBorder, width: 2),
            ),
            child:
                const Icon(Icons.cancel_rounded, color: AppColors.rose, size: 52),
          ),
          const SizedBox(height: 28),
          Text('Payment Failed',
              style: AppTextStyles.display2.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            _failureMessage.isNotEmpty
                ? _failureMessage
                : 'Your payment could not be processed.',
            style: AppTextStyles.body2.copyWith(color: AppColors.text3),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFCC80)),
            ),
            child: Text(
              'Your slot has been released and any wallet balance refunded.',
              style: AppTextStyles.caption
                  .copyWith(color: const Color(0xFF7A3100)),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () => setState(() => _paymentFailed = false),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 16),
                ],
              ),
              child: Text('Try Again',
                  style:
                      AppTextStyles.btnLabel.copyWith(color: Colors.black)),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Text('Back to Home',
                style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PayMethodChip extends StatelessWidget {
  final String label;
  final String emoji;
  const _PayMethodChip({required this.label, required this.emoji});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.text2, fontSize: 10)),
      ]);
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});
  @override
  Widget build(BuildContext context) => Text(label,
      style: AppTextStyles.eyebrow
          .copyWith(color: AppColors.gold, letterSpacing: 2.5));
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  const _Card({required this.child, this.accentColor});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.cardWhite,
          border: Border.all(color: accentColor ?? AppColors.border2),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: child,
      );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  const _DetailRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.iconColor});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldBg,
              border: Border.all(
                  color: AppColors.goldBorder.withValues(alpha: 0.6)),
            ),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
          const Spacer(),
          Flexible(
              child: Text(value,
                  style:
                      AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ]),
      );
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _PriceRow(
      {required this.label, required this.value, required this.valueColor});
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: AppTextStyles.body2.copyWith(color: AppColors.text2)),
        Text(value,
            style: AppTextStyles.body1
                .copyWith(color: valueColor, fontWeight: FontWeight.w600)),
      ]);
}

class _RowDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 2),
      color: AppColors.border);
}

class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isLoading;
  final bool isWallet;
  final VoidCallback? onPressed;
  const _PrimaryButton(
      {required this.label,
      required this.icon,
      required this.isLoading,
      this.isWallet = false,
      this.onPressed});
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scale =
        Tween<double>(begin: 1.0, end: 0.97).animate(_ctrl);
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
                ? const LinearGradient(
                    colors: [Color(0xFFD9CEC0), Color(0xFFC8B9A5)])
                : widget.isWallet
                    ? const LinearGradient(
                        colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)
                    : const LinearGradient(
                        colors: [Color(0xFF7B1FA2), Color(0xFFAB47BC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                        color: (widget.isWallet
                                ? AppColors.sage
                                : const Color(0xFF7B1FA2))
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(widget.label, style: AppTextStyles.btnLabel),
                  ],
                ),
        ),
      ),
    );
  }
}
