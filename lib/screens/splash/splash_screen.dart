import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {

  void _navigate(AsyncValue<User?> state) {
    if (!state.isLoading) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (mounted) {
          if (state.value != null) {
            context.go('/home');
          } else {
            context.go('/login');
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    ref.listen(authStateProvider, (previous, next) => _navigate(next));
    _navigate(authState);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/splash_bg.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}