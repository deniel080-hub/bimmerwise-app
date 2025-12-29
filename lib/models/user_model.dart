import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bimmerwise_connect/models/address_model.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? profilePicture;
  final bool isAdmin;
  final List<Address> addresses;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? fcmToken;
  final DateTime? lastTokenUpdate;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.profilePicture,
    this.isAdmin = false,
    this.addresses = const [],
    required this.createdAt,
    required this.updatedAt,
    this.fcmToken,
    this.lastTokenUpdate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'profilePicture': profilePicture,
    'isAdmin': isAdmin,
    'addresses': addresses.map((a) => a.toJson()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
    if (fcmToken != null) 'fcmToken': fcmToken,
    if (lastTokenUpdate != null) 'lastTokenUpdate': Timestamp.fromDate(lastTokenUpdate!),
  };

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String,
      profilePicture: json['profilePicture'] as String?,
      isAdmin: json['isAdmin'] as bool? ?? false,
      addresses: (json['addresses'] as List<dynamic>?)
          ?.map((a) => Address.fromJson(a as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
      fcmToken: json['fcmToken'] as String?,
      lastTokenUpdate: json['lastTokenUpdate'] != null
          ? ((json['lastTokenUpdate'] is Timestamp)
              ? (json['lastTokenUpdate'] as Timestamp).toDate()
              : DateTime.parse(json['lastTokenUpdate'] as String))
          : null,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? profilePicture,
    bool? isAdmin,
    List<Address>? addresses,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? fcmToken,
    DateTime? lastTokenUpdate,
  }) => User(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    profilePicture: profilePicture ?? this.profilePicture,
    isAdmin: isAdmin ?? this.isAdmin,
    addresses: addresses ?? this.addresses,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    fcmToken: fcmToken ?? this.fcmToken,
    lastTokenUpdate: lastTokenUpdate ?? this.lastTokenUpdate,
  );
}
