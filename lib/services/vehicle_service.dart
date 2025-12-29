import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';

/// VehicleService manages vehicle data in Firestore
/// All vehicle data is securely stored in Firebase Cloud Firestore
class VehicleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all vehicles (admin only)
  Future<List<Vehicle>> getAllVehicles() async {
    try {
      final snapshot = await _firestore
          .collection('vehicles')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      
      return snapshot.docs.map((doc) => Vehicle.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting all vehicles: $e');
      return [];
    }
  }

  /// Get vehicle by ID
  Future<Vehicle?> getVehicleById(String id) async {
    try {
      final doc = await _firestore.collection('vehicles').doc(id).get();
      if (!doc.exists) return null;
      return Vehicle.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting vehicle by ID: $e');
      return null;
    }
  }

  /// Get vehicles by user ID
  Future<List<Vehicle>> getVehiclesByUserId(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('vehicles')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => Vehicle.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting vehicles by user ID: $e');
      return [];
    }
  }

  /// Add new vehicle
  Future<void> addVehicle(Vehicle vehicle) async {
    try {
      await _firestore.collection('vehicles').doc(vehicle.id).set(vehicle.toJson());
      debugPrint('Vehicle added successfully: ${vehicle.id}');
    } catch (e) {
      debugPrint('Error adding vehicle: $e');
      rethrow;
    }
  }

  /// Update vehicle
  Future<void> updateVehicle(Vehicle vehicle) async {
    try {
      final updatedVehicle = vehicle.copyWith(updatedAt: DateTime.now());
      await _firestore.collection('vehicles').doc(vehicle.id).update(updatedVehicle.toJson());
      debugPrint('Vehicle updated successfully: ${vehicle.id}');
    } catch (e) {
      debugPrint('Error updating vehicle: $e');
      rethrow;
    }
  }

  /// Delete vehicle
  Future<void> deleteVehicle(String id) async {
    try {
      await _firestore.collection('vehicles').doc(id).delete();
      debugPrint('Vehicle deleted successfully: $id');
    } catch (e) {
      debugPrint('Error deleting vehicle: $e');
      rethrow;
    }
  }

  /// Stream of vehicles for a user
  Stream<List<Vehicle>> getVehiclesByUserIdStream(String userId) {
    return _firestore
        .collection('vehicles')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => Vehicle.fromJson(doc.data())).toList());
  }
}
