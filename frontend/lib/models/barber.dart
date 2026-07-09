/// Sartarosh modeli
/// Database: barbers jadvali bilan to'liq moslangan
class Barber {
  final int id;
  final int? userId;
  final String name;
  final String district;
  final double rating;
  final int totalReviews;
  final double lat;
  final double lng;
  final double? distance;
  final String? experience;
  final String? specialization;
  final String? phone;
  final bool isOnline;
  final String? avatarUrl;
  final String? bio;
  final String? workingHoursStart;
  final String? workingHoursEnd;
  final int slotDurationMinutes;
  final List<dynamic>? services;
  final List<dynamic>? reviews;
  final List<dynamic>? workingDays;
  final String? createdAt;

  const Barber({
    required this.id,
    this.userId,
    required this.name,
    required this.district,
    required this.rating,
    this.totalReviews = 0,
    required this.lat,
    required this.lng,
    this.distance,
    this.experience,
    this.specialization,
    this.phone,
    this.isOnline = true,
    this.avatarUrl,
    this.bio,
    this.workingHoursStart,
    this.workingHoursEnd,
    this.slotDurationMinutes = 30,
    this.services,
    this.reviews,
    this.workingDays,
    this.createdAt,
  });

  /// JSON dan Barber obyektini yaratish
  factory Barber.fromJson(Map<String, dynamic> json) {
    return Barber(
      id: _parseInt(json['id']),
      userId: json['user_id'] != null ? _parseInt(json['user_id']) : null,
      name: json['name']?.toString() ?? '',
      district: json['district']?.toString() ?? 'Toshkent',
      rating: _parseDouble(json['rating'], defaultValue: 5.0),
      totalReviews: _parseInt(json['total_reviews']),
      lat: _parseDouble(json['lat']),
      lng: _parseDouble(json['lng']),
      distance: json['distance'] != null ? _parseDouble(json['distance']) : null,
      experience: json['experience']?.toString(),
      specialization: json['specialization']?.toString(),
      phone: json['phone']?.toString(),
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      avatarUrl: json['avatar_url']?.toString(),
      bio: json['bio']?.toString(),
      workingHoursStart: json['working_hours_start']?.toString(),
      workingHoursEnd: json['working_hours_end']?.toString(),
      slotDurationMinutes: _parseInt(json['slot_duration_minutes'], defaultValue: 30),
      services: json['services'] is List ? json['services'] : null,
      reviews: json['reviews'] is List ? json['reviews'] : null,
      workingDays: json['working_days'] is List ? json['working_days'] : null,
      createdAt: json['created_at']?.toString(),
    );
  }

  /// Barber obyektini JSON ga o'girish
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'district': district,
    'rating': rating,
    'total_reviews': totalReviews,
    'lat': lat,
    'lng': lng,
    'distance': distance,
    'experience': experience,
    'specialization': specialization,
    'phone': phone,
    'is_online': isOnline,
    'avatar_url': avatarUrl,
    'bio': bio,
    'working_hours_start': workingHoursStart,
    'working_hours_end': workingHoursEnd,
    'slot_duration_minutes': slotDurationMinutes,
  };

  /// Profil yangilash uchun JSON
  Map<String, dynamic> toUpdateJson() {
    final map = <String, dynamic>{};
    if (name.isNotEmpty) map['full_name'] = name;
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    if (bio != null) map['bio'] = bio;
    if (specialization != null && specialization!.isNotEmpty) {
      map['specialization'] = specialization;
    }
    if (experience != null && experience!.isNotEmpty) {
      map['experience'] = experience;
    }
    if (workingHoursStart != null) map['working_hours_start'] = workingHoursStart;
    if (workingHoursEnd != null) map['working_hours_end'] = workingHoursEnd;
    return map;
  }

  /// Yangi ma'lumotlar bilan nusxa yaratish
  Barber copyWith({
    int? id,
    int? userId,
    String? name,
    String? district,
    double? rating,
    int? totalReviews,
    double? lat,
    double? lng,
    double? distance,
    String? experience,
    String? specialization,
    String? phone,
    bool? isOnline,
    String? avatarUrl,
    String? bio,
    String? workingHoursStart,
    String? workingHoursEnd,
    int? slotDurationMinutes,
    List<dynamic>? services,
    List<dynamic>? reviews,
    List<dynamic>? workingDays,
  }) {
    return Barber(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      district: district ?? this.district,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      distance: distance ?? this.distance,
      experience: experience ?? this.experience,
      specialization: specialization ?? this.specialization,
      phone: phone ?? this.phone,
      isOnline: isOnline ?? this.isOnline,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      workingHoursStart: workingHoursStart ?? this.workingHoursStart,
      workingHoursEnd: workingHoursEnd ?? this.workingHoursEnd,
      slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
      services: services ?? this.services,
      reviews: reviews ?? this.reviews,
      workingDays: workingDays ?? this.workingDays,
    );
  }

  // ─── HELPER PROPERTIES ──────────────────────────────────────────────────────

  /// Ish vaqti formatlangan (09:00 – 20:00)
  String get formattedWorkingHours {
    final start = workingHoursStart ?? '09:00';
    final end = workingHoursEnd ?? '20:00';
    return '$start – $end';
  }

  /// Masofa formatlangan
  String get formattedDistance {
    if (distance == null) return '';
    if (distance! < 1) return '${(distance! * 1000).toStringAsFixed(0)} m';
    return '${distance!.toStringAsFixed(1)} km';
  }

  /// Tajriba formatlangan
  String get formattedExperience {
    if (experience == null || experience!.isEmpty) return "Ko'rsatilmagan";
    if (int.tryParse(experience!) != null) return '$experience yil';
    return experience!;
  }

  /// Reyting yulduzcha soni (1-5)
  int get ratingStars => rating.round().clamp(1, 5);

  /// Online status matni
  String get statusText => isOnline ? 'Online' : 'Offline';

  /// Avatar bor-yo'qligini tekshirish
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Ismning birinchi harfi (avatar uchun)
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : 'S';

  // ─── PRIVATE PARSE HELPERS ────────────────────────────────────────────────

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  static double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  @override
  String toString() => 'Barber(id: $id, name: $name, rating: $rating, online: $isOnline)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Barber && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
