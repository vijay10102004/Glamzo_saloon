/// Gender preference options for a service.
enum GenderPreference {
  /// Shown for Male-filtered view AND "All"
  male,

  /// Shown for Female-filtered view AND "All"
  female,

  /// Shown in all views (default for legacy services)
  both;

  /// Parse from Firestore string value. Falls back to [both] for safety.
  static GenderPreference fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'male':   return GenderPreference.male;
      case 'female': return GenderPreference.female;
      default:       return GenderPreference.both;
    }
  }

  /// Firestore-compatible string representation (title-case).
  String toStorageString() {
    switch (this) {
      case GenderPreference.male:   return 'Male';
      case GenderPreference.female: return 'Female';
      case GenderPreference.both:   return 'Both';
    }
  }

  /// Human-readable display label with emoji.
  String get displayLabel {
    switch (this) {
      case GenderPreference.male:   return '♂ Male';
      case GenderPreference.female: return '♀ Female';
      case GenderPreference.both:   return '⚥ Both';
    }
  }

  /// Short badge label shown on service tiles.
  String get badgeLabel {
    switch (this) {
      case GenderPreference.male:   return '♂';
      case GenderPreference.female: return '♀';
      case GenderPreference.both:   return '⚥';
    }
  }
}

class ServiceModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category; // Haircut, Beard, Facial, Hair Color, Keratin, Head Spa, Waxing, Massage, Other
  final String icon;     // emoji icon e.g. ✂️ 🪒 💆
  final int durationMinutes;
  final bool isActive;
  final int sortOrder;   // controls display order in carousel
  final GenderPreference genderPreference; // new: who this service is for

  const ServiceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    this.icon = '✂️',
    this.durationMinutes = 30,
    this.isActive = true,
    this.sortOrder = 0,
    this.genderPreference = GenderPreference.both, // safe default
  });

  factory ServiceModel.fromMap(String id, Map<String, dynamic> map) {
    return ServiceModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['imageUrl'] ?? '',
      category: map['category'] ?? '',
      icon: map['icon'] ?? '✂️',
      durationMinutes: (map['durationMinutes'] ?? 30).toInt(),
      isActive: map['isActive'] ?? true,
      sortOrder: (map['sortOrder'] ?? 0).toInt(),
      genderPreference: GenderPreference.fromString(map['genderPreference'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'price': price,
    'imageUrl': imageUrl,
    'category': category,
    'icon': icon,
    'durationMinutes': durationMinutes,
    'isActive': isActive,
    'sortOrder': sortOrder,
    'genderPreference': genderPreference.toStorageString(),
  };
}
