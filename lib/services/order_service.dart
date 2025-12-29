import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/order_model.dart' as order_model;

class OrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'orders';

  Future<List<order_model.Order>> getAllOrders() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      return snapshot.docs.map((doc) => order_model.Order.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all orders: $e');
      return [];
    }
  }

  Future<order_model.Order?> getOrderById(String orderId) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(orderId).get();
      if (doc.exists) {
        return order_model.Order.fromJson(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting order by ID: $e');
      return null;
    }
  }

  Future<List<order_model.Order>> getOrdersByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .get();
      return snapshot.docs.map((doc) => order_model.Order.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting orders by user ID: $e');
      return [];
    }
  }

  Future<void> createOrder(order_model.Order order) async {
    try {
      await _firestore.collection(_collectionName).doc(order.id).set(order.toJson());
    } catch (e) {
      debugPrint('Error creating order: $e');
      rethrow;
    }
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection(_collectionName).doc(orderId).update({
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      debugPrint('Error updating order status: $e');
      rethrow;
    }
  }

  Future<void> deleteOrder(String orderId) async {
    try {
      await _firestore.collection(_collectionName).doc(orderId).delete();
    } catch (e) {
      debugPrint('Error deleting order: $e');
      rethrow;
    }
  }
}
