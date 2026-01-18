class Booking {
  final String id;
  final String userId;
  final String parkingId;
  final ParkingInfo? parking;
  final int slotNumber;
  final DateTime startTime;
  final DateTime endTime;
  final double duration;
  final double totalPrice;
  final String status;
  final String? qrCode;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String paymentStatus;
  final String paymentMethod;

  Booking({
    required this.id,
    required this.userId,
    required this.parkingId,
    this.parking,
    required this.slotNumber,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.totalPrice,
    required this.status,
    this.qrCode,
    this.checkInTime,
    this.checkOutTime,
    required this.paymentStatus,
    required this.paymentMethod,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user'] is String 
          ? json['user'] 
          : json['user']?['_id'] ?? json['user']?['id'] ?? '',
      parkingId: json['parking'] is String 
          ? json['parking'] 
          : json['parking']?['_id'] ?? json['parking']?['id'] ?? '',
      parking: json['parking'] is Map 
          ? ParkingInfo.fromJson(json['parking']) 
          : null,
      slotNumber: json['slotNumber'] ?? 0,
      startTime: json['startTime'] != null 
          ? DateTime.parse(json['startTime']) 
          : DateTime.now(),
      endTime: json['endTime'] != null 
          ? DateTime.parse(json['endTime']) 
          : DateTime.now(),
      duration: (json['duration'] ?? 0).toDouble(),
      totalPrice: (json['totalPrice'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      qrCode: json['qrCode'],
      checkInTime: json['checkInTime'] != null 
          ? DateTime.parse(json['checkInTime']) 
          : null,
      checkOutTime: json['checkOutTime'] != null 
          ? DateTime.parse(json['checkOutTime']) 
          : null,
      paymentStatus: json['paymentStatus'] ?? 'pending',
      paymentMethod: json['paymentMethod'] ?? 'cash',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'parking': parkingId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'paymentMethod': paymentMethod,
    };
  }
}

class ParkingInfo {
  final String id;
  final String name;
  final Address? address;
  final Location? location;
  final double pricePerHour;

  ParkingInfo({
    required this.id,
    required this.name,
    this.address,
    this.location,
    required this.pricePerHour,
  });

  factory ParkingInfo.fromJson(Map<String, dynamic> json) {
    return ParkingInfo(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] != null 
          ? Address.fromJson(json['address']) 
          : null,
      location: json['location'] != null 
          ? Location.fromJson(json['location']) 
          : null,
      pricePerHour: (json['pricePerHour'] ?? 0).toDouble(),
    );
  }
}

class Address {
  final String street;
  final String city;
  final String state;
  final String zipCode;

  Address({
    required this.street,
    required this.city,
    required this.state,
    required this.zipCode,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      street: json['street'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      zipCode: json['zipCode'] ?? '',
    );
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
}
