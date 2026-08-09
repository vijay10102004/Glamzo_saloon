import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/otp_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/home/search_screen.dart';
import '../../screens/booking/trainer_select_screen.dart';
import '../../screens/booking/trainer_select_all_screen.dart';
import '../../screens/booking/service_select_screen.dart';
import '../../screens/booking/book_now_service_select_screen.dart';
import '../../screens/booking/location_select_screen.dart';
import '../../screens/booking/slot_booking_screen.dart';
import '../../screens/booking/booking_confirm_screen.dart';
import '../../screens/queue/queue_screen.dart';
import '../../screens/queue/pay_pending_screen.dart';
import '../../screens/loyalty/loyalty_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/reviews/add_review_screen.dart';
import '../../models/booking_model.dart';
import '../../widgets/nav/bottom_nav.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),

      // OTP route — receives verificationId + phone via extra
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpScreen(
            verificationId: extra['verificationId'] as String,
            phone: extra['phone'] as String,
          );
        },
      ),

      ShellRoute(
        builder: (_, __, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
            routes: [
              // ── Search ──
              GoRoute(
                path: 'search',
                builder: (_, __) => const SearchScreen(),
              ),
              // ── Normal Booking Flow ──
              GoRoute(
                path: 'service-select',
                builder: (_, __) => const ServiceSelectScreen(),
              ),
              // ── Book Now Multi-Service Flow ──
              GoRoute(
                path: 'book-now',
                builder: (_, __) => const BookNowServiceSelectScreen(),
              ),
              GoRoute(
                path: 'trainer-select-all',
                builder: (_, __) => const TrainerSelectAllScreen(),
              ),
              // ── Premium Offer Flow ──
              GoRoute(
                path: 'trainer-select',
                builder: (_, __) => const TrainerSelectScreen(),
              ),
              GoRoute(
                path: 'location-select',
                builder: (_, __) => const LocationSelectScreen(),
              ),
              GoRoute(
                path: 'slot-booking',
                builder: (_, __) => const SlotBookingScreen(),
              ),
              GoRoute(
                path: 'booking-confirm',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return BookingConfirmScreen(extra: extra);
                },
              ),
              GoRoute(
                path: 'queue',
                builder: (_, __) => const QueueScreen(),
              ),
              GoRoute(
                path: 'notifications',
                builder: (_, __) => const NotificationsScreen(),
              ),
              GoRoute(
                path: 'profile',
                builder: (_, __) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'loyalty',
                builder: (_, __) => const LoyaltyScreen(),
              ),
              GoRoute(
                path: 'pay-pending',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>?;
                  return PayPendingScreen(extra: extra);
                },
              ),
              GoRoute(
                path: 'add-review',
                builder: (_, state) {
                  final booking = state.extra as BookingModel;
                  return AddReviewScreen(booking: booking);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
