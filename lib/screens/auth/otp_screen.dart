import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String verificationId;
  final String phone;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phone,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with TickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCountdown = 30;
  Timer? _resendTimer;

  // ── Animation controllers ──────────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _pulseCtrl;    // pulsing rings on icon
  late AnimationController _orbCtrl;      // floating orb
  late AnimationController _successCtrl;  // success celebration

  late Animation<double> _fadeAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _slideAnim;

  String get _otp => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _orbCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 5))
      ..repeat(reverse: true);
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);

    _startResendTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    _fadeCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    _orbCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  // ── Business logic (unchanged) ─────────────────────────────────────────────
  void _startResendTimer() {
    _resendCountdown = 30;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) t.cancel();
    });
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      _focusNodes[digits.length < 6 ? digits.length : 5].requestFocus();
      setState(() {});
      if (digits.length == 6) _verifyOTP();
      return;
    }
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
    if (_otp.length == 6) {
      Future.delayed(const Duration(milliseconds: 100), _verifyOTP);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOTP() async {
    if (_otp.length != 6 || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await ref.read(authServiceProvider).verifyPhoneOTP(
            widget.verificationId,
            _otp,
          );
      if (!mounted) return;
      if (result.isNewUser) {
        await _showNameSheet(result.credential.user!.uid);
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _shakeCtrl.forward(from: 0);
      for (final c in _controllers) { c.clear(); }
      _focusNodes[0].requestFocus();
      _showSnack('Invalid OTP. Please try again.', isError: true);
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCountdown > 0 || _isResending) return;
    setState(() => _isResending = true);
    try {
      await ref.read(authServiceProvider).sendPhoneOTP(
        phoneNumber: widget.phone,
        onVerificationCompleted: (_) {},
        onVerificationFailed: (e) {
          if (mounted) _showSnack(e.message ?? 'Failed to resend OTP', isError: true);
        },
        onCodeSent: (verificationId, _) {
          if (mounted) {
            _showSnack('OTP resent successfully!');
            _startResendTimer();
            context.pushReplacement('/otp', extra: {
              'verificationId': verificationId,
              'phone': widget.phone,
            });
          }
        },
        onCodeAutoRetrievalTimeout: (_) {},
      );
    } catch (_) {
      if (mounted) _showSnack('Failed to resend OTP. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isResending = false);
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
                  child: Text('Welcome to Glamzo',
                      style: AppTextStyles.display2.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: 6),
                Text('What should we call you?',
                    style: AppTextStyles.body2.copyWith(color: AppColors.text3)),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.05),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    keyboardType: TextInputType.name,
                    textCapitalization: TextCapitalization.words,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      hintText: 'e.g. Priya Sharma',
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3), fontSize: 15),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 10),
                        child: Icon(Icons.person_outline_rounded,
                            color: AppColors.gold.withValues(alpha: 0.5), size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please enter your name')),
                            );
                            return;
                          }
                          setBS(() => saving = true);
                          try {
                            await ref.read(authServiceProvider)
                                .saveUserName(uid: uid, name: name);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) context.go('/home');
                          } catch (_) {
                            setBS(() => saving = false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: saving
                          ? const LinearGradient(
                              colors: [Color(0xFF2A2015), Color(0xFF1A150A)])
                          : const LinearGradient(
                              colors: [Color(0xFFBF953F), Color(0xFFD4AF37), Color(0xFFAA8820)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: saving
                          ? []
                          : [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8))
                            ],
                    ),
                    alignment: Alignment.center,
                    child: saving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text("Let's Go  ✨",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
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
    final filledCount = _controllers.where((c) => c.text.isNotEmpty).length;

    return Scaffold(
      backgroundColor: const Color(0xFF080608),
      body: Stack(
        children: [
          // ── Background ──
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0C0908), Color(0xFF100D08), Color(0xFF0A0808)],
              ),
            ),
          ),

          // ── Background painter ──
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _OtpBgPainter(),
          ),

          // ── Top-right orb ──
          Positioned(
            top: -80,
            right: -80,
            child: AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, _orbCtrl.value * 25 - 12),
                child: Container(
                  width: 260, height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.gold.withValues(alpha: 0.15),
                      AppColors.gold.withValues(alpha: 0.04),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom-left orb ──
          Positioned(
            bottom: -60,
            left: -60,
            child: AnimatedBuilder(
              animation: _orbCtrl,
              builder: (_, __) => Transform.translate(
                offset: Offset(_orbCtrl.value * 15 - 7, 0),
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.gold.withValues(alpha: 0.10),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──
          SafeArea(
            child: AnimatedBuilder(
              animation: _fadeCtrl,
              builder: (_, child) => Opacity(
                opacity: _fadeAnim.value,
                child: Transform.translate(
                  offset: Offset(0, _slideAnim.value),
                  child: child,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Pulsing icon ──
                          _PulsingVerifyIcon(animation: _pulseAnim),

                          const SizedBox(height: 28),

                          // ── Title ──
                          ShaderMask(
                            shaderCallback: (b) => const LinearGradient(
                              colors: [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFAA8820)],
                            ).createShader(b),
                            child: Text(
                              'Verify OTP',
                              style: AppTextStyles.display1.copyWith(
                                fontSize: 44,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.05,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Container(
                                width: 20, height: 2,
                                decoration: BoxDecoration(
                                  gradient: AppColors.goldGradient,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.4),
                                        fontSize: 14),
                                    children: [
                                      const TextSpan(text: 'OTP sent to  '),
                                      TextSpan(
                                        text: widget.phone,
                                        style: TextStyle(
                                          color: AppColors.gold.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 48),

                          // ── OTP Boxes ──
                          AnimatedBuilder(
                            animation: _shakeAnim,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                _shakeAnim.value *
                                    10 *
                                    (1 - _shakeAnim.value) *
                                    ((_shakeCtrl.value * 10).round() % 2 == 0 ? 1 : -1),
                                0,
                              ),
                              child: child,
                            ),
                            child: Row(
                              children: List.generate(6, (i) {
                                final isFilled = _controllers[i].text.isNotEmpty;
                                final isFocused = _focusNodes[i].hasFocus;
                                return Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(right: i < 5 ? 10 : 0),
                                    height: 62,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: isFilled
                                          ? AppColors.gold.withValues(alpha: 0.12)
                                          : Colors.white.withValues(alpha: 0.04),
                                      border: Border.all(
                                        color: isFilled
                                            ? AppColors.gold
                                            : isFocused
                                                ? AppColors.gold.withValues(alpha: 0.5)
                                                : Colors.white.withValues(alpha: 0.10),
                                        width: isFilled || isFocused ? 1.5 : 1,
                                      ),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: AppColors.gold.withValues(alpha: 0.25),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : isFocused
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.gold.withValues(alpha: 0.10),
                                                    blurRadius: 10,
                                                  ),
                                                ]
                                              : [],
                                    ),
                                    child: KeyboardListener(
                                      focusNode: FocusNode(),
                                      onKeyEvent: (e) => _onKeyEvent(i, e),
                                      child: TextField(
                                        controller: _controllers[i],
                                        focusNode: _focusNodes[i],
                                        maxLength: 6,
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        style: TextStyle(
                                          color: isFilled
                                              ? AppColors.gold
                                              : Colors.white.withValues(alpha: 0.85),
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                        ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          counterText: '',
                                          contentPadding:
                                              EdgeInsets.symmetric(vertical: 18),
                                        ),
                                        onChanged: (v) => _onDigitChanged(i, v),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 14),

                          // ── Progress dots ──
                          Row(
                            children: List.generate(6, (i) {
                              final filled = i < filledCount;
                              return Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  height: 3,
                                  margin: EdgeInsets.only(right: i < 5 ? 10 : 0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(2),
                                    gradient: filled
                                        ? const LinearGradient(colors: [
                                            Color(0xFFBF953F),
                                            Color(0xFFD4AF37),
                                          ])
                                        : null,
                                    color: filled
                                        ? null
                                        : Colors.white.withValues(alpha: 0.08),
                                    boxShadow: filled
                                        ? [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(alpha: 0.3),
                                              blurRadius: 6,
                                            )
                                          ]
                                        : [],
                                  ),
                                ),
                              );
                            }),
                          ),

                          const SizedBox(height: 44),

                          // ── Verify button ──
                          _VerifyButton(
                            isLoading: _isLoading,
                            isEnabled: filledCount == 6,
                            onTap: _verifyOTP,
                          ),

                          const SizedBox(height: 32),

                          // ── Resend row ──
                          Center(
                            child: _resendCountdown > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 18, vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      color: Colors.white.withValues(alpha: 0.04),
                                      border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.08)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _CountdownArc(
                                          progress: _resendCountdown / 30,
                                          countdown: _resendCountdown,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Resend OTP in ${_resendCountdown}s',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.4),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : GestureDetector(
                                    onTap: _isResending ? null : _resendOTP,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: AppColors.gold.withValues(alpha: 0.08),
                                        border: Border.all(
                                            color: AppColors.gold.withValues(alpha: 0.25)),
                                      ),
                                      child: _isResending
                                          ? const SizedBox(
                                              width: 18, height: 18,
                                              child: CircularProgressIndicator(
                                                  color: AppColors.gold, strokeWidth: 2))
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.refresh_rounded,
                                                    color: AppColors.gold, size: 16),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Resend OTP',
                                                  style: TextStyle(
                                                    color: AppColors.gold,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 32),

                          // ── Footer ──
                          Center(
                            child: Text(
                              '🔒  Your number is safe and never shared',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.2),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing verify icon ───────────────────────────────────────────────────────
class _PulsingVerifyIcon extends StatelessWidget {
  final Animation<double> animation;
  const _PulsingVerifyIcon({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final pulse = math.sin(animation.value * math.pi * 2);
        return SizedBox(
          width: 90, height: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 90 + pulse * 10,
                height: 90 + pulse * 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.08 + pulse * 0.05),
                    width: 1,
                  ),
                ),
              ),
              // Mid ring
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.06 + pulse * 0.03),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.15 + pulse * 0.08),
                    width: 1,
                  ),
                ),
              ),
              // Core circle
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFBF953F), Color(0xFFD4AF37), Color(0xFFAA8820)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4 + pulse * 0.15),
                      blurRadius: 20 + pulse * 10,
                    ),
                  ],
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Countdown arc widget ──────────────────────────────────────────────────────
class _CountdownArc extends StatelessWidget {
  final double progress;
  final int countdown;
  const _CountdownArc({required this.progress, required this.countdown});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  const _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fg = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Animated Verify Button ────────────────────────────────────────────────────
class _VerifyButton extends StatefulWidget {
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onTap;
  const _VerifyButton({required this.isLoading, required this.isEnabled, required this.onTap});

