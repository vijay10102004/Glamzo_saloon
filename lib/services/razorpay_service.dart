import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Razorpay Payment Gateway Service
//
// Flow:
//  1. initiatePayment() → Opens Razorpay hosted checkout URL in browser
//  2. User pays with ANY method (GPay / UPI / Cards / NetBanking)
//  3. Razorpay redirects browser to glamzo://payment/callback (deep link)
//  4. App resumes via AppLifecycleState.resumed → checkStatusWithRetry()
//  5. ⚠️  IMPORTANT: Final payment verification MUST be done server-side
//     via Firebase Cloud Function + Razorpay webhook signature check.
//     The client-side status check here is a UX convenience only — the
//     Cloud Function is the authoritative payment confirmation source.
//
// Security Notes:
//  • Key ID is safe to expose in the client (read-only, no charge capability)
//  • Key Secret is NEVER in the app — always server-side only
//  • Payment confirmation is authoritative via Razorpay webhook → Cloud Fn
//  • Client-side status check is for UX feedback only, NOT for booking confirm
// ─────────────────────────────────────────────────────────────────────────────

class RazorpayService {
  static const String _apiBase          = 'https://api.razorpay.com/v1';
  static const String _paymentsEndpoint = '/payments';

  // Maximum retries for status check to avoid infinite loops
  static const int _maxStatusRetries = 5;

