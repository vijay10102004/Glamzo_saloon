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
  // For production: use a deep-link like 'glamzo://payment/callback'
  static const String razorpayCallbackUrl  = 'https://glamzo.in/payment/callback';

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
  static const String imgBbApiKey    = '6903f3bf70feb32c2581845e01f765fc';
  static const String imgBbUploadUrl = 'https://api.imgbb.com/1/upload';

  // ── Loyalty System ─────────────────────────────────────────────────────────
  /// ₹1 spent = 1 point
  static const int loyaltyPointsPerRupee = 1;
  /// Points required to earn ₹200 discount voucher
  static const int loyaltyRedemptionThreshold = 10000;
  /// Discount value of the voucher in INR
  static const double loyaltyVoucherValue = 200.0;
}
