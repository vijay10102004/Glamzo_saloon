import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Razorpay Payment Gateway Service
//
// Flow:
//  1. initiatePayment() → POST /v1/payment_links → get short_url
//  2. Open short_url in browser (Razorpay checkout: GPay / UPI / Cards / NetBanking)
//  3. User pays with ANY method
//  4. App resumes → checkPaymentStatus() → paid / failed / pending
//  5. Auto-confirm or cancel booking — ZERO admin involvement
//
// Checkout supports: GPay · PhonePe UPI · Paytm · BHIM · All UPI ·
//                    Credit/Debit Cards (Visa, MC, RuPay, Amex) · NetBanking
//
// NOTE: Only the Key ID is used here (client-safe).
//       Key Secret is used server-side only (never in the app).
// ─────────────────────────────────────────────────────────────────────────────

class RazorpayService {
  // ── API Base URL ──────────────────────────────────────────────────────────
  static const String _apiBase = 'https://api.razorpay.com/v1';

  // ── Endpoints ─────────────────────────────────────────────────────────────
  static const String _paymentsEndpoint = '/payments';

  /// No-op init — kept for API compatibility
  static Future<void> init() async {
    debugPrint('✅ Razorpay PG ready [${AppConstants.razorpayEnvironment}]');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1 — Initiate Payment via Razorpay Payment Links
  //
  // Creates a Razorpay Payment Link and opens it in the browser.
  // The checkout page allows: GPay · UPI · Paytm · Cards · NetBanking
  // Returns [RazorpayResult] with success=true if checkout opened.
  //
  // ⚠️  In TEST mode, Payment Links API requires a Key Secret on the server.
  //     For a pure client-side flow (no backend), we fall back to the
  //     Razorpay hosted checkout redirect URL with prefilled params.
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
    try {
      final amountInPaise = (amount * 100).toInt();
      final sanitisedPhone = mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');

      debugPrint('💳 Razorpay PG: Initiating payment ₹$amount');
      debugPrint('🔑 Txn Ref: $merchantTransactionId');

      // ── Build Razorpay hosted checkout URL ────────────────────────────────
      // This URL opens Razorpay's universal payment page which supports
      // UPI (GPay, PhonePe, Paytm, BHIM) + Cards + NetBanking.
      //
      // Parameters:
      //   key         → your Key ID (safe to expose in client)
      //   amount      → in paise
      //   currency    → INR
      //   name        → business name shown on checkout
      //   description → booking description
      //   prefill     → pre-fills customer details
      //   callback_url→ where Razorpay redirects after payment
      //   redirect    → true = browser redirect flow (works without SDK)
      // ─────────────────────────────────────────────────────────────────────
      final checkoutParams = {
        'key':          AppConstants.razorpayKeyId,
        'amount':       amountInPaise.toString(),
        'currency':     'INR',
        'name':         AppConstants.razorpayBusinessName,
        'description':  description ?? 'Glamzo Salon Booking',
        'order_id':     merchantTransactionId,
        'prefill[contact]': sanitisedPhone.isNotEmpty ? sanitisedPhone : '',
        if (customerName  != null) 'prefill[name]' : customerName,
        if (customerEmail != null) 'prefill[email]': customerEmail,
        'theme[color]': AppConstants.razorpayThemeColor,
        'callback_url': AppConstants.razorpayCallbackUrl,
        'redirect':     'true',
      };

      // Build the hosted checkout URL
      final uri = Uri.https(
        'api.razorpay.com',
        '/v1/checkout/embedded',
        checkoutParams,
      );

      debugPrint('🌐 Opening Razorpay checkout: $uri');

      bool opened = false;
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
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
        message: 'Payment initiation failed: ${e.toString()}',
        status: 'ERROR',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2 — Check Payment Status (called after user returns to app)
  //
  // Queries Razorpay's payments API by order reference.
  // Returns:
  //   RazorpayPaymentStatus.success  → auto-confirm booking
  //   RazorpayPaymentStatus.pending  → wait / retry
  //   RazorpayPaymentStatus.failed   → cancel booking
  //
  // NOTE: Full status verification via signature requires Key Secret on
  // a backend server. This client-side check queries the public payments
  // endpoint with the Key ID. For production, move this to Firebase Functions.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RazorpayStatusResult> checkPaymentStatus({
    required String merchantTransactionId,
  }) async {
    try {
      debugPrint('🔍 Checking Razorpay payment status: $merchantTransactionId');

      // Query Razorpay payments filtered by our order reference
      final uri = Uri.parse(
        '$_apiBase$_paymentsEndpoint?count=1&description=$merchantTransactionId',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // Basic auth: Key ID as username, empty password (no secret in app)
          'Authorization': 'Basic ${base64Encode(utf8.encode('${AppConstants.razorpayKeyId}:'))}',
        },
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('📩 Razorpay Status Response: $responseData');

      if (response.statusCode == 200) {
        final items = responseData['items'] as List<dynamic>? ?? [];
        if (items.isNotEmpty) {
          final payment  = items.first as Map<String, dynamic>;
          final status   = payment['status'] as String? ?? '';
          final payId    = payment['id']     as String? ?? '';
          return _mapStatus(status, payId);
        }
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
  // Useful after app resumes — Razorpay may not update instantly.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<RazorpayStatusResult> checkStatusWithRetry({
    required String merchantTransactionId,
    int maxRetries = 4,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    Duration delay = initialDelay;
    for (int i = 0; i < maxRetries; i++) {
      final result = await checkPaymentStatus(
          merchantTransactionId: merchantTransactionId);
      if (result.status != RazorpayPaymentStatus.pending) return result;
      if (i < maxRetries - 1) {
        debugPrint(
            '⏳ Payment pending, retrying in ${delay.inSeconds}s (attempt ${i + 1}/$maxRetries)');
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
          code:    status,
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
