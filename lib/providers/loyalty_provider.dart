import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/loyalty_model.dart';
import '../models/user_model.dart';
import 'auth_provider.dart';
import 'offers_provider.dart';

/// Stream of current user's UserModel (includes loyaltyPoints + hasLoyaltyVoucher)
final userModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getUserStream(uid);
});

/// Stream of loyalty transaction history
final loyaltyHistoryProvider = StreamProvider<List<LoyaltyTransaction>>((ref) {
  final authState = ref.watch(authStateProvider);
  final uid = authState.value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(firestoreServiceProvider).getLoyaltyHistory(uid);
});
