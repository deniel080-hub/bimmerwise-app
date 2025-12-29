import 'package:cloud_firestore/cloud_firestore.dart';

class Address {
  final String id;
  final String fullName;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String phone;
  final String type; // 'shipping', 'billing', or 'both'
  final DateTime createdAt;
  final DateTime updatedAt;

  Address({
    required this.id,
    required this.fullName,
    required this.street,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
    required this.phone,
    this.type = 'both',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fullName': fullName,
    'street': street,
    'city': city,
    'state': state,
    'postalCode': postalCode,
    'country': country,
    'phone': phone,
    'type': type,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      street: json['street'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      postalCode: json['postalCode'] as String,
      country: json['country'] as String,
      phone: json['phone'] as String,
      type: json['type'] as String? ?? 'both',
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Address copyWith({
    String? id,
    String? fullName,
    String? street,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? phone,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Address(
    id: id ?? this.id,
    fullName: fullName ?? this.fullName,
    street: street ?? this.street,
    city: city ?? this.city,
    state: state ?? this.state,
    postalCode: postalCode ?? this.postalCode,
    country: country ?? this.country,
    phone: phone ?? this.phone,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  String get formattedAddress => '$street, $city, $state $postalCode, $country';
  
  String get shortDisplay {
    final streetPart = street.length > 20 ? '${street.substring(0, 20)}...' : street;
    return '$streetPart, $city';
  }
  
  String get multilineDisplay => 
    '$fullName\n$street\n$city, $state\n$postalCode, $country\nPhone: $phone';
}
