
class UserModel {
  final String uid;
  final String email;
  final String name;
  final String phone;
  final String fcmToken;
  final int loyaltyPoints;
  final bool hasLoyaltyVoucher;
  final DateTime createdAt;
  // New fields
  final double walletBalance;
  final String gender;       // 'male' | 'female' | 'other' | ''
  final DateTime? dob;       // Date of birth (for birthday bonus)
  final String photoUrl;     // Profile photo URL
  final bool isNewUser;      // true until profile setup completed
  final bool oneTimeOfferClaimed; // true once the ₹100 one-time offer has been claimed

  const UserModel({
    required this.uid,
    required this.email,
    this.name = '',
    this.phone = '',
    this.fcmToken = '',
    this.loyaltyPoints = 0,
    this.hasLoyaltyVoucher = false,
    required this.createdAt,
    this.walletBalance = 0.0,
    this.gender = '',
    this.dob,
    this.photoUrl = '',
    this.isNewUser = true,
    this.oneTimeOfferClaimed = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      fcmToken: map['fcmToken'] ?? '',
      loyaltyPoints: (map['loyaltyPoints'] ?? 0) as int,
      hasLoyaltyVoucher: map['hasLoyaltyVoucher'] ?? false,
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      walletBalance: (map['walletBalance'] ?? 0).toDouble(),
      gender: map['gender'] ?? '',
      dob: (map['dob'] as dynamic)?.toDate(),
      photoUrl: map['photoUrl'] ?? '',
      isNewUser: map['isNewUser'] ?? true,
      oneTimeOfferClaimed: map['oneTimeOfferClaimed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'name': name,
    'phone': phone,
    'fcmToken': fcmToken,
    'loyaltyPoints': loyaltyPoints,
    'hasLoyaltyVoucher': hasLoyaltyVoucher,
    'createdAt': createdAt,
    'walletBalance': walletBalance,
    'gender': gender,
    'dob': dob,
    'photoUrl': photoUrl,
    'isNewUser': isNewUser,
    'oneTimeOfferClaimed': oneTimeOfferClaimed,
  };

  UserModel copyWith({
    String? name,
    String? phone,
    String? fcmToken,
    int? loyaltyPoints,
    bool? hasLoyaltyVoucher,
    double? walletBalance,
    String? gender,
    DateTime? dob,
    String? photoUrl,
    bool? isNewUser,
    bool? oneTimeOfferClaimed,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      fcmToken: fcmToken ?? this.fcmToken,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      hasLoyaltyVoucher: hasLoyaltyVoucher ?? this.hasLoyaltyVoucher,
      createdAt: createdAt,
      walletBalance: walletBalance ?? this.walletBalance,
      gender: gender ?? this.gender,
      dob: dob ?? this.dob,
      photoUrl: photoUrl ?? this.photoUrl,
      isNewUser: isNewUser ?? this.isNewUser,
      oneTimeOfferClaimed: oneTimeOfferClaimed ?? this.oneTimeOfferClaimed,
    );
  }
}
