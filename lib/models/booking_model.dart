import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  final String id;
  final String userId;
  final String offerId;
  final String offerTitle;
  final String trainerId;
  final String trainerName;
  final String slotId;
  final DateTime slotTime;
  final double amount;

  /// Branch where the booking was made: 'Anna Nagar' | 'Kaalavasal'
  final String branch;

  /// Status lifecycle:
  ///  'pending_payment'      → UPI app launched, awaiting user action
  ///  'pending_verification' → User claimed payment + submitted UTR; awaiting admin verification
  ///  'confirmed'            → Admin verified money received in bank / PhonePe dashboard
  ///  'completed'            → Service delivered
  ///  'cancelled'            → Payment not made or booking cancelled
  final String status;

  final String phonePeTransactionId;
  final String upiTransactionId; // backward compat

  /// UPI Transaction Reference Number (12-digit UTR) entered by customer.
  /// Admin cross-checks this against PhonePe / bank statement.
  final String utrNumber;

  /// true once the customer has tapped "I Paid" and submitted their UTR.
  /// Even if this is true, booking stays 'pending_verification' until admin confirms.
  final bool paymentClaimed;

  /// Timestamp when customer submitted the UTR claim
  final DateTime? paymentClaimedAt;

  /// Timestamp when admin confirmed the payment
  final DateTime? adminConfirmedAt;

  /// Admin who confirmed (UID or name)
  final String adminConfirmedBy;

  final int loyaltyPointsEarned;
  final bool loyaltyVoucherApplied;
  final DateTime createdAt;

  /// Timestamp when slot was reserved (for expiry tracking)
  final DateTime? slotReservedAt;

  /// true once the user has submitted a review for this completed booking
  final bool reviewSubmitted;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.offerId,
    required this.offerTitle,
    required this.trainerId,
    required this.trainerName,
    required this.slotId,
    required this.slotTime,
    required this.amount,
    this.branch = '',
    required this.status,
    this.phonePeTransactionId = '',
    this.upiTransactionId = '',
    this.utrNumber = '',
    this.paymentClaimed = false,
    this.paymentClaimedAt,
    this.adminConfirmedAt,
    this.adminConfirmedBy = '',
    this.loyaltyPointsEarned = 0,
    this.loyaltyVoucherApplied = false,
    this.reviewSubmitted = false,
    required this.createdAt,
    this.slotReservedAt,
  });

  factory BookingModel.fromMap(String id, Map<String, dynamic> map) {
    DateTime? toDate(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    return BookingModel(
      id: id,
      userId: map['userId'] ?? '',
      offerId: map['offerId'] ?? '',
      offerTitle: map['offerTitle'] ?? '',
      trainerId: map['trainerId'] ?? '',
      trainerName: map['trainerName'] ?? '',
      slotId: map['slotId'] ?? '',
      slotTime: (map['slotTime'] as dynamic).toDate(),
      amount: (map['amount'] ?? 0).toDouble(),
      branch: map['branch'] ?? '',
      status: map['status'] ?? 'pending_payment',
      phonePeTransactionId: map['phonePeTransactionId'] ?? '',
      upiTransactionId: map['upiTransactionId'] ?? map['razorpayPaymentId'] ?? '',
      utrNumber: map['utrNumber'] ?? '',
      paymentClaimed: map['paymentClaimed'] ?? false,
      paymentClaimedAt: toDate(map['paymentClaimedAt']),
      adminConfirmedAt: toDate(map['adminConfirmedAt']),
      adminConfirmedBy: map['adminConfirmedBy'] ?? '',
      loyaltyPointsEarned: (map['loyaltyPointsEarned'] ?? 0) as int,
      loyaltyVoucherApplied: map['loyaltyVoucherApplied'] ?? false,
      reviewSubmitted: map['reviewSubmitted'] ?? false,
      createdAt: toDate(map['createdAt']) ?? DateTime.now(),
      slotReservedAt: toDate(map['slotReservedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'offerId': offerId,
    'offerTitle': offerTitle,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'slotId': slotId,
    'slotTime': Timestamp.fromDate(slotTime),
    'amount': amount,
    'branch': branch,
    'status': status,
    'phonePeTransactionId': phonePeTransactionId,
    'upiTransactionId': upiTransactionId,
    'utrNumber': utrNumber,
    'paymentClaimed': paymentClaimed,
    if (paymentClaimedAt != null) 'paymentClaimedAt': Timestamp.fromDate(paymentClaimedAt!),
    if (adminConfirmedAt != null) 'adminConfirmedAt': Timestamp.fromDate(adminConfirmedAt!),
    'adminConfirmedBy': adminConfirmedBy,
    'loyaltyPointsEarned': loyaltyPointsEarned,
    'loyaltyVoucherApplied': loyaltyVoucherApplied,
    'reviewSubmitted': reviewSubmitted,
    'createdAt': Timestamp.fromDate(createdAt),
    if (slotReservedAt != null) 'slotReservedAt': Timestamp.fromDate(slotReservedAt!),
  };

  BookingModel copyWith({
    String? status,
    String? phonePeTransactionId,
    String? utrNumber,
    bool? paymentClaimed,
    DateTime? paymentClaimedAt,
    DateTime? adminConfirmedAt,
    String? adminConfirmedBy,
    int? loyaltyPointsEarned,
    bool? loyaltyVoucherApplied,
    bool? reviewSubmitted,
  }) {
    return BookingModel(
      id: id, userId: userId, offerId: offerId, offerTitle: offerTitle,
      trainerId: trainerId, trainerName: trainerName, slotId: slotId,
      slotTime: slotTime, amount: amount, branch: branch,
      status: status ?? this.status,
      phonePeTransactionId: phonePeTransactionId ?? this.phonePeTransactionId,
      upiTransactionId: upiTransactionId,
      utrNumber: utrNumber ?? this.utrNumber,
      paymentClaimed: paymentClaimed ?? this.paymentClaimed,
      paymentClaimedAt: paymentClaimedAt ?? this.paymentClaimedAt,
      adminConfirmedAt: adminConfirmedAt ?? this.adminConfirmedAt,
      adminConfirmedBy: adminConfirmedBy ?? this.adminConfirmedBy,
      loyaltyPointsEarned: loyaltyPointsEarned ?? this.loyaltyPointsEarned,
      loyaltyVoucherApplied: loyaltyVoucherApplied ?? this.loyaltyVoucherApplied,
      reviewSubmitted: reviewSubmitted ?? this.reviewSubmitted,
      createdAt: createdAt,
      slotReservedAt: slotReservedAt,
    );
  }
}
