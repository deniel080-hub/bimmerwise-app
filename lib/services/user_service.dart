import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/user_model.dart';

/// UserService manages user data in Firestore
/// All user data is securely stored in Firebase Cloud Firestore
class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all users (admin only)
  Future<List<User>> getAllUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      return snapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all users: $e');
      return [];
    }
  }

  /// Get user by ID
  Future<User?> getUserById(String id) async {
    try {
      final doc = await _firestore.collection('users').doc(id).get();
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting user by ID: $e');
      return null;
    }
  }

  /// Update user data
  Future<void> updateUser(User user) async {
    try {
      final updatedUser = user.copyWith(updatedAt: DateTime.now());
      await _firestore.collection('users').doc(user.id).update(updatedUser.toJson());
      debugPrint('User updated successfully: ${user.id}');
    } catch (e) {
      debugPrint('Error updating user: $e');
      rethrow;
    }
  }

  /// Delete user
  Future<void> deleteUser(String id) async {
    try {
      await _firestore.collection('users').doc(id).delete();
      debugPrint('User deleted successfully: $id');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      rethrow;
    }
  }

  /// Get user by email
  Future<User?> getUserByEmail(String email) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.toLowerCase())
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      return User.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error getting user by email: $e');
      return null;
    }
  }

  /// Stream of user data for real-time updates
  Stream<User?> getUserStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return User.fromJson(doc.data()!);
    });
  }

  /// Get all admin users
  Future<List<User>> getAllAdminUsers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('isAdmin', isEqualTo: true)
          .get();
      
      final admins = snapshot.docs.map((doc) => User.fromJson(doc.data())).toList();
      debugPrint('Found ${admins.length} admin users');
      return admins;
    } catch (e) {
      debugPrint('Error getting admin users: $e');
      return [];
    }
  }
}
