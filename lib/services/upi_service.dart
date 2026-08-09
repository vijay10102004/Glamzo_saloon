import 'package:url_launcher/url_launcher.dart';

class UpiService {
  /// Opens a UPI payment intent on the user's device.
  /// Returns true if the UPI app was launched successfully.
  static Future<bool> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    required String transactionNote,
    String? transactionRefId,
  }) async {
    final amountStr = amount.toStringAsFixed(2);
    final ref = transactionRefId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // Standard UPI deep-link URI (works on Android; iOS opens web fallback)
    final upiUri = Uri.parse(
      'upi://pay?pa=$upiId'
      '&pn=${Uri.encodeComponent(payeeName)}'
      '&am=$amountStr'
      '&cu=INR'
      '&tn=${Uri.encodeComponent(transactionNote)}'
      '&tr=${Uri.encodeComponent(ref)}',
    );

    if (await canLaunchUrl(upiUri)) {
      await launchUrl(upiUri, mode: LaunchMode.externalApplication);
      return true;
    }

    // Fallback: open Google Pay web intent
    final gpayUri = Uri.parse(
      'https://pay.google.com/intl/en_in/about/',
    );
    await launchUrl(gpayUri, mode: LaunchMode.externalApplication);
    return false;
  }
}
