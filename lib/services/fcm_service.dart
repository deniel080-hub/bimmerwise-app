import 'dart:async';
import 'dart:math';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// FCM Service for handling push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isInitialized = false;

  /// Initialize FCM and request permissions (simplified for iOS and Android)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize local notifications for foreground messages (mobile only)
      if (!kIsWeb) {
        try {
          const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
          const iosSettings = DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          );
          const initSettings = InitializationSettings(
            android: androidSettings,
            iOS: iosSettings,
          );

          await _localNotifications.initialize(
            initSettings,
            onDidReceiveNotificationResponse: _onNotificationTapped,
          ).timeout(const Duration(seconds: 5));

          // Create Android notification channel (will be ignored on iOS)
          const androidChannel = AndroidNotificationChannel(
            'bimmerwise_channel',
            'BIMMERWISE Notifications',
            description: 'Service updates and booking notifications',
            importance: Importance.high,
            playSound: true,
          );

          await _localNotifications
              .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(androidChannel);
          
          debugPrint('✅ Local notifications initialized');
        } catch (e) {
          debugPrint('⚠️ Error initializing local notifications: $e');
          // Don't throw - continue even if local notifications fail
        }
      }

      // Request FCM permissions (this handles both iOS and Android properly)
      try {
        final settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        ).timeout(const Duration(seconds: 5));
        
        debugPrint('✅ FCM Permission status: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('⚠️ Error requesting FCM permissions: $e');
        // Continue anyway - permissions might already be granted
      }

      // Handle foreground messages (when app is open)
      try {
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      } catch (e) {
        debugPrint('⚠️ Error setting up foreground message listener: $e');
      }

      // Handle background message taps
      try {
        FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);
      } catch (e) {
        debugPrint('⚠️ Error setting up background message listener: $e');
      }

      // Check if app was opened from a terminated state notification
      try {
        final initialMessage = await _fcm.getInitialMessage().timeout(const Duration(seconds: 3));
        if (initialMessage != null) {
          debugPrint('📨 App opened from terminated state via notification');
          _handleBackgroundMessageTap(initialMessage);
        }
      } catch (e) {
        debugPrint('⚠️ Error getting initial message: $e');
      }

      // Listen for token refresh
      try {
        _fcm.onTokenRefresh.listen((newToken) {
          debugPrint('🔄 FCM token refreshed: $newToken');
        }, onError: (error) {
          debugPrint('⚠️ Error in token refresh listener: $error');
        });
      } catch (e) {
        debugPrint('⚠️ Error setting up token refresh listener: $e');
      }

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing FCM: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // ALWAYS mark as initialized so app doesn't get stuck
      _isInitialized = true;
    }
  }

  /// Get FCM token for this device (simplified - no platform-specific checks)
  Future<String?> getToken() async {
    try {
      // On web, FCM might not be available
      if (kIsWeb) {
        try {
          final token = await _fcm.getToken(
            vapidKey: 'YOUR_VAPID_KEY_HERE', // Add your VAPID key for web push
          );
          debugPrint('📱 FCM Token (Web): $token');
          return token;
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

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message received: ${message.notification?.title}');
    debugPrint('   - Body: ${message.notification?.body}');
    debugPrint('   - Data: ${message.data}');

    if (message.notification != null) {
      _showLocalNotification(
        title: message.notification!.title ?? 'BIMMERWISE',
        body: message.notification!.body ?? '',
        payload: message.data['bookingId'] ?? message.data['recordId'] ?? '',
      );
    }
  }

  /// Handle background message tap (when user taps notification)
  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('📨 Background message tapped: ${message.notification?.title}');
    debugPrint('   - Data: ${message.data}');
    
    final bookingId = message.data['bookingId'] ?? message.data['recordId'];
    final notificationType = message.data['type'];
    
    debugPrint('   - Booking ID: $bookingId');
    debugPrint('   - Type: $notificationType');
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped');
    debugPrint('   - Payload: ${response.payload}');
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'bimmerwise_channel',
        'BIMMERWISE Notifications',
        channelDescription: 'Service updates and booking notifications',
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        visibility: NotificationVisibility.public,
        ongoing: false,
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
        payload: payload,
      );
      
      debugPrint('✅ Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing local notification: $e');
    }
  }

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
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Background message received: ${message.notification?.title}');
}
