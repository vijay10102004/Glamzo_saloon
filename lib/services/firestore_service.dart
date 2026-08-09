import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/offer_model.dart';
import '../models/service_model.dart';
import '../models/trainer_model.dart';
import '../models/slot_model.dart';
import '../models/booking_model.dart';
import '../models/loyalty_model.dart';
import '../models/user_model.dart';
import '../core/constants/app_constants.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ─────────────────── OFFERS ───────────────────

  /// Stream of all active offers (for general booking flow)
  Stream<List<OfferModel>> getActiveOffers() {
    return _db
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => OfferModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// Stream of all active offers for the home carousel
  Stream<List<OfferModel>> getLivePremiumOffers() {
    return _db
        .collection('offers')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => OfferModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ─────────────────── SERVICES ───────────────────

  /// Real-time stream of all active salon services for home carousel
  /// Sorts by sortOrder client-side to avoid requiring a composite Firestore index.
  Stream<List<ServiceModel>> getActiveServices() {
    return _db
        .collection('services')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => ServiceModel.fromMap(d.id, d.data()))
              .toList();
          list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          return list;
        });
  }

  /// Add a new service
  Future<void> addService(Map<String, dynamic> data) async {
    await _db.collection('services').add(data);
  }

  /// Update an existing service by ID
  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _db.collection('services').doc(id).update(data);
  }

  /// Delete a service by ID
  Future<void> deleteService(String id) async {
    await _db.collection('services').doc(id).delete();
  }

  /// Toggle a service active/inactive
  Future<void> toggleService(String id, bool isActive) async {
    await _db.collection('services').doc(id).update({'isActive': isActive});
  }

  // ─────────────────── TRAINERS ───────────────────

  Future<List<TrainerModel>> getTrainersForOffer(List<String> ids) async {
    if (ids.isEmpty) return [];
    final futures = ids.map((id) => _db.collection('trainers').doc(id).get());
    final docs = await Future.wait(futures);
    return docs
        .where((d) => d.exists)
        .map((d) => TrainerModel.fromMap(d.id, d.data()!))
        .toList();
  }

  Future<List<TrainerModel>> getAllTrainers() async {
    final snap = await _db.collection('trainers').get();
    return snap.docs
        .map((d) => TrainerModel.fromMap(d.id, d.data()))
        .toList();
  }

  /// Real-time stream of all trainers for the stylist catalogue
  Stream<List<TrainerModel>> getAllTrainersStream() {
    return _db
        .collection('trainers')
        .snapshots()
        .map((s) => s.docs
            .map((d) => TrainerModel.fromMap(d.id, d.data()))
            .toList());
  }

  // ─────────────────── SLOTS ───────────────────

  Future<SlotModel?> getNextAvailableSlot(String trainerId) async {
    final snap = await _db
        .collection('slots')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'available')
        .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('startTime')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return SlotModel.fromMap(snap.docs.first.id, snap.docs.first.data());
  }

  /// Stream of ALL slots for a given trainer + date (available AND booked).
  /// When [branch] is non-empty, only slots belonging to that branch are returned,
  /// giving each location its own independent slot pool.
  Stream<List<SlotModel>> getAllSlots(String trainerId, DateTime date, {String branch = ''}) {
    final start = DateTime(date.year, date.month, date.day, 0, 0);
    final end   = DateTime(date.year, date.month, date.day, 23, 59);

    Query q = _db
        .collection('slots')
        .where('trainerId', isEqualTo: trainerId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end));

    if (branch.isNotEmpty) {
      q = q.where('branch', isEqualTo: branch);
    }

    return (q.orderBy('startTime') as Query)
        .snapshots()
        .map((s) => s.docs.map((d) => SlotModel.fromMap(d.id, d.data() as Map<String, dynamic>)).toList());
  }

  // ─────────────────── BOOKINGS ───────────────────

  /// Creates booking with status='pending_payment' and slot as 'reserved'.
  /// Use this BEFORE launching the UPI app to hold the slot.
  /// Call [claimPaymentWithUtr] when user returns from UPI app.
  /// Call [cancelPendingBooking] if user cancels.
  Future<String> createPendingBooking(BookingModel booking) async {
    final slotRef = _db.collection('slots').doc(booking.slotId);
    late DocumentReference bookingRef;

    await _db.runTransaction((transaction) async {
      final slotSnap = await transaction.get(slotRef);
      if (!slotSnap.exists) throw Exception('Slot not found');

      final currentStatus = slotSnap.data()!['status'] as String? ?? '';
      if (currentStatus != 'available') {
        throw Exception('Slot is no longer available. Please pick another time.');
      }

      // Create booking as pending_payment
      bookingRef = _db.collection('bookings').doc();
      transaction.set(bookingRef, {
        ...booking.toMap(),
        'status': 'pending_payment',
        'slotReservedAt': Timestamp.fromDate(DateTime.now()),
      });

      // Reserve slot — prevents double-booking but doesn't confirm yet
      transaction.update(slotRef, {
        'status': 'reserved',
        'bookingId': bookingRef.id,
        'reservedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    return bookingRef.id;
  }

  /// Creates booking atomically — prevents double-booking the same slot.
  /// Throws an exception if the slot is already taken.
  /// ⚠️  Legacy method — prefer [createPendingBooking] for new flows.
  Future<String> createBookingAtomic(BookingModel booking) async {
    final slotRef = _db.collection('slots').doc(booking.slotId);
    late DocumentReference bookingRef;

    await _db.runTransaction((transaction) async {
      final slotSnap = await transaction.get(slotRef);
      if (!slotSnap.exists) throw Exception('Slot not found');

      final currentStatus = slotSnap.data()!['status'] as String? ?? '';
      if (currentStatus != 'available') {
        throw Exception('Slot is no longer available. Please pick another time.');
      }

      // Create booking doc
      bookingRef = _db.collection('bookings').doc();
      transaction.set(bookingRef, booking.toMap());

      // Mark slot as booked
      transaction.update(slotRef, {
        'status': 'booked',
        'bookingId': bookingRef.id,
      });
    });

    return bookingRef.id;
  }

  /// Called automatically by the app after PhonePe PG status API
  /// returns PAYMENT_SUCCESS — no admin intervention required.
  ///
  /// Atomically:
  ///   • booking status → 'confirmed' + PG transaction ID
  ///   • slot status   → 'booked'
  ///   • loyalty points awarded to customer
  Future<void> autoConfirmBookingAfterPayment({
    required String bookingId,
    required String slotId,
    required String uid,
    required String pgTransactionId,
    required int pointsToAward,
    required String offerTitle,
  }) async {
    final slotRef    = _db.collection('slots').doc(slotId);
    final bookingRef = _db.collection('bookings').doc(bookingId);
    final userRef    = _db.collection('users').doc(uid);
    final now        = Timestamp.fromDate(DateTime.now());

    await _db.runTransaction((transaction) async {
      final userSnap   = await transaction.get(userRef);
      final currentPts = (userSnap.data()?['loyaltyPoints'] ?? 0) as int;
      final hasVoucher = userSnap.data()?['hasLoyaltyVoucher'] ?? false;
      final newTotal   = currentPts + pointsToAward;

      // ── Confirm booking ────────────────────────────────────────────────
      transaction.update(bookingRef, {
        'status': 'confirmed',
        'phonePeTransactionId': pgTransactionId,
        'paymentConfirmedAt': now,
        'paymentConfirmedBy': 'phonepe_gateway',  // auto-confirmed
        'loyaltyPointsEarned': pointsToAward,
      });

      // ── Mark slot booked ───────────────────────────────────────────────
      if (slotId.isNotEmpty) {
        transaction.update(slotRef, {'status': 'booked'});
      }

      // ── Award loyalty points ───────────────────────────────────────────
      if (pointsToAward > 0) {
        final ptUpdate = <String, dynamic>{'loyaltyPoints': newTotal};
        if (newTotal >= AppConstants.loyaltyRedemptionThreshold &&
            !(hasVoucher as bool)) {
          ptUpdate['hasLoyaltyVoucher'] = true;
        }
        transaction.update(userRef, ptUpdate);

        final txnRef = _db.collection('loyalty_transactions').doc();
        transaction.set(txnRef, {
          'id': txnRef.id,
          'userId': uid,
          'points': pointsToAward,
          'type': 'earned',
          'description': 'Earned for booking: $offerTitle (PhonePe PG)',
          'bookingId': bookingId,
          'createdAt': now,
        });
      }
    });
  }

  /// [Legacy] Customer UTR claim — kept for backward compatibility.
  /// New flow uses [autoConfirmBookingAfterPayment] via PhonePe status API.
  Future<void> claimPaymentWithUtr({
    required String bookingId,
    required String utrNumber,
    required String merchantTransactionId,
  }) async {
    await _db.collection('bookings').doc(bookingId).update({
      'status': 'pending_verification',
      'paymentClaimed': true,
      'utrNumber': utrNumber.trim(),
      'phonePeTransactionId': merchantTransactionId,
      'paymentClaimedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Admin verifies money received in PhonePe/bank dashboard and confirms booking.
  /// Atomically:
  ///   • booking status → 'confirmed'
  ///   • slot status   → 'booked'
  ///   • loyalty points awarded
  Future<void> confirmBookingPayment({
    required String bookingId,
    required String slotId,
    required String adminId,
    required String uid,
    required int pointsToAward,
    required String offerTitle,
  }) async {
    final slotRef    = _db.collection('slots').doc(slotId);
    final bookingRef = _db.collection('bookings').doc(bookingId);
    final userRef    = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      final userSnap    = await transaction.get(userRef);
      final currentPts  = (userSnap.data()?['loyaltyPoints'] ?? 0) as int;
      final hasVoucher  = userSnap.data()?['hasLoyaltyVoucher'] ?? false;
      final newTotal    = currentPts + pointsToAward;

      // Confirm booking
      transaction.update(bookingRef, {
        'status': 'confirmed',
        'adminConfirmedAt': Timestamp.fromDate(DateTime.now()),
        'adminConfirmedBy': adminId,
        'loyaltyPointsEarned': pointsToAward,
      });

      // Mark slot booked
      transaction.update(slotRef, {'status': 'booked'});

      // Award loyalty points
      if (pointsToAward > 0) {
        final ptUpdate = <String, dynamic>{'loyaltyPoints': newTotal};
        if (newTotal >= AppConstants.loyaltyRedemptionThreshold && !(hasVoucher as bool)) {
          ptUpdate['hasLoyaltyVoucher'] = true;
        }
        transaction.update(userRef, ptUpdate);

        final txnRef = _db.collection('loyalty_transactions').doc();
        transaction.set(txnRef, {
          'id': txnRef.id,
          'userId': uid,
          'points': pointsToAward,
          'type': 'earned',
          'description': 'Earned for booking: $offerTitle',
          'bookingId': bookingId,
          'createdAt': Timestamp.fromDate(DateTime.now()),
        });
      }
    });
  }

  /// Cancels a pending booking and frees the reserved slot.
  /// Also refunds wallet if [walletRefundAmount] > 0.
  Future<void> cancelPendingBooking({
    required String bookingId,
    required String slotId,
    required String uid,
    double walletRefundAmount = 0,
  }) async {
    final slotRef    = _db.collection('slots').doc(slotId);
    final bookingRef = _db.collection('bookings').doc(bookingId);
    final userRef    = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      // Cancel booking
      transaction.update(bookingRef, {
        'status': 'cancelled',
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
      });

      // Free slot
      transaction.update(slotRef, {
        'status': 'available',
        'bookingId': '',
        'reservedAt': FieldValue.delete(),
      });

      // Refund wallet if applicable
      if (walletRefundAmount > 0) {
        final userSnap = await transaction.get(userRef);
        final current  = (userSnap.data()?['walletBalance'] ?? 0).toDouble();
        transaction.update(userRef, {'walletBalance': current + walletRefundAmount});
        final txnRef = userRef.collection('transactions').doc();
        transaction.set(txnRef, {
          'type': 'credit',
          'amount': walletRefundAmount,
          'reason': 'Refund: Booking cancelled',
          'timestamp': Timestamp.fromDate(DateTime.now()),
        });
      }
    });
  }

  Future<void> updateBookingStatus(
    String bookingId,
    String status, {
    String phonePeTransactionId = '',
    int loyaltyPointsEarned = 0,
    bool loyaltyVoucherApplied = false,
  }) async {
    final update = <String, dynamic>{'status': status};
    if (phonePeTransactionId.isNotEmpty) {
      update['phonePeTransactionId'] = phonePeTransactionId;
    }
    if (loyaltyPointsEarned > 0) {
      update['loyaltyPointsEarned'] = loyaltyPointsEarned;
    }
    if (loyaltyVoucherApplied) {
      update['loyaltyVoucherApplied'] = true;
    }
    await _db.collection('bookings').doc(bookingId).update(update);
  }

  Future<void> updateSlotStatus(String slotId, String status, String bookingId) async {
    await _db.collection('slots').doc(slotId).update({
      'status': status,
      'bookingId': bookingId,
    });
  }

  /// All user bookings stream (for backward compat)
  Stream<List<BookingModel>> getUserBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Confirmed bookings only (Confirmed tab — upcoming)
  Stream<List<BookingModel>> getUserConfirmedBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'confirmed')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Completed bookings (for History tab)
  Stream<List<BookingModel>> getUserCompletedBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Pending payment OR pending verification bookings (Pending tab)
  Stream<List<BookingModel>> getUserPendingBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: ['pending_payment', 'pending_verification'])
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Cancelled bookings (Cancelled tab)
  Stream<List<BookingModel>> getUserCancelledBookings(String uid) {
    return _db
        .collection('bookings')
        .where('userId', isEqualTo: uid)
        .where('status', isEqualTo: 'cancelled')
        .snapshots()
        .map((s) {
          final list = s.docs.map((d) => BookingModel.fromMap(d.id, d.data())).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // ─────────────────── LOYALTY ───────────────────

  /// Awards loyalty points and records the transaction atomically.
  /// Also checks if user has hit the redemption threshold.
  Future<bool> awardLoyaltyPoints({
    required String uid,
    required int points,
    required String bookingId,
    required String serviceName,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    bool voucherUnlocked = false;

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final currentPoints = (userSnap.data()?['loyaltyPoints'] ?? 0) as int;
      final hasVoucher = userSnap.data()?['hasLoyaltyVoucher'] ?? false;
      final newTotal = currentPoints + points;

      final update = <String, dynamic>{'loyaltyPoints': newTotal};

      // Auto-generate voucher when threshold is hit (and not already holding one)
      if (newTotal >= AppConstants.loyaltyRedemptionThreshold && !(hasVoucher as bool)) {
        update['hasLoyaltyVoucher'] = true;
        voucherUnlocked = true;
      }

      transaction.update(userRef, update);

      // Record in loyalty_transactions subcollection
      final txnRef = _db.collection('loyalty_transactions').doc();
      transaction.set(txnRef, LoyaltyTransaction(
        id: txnRef.id,
        userId: uid,
        points: points,
        type: 'earned',
        description: 'Earned for booking: $serviceName',
        bookingId: bookingId,
        createdAt: DateTime.now(),
      ).toMap());
    });

    return voucherUnlocked;
  }

  /// Redeems the loyalty voucher — deducts threshold points, clears the voucher flag,
  /// and credits the voucher value (₹200) directly to the user's wallet balance.
  /// Works even if [hasLoyaltyVoucher] flag is out-of-sync, as long as
  /// the user's points are >= [AppConstants.loyaltyRedemptionThreshold].
  Future<void> redeemLoyaltyVoucher(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final currentPoints = (userSnap.data()?['loyaltyPoints'] ?? 0) as int;
      final hasVoucher = userSnap.data()?['hasLoyaltyVoucher'] ?? false;
      final currentWallet = (userSnap.data()?['walletBalance'] ?? 0).toDouble();

      // Allow redemption when flag is set OR when points already meet the threshold
      // (handles the case where the flag got out of sync with actual points)
      final canRedeem = (hasVoucher as bool) ||
          currentPoints >= AppConstants.loyaltyRedemptionThreshold;

      if (!canRedeem) throw Exception('No voucher available');
      if (currentPoints < AppConstants.loyaltyRedemptionThreshold) {
        throw Exception('Insufficient points');
      }

      // Deduct points, clear voucher, and credit wallet
      transaction.update(userRef, {
        'loyaltyPoints': currentPoints - AppConstants.loyaltyRedemptionThreshold,
        'hasLoyaltyVoucher': false,
        'walletBalance': currentWallet + AppConstants.loyaltyVoucherValue,
      });

      // Record loyalty redemption
      final txnRef = _db.collection('loyalty_transactions').doc();
      transaction.set(txnRef, LoyaltyTransaction(
        id: txnRef.id,
        userId: uid,
        points: -AppConstants.loyaltyRedemptionThreshold,
        type: 'redeemed',
        description: 'Redeemed for ₹${AppConstants.loyaltyVoucherValue.toInt()} wallet credit',
        createdAt: DateTime.now(),
      ).toMap());

      // Record wallet credit transaction
      final walletTxnRef = userRef.collection('transactions').doc();
      transaction.set(walletTxnRef, {
        'type': 'credit',
        'amount': AppConstants.loyaltyVoucherValue,
        'reason': 'Loyalty Voucher Redeemed 🏆',
        'timestamp': DateTime.now(),
      });
    });
  }

  /// Claims the one-time ₹100 welcome offer for new users.
  /// Guarded by `oneTimeOfferClaimed` flag — safe to call once.
  Future<void> claimOneTimeOffer({required String uid}) async {
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    // Guard: only credit if not already claimed
    if (userSnap.data()?['oneTimeOfferClaimed'] == true) {
      throw Exception('One-time offer already claimed');
    }

    await _db.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final currentBalance = (snap.data()?['walletBalance'] ?? 0).toDouble();
      txn.update(userRef, {
        'walletBalance': currentBalance + 100.0,
        'oneTimeOfferClaimed': true,
      });
      // Record wallet transaction
      final txnRef = userRef.collection('transactions').doc();
      txn.set(txnRef, {
        'type': 'credit',
        'amount': 100.0,
        'reason': 'One-Time Welcome Offer 🎁',
        'timestamp': DateTime.now(),
      });
    });
  }

  /// Deducts [amount] from user's wallet balance atomically.
  /// Throws if balance is insufficient.
  Future<void> deductWalletBalance({
    required String uid,
    required double amount,
    required String reason,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final currentBalance = (snap.data()?['walletBalance'] ?? 0).toDouble();
      if (currentBalance < amount) {
        throw Exception('Insufficient wallet balance');
      }
      txn.update(userRef, {'walletBalance': currentBalance - amount});
      final txnRef = userRef.collection('transactions').doc();
      txn.set(txnRef, {
        'type': 'debit',
        'amount': amount,
        'reason': reason,
        'timestamp': DateTime.now(),
      });
    });
  }

  Stream<UserModel?> getUserStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromMap(snap.data()!);
    });
  }

  Stream<List<LoyaltyTransaction>> getLoyaltyHistory(String uid) {
    return _db
        .collection('loyalty_transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs
            .map((d) => LoyaltyTransaction.fromMap(d.id, d.data()))
            .toList());
  }

  // ─────────────────── NOTIFICATIONS ───────────────────

  Stream<List<Map<String, dynamic>>> getUserNotifications(String uid) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  Future<void> markNotificationRead(String notifId) async {
    await _db.collection('notifications').doc(notifId).update({'isRead': true});
  }

  // ─────────────────── SEED DATABASE ───────────────────

  Future<void> seedDatabase() async {
    final trainersRef = _db.collection('trainers');
    final offersRef   = _db.collection('offers');
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(days: 5));

    // ── Trainers ──
    await trainersRef.doc('emma_watson').set({
      'name': 'Emma Watson',
      'specialties': ['Hair Styling', 'Colour', 'Balayage'],
      'rating': 4.9,
      'totalReviews': 234,
      'photoUrl': 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=200&fit=crop&q=80',
      'isAvailable': true,
    });
    await trainersRef.doc('david_beckham').set({
      'name': 'David Beckham',
      'specialties': ['Beard Sculpting', "Men's Cut", 'Shave'],
      'rating': 4.8,
      'totalReviews': 189,
      'photoUrl': 'https://images.unsplash.com/photo-1503951914875-452162b0f3f1?w=200&fit=crop&q=80',
      'isAvailable': true,
    });
    await trainersRef.doc('sophia_loren').set({
      'name': 'Sophia Loren',
      'specialties': ['Facial', 'Spa', 'Skincare'],
      'rating': 4.7,
      'totalReviews': 156,
      'photoUrl': 'https://images.unsplash.com/photo-1512290923902-8a9f81dc236c?w=200&fit=crop&q=80',
      'isAvailable': true,
    });
    await trainersRef.doc('arjun_mehta').set({
      'name': 'Arjun Mehta',
      'specialties': ['Keratin', 'Smoothening', 'Hair Spa'],
      'rating': 4.8,
      'totalReviews': 142,
      'photoUrl': 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=200&fit=crop&q=80',
      'isAvailable': true,
    });
    await trainersRef.doc('priya_sharma').set({
      'name': 'Priya Sharma',
      'specialties': ['Head Spa', 'Ayurvedic', 'Scalp Treatment'],
      'rating': 4.9,
      'totalReviews': 198,
      'photoUrl': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&fit=crop&q=80',
      'isAvailable': true,
    });

    // ── Offers / Services ──
    await offersRef.doc('premium_haircut').set({
      'title': 'Premium Haircut & Style',
      'description': 'Expert cut, wash, and blow-dry by our master stylists.',
      'price': 399.0,
      'originalPrice': 699.0,
      'imageUrl': 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=800&fit=crop&q=80',
      'trainerIds': ['emma_watson', 'david_beckham'],
      'isActive': true,
      'isPremium': true,
      'serviceCategory': 'Haircut',
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await offersRef.doc('luxury_facial').set({
      'title': 'Luxury Facial & Glow',
      'description': '60-min hydra-facial with premium serum infusion for radiant skin.',
      'price': 1199.0,
      'originalPrice': 2499.0,
      'imageUrl': 'https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=800&fit=crop&q=80',
      'trainerIds': ['sophia_loren'],
      'isActive': true,
      'isPremium': true,
      'serviceCategory': 'Facial',
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await offersRef.doc('hair_color').set({
      'title': 'Hair Color & Highlights',
      'description': 'Full colour, balayage, or highlights by our colour experts.',
      'price': 1999.0,
      'originalPrice': 3499.0,
      'imageUrl': 'https://images.unsplash.com/photo-1560869713-7d0a29430803?w=800&fit=crop&q=80',
      'trainerIds': ['emma_watson'],
      'isActive': true,
      'isPremium': true,
      'serviceCategory': 'Hair Color',
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await offersRef.doc('keratin_treatment').set({
      'title': 'Keratin Smoothening',
      'description': 'Brazilian keratin treatment for frizz-free silky hair for 3 months.',
      'price': 2499.0,
      'originalPrice': 4999.0,
      'imageUrl': 'https://images.unsplash.com/photo-1626015365107-8a88e9b6e4b3?w=800&fit=crop&q=80',
      'trainerIds': ['arjun_mehta'],
      'isActive': true,
      'isPremium': true,
      'serviceCategory': 'Keratin',
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    await offersRef.doc('head_spa').set({
      'title': 'Indulgent Head Spa',
      'description': 'Ayurvedic scalp therapy with deep conditioning and massage.',
      'price': 799.0,
      'originalPrice': 1499.0,
      'imageUrl': 'https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=800&fit=crop&q=80',
      'trainerIds': ['priya_sharma'],
      'isActive': true,
      'isPremium': true,
      'serviceCategory': 'Head Spa',
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    // ── Slots for next 7 days ──
    final slotsRef = _db.collection('slots');
    final trainers = ['emma_watson', 'david_beckham', 'sophia_loren', 'arjun_mehta', 'priya_sharma'];
    final hours = [10, 11, 13, 14, 16, 17];

    final existingSlots = await slotsRef.get();
    for (var doc in existingSlots.docs) {
      await doc.reference.delete();
    }

    final today = DateTime.now();
    for (int day = 0; day < 7; day++) {
      final date = today.add(Duration(days: day));
      for (final trainerId in trainers) {
        for (final hour in hours) {
          final startTime = DateTime(date.year, date.month, date.day, hour, 0);
          final endTime = startTime.add(const Duration(hours: 1));
          await slotsRef.add({
            'trainerId': trainerId,
            'startTime': Timestamp.fromDate(startTime),
            'endTime': Timestamp.fromDate(endTime),
            'status': 'available',
          });
        }
      }
    }
  }

  // ─────────────────── WALLET ───────────────────

  /// Credits wallet amount and records a transaction
  Future<void> addWalletCredit({
    required String uid,
    required double amount,
    required String reason,
    String? bookingId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final current = (snap.data()?['walletBalance'] ?? 0).toDouble();
      txn.update(userRef, {'walletBalance': current + amount});
      final txnRef = userRef.collection('transactions').doc();
      txn.set(txnRef, {
        'type': 'credit',
        'amount': amount,
        'reason': reason,
        'timestamp': DateTime.now(),
        if (bookingId != null) 'bookingId': bookingId,
      });
    });
  }

  /// Deducts wallet amount and records a transaction
  Future<void> deductWalletAmount({
    required String uid,
    required double amount,
    required String reason,
    String? bookingId,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(userRef);
      final current = (snap.data()?['walletBalance'] ?? 0).toDouble();
      if (current < amount) throw Exception('Insufficient wallet balance');
      txn.update(userRef, {'walletBalance': current - amount});
      final txnRef = userRef.collection('transactions').doc();
      txn.set(txnRef, {
        'type': 'debit',
        'amount': amount,
        'reason': reason,
        'timestamp': DateTime.now(),
        if (bookingId != null) 'bookingId': bookingId,
      });
    });
  }

  /// Stream of wallet transactions for a user
  Stream<List<Map<String, dynamic>>> getWalletTransactions(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─────────────────── REVIEWS ───────────────────

  /// Submit a review (published: false by default)
  Future<void> submitReview({
    required String userId,
    required String customerName,
    String customerPhone = '',
    required String stylistId,
    required String stylistName,
    required double rating,
    String reviewText = '',
    String bookingId = '',
  }) async {
    await _db.collection('reviews').add({
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'stylistId': stylistId,
      'stylistName': stylistName,
      'rating': rating,
      'reviewText': reviewText,
      'bookingId': bookingId,
      'date': DateTime.now(),
      'published': false,
      'loyaltyCredited': false,
    });
  }

  /// Stream of published reviews (for home carousel).
  /// Fetches all reviews and filters client-side to avoid requiring a
  /// composite Firestore index on (published, date).
  Stream<List<Map<String, dynamic>>> getPublishedReviews() {
    return _db
        .collection('reviews')
        .snapshots()
        .map((s) {
          final all = s.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          // Filter published only
          final published = all.where((r) => r['published'] == true).toList();
          // Sort by date descending (handles Timestamp, DateTime, or null)
          published.sort((a, b) {
            int toMs(dynamic v) {
              if (v == null) return 0;
              if (v is Timestamp) return v.millisecondsSinceEpoch;
              if (v is DateTime) return v.millisecondsSinceEpoch;
              return 0;
            }
            return toMs(b['date'] ?? b['createdAt'])
                .compareTo(toMs(a['date'] ?? a['createdAt']));
          });
          return published.take(20).toList();
        });
  }

  /// Stream of reviews for a specific stylist
  Stream<List<Map<String, dynamic>>> getStylistReviews(String stylistId) {
    return _db
        .collection('reviews')
        .where('stylistId', isEqualTo: stylistId)
        .where('published', isEqualTo: true)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─────────────────── REVIEW ACTIONS ───────────────────

  /// Marks a booking as reviewed so the "Add Review" button is hidden.
  Future<void> markBookingReviewed(String bookingId) async {
    await _db.collection('bookings').doc(bookingId).update({'reviewSubmitted': true});
  }

  // ─────────────────── RESCHEDULE ───────────────────

  /// Returns up to 8 upcoming available slots for [trainerId] after now.
  Future<List<SlotModel>> getAvailableSlotsForReschedule(String trainerId) async {
    final snap = await _db
        .collection('slots')
        .where('trainerId', isEqualTo: trainerId)
        .where('status', isEqualTo: 'available')
        .where('startTime', isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('startTime')
        .limit(8)
        .get();
    return snap.docs.map((d) => SlotModel.fromMap(d.id, d.data())).toList();
  }

  /// Atomically reschedules a booking:
  /// 1. Frees the old slot (status → 'available', clears bookingId).
  /// 2. Marks the new slot as booked.
  /// 3. Updates the booking document with new slotId and slotTime.
  Future<void> rescheduleBooking({
    required String bookingId,
    required String oldSlotId,
    required String newSlotId,
    required DateTime newSlotTime,
  }) async {
    final oldSlotRef = _db.collection('slots').doc(oldSlotId);
    final newSlotRef = _db.collection('slots').doc(newSlotId);
    final bookingRef = _db.collection('bookings').doc(bookingId);

    await _db.runTransaction((transaction) async {
      final newSlotSnap = await transaction.get(newSlotRef);
      if (!newSlotSnap.exists) throw Exception('Slot not found');
      final currentStatus = newSlotSnap.data()!['status'] as String? ?? '';
      if (currentStatus != 'available') {
        throw Exception('That slot was just taken. Please pick another.');
      }

      // Free old slot
      transaction.update(oldSlotRef, {'status': 'available', 'bookingId': ''});

      // Book new slot
      transaction.update(newSlotRef, {'status': 'booked', 'bookingId': bookingId});

      // Update booking record
      transaction.update(bookingRef, {
        'slotId': newSlotId,
        'slotTime': Timestamp.fromDate(newSlotTime),
      });
    });
  }
}
