/// Model pre Duchovné cvičenia
/// Zodpovedá štruktúre z backend/src/app/api/spiritual-exercises

class SpiritualExerciseLocale {
  final int id;
  final String code;
  final String nativeName;

  SpiritualExerciseLocale({
    required this.id,
    required this.code,
    required this.nativeName,
  });

  factory SpiritualExerciseLocale.fromJson(Map<String, dynamic> json) {
    return SpiritualExerciseLocale(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      nativeName: json['native_name'] ?? '',
    );
  }
}

class SpiritualExercisePricing {
  final int id;
  final String roomType;
  final String? description;
  final double price;
  final double? deposit;
  final int displayOrder;

  SpiritualExercisePricing({
    required this.id,
    required this.roomType,
    this.description,
    required this.price,
    this.deposit,
    required this.displayOrder,
  });

  factory SpiritualExercisePricing.fromJson(Map<String, dynamic> json) {
    return SpiritualExercisePricing(
      id: json['id'] ?? 0,
      roomType: json['room_type'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0).toDouble(),
      deposit: json['deposit']?.toDouble(),
      displayOrder: json['display_order'] ?? 0,
    );
  }

  double get totalPrice => price + (deposit ?? 50.0);
}

class SpiritualExerciseTestimonial {
  final int id;
  final String authorName;
  final String testimonialText;
  final int? rating;
  final int displayOrder;

  SpiritualExerciseTestimonial({
    required this.id,
    required this.authorName,
    required this.testimonialText,
    this.rating,
    required this.displayOrder,
  });

  factory SpiritualExerciseTestimonial.fromJson(Map<String, dynamic> json) {
    return SpiritualExerciseTestimonial(
      id: json['id'] ?? 0,
      authorName: json['author_name'] ?? '',
      testimonialText: json['testimonial_text'] ?? '',
      rating: json['rating'],
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

class SpiritualExerciseGallery {
  final int id;
  final String imageUrl;
  final String? altText;
  final String? caption;
  final int displayOrder;

  SpiritualExerciseGallery({
    required this.id,
    required this.imageUrl,
    this.altText,
    this.caption,
    required this.displayOrder,
  });

  factory SpiritualExerciseGallery.fromJson(Map<String, dynamic> json) {
    return SpiritualExerciseGallery(
      id: json['id'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      altText: json['alt_text'],
      caption: json['caption'],
      displayOrder: json['display_order'] ?? 0,
    );
  }
}

/// Základný model pre zoznam cvičení
class SpiritualExercise {
  final int id;
  final String title;
  final String slug;
  final String? description;
  final String? imageUrl;
  final String? homeImageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final String locationName;
  final String? locationCity;
  final String locationCountry;
  final String? leaderName;
  final int? maxCapacity;
  final SpiritualExerciseLocale locale;

  SpiritualExercise({
    required this.id,
    required this.title,
    required this.slug,
    this.description,
    this.imageUrl,
    this.homeImageUrl,
    required this.startDate,
    required this.endDate,
    required this.locationName,
    this.locationCity,
    required this.locationCountry,
    this.leaderName,
    this.maxCapacity,
    required this.locale,
  });

  factory SpiritualExercise.fromJson(Map<String, dynamic> json) {
    return SpiritualExercise(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      homeImageUrl: json['home_image_url'],
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      locationName: json['location_name'] ?? '',
      locationCity: json['location_city'],
      locationCountry: json['location_country'] ?? '',
      leaderName: json['leader_name'],
      maxCapacity: json['max_capacity'],
      locale: json['locale'] != null 
          ? SpiritualExerciseLocale.fromJson(json['locale'])
          : SpiritualExerciseLocale(id: 0, code: 'sk', nativeName: 'Slovenčina'),
    );
  }

  String get locationDisplay {
    if (locationCity != null && locationCity!.isNotEmpty) {
      return '$locationName, $locationCity';
    }
    return locationName;
  }
}

/// Rozšírený model pre detail cvičenia
class SpiritualExerciseDetail extends SpiritualExercise {
  final String? fullDescription;
  final String? leaderBio;
  final String? leaderPhoto;
  final String? locationAddress;
  final List<SpiritualExercisePricing> pricing;
  final List<SpiritualExerciseTestimonial> testimonials;
  final List<SpiritualExerciseGallery> gallery;
  final int currentRegistrations;
  final bool isFull;

  SpiritualExerciseDetail({
    required super.id,
    required super.title,
    required super.slug,
    super.description,
    super.imageUrl,
    super.homeImageUrl,
    required super.startDate,
    required super.endDate,
    required super.locationName,
    super.locationCity,
    required super.locationCountry,
    super.leaderName,
    super.maxCapacity,
    required super.locale,
    this.fullDescription,
    this.leaderBio,
    this.leaderPhoto,
    this.locationAddress,
    required this.pricing,
    required this.testimonials,
    required this.gallery,
    required this.currentRegistrations,
    required this.isFull,
  });

  factory SpiritualExerciseDetail.fromJson(Map<String, dynamic> json) {
    final pricingList = (json['pricing'] as List<dynamic>?)
        ?.map((p) => SpiritualExercisePricing.fromJson(p))
        .toList() ?? [];
    pricingList.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final testimonialsList = (json['testimonials'] as List<dynamic>?)
        ?.map((t) => SpiritualExerciseTestimonial.fromJson(t))
        .toList() ?? [];
    testimonialsList.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final galleryList = (json['gallery'] as List<dynamic>?)
        ?.map((g) => SpiritualExerciseGallery.fromJson(g))
        .toList() ?? [];
    galleryList.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return SpiritualExerciseDetail(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      fullDescription: json['full_description'],
      imageUrl: json['image_url'],
      homeImageUrl: json['home_image_url'],
      startDate: DateTime.parse(json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate: DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      locationName: json['location_name'] ?? '',
      locationCity: json['location_city'],
      locationCountry: json['location_country'] ?? '',
      locationAddress: json['location_address'],
      leaderName: json['leader_name'],
      leaderBio: json['leader_bio'],
      leaderPhoto: json['leader_photo'],
      maxCapacity: json['max_capacity'],
      locale: json['locale'] != null 
          ? SpiritualExerciseLocale.fromJson(json['locale'])
          : SpiritualExerciseLocale(id: 0, code: 'sk', nativeName: 'Slovenčina'),
      pricing: pricingList,
      testimonials: testimonialsList,
      gallery: galleryList,
      currentRegistrations: json['current_registrations'] ?? 0,
      isFull: json['is_full'] ?? false,
    );
  }

  String get capacityDisplay {
    if (maxCapacity == null) return '';
    return '$currentRegistrations / $maxCapacity miest';
  }
}

