import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';

/// FCM Service - iOS-SAFE implementation
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _done = false;

  /// ✅ iOS-SAFE initialization - call this AFTER first frame with 800ms delay
  Future<void> safeInit() async {
    if (_done) return;

    try {
      final messaging = FirebaseMessaging.instance;

      // ✅ Request iOS permissions FIRST (before any other FCM calls)
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // ✅ Initialize NotificationService (iOS-safe, no Android channel logic)
      await NotificationService().init();

      // ✅ Get FCM token AFTER permissions and init
      final token = await messaging.getToken();
      debugPrint('FCM token: $token');

      // ✅ Set up foreground message listener
      FirebaseMessaging.onMessage.listen((message) {
        NotificationService().show(message);
      });

      _done = true;
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ Web FCM not configured');
        return null;
      }
      
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: ${token.substring(0, min(20, token.length))}...');
      }
      return token;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToUser(String userId) async {
    try {
      final token = await getToken();
      if (token != null && token.isNotEmpty) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM token saved');
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Send notification to user
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,
        'type': data?['type'] ?? 'general',
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notification stored');
    } catch (e) {
      debugPrint('Error sending notification: $e');
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing: $e');
    }
  }
}
