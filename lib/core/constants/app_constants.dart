class AppConstants {
  AppConstants._();

  static const String appName    = 'Glamzo';
  static const String appTagline = 'BOOK. STYLE. GLOW.';

  // ── Contact ──
  static const String whatsappUrl  = 'https://wa.me/91XXXXXXXXXX';
  static const String salonAddress = '123 Style Street, Mumbai 400001';
  static const String salonPhone   = '+91 98765 43210';

  // ─────────────────────────────────────────────────────────────────────────
  // Razorpay Payment Gateway Credentials
  //
  // 🔴 HOW TO GET REAL CREDENTIALS:
  //    1. Sign up at https://dashboard.razorpay.com
  //    2. Complete KYC & business verification (PAN, bank, address proof)
  //    3. Go to Settings → API Keys
  //    4. Click "Generate Test Key" (sandbox) or "Generate Live Key" (after KYC)
  //    5. Copy the Key ID (starts with rzp_test_... or rzp_live_...)
  //    6. Replace razorpayKeyId below — Key Secret is NOT needed in the app
  //
  // ✅ WHAT PAYMENT METHODS IT SUPPORTS (Razorpay checkout page):
  //    • Google Pay (GPay)
  //    • PhonePe UPI
  //    • Paytm UPI / Wallet
  //    • BHIM & all UPI apps
  //    • Credit / Debit Cards (Visa, Mastercard, RuPay, Amex)
  //    • Net Banking (all major banks)
  //    • Razorpay Wallet
  //
  // ⚠️  Currently set to TEST mode.
  //      Change razorpayEnvironment to 'LIVE' and update Key ID
  //      once your KYC is approved in the Razorpay dashboard.
  // ─────────────────────────────────────────────────────────────────────────
  static const String razorpayEnvironment  = 'TEST';                        // 'TEST' or 'LIVE'
  static const String razorpayKeyId        = 'rzp_test_XXXXXXXXXXXXXXXX';  // ← Replace with your Key ID
  static const String razorpayBusinessName = 'Glamzo Salon';
  static const String razorpayThemeColor   = '#C9A96E';                    // Gold brand color

  // Redirect URL after Razorpay payment completes (browser closes and returns to app)
  // Uses a custom deep-link scheme. Register 'glamzo' scheme in AndroidManifest.xml
  // and iOS Info.plist URL Schemes so the OS can route it back to this app.
  static const String razorpayCallbackUrl  = 'glamzo://payment/callback';

  // Webhook URL — where Razorpay sends server-to-server payment notification
  // Set this in Razorpay Dashboard → Webhooks
  // Example: 'https://us-central1-glamzo.cloudfunctions.net/razorpayWebhook'
  static const String razorpayWebhookUrl   = 'https://glamzo.in/api/razorpay/webhook';

  // ── Merchant details (shown on Razorpay checkout page) ───────────────────
  static const String merchantName = 'Glamzo Salon';

  // ── Payment Status Codes ──────────────────────────────────────────────────
  static const String statusPendingPayment      = 'pending_payment';
  static const String statusConfirmed           = 'confirmed';
  static const String statusCancelled           = 'cancelled';
  static const String statusCompleted           = 'completed';

  // Minutes a reserved slot is held before auto-expiry
  static const int slotReservationMinutes = 15;

  // ── ImgBB ──────────────────────────────────────────────────────────────────
  // ⚠️  SECURITY: Move this key to a Firebase Remote Config or a server-side
  // Cloud Function. Never ship a third-party API key in a release binary.
  // For now, store in a .env file and inject via --dart-define at build time:
  //   flutter build apk --dart-define=IMGBB_API_KEY=your_key_here
  static const String imgBbApiKey    = String.fromEnvironment('IMGBB_API_KEY', defaultValue: '');
  static const String imgBbUploadUrl = 'https://api.imgbb.com/1/upload';

  // ── Loyalty System ─────────────────────────────────────────────────────────
  /// ₹1 spent = 1 point
  static const int loyaltyPointsPerRupee = 1;
  /// Points required to earn ₹200 discount voucher
  static const int loyaltyRedemptionThreshold = 10000;
  /// Discount value of the voucher in INR
  static const double loyaltyVoucherValue = 200.0;
}