  @override
  State<_VerifyButton> createState() => _VerifyButtonState();
}

class _VerifyButtonState extends State<_VerifyButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scale;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(_scale);
  }

  @override
  void dispose() { _scale.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled && !widget.isLoading;
    return GestureDetector(
      onTapDown: enabled ? (_) => _scale.forward() : null,
      onTapUp: enabled ? (_) => _scale.reverse() : null,
      onTapCancel: () => _scale.reverse(),
      onTap: enabled ? widget.onTap : null,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 60,
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFBF953F), Color(0xFFD4AF37), Color(0xFFAA8820)],
                  )
                : const LinearGradient(
                    colors: [Color(0xFF1A1408), Color(0xFF141008)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      color: AppColors.gold, strokeWidth: 2))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Verify & Continue',
                      style: TextStyle(
                        color: enabled ? Colors.black : Colors.white.withValues(alpha: 0.2),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    if (enabled) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.verified_rounded,
                          color: Colors.black, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

// ── OTP Background Painter ────────────────────────────────────────────────────
class _OtpBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Diagonal lines
    paint.color = const Color(0xFFD4AF37).withValues(alpha: 0.035);
    const spacing = 48.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }

    // Scattered gold particles
    final dot = Paint()..style = PaintingStyle.fill;
    final rand = math.Random(99);
    for (int i = 0; i < 35; i++) {
      final x = rand.nextDouble() * size.width;
      final y = rand.nextDouble() * size.height;
      final r = rand.nextDouble() * 1.5 + 0.4;
      dot.color = const Color(0xFFD4AF37)
          .withValues(alpha: rand.nextDouble() * 0.07 + 0.02);
      canvas.drawCircle(Offset(x, y), r, dot);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}