  /// No-op init — kept for API compatibility
  static Future<void> init() async {
    debugPrint('✅ Razorpay PG ready [${AppConstants.razorpayEnvironment}]');
    // Validate that Key ID is set and not a placeholder
    if (AppConstants.razorpayKeyId.contains('XXXX')) {
      debugPrint('⚠️  WARNING: Razorpay Key ID is a placeholder. '
          'Replace it in AppConstants before release.');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Initiate Payment via Razorpay hosted checkout
  //
  // Creates a Razorpay checkout URL and opens it in the browser.
  // Returns [RazorpayResult] with success=true if checkout opened.
  //
  // ⚠️  Security: Do NOT trust the client-side return value of this function
  //     as payment confirmation. Use checkStatusWithRetry() for UX feedback
  //     and rely on the Razorpay webhook → Cloud Function for final truth.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RazorpayResult> initiatePayment({
    required double amount,
    required String merchantTransactionId,
    required String userId,
    required String mobileNumber,
    String? customerName,
    String? customerEmail,
    String? description,
  }) async {
    // ── Input validation ────────────────────────────────────────────────────
    if (amount <= 0) {
      return RazorpayResult(
        success: false,
        transactionId: merchantTransactionId,
        message: 'Invalid payment amount.',
        status: 'INVALID_AMOUNT',
      );
    }

    if (merchantTransactionId.isEmpty) {
      return RazorpayResult(
        success: false,
        transactionId: '',
        message: 'Transaction ID is required.',
        status: 'INVALID_TXN_ID',
      );
    }

    try {
      final amountInPaise = (amount * 100).round(); // Use round() not toInt() to avoid floating-point errors
      final sanitisedPhone = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');

      // Validate sanitised phone (10 digits for India)
      final validPhone = sanitisedPhone.length >= 10 ? sanitisedPhone : '';

      debugPrint('💳 Razorpay PG: Initiating payment ₹$amount');
      debugPrint('🔑 Txn Ref: $merchantTransactionId');

      // ── Build Razorpay hosted checkout URL ────────────────────────────────
      // Parameters:
      //   key         → Key ID (safe to expose — cannot create charges alone)
      //   amount      → in paise (smallest INR unit)
      //   currency    → INR
      //   name        → business name shown on checkout
      //   description → booking description
      //   prefill     → pre-fills customer details (UX improvement only)
      //   callback_url→ deep link back to app after payment
      //   redirect    → true = browser redirect flow (no native SDK needed)
      // ─────────────────────────────────────────────────────────────────────
      final checkoutParams = <String, String>{
        'key':          AppConstants.razorpayKeyId,
        'amount':       amountInPaise.toString(),
        'currency':     'INR',
        'name':         AppConstants.razorpayBusinessName,
        'description':  description ?? 'Glamzo Salon Booking',
        'order_id':     merchantTransactionId,
        'theme[color]': AppConstants.razorpayThemeColor,
        'callback_url': AppConstants.razorpayCallbackUrl,
        'redirect':     'true',
      };

      if (validPhone.isNotEmpty) {
        checkoutParams['prefill[contact]'] = validPhone;
      }
      if (customerName != null && customerName.trim().isNotEmpty) {
        checkoutParams['prefill[name]'] = customerName.trim();
      }
      if (customerEmail != null && customerEmail.trim().isNotEmpty
          && customerEmail.contains('@')) {
        checkoutParams['prefill[email]'] = customerEmail.trim();
      }

      final uri = Uri.https(
        'api.razorpay.com',
        '/v1/checkout/embedded',
        checkoutParams,
      );

      debugPrint('🌐 Opening Razorpay checkout');

      bool opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        try {
          opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (e) {
          debugPrint('❌ Failed to launch URL: $e');
        }
      }

      if (!opened) {
        return RazorpayResult(
          success: false,
          transactionId: merchantTransactionId,
          message: 'Could not open Razorpay checkout. Check your internet connection.',
          status: 'LAUNCH_FAILED',
        );
      }

      return RazorpayResult(
        success: true,
        transactionId: merchantTransactionId,
        message: 'Razorpay checkout opened.',
        status: 'INITIATED',
      );
    } on Exception catch (e) {
      debugPrint('❌ Razorpay error: $e');
      return RazorpayResult(
        success: false,
        transactionId: merchantTransactionId,
        message: 'Payment initiation failed. Please try again.',
        // Do not expose internal error messages to the UI in production
        status: 'ERROR',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Check Payment Status (UX convenience only)
  //
  // ⚠️  IMPORTANT SECURITY NOTE:
  //     This is a CLIENT-SIDE check using only the Key ID (no secret).
  //     It is used ONLY to show the user feedback (spinner, success/fail UI).
  //     The authoritative payment verification is:
  //       Razorpay Webhook → Firebase Cloud Function → verify HMAC signature
  //       → update Firestore booking status
  //     Never confirm a booking solely based on this client-side result.
  //
  // Queries Razorpay's payments API by order reference.
  // Returns:
  //   RazorpayPaymentStatus.success  → show success UI (booking confirmed by webhook)
  //   RazorpayPaymentStatus.pending  → wait / retry
  //   RazorpayPaymentStatus.failed   → show fail UI (booking cancelled by webhook)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RazorpayStatusResult> checkPaymentStatus({
    required String merchantTransactionId,
  }) async {
    if (merchantTransactionId.isEmpty) {
      return RazorpayStatusResult(
        status:  RazorpayPaymentStatus.pending,
        code:    'INVALID_ID',
        message: 'Transaction ID is missing.',
      );
    }

    try {
      debugPrint('🔍 Checking Razorpay payment status: $merchantTransactionId');

      final uri = Uri.parse(
        '$_apiBase$_paymentsEndpoint?count=1&description=$merchantTransactionId',
      );

      // Note: Without the Key Secret, this endpoint may return limited data.
      // Full verification requires server-side Basic auth with Key ID + Secret.
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // Key ID only — Key Secret never goes in the app
          'Authorization': 'Basic ${base64Encode(utf8.encode('${AppConstants.razorpayKeyId}:'))}',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('{"error":"timeout"}', 408),
      );

      if (response.statusCode == 408) {
        return RazorpayStatusResult(
          status:  RazorpayPaymentStatus.pending,
          code:    'TIMEOUT',
          message: 'Payment status check timed out. Please wait…',
        );
      }

      if (response.statusCode != 200) {
        debugPrint('⚠️ Razorpay API returned ${response.statusCode}');
        return RazorpayStatusResult(
          status:  RazorpayPaymentStatus.pending,
          code:    'API_ERROR',
          message: 'Waiting for payment confirmation…',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      final items = responseData['items'] as List<dynamic>? ?? [];
      if (items.isNotEmpty) {
        final payment  = items.first as Map<String, dynamic>;
        final status   = payment['status'] as String? ?? '';
        final payId    = payment['id']     as String? ?? '';
        return _mapStatus(status, payId);
      }

      // No payment found yet — treat as pending
      return RazorpayStatusResult(
        status:  RazorpayPaymentStatus.pending,
        code:    'PENDING',
        message: 'Waiting for payment confirmation…',
      );
    } on Exception catch (e) {
      debugPrint('❌ Razorpay status check error: $e');
      return RazorpayStatusResult(
        status:  RazorpayPaymentStatus.pending,
        code:    'ERROR',
        message: 'Could not verify payment status. Retrying…',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Retry status check with exponential back-off
  // maxRetries is capped at _maxStatusRetries to prevent infinite loops.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RazorpayStatusResult> checkStatusWithRetry({
    required String merchantTransactionId,
    int maxRetries = 4,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    // Safety cap to prevent DoS-ing Razorpay's API
    final effectiveRetries = maxRetries.clamp(1, _maxStatusRetries);
    Duration delay = initialDelay;

    for (int i = 0; i < effectiveRetries; i++) {
      final result = await checkPaymentStatus(
          merchantTransactionId: merchantTransactionId);
      if (result.status != RazorpayPaymentStatus.pending) return result;
      if (i < effectiveRetries - 1) {
        debugPrint(
            '⏳ Payment pending, retrying in ${delay.inSeconds}s (attempt ${i + 1}/$effectiveRetries)');
        await Future.delayed(delay);
        delay = delay * 2; // Exponential back-off
      }
    }
    // Last check
    return checkPaymentStatus(merchantTransactionId: merchantTransactionId);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static RazorpayStatusResult _mapStatus(String status, String paymentId) {
    switch (status) {
      case 'captured':
        return RazorpayStatusResult(
          status:        RazorpayPaymentStatus.success,
          code:          'PAYMENT_SUCCESS',
          message:       'Payment successful!',
          transactionId: paymentId,
        );
      case 'authorized':
        // Authorized but not yet captured — treat as success for auto-capture
        return RazorpayStatusResult(
          status:        RazorpayPaymentStatus.success,
          code:          'PAYMENT_AUTHORIZED',
          message:       'Payment authorised!',
          transactionId: paymentId,
        );
      case 'created':
      case 'attempted':
        return RazorpayStatusResult(
          status:  RazorpayPaymentStatus.pending,
          code:    'PAYMENT_PENDING',
          message: 'Payment is being processed…',
        );
      case 'failed':
        return RazorpayStatusResult(
          status:  RazorpayPaymentStatus.failed,
          code:    'PAYMENT_FAILED',
          message: 'Payment was declined. Please try a different method.',
        );
      default:
        return RazorpayStatusResult(
          status:  RazorpayPaymentStatus.pending,
          code:    'UNKNOWN',  // Don't expose raw status strings
          message: 'Waiting for payment confirmation…',
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────

class RazorpayResult {
  final bool   success;
  final String transactionId;
  final String message;
  final String status;

  const RazorpayResult({
    required this.success,
    required this.transactionId,
    required this.message,
    this.status = '',
  });
}

enum RazorpayPaymentStatus { success, pending, failed }

class RazorpayStatusResult {
  final RazorpayPaymentStatus status;
  final String  code;
  final String  message;
  final String? transactionId;

  const RazorpayStatusResult({
    required this.status,
    required this.code,
    required this.message,
    this.transactionId,
  });

  bool get isSuccess => status == RazorpayPaymentStatus.success;
  bool get isPending  => status == RazorpayPaymentStatus.pending;
  bool get isFailed   => status == RazorpayPaymentStatus.failed;
}
