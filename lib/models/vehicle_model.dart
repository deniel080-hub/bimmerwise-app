import 'package:cloud_firestore/cloud_firestore.dart';

class Vehicle {
  final String id;
  final String userId;
  final String model;
  final String year;
  final String vin;
  final String licensePlate;
  final String color;
  final String? engineSize;
  final String? fuelType;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.userId,
    required this.model,
    required this.year,
    required this.vin,
    required this.licensePlate,
    required this.color,
    this.engineSize,
    this.fuelType,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'model': model,
    'year': year,
    'vin': vin,
    'licensePlate': licensePlate,
    'color': color,
    'engineSize': engineSize,
    'fuelType': fuelType,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as String,
      userId: json['userId'] as String,
      model: json['model'] as String,
      year: json['year'] as String,
      vin: json['vin'] as String,
      licensePlate: json['licensePlate'] as String,
      color: json['color'] as String,
      engineSize: json['engineSize'] as String?,
      fuelType: json['fuelType'] as String?,
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Vehicle copyWith({
    String? id,
    String? userId,
    String? model,
    String? year,
    String? vin,
    String? licensePlate,
    String? color,
    String? engineSize,
    String? fuelType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Vehicle(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    model: model ?? this.model,
    year: year ?? this.year,
    vin: vin ?? this.vin,
    licensePlate: licensePlate ?? this.licensePlate,
    color: color ?? this.color,
    engineSize: engineSize ?? this.engineSize,
    fuelType: fuelType ?? this.fuelType,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
