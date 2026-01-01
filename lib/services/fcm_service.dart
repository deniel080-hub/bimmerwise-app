import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FCM Service for handling push notifications
/// iOS-SAFE: No local notifications plugin to prevent crashes
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Request FCM permissions after first frame is rendered
  /// Call this from postFrameCallback to ensure UI is ready
  void requestPermissionsAfterFirstFrame() {
    // Fire and forget - don't await, don't block
    _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    ).timeout(const Duration(seconds: 10)).then((settings) {
      debugPrint('✅ FCM Permission status: ${settings.authorizationStatus}');
    }).catchError((e, stackTrace) {
      debugPrint('⚠️ Error requesting FCM permissions: $e');
      // Don't crash - just log
      return null;
    });
  }

  /// Initialize FCM WITHOUT requesting permissions (Samsung-safe - no local notifications)
  /// Permissions should be requested separately after first frame using postFrameCallback
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ FCM already initialized, skipping');
      return;
    }

    try {
      debugPrint('🚀 Initializing FCM Service (Samsung-safe mode)...');
      debugPrint('📌 Note: Permissions will be requested after first frame via postFrameCallback');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error during FCM initialization: $e');
      debugPrint('⚠️ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    }

    try {
      // Handle foreground messages (when app is open) - SIMPLIFIED & SAMSUNG-SAFE
      try {
        FirebaseMessaging.onMessage.listen(
          (message) {
            debugPrint('📨 Foreground message: ${message.notification?.title}');
            // Store in Firestore only - no local notifications to avoid Samsung crashes
          },
          onError: (error, stackTrace) {
            debugPrint('⚠️ Foreground message error: $error');
            // Don't crash - just log
          },
          cancelOnError: false, // Keep stream active even after errors
        );
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error setting up foreground listener: $e');
        debugPrint('⚠️ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }

      // Handle background message taps - SAMSUNG-SAFE
      try {
        FirebaseMessaging.onMessageOpenedApp.listen(
          _handleBackgroundMessageTap,
          onError: (error, stackTrace) {
            debugPrint('⚠️ Background tap error: $error');
            // Don't crash - just log
          },
          cancelOnError: false,
        );
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error setting up background listener: $e');
        debugPrint('⚠️ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }

      // Check if app was opened from a terminated state notification - SAMSUNG-SAFE
      try {
        final initialMessage = await _fcm.getInitialMessage().timeout(const Duration(seconds: 5));
        if (initialMessage != null) {
          debugPrint('📨 App opened from notification');
          _handleBackgroundMessageTap(initialMessage);
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error getting initial message: $e');
        debugPrint('⚠️ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }

      // Listen for token refresh - SAMSUNG-SAFE
      try {
        _fcm.onTokenRefresh.listen(
          (newToken) {
            debugPrint('🔄 FCM token refreshed');
          },
          onError: (error, stackTrace) {
            debugPrint('⚠️ Token refresh error: $error');
            // Don't crash - just log
          },
          cancelOnError: false,
        );
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error setting up token refresh: $e');
        debugPrint('⚠️ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      }

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized (Samsung-safe mode)');
    } catch (e, stackTrace) {
      debugPrint('❌ FCM initialization error: $e');
      debugPrint('❌ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      // ALWAYS mark as initialized to prevent crash loops on Samsung devices
      _isInitialized = true;
    }
  }

  /// Get FCM token for this device (simplified - no platform-specific checks)
  Future<String?> getToken() async {
    try {
      // On web, FCM might not be available
      if (kIsWeb) {
        try {
          // Web push requires VAPID key - skip for now if not configured
          debugPrint('⚠️ Web FCM not configured (VAPID key required)');
          return null;
        } catch (e) {
          debugPrint('⚠️ FCM token not available on web: $e');
          return null;
        }
      }
      
      // Mobile (iOS and Android) - let Firebase SDK handle platform differences
      String? token;
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          token = await _fcm.getToken().timeout(const Duration(seconds: 8));
          if (token != null) {
            debugPrint('📱 FCM Token obtained (attempt $attempt): ${token.substring(0, min(20, token.length))}...');
            return token;
          }
          debugPrint('⚠️ FCM token is null on attempt $attempt, retrying...');
          await Future.delayed(Duration(seconds: attempt));
        } catch (e) {
          debugPrint('⚠️ Error getting FCM token (attempt $attempt): $e');
          if (attempt == 3) {
            debugPrint('❌ Failed to get FCM token after 3 attempts');
            return null;
          }
          await Future.delayed(Duration(seconds: attempt));
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore user document
  Future<void> saveTokenToUser(String userId) async {
    try {
      debugPrint('🔑 Attempting to get FCM token for user: $userId');
      
      final token = await getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏱️ FCM token retrieval timeout for user: $userId');
          return null;
        },
      );
      
      if (token != null && token.isNotEmpty) {
        debugPrint('📱 Got FCM token, saving to Firestore...');
        
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏱️ Firestore write timeout when saving FCM token');
            throw TimeoutException('Firestore write timeout');
          },
        );
        
        debugPrint('✅ FCM token saved to user document: $userId');
      } else {
        debugPrint('⚠️ No FCM token available to save for user: $userId');
      }
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout saving FCM token: $e');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Handle foreground messages (when app is open) - REMOVED to avoid Samsung crashes
  /// Notifications are now stored in Firestore and displayed in-app only

  /// Handle background message tap (when user taps notification) - SAMSUNG-SAFE
  void _handleBackgroundMessageTap(RemoteMessage message) {
    try {
      debugPrint('📨 Background message tapped: ${message.notification?.title}');
      debugPrint('   - Data: ${message.data}');
      
      final bookingId = message.data['bookingId'] ?? message.data['recordId'];
      final notificationType = message.data['type'];
      
      debugPrint('   - Booking ID: $bookingId');
      debugPrint('   - Type: $notificationType');
    } catch (e, stackTrace) {
      // CRITICAL: Never throw from notification handler - causes Samsung crash loops
      debugPrint('❌ Error handling background message tap: $e');
      debugPrint('❌ Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
    }
  }

  /// Local notifications REMOVED to avoid iOS & Samsung crashes
  /// All notifications are stored in Firestore and shown in-app only

  /// Send notification to a specific user via FCM
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

      debugPrint('✅ Notification stored in Firestore for user: $userId');
      debugPrint('   - Title: $title');
      debugPrint('   - Message: $body');
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  /// Subscribe to topic (for broadcast notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }
}

/// Background message handler (must be top-level function)
/// ULTRA-MINIMAL: No Firebase init, no async work, no conditional logic
/// Prevents background isolate deadlock that causes black screen on iOS
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // DO NOT initialize Firebase here - already done in main()
  // DO NOT do any async work - causes deadlock
  // Just return immediately - no logic whatsoever
  return;
}
