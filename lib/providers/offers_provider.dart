import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service.dart';
import '../models/offer_model.dart';
import '../models/service_model.dart';

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// All active offers (used in booking flow)
final offersProvider = StreamProvider<List<OfferModel>>((ref) {
  return ref.read(firestoreServiceProvider).getActiveOffers();
});

/// Only live premium offers for the home carousel
final premiumOffersProvider = StreamProvider<List<OfferModel>>((ref) {
  return ref.read(firestoreServiceProvider).getLivePremiumOffers();
});

final selectedOfferProvider = StateProvider<OfferModel?>((ref) => null);

/// Active salon services for the home screen services carousel
final servicesProvider = StreamProvider<List<ServiceModel>>((ref) {
  return ref.read(firestoreServiceProvider).getActiveServices();
});

/// Multi-service selection for the Book Now flow
final selectedServicesProvider =
    StateProvider<List<ServiceModel>>((ref) => []);

/// True while the user is inside any booking sub-flow.
/// Drives the hide/show of the Home hero Book Now button so there
/// is never more than one active Book Now CTA visible at once.
final bookingActiveProvider = StateProvider<bool>((ref) => false);

/// Selected branch location: 'Anna Nagar' | 'Kaalavasal' | null
final selectedLocationProvider = StateProvider<String?>((ref) => null);
