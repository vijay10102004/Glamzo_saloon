class TrainerModel {
  final String id;
  final String name;
  final String photoUrl;
  final List<String> specialties;
  final double rating;
  final int totalReviews;
  // New fields
  final String bio;
  final int experienceYears;
  final String specialisation; // primary specialisation display string
  final List<String> badges;   // e.g. ['Most Booked', 'New Stylist', 'Top Rated']
  final bool isAvailable;

  const TrainerModel({
    required this.id,
    required this.name,
    required this.photoUrl,
    required this.specialties,
    required this.rating,
    required this.totalReviews,
    this.bio = '',
    this.experienceYears = 0,
    this.specialisation = '',
    this.badges = const [],
    this.isAvailable = true,
  });

  factory TrainerModel.fromMap(String id, Map<String, dynamic> map) {
    return TrainerModel(
      id: id,
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      specialties: List<String>.from(map['specialties'] ?? []),
      rating: (map['rating'] ?? 0).toDouble(),
      totalReviews: map['totalReviews'] ?? 0,
      bio: map['bio'] ?? '',
      experienceYears: map['experienceYears'] ?? 0,
      specialisation: map['specialisation'] ?? (List<String>.from(map['specialties'] ?? [])).isNotEmpty
          ? (List<String>.from(map['specialties'] ?? [])).first
          : '',
      badges: List<String>.from(map['badges'] ?? []),
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'photoUrl': photoUrl,
    'specialties': specialties,
    'rating': rating,
    'totalReviews': totalReviews,
    'bio': bio,
    'experienceYears': experienceYears,
    'specialisation': specialisation,
    'badges': badges,
    'isAvailable': isAvailable,
  };
}
