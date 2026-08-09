/// A single loyalty transaction entry (earn or redeem)
class LoyaltyTransaction {
  final String id;
  final String userId;
  final int points;        // positive = earned, negative = redeemed
  final String type;       // 'earned' | 'redeemed'
  final String description;
  final String bookingId;
  final DateTime createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.userId,
    required this.points,
    required this.type,
    required this.description,
    this.bookingId = '',
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromMap(String id, Map<String, dynamic> map) {
    return LoyaltyTransaction(
      id: id,
      userId: map['userId'] ?? '',
      points: (map['points'] ?? 0) as int,
      type: map['type'] ?? 'earned',
      description: map['description'] ?? '',
      bookingId: map['bookingId'] ?? '',
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'points': points,
    'type': type,
    'description': description,
    'bookingId': bookingId,
    'createdAt': createdAt,
  };
}
