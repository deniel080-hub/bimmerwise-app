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

  /// Initialize FCM and request permissions
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip FCM initialization on web if not supported
      if (kIsWeb) {
        try {
          // Request notification permissions
          final settings = await _fcm.requestPermission(
            alert: true,
            announcement: false,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          );
          debugPrint('FCM Permission (Web): ${settings.authorizationStatus}');
          
          // If permission denied on web, just mark as initialized and continue
          if (settings.authorizationStatus == AuthorizationStatus.denied || 
              settings.authorizationStatus == AuthorizationStatus.notDetermined) {
            debugPrint('⚠️ FCM notifications not available on web preview. Will work on mobile.');
            _isInitialized = true;
            return;
          }
        } catch (e) {
          debugPrint('⚠️ FCM not available on web: $e');
          _isInitialized = true;
          return;
        }
      } else {
        // Request notification permissions for mobile (including Samsung devices)
        debugPrint('🔔 Requesting FCM permissions for mobile device...');
        final settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        debugPrint('✅ FCM Permission status: ${settings.authorizationStatus}');
        
        // Log additional permission details for Samsung debugging
        debugPrint('   - Alert: ${settings.alert}');
        debugPrint('   - Badge: ${settings.badge}');
        debugPrint('   - Sound: ${settings.sound}');
        
        if (settings.authorizationStatus != AuthorizationStatus.authorized &&
            settings.authorizationStatus != AuthorizationStatus.provisional) {
          debugPrint('⚠️ Notifications not authorized. User needs to enable in system settings.');
        }
      }

      // Initialize local notifications for foreground (with Samsung-specific handling)
      try {
        const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
        const initSettings = InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );

        // Create notification channel for Android (Samsung/other devices)
        if (defaultTargetPlatform == TargetPlatform.android) {
          debugPrint('🤖 Setting up Android notification channel for Samsung/other devices...');
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
          debugPrint('✅ Android notification channel created successfully');
        }
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error initializing local notifications: $e');
        debugPrint('   Stack trace: ${stackTrace.toString().split('\n').take(2).join('\n')}');
        // Don't throw - continue with FCM initialization even if local notifications fail
      }

      // Handle foreground messages (when app is open)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background message taps (when user taps notification while app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

      // Check if app was opened from a terminated state notification
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📨 App opened from terminated state via notification');
        _handleBackgroundMessageTap(initialMessage);
      }

      // Listen for token refresh (important for Samsung devices)
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed: $newToken');
        // Token will be saved when user logs in next time
      });

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized successfully');
      debugPrint('📱 Device is ready to receive push notifications');
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing FCM: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Mark as initialized anyway so app doesn't get stuck
      _isInitialized = true;
    }
  }

  /// Get FCM token for this device
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
      } else {
        // Get token with retry logic for Samsung and iOS devices
        String? token;
        for (int attempt = 1; attempt <= 3; attempt++) {
          try {
            // For iOS, get APNs token first (ONLY on iOS, not Android/Samsung)
            if (defaultTargetPlatform == TargetPlatform.iOS) {
              final apnsToken = await _fcm.getAPNSToken();
              if (apnsToken != null) {
                debugPrint('🍎 APNs Token obtained: ${apnsToken.substring(0, min(20, apnsToken.length))}...');
              } else {
                debugPrint('⚠️ APNs token not available yet (iOS might need permission)');
              }
            } else {
              debugPrint('🤖 Android device detected (Samsung/other), skipping APNs token');
            }
            
            // Get FCM token (works for both iOS and Android)
            token = await _fcm.getToken();
            if (token != null) {
              debugPrint('📱 FCM Token obtained (attempt $attempt): ${token.substring(0, 20)}...');
              return token;
            }
            debugPrint('⚠️ FCM token is null on attempt $attempt, retrying...');
            await Future.delayed(Duration(seconds: attempt));
          } catch (e) {
            debugPrint('⚠️ Error getting FCM token (attempt $attempt): $e');
            if (attempt == 3) {
              // Don't rethrow - return null instead to avoid crash
              debugPrint('❌ Failed to get FCM token after 3 attempts, returning null');
              return null;
            }
          }
        }
        debugPrint('❌ Failed to get FCM token after 3 attempts');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Save FCM token to Firestore user document
  /// Enhanced for Samsung devices with comprehensive error handling
  Future<void> saveTokenToUser(String userId) async {
    try {
      debugPrint('🔑 Attempting to get FCM token for user: $userId');
      
      // Get token with explicit timeout for Samsung devices
      final token = await getToken().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⏱️ FCM token retrieval timeout for user: $userId (Samsung device)');
          return null;
        },
      );
      
      if (token != null && token.isNotEmpty) {
        debugPrint('📱 Got FCM token, saving to Firestore...');
        
        // Use set with merge to avoid update errors if document doesn't have the field yet
        // Add timeout for Firestore write operation (Samsung devices may have network issues)
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⏱️ Firestore write timeout when saving FCM token (Samsung device)');
            throw TimeoutException('Firestore write timeout');
          },
        );
        
        debugPrint('✅ FCM token saved to user document: $userId');
        debugPrint('   Token preview: ${token.substring(0, min(20, token.length))}...');
      } else {
        debugPrint('⚠️ No FCM token available to save for user: $userId (normal on web)');
      }
    } on TimeoutException catch (e) {
      debugPrint('⏱️ Timeout saving FCM token: $e');
      // Don't rethrow - FCM token save should never block user flow
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving FCM token: $e');
      debugPrint('   Stack trace: ${stackTrace.toString().split('\n').take(3).join('\n')}');
      // Don't rethrow - FCM token save should never block user flow
    }
  }

  /// Handle foreground messages (when app is open)
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📨 Foreground message received: ${message.notification?.title}');
    debugPrint('   - Body: ${message.notification?.body}');
    debugPrint('   - Data: ${message.data}');

    if (message.notification != null) {
      // Show local notification even when app is in foreground (Samsung devices need this)
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
    
    // Extract booking/record ID from notification data
    final bookingId = message.data['bookingId'] ?? message.data['recordId'];
    final notificationType = message.data['type'];
    
    debugPrint('   - Booking ID: $bookingId');
    debugPrint('   - Type: $notificationType');
    
    // TODO: Navigate to appropriate screen based on message.data
    // This will be handled by the main app with router navigation
  }

  /// Handle local notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped');
    debugPrint('   - Payload: ${response.payload}');
    
    // TODO: Navigate to appropriate screen based on payload
    // This will be handled by the main app with router navigation
  }

  /// Show local notification (for foreground messages)
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Samsung-optimized notification settings
      const androidDetails = AndroidNotificationDetails(
        'bimmerwise_channel',
        'BIMMERWISE Notifications',
        channelDescription: 'Service updates and booking notifications',
        importance: Importance.max, // Changed from high to max for Samsung
        priority: Priority.max, // Changed from high to max for Samsung
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        // Samsung-specific: Ensure notification shows on lock screen
        visibility: NotificationVisibility.public,
        // Samsung-specific: Keep notification persistent until dismissed
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
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
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
  /// Note: This requires a backend service (Firebase Cloud Functions or your own server)
  /// to actually send the FCM message. This method stores the notification in Firestore
  /// which can trigger a Cloud Function to send the actual push notification.
  Future<void> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Store notification in Firestore
      // Use 'message' field to match AppNotification model, and 'type' field
      await _firestore.collection('notifications').add({
        'userId': userId,
        'title': title,
        'message': body,  // Changed from 'body' to 'message' to match AppNotification model
        'type': data?['type'] ?? 'general',  // Add type field for AppNotification
        'data': data ?? {},
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification stored in Firestore for user: $userId');
      debugPrint('   - Title: $title');
      debugPrint('   - Message: $body');
      debugPrint('   - Type: ${data?['type'] ?? 'general'}');

      // Note: You need to set up a Cloud Function that:
      // 1. Listens to the 'notifications' collection
      // 2. Gets the user's FCM token from the users collection
      // 3. Sends the actual FCM push notification using Firebase Admin SDK
      // 
      // For now, this will work for in-app notifications.
      // For background push notifications, you'll need to set up Cloud Functions.
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
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
  // Handle background notification here if needed
}
