import 'package:cloud_firestore/cloud_firestore.dart';

class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String variantId;
  final String variantName;
  final String variantImageUrl;
  final int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantName,
    required this.variantImageUrl,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'productId': productId,
    'productName': productName,
    'variantId': variantId,
    'variantName': variantName,
    'variantImageUrl': variantImageUrl,
    'quantity': quantity,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      variantId: json['variantId'] as String,
      variantName: json['variantName'] as String,
      variantImageUrl: json['variantImageUrl'] as String,
      quantity: json['quantity'] as int,
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  CartItem copyWith({
    String? id,
    String? productId,
    String? productName,
    String? variantId,
    String? variantName,
    String? variantImageUrl,
    int? quantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CartItem(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    variantId: variantId ?? this.variantId,
    variantName: variantName ?? this.variantName,
    variantImageUrl: variantImageUrl ?? this.variantImageUrl,
    quantity: quantity ?? this.quantity,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
