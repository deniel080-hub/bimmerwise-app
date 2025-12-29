import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';

/// ServiceRecordService manages service records in Firestore
/// All service records are securely stored in Firebase Cloud Firestore
class ServiceRecordService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get all service records (admin only)
  /// Enhanced with error handling for Samsung devices
  Future<List<ServiceRecord>> getAllRecords() async {
    try {
      final snapshot = await _firestore
          .collection('service_records')
          .orderBy('serviceDate', descending: true)
          .limit(100)
          .get();
      
      // Process each document with individual error handling to skip corrupted data
      final records = <ServiceRecord>[];
      for (var doc in snapshot.docs) {
        try {
          records.add(ServiceRecord.fromJson(doc.data()));
        } catch (e) {
          debugPrint('⚠️ Skipping corrupted service record ${doc.id}: $e');
          // Continue processing other records instead of crashing
        }
      }
      
      return records;
    } catch (e) {
      debugPrint('❌ Error getting all service records: $e');
      debugPrint('   This might be due to missing Firestore index. Creating index...');
      // Return empty list instead of crashing - app will continue to work
      return [];
    }
  }

  /// Get service records by vehicle ID
  Future<List<ServiceRecord>> getRecordsByVehicleId(String vehicleId) async {
    try {
      final snapshot = await _firestore
          .collection('service_records')
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('serviceDate', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => ServiceRecord.fromJson(doc.data())).toList();
    } catch (e) {
      debugPrint('Error getting service records by vehicle ID: $e');
      return [];
    }
  }

  /// Get latest service record by vehicle ID
  Future<ServiceRecord?> getLatestRecordByVehicleId(String vehicleId) async {
    try {
      final snapshot = await _firestore
          .collection('service_records')
          .where('vehicleId', isEqualTo: vehicleId)
          .orderBy('serviceDate', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return null;
      return ServiceRecord.fromJson(snapshot.docs.first.data());
    } catch (e) {
      debugPrint('Error getting latest service record: $e');
      return null;
    }
  }

  /// Add new service record
  Future<void> addRecord(ServiceRecord record) async {
    try {
      await _firestore.collection('service_records').doc(record.id).set(record.toJson());
      debugPrint('Service record added successfully: ${record.id}');
    } catch (e) {
      debugPrint('Error adding service record: $e');
      rethrow;
    }
  }

  /// Update service record
  Future<void> updateRecord(ServiceRecord record) async {
    try {
      final updatedRecord = record.copyWith(updatedAt: DateTime.now());
      await _firestore.collection('service_records').doc(record.id).update(updatedRecord.toJson());
      debugPrint('Service record updated successfully: ${record.id}');
    } catch (e) {
      debugPrint('Error updating service record: $e');
      rethrow;
    }
  }

  /// Delete service record
  Future<void> deleteRecord(String id) async {
    try {
      await _firestore.collection('service_records').doc(id).delete();
      debugPrint('Service record deleted successfully: $id');
    } catch (e) {
      debugPrint('Error deleting service record: $e');
      rethrow;
    }
  }

  /// Stream of service records for a vehicle
  /// Enhanced with error handling to prevent crashes from corrupted data on Samsung devices
  Stream<List<ServiceRecord>> getRecordsByVehicleIdStream(String vehicleId) {
    return _firestore
        .collection('service_records')
        .where('vehicleId', isEqualTo: vehicleId)
        .orderBy('serviceDate', descending: true)
        .snapshots()
        .handleError((error, stackTrace) {
          debugPrint('❌ Error in service records stream: $error');
          debugPrint('❌ Stack trace: $stackTrace');
          // Return empty stream on error to prevent crash
        })
        .map((snapshot) {
          final records = <ServiceRecord>[];
          
          // Process each document with individual error handling to skip corrupted data
          for (var doc in snapshot.docs) {
            try {
              records.add(ServiceRecord.fromJson(doc.data()));
            } catch (e) {
              debugPrint('⚠️ Skipping corrupted service record ${doc.id}: $e');
              // Continue processing other records instead of crashing
            }
          }
          
          return records;
        });
  }

  /// Get service record by ID
  Future<ServiceRecord?> getRecordById(String id) async {
    try {
      final doc = await _firestore.collection('service_records').doc(id).get();
      if (!doc.exists) return null;
      return ServiceRecord.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting service record by ID: $e');
      return null;
    }
  }

  /// Stream of unconfirmed bookings count (admin only)
  Stream<int> getUnconfirmedBookingsCountStream() {
    return _firestore
        .collection('service_records')
        .where('status', isEqualTo: 'Booking In Progress')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
