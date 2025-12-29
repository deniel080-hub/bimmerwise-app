import 'package:cloud_firestore/cloud_firestore.dart';

class ProductVariant {
  final String id;
  final String name;
  final String imageUrl;
  final int stock;

  ProductVariant({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.stock,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'imageUrl': imageUrl,
    'stock': stock,
  };

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      stock: json['stock'] as int? ?? 0,
    );
  }

  ProductVariant copyWith({
    String? id,
    String? name,
    String? imageUrl,
    int? stock,
  }) => ProductVariant(
    id: id ?? this.id,
    name: name ?? this.name,
    imageUrl: imageUrl ?? this.imageUrl,
    stock: stock ?? this.stock,
  );
}

class Product {
  final String id;
  final String name;
  final String category;
  final String description;
  final String compatibility;
  final List<ProductVariant> variants;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.compatibility,
    required this.variants,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
    'compatibility': compatibility,
    'variants': variants.map((v) => v.toJson()).toList(),
    'note': note,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      compatibility: json['compatibility'] as String,
      variants: (json['variants'] as List<dynamic>?)
          ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
          .toList() ?? [],
      note: json['note'] as String? ?? '',
      createdAt: (json['createdAt'] is Timestamp)
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: (json['updatedAt'] is Timestamp)
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? description,
    String? compatibility,
    List<ProductVariant>? variants,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Product(
    id: id ?? this.id,
    name: name ?? this.name,
    category: category ?? this.category,
    description: description ?? this.description,
    compatibility: compatibility ?? this.compatibility,
    variants: variants ?? this.variants,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
