import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _isLoading = false;
  bool _phoneFocused = false;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _masterFade;   // overall entrance
  late AnimationController _orb1Ctrl;     // top-right orb
  late AnimationController _orb2Ctrl;     // bottom-left orb
  late AnimationController _orb3Ctrl;     // centre-right orb
  late AnimationController _shimmerCtrl;  // brand text shimmer

  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _masterFade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _masterFade, curve: const Interval(0, 0.6));
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
        CurvedAnimation(parent: _masterFade, curve: Curves.easeOutCubic));

    _orb1Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat(reverse: true);
    _orb2Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 6))
      ..repeat(reverse: true);
    _orb3Ctrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();

    _phoneFocus.addListener(() {
      if (mounted) setState(() => _phoneFocused = _phoneFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _masterFade.dispose();
    _orb1Ctrl.dispose();
    _orb2Ctrl.dispose();
    _orb3Ctrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  // ── Business logic (unchanged) ─────────────────────────────────────────────
  bool _isValidPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    return RegExp(r'^(\+91)?[6-9]\d{9}$').hasMatch(cleaned);
  }

  String _formatPhoneForFirebase(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('+91')) return cleaned;
    return '+91$cleaned';
  }

  void _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnack('Please enter your mobile number.', isError: true);
      return;
    }
    if (!_isValidPhone(phone)) {
      _showSnack('Enter a valid 10-digit Indian mobile number.', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    final formatted = _formatPhoneForFirebase(phone);
    try {
      await ref.read(authServiceProvider).sendPhoneOTP(
        phoneNumber: formatted,
        onVerificationCompleted: (credential) async {
          try {
            final result =
                await ref.read(authServiceProvider).signInWithCredential(credential);
            if (!mounted) return;
            if (result.isNewUser) {
              await _showNameSheet(result.credential.user!.uid);
            } else {
              context.go('/home');
            }
          } catch (_) {}
        },
        onVerificationFailed: (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showSnack(_getFriendlyError(e.code), isError: true);
          }
        },
        onCodeSent: (verificationId, resendToken) {
          if (mounted) {
            setState(() => _isLoading = false);
            context.push('/otp', extra: {
              'verificationId': verificationId,
              'phone': formatted,
            });
          }
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Something went wrong. Please try again.', isError: true);
      }
    }
  }

  String _getFriendlyError(String? code) {
    switch (code) {
      case 'quota-exceeded':
        return '📵 Daily OTP limit reached. Please try again tomorrow or use a test number.';
      case 'invalid-phone-number':
        return '📱 Invalid phone number. Please enter a valid 10-digit Indian mobile number.';
      case 'missing-client-identifier':
      case 'missing-android-pkg-name':
      case 'app-not-authorized':
        return '⚠️ App not properly configured. Please contact support.';
      case 'too-many-requests':
        return '🚫 Too many attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return '🌐 No internet connection. Please check your network and try again.';
      case 'billing-not-enabled':
        return '💳 SMS service temporarily unavailable. Please use a registered test number.';
      case 'captcha-check-failed':
      case 'web-context-cancelled':
        return '🤖 Verification check failed. Please try again.';
      case 'session-expired':
        return '⏰ Session expired. Please request a new OTP.';
      default:
        return '❌ OTP failed: Real numbers require Firebase billing to be enabled. Use a test number for now.';
    }
  }

  Future<void> _showNameSheet(String uid) async {
    final nameCtrl = TextEditingController();
    bool saving = false;
    await showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1412), Color(0xFF0F0D0A)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: AppColors.goldBorder),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.goldBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.gold.withValues(alpha: 0.4), blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.waving_hand_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (b) => AppColors.goldShimmer.createShader(b),
                  child: Text('Welcome to Glamzo', style: AppTextStyles.display2.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: 6),
                Text(
                  'What should we call you?',
                  style: AppTextStyles.body2.copyWith(color: AppColors.text3),
                ),
                const SizedBox(height: 24),
                _LuxuryInput(
                  controller: nameCtrl,
                  hint: 'Your full name',
                  icon: Icons.person_outline_rounded,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                _GoldButton(
                  label: "Let's Go",
                  isLoading: saving,
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Please enter your name')),
                      );
                      return;
                    }
                    setBS(() => saving = true);
                    try {
                      await ref.read(authServiceProvider).saveUserName(uid: uid, name: name);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) context.go('/home');
                    } catch (_) {
                      setBS(() => saving = false);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: isError ? AppColors.rose : AppColors.sage,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: AppTextStyles.body2.copyWith(color: AppColors.ink))),
          ],
        ),
        backgroundColor: AppColors.bg3,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isError ? AppColors.roseBorder : AppColors.sageBorder),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080608),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Rich dark background ──
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0C0908),
                  Color(0xFF100D08),
                  Color(0xFF0A0808),
                ],
              ),
            ),
          ),

          // ── Background painter (diagonal lines + particles) ──
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _LuxuryBgPainter(),
          ),

          // ── Animated orb 1 — top right ──
          Positioned(
            top: -100,
            right: -60,
            child: AnimatedBuilder(
              animation: _orb1Ctrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _orb1Ctrl.value * 30 - 15),
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.gold.withValues(alpha: 0.18),
                      AppColors.gold.withValues(alpha: 0.05),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Animated orb 2 — bottom left ──
          Positioned(
            bottom: -80,
            left: -80,
            child: AnimatedBuilder(
              animation: _orb2Ctrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(_orb2Ctrl.value * 20 - 10, 0),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.gold.withValues(alpha: 0.12),
                      AppColors.gold.withValues(alpha: 0.03),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Animated orb 3 — mid screen ──
          Positioned(
            top: size.height * 0.35,
            right: -120,
            child: AnimatedBuilder(
              animation: _orb3Ctrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _orb3Ctrl.value * 40 - 20),
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFD4AF37).withValues(alpha: 0.10),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: AnimatedBuilder(
              animation: _masterFade,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 56),

                    // ── Brand name ──
                    AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) => ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: const [
                            Color(0xFFBF953F),
                            Color(0xFFFCF6BA),
                            Color(0xFFB38728),
                            Color(0xFFFBF5B7),
                            Color(0xFFAA771C),
                          ],
                          stops: [
                            0.0,
                            (_shimmerCtrl.value - 0.3).clamp(0.0, 1.0),
                            _shimmerCtrl.value.clamp(0.0, 1.0),
                            (_shimmerCtrl.value + 0.3).clamp(0.0, 1.0),
                            1.0,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          'GLAMZO',
                          style: AppTextStyles.eyebrow.copyWith(
                            color: Colors.white,
                            fontSize: 36,
                            letterSpacing: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'BOOK · STYLE · GLOW',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        letterSpacing: 4,
                        fontSize: 10,
                      ),
                    ),

                    const SizedBox(height: 56),

                    // ── Headline ──
                    Text(
                      'Welcome\nBack',
                      style: AppTextStyles.display1.copyWith(
                        fontSize: 46,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Your luxury salon experience awaits',
                          style: AppTextStyles.body2.copyWith(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // ── Service pills ──
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          'Haircut', 'Facial', 'Head Spa', 'Waxing', 'Keratin',
                        ].map((s) => _ServicePill(label: s)).toList(),
                      ),
                    ),

                    const SizedBox(height: 44),

                    // ── Phone label ──
                    Text(
                      'MOBILE NUMBER',
                      style: AppTextStyles.eyebrow.copyWith(
                        color: AppColors.gold.withValues(alpha: 0.6),
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Animated phone input ──
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: _phoneFocused
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.10),
                          width: _phoneFocused ? 1.5 : 1,
                        ),
                        boxShadow: _phoneFocused
                            ? [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          // Country code badge
                          Container(
                            margin: const EdgeInsets.only(left: 14),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.15),
                                  AppColors.gold.withValues(alpha: 0.08),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '🇮🇳  +91',
                              style: AppTextStyles.label.copyWith(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Input field
                          Expanded(
                            child: TextField(
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 17,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w500,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 20),
                                hintText: '98765 43210',
                                hintStyle: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  fontSize: 17,
                                  letterSpacing: 2,
                                ),
                              ),
                              onSubmitted: (_) => _sendOTP(),
                            ),
                          ),
                          // Mic icon
                          Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Icon(
                              Icons.phone_iphone_rounded,
                              color: _phoneFocused
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.2),
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.lock_outline_rounded,
                            size: 12,
                            color: Colors.white.withValues(alpha: 0.25)),
                        const SizedBox(width: 6),
                        Text(
                          'We\'ll send a 6-digit OTP to verify your number',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 36),

                    // ── Gold CTA ──
                    _GoldButton(
                      label: 'Send OTP',
                      isLoading: _isLoading,
                      onPressed: _sendOTP,
                    ),

                    const SizedBox(height: 44),

                    // ── Divider ──
                    Row(
                      children: [
                        Expanded(child: _GoldLine()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '✦  SECURED LOGIN  ✦',
                            style: AppTextStyles.eyebrow.copyWith(
                              letterSpacing: 2,
                              color: AppColors.gold.withValues(alpha: 0.35),
                              fontSize: 8,
                            ),
                          ),
                        ),
                        Expanded(child: _GoldLine()),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // ── Trust badges ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _TrustBadge(icon: Icons.verified_user_outlined, label: 'OTP Verified'),
                        SizedBox(width: 28),
                        _TrustBadge(icon: Icons.lock_outline_rounded, label: 'Encrypted'),
                        SizedBox(width: 28),
                        _TrustBadge(icon: Icons.shield_outlined, label: 'Safe & Secure'),
                      ],
                    ),

                    const SizedBox(height: 36),

                    Center(
                      child: Text(
                        'By continuing, you agree to our Terms & Privacy Policy',
                        style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.2)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Service pill ──────────────────────────────────────────────────────────────
class _ServicePill extends StatelessWidget {
  final String label;
  const _ServicePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.gold.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.gold.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Trust Badge ───────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.gold.withValues(alpha: 0.08),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: AppColors.gold.withValues(alpha: 0.6), size: 17),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

// ── Luxury Input ──────────────────────────────────────────────────────────────
class _LuxuryInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  const _LuxuryInput({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(icon, color: AppColors.gold.withValues(alpha: 0.5), size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
      ),
    );
  }
}

// ── Gold CTA Button ───────────────────────────────────────────────────────────
class _GoldButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoldButton({required this.label, required this.isLoading, this.onPressed});

  @override
  State<_GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<_GoldButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(_press);
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: widget.isLoading
                ? const LinearGradient(colors: [Color(0xFF2A2015), Color(0xFF1A150A)])
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFBF953F),
                      Color(0xFFD4AF37),
                      Color(0xFFAA8820),
                    ],
                  ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded,
                        color: Colors.black, size: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Gold Line ─────────────────────────────────────────────────────────────────
class _GoldLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.gold.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ── Luxury Background Painter ─────────────────────────────────────────────────
class _LuxuryBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Diagonal lines
    paint.color = const Color(0xFFD4AF37).withValues(alpha: 0.04);
    const spacing = 48.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }

    // Fine horizontal lines
    paint.color = const Color(0xFFD4AF37).withValues(alpha: 0.02);
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Gold scatter dots
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final rand = math.Random(42);
    for (int i = 0; i < 40; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5 + 0.5;
      final opacity = rand.nextDouble() * 0.08 + 0.02;
      dotPaint.color = Color(0xFFD4AF37).withValues(alpha: opacity);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
