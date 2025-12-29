import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bimmerwise_connect/models/address_model.dart';
import 'package:bimmerwise_connect/models/cart_item_model.dart';

class Order {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String userPhone;
  final List<CartItem> items;
  final Address shippingAddress;
  final Address billingAddress;
  final String shippingMethod;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.items,
    required this.shippingAddress,
    required this.billingAddress,
    required this.shippingMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'userPhone': userPhone,
    'items': items.map((i) => i.toJson()).toList(),
    'shippingAddress': shippingAddress.toJson(),
    'billingAddress': billingAddress.toJson(),
    'shippingMethod': shippingMethod,
    'status': status,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      userEmail: json['userEmail'] as String,
      userPhone: json['userPhone'] as String,
      items: (json['items'] as List<dynamic>?)
          ?.map((i) => CartItem.fromJson(i as Map<String, dynamic>))
          .toList() ?? [],
      shippingAddress: Address.fromJson(json['shippingAddress'] as Map<String, dynamic>),
      billingAddress: Address.fromJson(json['billingAddress'] as Map<String, dynamic>),
      shippingMethod: json['shippingMethod'] as String,
      status: json['status'] as String,
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Order copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    String? userPhone,
    List<CartItem>? items,
    Address? shippingAddress,
    Address? billingAddress,
    String? shippingMethod,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Order(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    userName: userName ?? this.userName,
    userEmail: userEmail ?? this.userEmail,
    userPhone: userPhone ?? this.userPhone,
    items: items ?? this.items,
    shippingAddress: shippingAddress ?? this.shippingAddress,
    billingAddress: billingAddress ?? this.billingAddress,
    shippingMethod: shippingMethod ?? this.shippingMethod,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);
}
