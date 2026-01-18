class Parking {
  final String id;
  final String name;
  final String? description;
  final Address address;
  final Location location;
  final int totalSlots;
  final int availableSlots;
  final double pricePerHour;
  final List<String> images;
  final List<String> amenities;
  final OperatingHours operatingHours;
  final bool isActive;
  final bool isVerified;
  final Rating rating;
  final double? distance; // Distance in km (calculated on frontend)

  Parking({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.location,
    required this.totalSlots,
    required this.availableSlots,
    required this.pricePerHour,
    this.images = const [],
    this.amenities = const [],
    required this.operatingHours,
    required this.isActive,
    required this.isVerified,
    required this.rating,
    this.distance,
  });

  factory Parking.fromJson(Map<String, dynamic> json) {
    return Parking(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      address: Address.fromJson(json['address'] ?? {}),
      location: Location.fromJson(json['location'] ?? {}),
      totalSlots: json['totalSlots'] ?? 0,
      availableSlots: json['availableSlots'] ?? 0,
      pricePerHour: (json['pricePerHour'] ?? 0).toDouble(),
      images: List<String>.from(json['images'] ?? []),
      amenities: List<String>.from(json['amenities'] ?? []),
      operatingHours: OperatingHours.fromJson(json['operatingHours'] ?? {}),
      isActive: json['isActive'] ?? true,
      isVerified: json['isVerified'] ?? false,
      rating: Rating.fromJson(json['rating'] ?? {}),
      distance: json['distance'] != null ? json['distance'].toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'address': address.toJson(),
      'location': location.toJson(),
      'totalSlots': totalSlots,
      'availableSlots': availableSlots,
      'pricePerHour': pricePerHour,
      'images': images,
      'amenities': amenities,
      'operatingHours': operatingHours.toJson(),
      'isActive': isActive,
      'isVerified': isVerified,
      'rating': rating.toJson(),
    };
  }
}

class Address {
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final String country;

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
    this.country = 'India',
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
      country: json['country'] ?? 'India',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'street': street,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
    };
  }

  String get fullAddress => '$street, $city, $state $zipCode';
}

class Location {
  final double latitude;
  final double longitude;

  Location({
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class OperatingHours {
  final String open;
  final String close;

  OperatingHours({
    this.open = '00:00',
    this.close = '23:59',
  });

  factory OperatingHours.fromJson(Map<String, dynamic> json) {
    return OperatingHours(
      open: json['open'] ?? '00:00',
      close: json['close'] ?? '23:59',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'close': close,
    };
  }
}

class Rating {
  final double average;
  final int count;

  Rating({
    this.average = 0.0,
    this.count = 0,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      average: (json['average'] ?? 0.0).toDouble(),
      count: json['count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'average': average,
      'count': count,
    };
  }
}
