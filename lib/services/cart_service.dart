import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/cart_item_model.dart';

class CartService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'carts';

  Future<List<CartItem>> getCartItems(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('items')
          .get();
      return snapshot.docs.map((doc) => CartItem.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting cart items: $e');
      return [];
    }
  }

  Future<void> addToCart(String userId, CartItem item) async {
    try {
      // Check if item already exists in cart
      final existingDoc = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('items')
          .doc(item.id)
          .get();
      
      if (existingDoc.exists) {
        // Update quantity if item exists
        final existingItem = CartItem.fromJson(existingDoc.data()!);
        final updatedItem = existingItem.copyWith(
          quantity: existingItem.quantity + item.quantity,
          updatedAt: DateTime.now(),
        );
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .collection('items')
            .doc(item.id)
            .update(updatedItem.toJson());
      } else {
        // Add new item
        await _firestore
            .collection(_collectionName)
            .doc(userId)
            .collection('items')
            .doc(item.id)
            .set(item.toJson());
      }
    } catch (e) {
      debugPrint('Error adding to cart: $e');
      rethrow;
    }
  }

  Future<void> updateCartItemQuantity(String userId, String itemId, int quantity) async {
    try {
      if (quantity <= 0) {
        await removeFromCart(userId, itemId);
        return;
      }
      
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('items')
          .doc(itemId)
          .update({
        'quantity': quantity,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error updating cart item quantity: $e');
      rethrow;
    }
  }

  Future<void> removeFromCart(String userId, String itemId) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('items')
          .doc(itemId)
          .delete();
    } catch (e) {
      debugPrint('Error removing from cart: $e');
      rethrow;
    }
  }

  Future<void> clearCart(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .doc(userId)
          .collection('items')
          .get();
      
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error clearing cart: $e');
      rethrow;
    }
  }

  Future<int> getCartItemCount(String userId) async {
    try {
      final items = await getCartItems(userId);
      return items.fold<int>(0, (sum, item) => sum + item.quantity);
    } catch (e) {
      debugPrint('Error getting cart item count: $e');
      return 0;
    }
  }
}
