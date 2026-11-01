import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UPI Payment Service
//
// ⚠️  SECURITY WARNING:
//     UPI deep-links are inherently unverifiable on the client side.
//     The OS returns true/false for whether the UPI app OPENED —
//     it does NOT return whether the payment SUCCEEDED.
//
//     To confirm a UPI payment you MUST:
//       1. Ask the user to share their UTR (transaction reference) number, OR
//       2. Use a payment gateway (e.g. Razorpay) that wraps UPI and provides
//          a server-side status API + webhook with HMAC signature verification.
//
//     This service is only used as a fallback / supplemental UPI launcher.
//     Primary payment flow uses RazorpayService with webhook confirmation.
// ─────────────────────────────────────────────────────────────────────────────
class UpiService {
  /// Opens a UPI payment intent on the user's device.
  ///
  /// Returns [UpiLaunchResult] indicating whether the UPI app was launched.
  /// ⚠️  A successful launch does NOT mean payment succeeded. Always verify
  ///     payment status via server-side webhook or UTR number confirmation.
  static Future<UpiLaunchResult> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    required String transactionNote,
    String? transactionRefId,
  }) async {
    // ── Input validation ──────────────────────────────────────────────────
    if (upiId.isEmpty || !upiId.contains('@')) {
      return UpiLaunchResult(
        launched: false,
        message: 'Invalid UPI ID format.',
      );
    }
    if (amount <= 0 || amount > 100000) {
      return UpiLaunchResult(
        launched: false,
        message: 'Invalid payment amount.',
      );
    }
    if (payeeName.trim().isEmpty) {
      return UpiLaunchResult(
        launched: false,
        message: 'Payee name is required.',
      );
    }

    // Sanitize inputs — prevent UPI deep-link injection
    final safePayeeName = payeeName.trim().replaceAll(RegExp(r'[&=?#]'), '');
    final safeNote = transactionNote.trim().replaceAll(RegExp(r'[&=?#]'), '');
    final amountStr = amount.toStringAsFixed(2);
    final ref = transactionRefId?.isNotEmpty == true
        ? transactionRefId!
        : DateTime.now().millisecondsSinceEpoch.toString();

    // Standard UPI deep-link URI (works on Android; iOS opens web fallback)
    final upiUri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': upiId,
        'pn': safePayeeName,
        'am': amountStr,
        'cu': 'INR',
        'tn': safeNote,
        'tr': ref,
      },
    );

    try {
      if (await canLaunchUrl(upiUri)) {
        final launched = await launchUrl(
          upiUri,
          mode: LaunchMode.externalApplication,
        );
        return UpiLaunchResult(
          launched: launched,
          message: launched
              ? 'UPI app opened. Complete payment there.'
              : 'Failed to open UPI app.',
        );
      }
    } catch (e) {
      debugPrint('❌ UPI launch error: $e');
    }

    // Fallback: open Razorpay (which supports UPI) instead of Google Pay web
    // since the web GPay page doesn't process payments directly.
    debugPrint('⚠️ No UPI app found. Falling back to Razorpay checkout.');
    return UpiLaunchResult(
      launched: false,
      message: 'No UPI app found on this device. Please use Razorpay checkout.',
    );
  }
}

class UpiLaunchResult {
  final bool launched;
  final String message;
  const UpiLaunchResult({required this.launched, required this.message});
}
