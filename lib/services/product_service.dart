import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/product_model.dart';

class ProductService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'products';

  Future<List<Product>> getAllProducts() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all products: $e');
      return [];
    }
  }

  Future<Product?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(productId).get();
      if (doc.exists) {
        return Product.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting product by ID: $e');
      return null;
    }
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) => Product.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting products by category: $e');
      return [];
    }
  }

  Future<void> addProduct(Product product) async {
    try {
      debugPrint('🔄 Attempting to add product: ${product.name} (ID: ${product.id})');
      final data = product.toJson();
      debugPrint('📦 Product data: $data');
      await _firestore.collection(_collectionName).doc(product.id).set(data);
      debugPrint('✅ Product added successfully');
    } catch (e) {
      debugPrint('❌ Error adding product: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> updateProduct(Product product) async {
    try {
      await _firestore.collection(_collectionName).doc(product.id).update(product.toJson());
    } catch (e) {
      debugPrint('Error updating product: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      await _firestore.collection(_collectionName).doc(productId).delete();
    } catch (e) {
      debugPrint('Error deleting product: $e');
      rethrow;
    }
  }

  Future<void> updateVariantStock(String productId, String variantId, int newStock) async {
    try {
      final product = await getProductById(productId);
      if (product != null) {
        final updatedVariants = product.variants.map((v) {
          if (v.id == variantId) {
            return v.copyWith(stock: newStock);
          }
          return v;
        }).toList();
        
        final updatedProduct = product.copyWith(
          variants: updatedVariants,
          updatedAt: DateTime.now(),
        );
        
        await updateProduct(updatedProduct);
      }
    } catch (e) {
      debugPrint('Error updating variant stock: $e');
      rethrow;
    }
  }
}
