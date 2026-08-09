class OfferModel {
  final String id;
  final String title;
  final String description;
  final double price;
  final double originalPrice;
  final String imageUrl;
  final List<String> trainerIds;
  final bool isActive;
  final bool isPremium;
  final String serviceCategory; // Haircut, Facial, Hair Color, Keratin, Head Spa
  final DateTime? expiresAt;    // Only set for premium offers

  const OfferModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.originalPrice,
    required this.imageUrl,
    required this.trainerIds,
    required this.isActive,
    this.isPremium = false,
    this.serviceCategory = '',
    this.expiresAt,
  });

  int get discountPercent =>
      originalPrice > 0
          ? (((originalPrice - price) / originalPrice) * 100).round()
          : 0;

  /// Returns true if this is a live premium offer (premium + not yet expired)
  bool get isLivePremium {
    if (!isPremium) return false;
    if (expiresAt == null) return false;
    return expiresAt!.isAfter(DateTime.now());
  }

  factory OfferModel.fromMap(String id, Map<String, dynamic> map) {
    return OfferModel(
      id: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      originalPrice: (map['originalPrice'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      trainerIds: List<String>.from(map['trainerIds'] ?? []),
      isActive: map['isActive'] ?? false,
      isPremium: map['isPremium'] ?? false,
      serviceCategory: map['serviceCategory'] ?? '',
      expiresAt: map['expiresAt'] != null
          ? (map['expiresAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'description': description,
    'price': price,
    'originalPrice': originalPrice,
    'imageUrl': imageUrl,
    'trainerIds': trainerIds,
    'isActive': isActive,
    'isPremium': isPremium,
    'serviceCategory': serviceCategory,
    'expiresAt': expiresAt,
  };
}
