import 'package:cloud_firestore/cloud_firestore.dart';

class ServiceRecord {
  final String id;
  final String vehicleId;
  final String? userId;
  final String serviceType;
  final String description;
  final DateTime serviceDate;
  final double cost;
  final String status;
  final int progress;
  final String? mileage;
  final String? adminNotes;
  final List<String>? attachedImages;
  final bool reminderSent;
  final bool modifiedByAdmin;
  final DateTime createdAt;
  final DateTime updatedAt;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    this.userId,
    required this.serviceType,
    required this.description,
    required this.serviceDate,
    required this.cost,
    required this.status,
    this.progress = 0,
    this.mileage,
    this.adminNotes,
    this.attachedImages,
    this.reminderSent = false,
    this.modifiedByAdmin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicleId': vehicleId,
    if (userId != null) 'userId': userId,
    'serviceType': serviceType,
    'description': description,
    'serviceDate': Timestamp.fromDate(serviceDate),
    'cost': cost,
    'status': status,
    'progress': progress,
    'mileage': mileage,
    'adminNotes': adminNotes,
    'attachedImages': attachedImages,
    'reminderSent': reminderSent,
    'modifiedByAdmin': modifiedByAdmin,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      userId: json['userId'] as String?,
      serviceType: json['serviceType'] as String,
      description: json['description'] as String,
      serviceDate: (json['serviceDate'] is Timestamp)
          ? (json['serviceDate'] as Timestamp).toDate()
          : DateTime.parse(json['serviceDate'] as String),
      cost: (json['cost'] as num).toDouble(),
      status: json['status'] as String,
      progress: (json['progress'] as int?) ?? 0,
      mileage: json['mileage'] as String?,
      adminNotes: json['adminNotes'] as String?,
      attachedImages: (json['attachedImages'] as List<dynamic>?)?.map((e) => e as String).toList(),
      reminderSent: (json['reminderSent'] as bool?) ?? false,
      modifiedByAdmin: (json['modifiedByAdmin'] as bool?) ?? false,
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  ServiceRecord copyWith({
    String? id,
    String? vehicleId,
    String? userId,
    String? serviceType,
    String? description,
    DateTime? serviceDate,
    double? cost,
    String? status,
    int? progress,
    String? mileage,
    String? adminNotes,
    List<String>? attachedImages,
    bool? reminderSent,
    bool? modifiedByAdmin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ServiceRecord(
    id: id ?? this.id,
    vehicleId: vehicleId ?? this.vehicleId,
    userId: userId ?? this.userId,
    serviceType: serviceType ?? this.serviceType,
    description: description ?? this.description,
    serviceDate: serviceDate ?? this.serviceDate,
    cost: cost ?? this.cost,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    mileage: mileage ?? this.mileage,
    adminNotes: adminNotes ?? this.adminNotes,
    attachedImages: attachedImages ?? this.attachedImages,
    reminderSent: reminderSent ?? this.reminderSent,
    modifiedByAdmin: modifiedByAdmin ?? this.modifiedByAdmin,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
