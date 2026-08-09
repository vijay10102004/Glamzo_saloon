import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'services/razorpay_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Performance: disable Google Fonts HTTP fetching (use bundled/cached fonts) ──
  GoogleFonts.config.allowRuntimeFetching = false;

  // ── Lock to portrait mode to reduce unnecessary layout calculations ──
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Initialize Razorpay PG service
  await RazorpayService.init();
  runApp(const ProviderScope(child: GlamzoApp()));
}

class GlamzoApp extends ConsumerWidget {
  const GlamzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Glamzo',
      theme: AppTheme.dark,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}