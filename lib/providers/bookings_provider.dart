import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/booking_model.dart';
import 'auth_provider.dart';
import 'offers_provider.dart';

/// All bookings (backward compat)
final userBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserBookings(uid);
});

/// Confirmed (upcoming) bookings
final confirmedBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserConfirmedBookings(uid);
});

/// Completed bookings (History tab — merged with cancelled)
final completedBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserCompletedBookings(uid);
});

/// Pending payment bookings (Pending tab)
final pendingBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserPendingBookings(uid);
});

/// Cancelled bookings (Cancelled tab)
final cancelledBookingsProvider = StreamProvider<List<BookingModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserCancelledBookings(uid);
});

final latestBookingProvider = StateProvider<BookingModel?>((ref) => null);

/// Published reviews stream — for home screen carousel
final publishedReviewsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(firestoreServiceProvider).getPublishedReviews();
});
