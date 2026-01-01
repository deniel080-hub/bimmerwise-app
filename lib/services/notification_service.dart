import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:bimmerwise_connect/services/fcm_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();

  /// ✅ iOS-SAFE: Minimal init with no platform-specific logic
  Future<void> init() async {
    try {
      // Minimal iOS-safe initialization
      debugPrint('✅ NotificationService initialized');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Get all notifications for a user from Firestore
  Future<List<AppNotification>> getNotificationsByUserId(String userId) async {
    try {
      debugPrint('🔍 Querying ALL notifications for userId: $userId');
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .limit(100)
          .get();
      
      debugPrint('🔍 Query returned ${snapshot.docs.length} documents');
      
      final notifications = snapshot.docs.map((doc) {
        debugPrint('🔍 Processing notification: ${doc.id} - ${doc.data()['title']}');
        final data = doc.data();
        data['id'] = doc.id; // Add document ID
        return AppNotification.fromJson(data);
      }).toList();
      
      // Sort in memory instead of using Firestore orderBy (which requires a composite index)
      notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      debugPrint('🔍 Returning ${notifications.length} parsed notifications');
      return notifications;
    } catch (e) {
      debugPrint('❌ Error getting notifications: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String userId) async {
    try {
      debugPrint('🔍 Querying unread count for userId: $userId');
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      
      debugPrint('🔍 Found ${snapshot.docs.length} unread notifications');
      for (var doc in snapshot.docs) {
        debugPrint('🔍 Unread notification: ${doc.data()['title']} (ID: ${doc.id})');
      }
      
      return snapshot.docs.length;
    } catch (e) {
      debugPrint('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Create a new notification in Firestore
  Future<void> createNotification(AppNotification notification) async {
    try {
      debugPrint('📝 Creating notification in Firestore:');
      debugPrint('   - Title: ${notification.title}');
      debugPrint('   - UserId: ${notification.userId}');
      debugPrint('   - Type: ${notification.type}');
      
      final jsonData = notification.toJson();
      debugPrint('   - JSON: $jsonData');
      
      final docRef = await _firestore.collection('notifications').add(jsonData);
      debugPrint('✅ Notification created with ID: ${docRef.id}');
      
      // Verify it was written
      final verifyDoc = await docRef.get();
      if (verifyDoc.exists) {
        debugPrint('✅ Verified: Notification exists in Firestore');
        debugPrint('   - Data: ${verifyDoc.data()}');
      } else {
        debugPrint('❌ WARNING: Notification was not found after creation!');
      }
    } catch (e) {
      debugPrint('❌ Error creating notification: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// ✅ iOS-SAFE: Show notification - NO Android channel logic
  Future<void> show(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    // Android-only notification display logic would go here
    // iOS handles notifications automatically via system
    debugPrint('📨 Received message: ${message.notification?.title}');
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).update({
        'isRead': true,
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }

  /// Clear all notifications for a user
  /// Uses batching to handle large numbers of notifications (500 per batch max in Firestore)
  Future<void> clearNotificationsByUserId(String userId) async {
    try {
      debugPrint('🗑️ Starting to clear all notifications for user: $userId');
      
      // Query ALL notifications without limit
      final snapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .get();
      
      debugPrint('🗑️ Found ${snapshot.docs.length} notifications to delete');
      
      if (snapshot.docs.isEmpty) {
        debugPrint('✅ No notifications to delete');
        return;
      }
      
      // Firestore batch limit is 500 operations
      const batchSize = 500;
      int deletedCount = 0;
      
      // Process in batches
      for (int i = 0; i < snapshot.docs.length; i += batchSize) {
        final batch = _firestore.batch();
        final endIndex = (i + batchSize < snapshot.docs.length) ? i + batchSize : snapshot.docs.length;
        
        for (int j = i; j < endIndex; j++) {
          batch.delete(snapshot.docs[j].reference);
          deletedCount++;
        }
        
        await batch.commit();
        debugPrint('🗑️ Deleted batch: $deletedCount/${snapshot.docs.length} notifications');
      }
      
      debugPrint('✅ Successfully deleted $deletedCount notifications for user: $userId');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing notifications: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow; // Re-throw to let UI handle the error
    }
  }

  /// Send service completion notification with push notification
  Future<void> sendServiceCompletionNotification({
    required String userId,
    required String userEmail,
    required String serviceName,
    required String vehicleInfo,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: 'Service Completed! 🎉',
      message: 'Your $serviceName for $vehicleInfo has been completed and is ready for pickup.',
      type: NotificationType.serviceComplete,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    
    // Send push notification via FCM
    await _fcmService.sendNotificationToUser(
      userId: userId,
      title: 'Service Completed! 🎉',
      body: 'Your $serviceName for $vehicleInfo is ready for pickup.',
      data: {
        'type': 'service_complete',
        'serviceName': serviceName,
        'vehicleInfo': vehicleInfo,
      },
    );
    
    debugPrint('📧 Notification sent to user: $userEmail');
  }

  /// Send registration welcome notification
  Future<void> sendRegistrationNotification({
    required String userId,
    required String userEmail,
    required String userName,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: 'Welcome to BIMMERWISE! 👋',
      message: 'Thank you for registering, $userName. Your account has been created successfully.',
      type: NotificationType.general,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    
    // Send push notification
    await _fcmService.sendNotificationToUser(
      userId: userId,
      title: 'Welcome to BIMMERWISE! 👋',
      body: 'Thank you for registering, $userName!',
      data: {'type': 'welcome'},
    );
    
    debugPrint('📧 Welcome notification sent to: $userEmail');
  }

  /// Send booking created notification to ALL admin users
  Future<void> sendBookingCreatedNotificationToAllAdmins({
    required String bookingId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
    required DateTime bookingDate,
  }) async {
    try {
      // Get all admin users from UserService
      final userService = UserService();
      final adminUsers = await userService.getAllAdminUsers();
      
      if (adminUsers.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return;
      }

      debugPrint('📧 Sending booking notifications to ${adminUsers.length} admin users');
      
      // Send notification to each admin user
      for (var admin in adminUsers) {
        final notification = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: admin.id,
          title: '🔔 New Booking',
          message: '$customerName booked $serviceName for $vehicleInfo on ${_formatDateTime(bookingDate)}',
          type: NotificationType.bookingCreated,
          isRead: false,
          createdAt: DateTime.now(),
          bookingId: bookingId,
        );
        
        await createNotification(notification);
        
        // Send push notification via FCM
        await _fcmService.sendNotificationToUser(
          userId: admin.id,
          title: '🔔 New Booking',
          body: '$customerName booked $serviceName for $vehicleInfo',
          data: {
            'type': 'new_booking',
            'bookingId': bookingId,
            'customerName': customerName,
            'serviceName': serviceName,
          },
        );
        
        debugPrint('✅ Notification sent to admin: ${admin.email}');
      }
      
      debugPrint('✅ All admin notifications sent for booking from $customerName ($customerEmail)');
    } catch (e) {
      debugPrint('❌ Error sending admin notifications: $e');
    }
  }

  /// Send booking created notification to admin (deprecated - use sendBookingCreatedNotificationToAllAdmins)
  @Deprecated('Use sendBookingCreatedNotificationToAllAdmins instead')
  Future<void> sendBookingCreatedNotificationToAdmin({
    required String adminUserId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
    required DateTime bookingDate,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: adminUserId,
      title: 'New Booking Created',
      message: '$customerName has booked $serviceName for $vehicleInfo on ${_formatDateTime(bookingDate)}.',
      type: NotificationType.bookingCreated,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    debugPrint('📧 Admin notification: New booking from $customerName ($customerEmail) for $serviceName');
  }

  /// Send booking modified notification to ALL admin users
  Future<void> sendBookingModifiedNotificationToAllAdmins({
    required String bookingId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
    required DateTime newBookingDate,
  }) async {
    try {
      final userService = UserService();
      final adminUsers = await userService.getAllAdminUsers();
      
      if (adminUsers.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return;
      }

      debugPrint('📧 Sending booking modification notifications to ${adminUsers.length} admin users');
      
      for (var admin in adminUsers) {
        final notification = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: admin.id,
          title: '🔄 Booking Modified',
          message: '$customerName modified $serviceName for $vehicleInfo. New date: ${_formatDateTime(newBookingDate)}',
          type: NotificationType.bookingModified,
          isRead: false,
          createdAt: DateTime.now(),
          bookingId: bookingId,
        );
        
        await createNotification(notification);
        
        await _fcmService.sendNotificationToUser(
          userId: admin.id,
          title: '🔄 Booking Modified',
          body: '$customerName modified their $serviceName booking',
          data: {
            'type': 'booking_modified',
            'bookingId': bookingId,
            'customerName': customerName,
          },
        );
        
        debugPrint('✅ Notification sent to admin: ${admin.email}');
      }
      
      debugPrint('✅ All admin notifications sent for booking modification by $customerName');
    } catch (e) {
      debugPrint('❌ Error sending admin modification notifications: $e');
    }
  }

  /// Send booking canceled notification to ALL admin users
  Future<void> sendBookingCanceledNotificationToAllAdmins({
    required String bookingId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
  }) async {
    try {
      final userService = UserService();
      final adminUsers = await userService.getAllAdminUsers();
      
      if (adminUsers.isEmpty) {
        debugPrint('⚠️ No admin users found to notify');
        return;
      }

      debugPrint('📧 Sending booking cancellation notifications to ${adminUsers.length} admin users');
      
      for (var admin in adminUsers) {
        final notification = AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          userId: admin.id,
          title: '❌ Booking Canceled',
          message: '$customerName canceled $serviceName for $vehicleInfo',
          type: NotificationType.bookingCanceled,
          isRead: false,
          createdAt: DateTime.now(),
          bookingId: bookingId,
        );
        
        await createNotification(notification);
        
        await _fcmService.sendNotificationToUser(
          userId: admin.id,
          title: '❌ Booking Canceled',
          body: '$customerName canceled their $serviceName booking',
          data: {
            'type': 'booking_canceled',
            'bookingId': bookingId,
            'customerName': customerName,
          },
        );
        
        debugPrint('✅ Notification sent to admin: ${admin.email}');
      }
      
      debugPrint('✅ All admin notifications sent for booking cancellation by $customerName');
    } catch (e) {
      debugPrint('❌ Error sending admin cancellation notifications: $e');
    }
  }

  /// Send booking modified notification to admin (deprecated - use sendBookingModifiedNotificationToAllAdmins)
  @Deprecated('Use sendBookingModifiedNotificationToAllAdmins instead')
  Future<void> sendBookingModifiedNotificationToAdmin({
    required String adminUserId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
    required DateTime newBookingDate,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: adminUserId,
      title: 'Booking Modified by Customer',
      message: '$customerName has modified their booking for $serviceName ($vehicleInfo). New date: ${_formatDateTime(newBookingDate)}. Please confirm.',
      type: NotificationType.bookingModified,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    debugPrint('📧 Admin notification: Booking modified by $customerName ($customerEmail)');
  }

  /// Send booking canceled notification to admin (deprecated - use sendBookingCanceledNotificationToAllAdmins)
  @Deprecated('Use sendBookingCanceledNotificationToAllAdmins instead')
  Future<void> sendBookingCanceledNotificationToAdmin({
    required String adminUserId,
    required String customerName,
    required String customerEmail,
    required String serviceName,
    required String vehicleInfo,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: adminUserId,
      title: 'Booking Canceled by Customer',
      message: '$customerName has canceled their booking for $serviceName ($vehicleInfo).',
      type: NotificationType.bookingCanceled,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    debugPrint('📧 Admin notification: Booking canceled by $customerName ($customerEmail)');
  }

  /// Send admin modification notification to user
  Future<void> sendAdminModifiedNotificationToUser({
    required String userId,
    required String userEmail,
    required String serviceName,
    required String vehicleInfo,
    required String newStatus,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: 'Booking Updated 🔄',
      message: 'Your booking for $serviceName ($vehicleInfo) has been updated. New status: $newStatus.',
      type: NotificationType.adminModified,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    
    // Send push notification
    await _fcmService.sendNotificationToUser(
      userId: userId,
      title: 'Booking Updated 🔄',
      body: 'Your $serviceName booking status: $newStatus',
      data: {
        'type': 'booking_updated',
        'status': newStatus,
      },
    );
    
    debugPrint('📧 Notification sent to: $userEmail');
  }

  /// Send admin cancellation notification to user
  Future<void> sendAdminCanceledNotificationToUser({
    required String userId,
    required String userEmail,
    required String serviceName,
    required String vehicleInfo,
  }) async {
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      title: 'Booking Canceled ❌',
      message: 'Your booking for $serviceName ($vehicleInfo) has been canceled by the admin. Please contact us for more information.',
      type: NotificationType.adminCanceled,
      isRead: false,
      createdAt: DateTime.now(),
    );
    
    await createNotification(notification);
    
    // Send push notification via FCM
    await _fcmService.sendNotificationToUser(
      userId: userId,
      title: 'Booking Canceled ❌',
      body: 'Your $serviceName booking has been canceled. Please contact us.',
      data: {
        'type': 'admin_canceled',
        'serviceName': serviceName,
      },
    );
    
    debugPrint('📧 Notification sent to $userEmail: Your booking for $serviceName has been canceled');
  }

  /// Format date time for display
  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Stream notifications for real-time updates
  /// Enhanced with error handling to prevent crashes from corrupted data on Samsung devices
  Stream<List<AppNotification>> streamNotificationsByUserId(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .limit(100)
        .snapshots()
        .handleError((error, stackTrace) {
          debugPrint('❌ Error in notification stream: $error');
          debugPrint('❌ Stack trace: $stackTrace');
          // Return empty stream on error to prevent crash
        })
        .map((snapshot) {
      final notifications = <AppNotification>[];
      
      // Process each document with individual error handling to skip corrupted data
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final notification = AppNotification.fromJson(data);
          notifications.add(notification);
        } catch (e) {
          debugPrint('⚠️ Skipping corrupted notification document ${doc.id}: $e');
          // Continue processing other documents instead of crashing
        }
      }
      
      // Sort in memory instead of using Firestore orderBy
      try {
        notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      } catch (e) {
        debugPrint('⚠️ Error sorting notifications: $e');
        // Continue with unsorted list instead of crashing
      }
      
      return notifications;
    });
  }
}

/// Notification model
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String message;
  final NotificationType type;
  final bool isRead;
  final DateTime createdAt;
  final String? bookingId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.bookingId,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'title': title,
    'message': message,
    'type': type.name,
    'isRead': isRead,
    'createdAt': Timestamp.fromDate(createdAt),
    if (bookingId != null) 'bookingId': bookingId,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    DateTime createdAt;
    if (json['createdAt'] is Timestamp) {
      createdAt = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      createdAt = DateTime.parse(json['createdAt'] as String);
    } else {
      createdAt = DateTime.now();
    }

    // Handle both 'message' and 'body' fields for backward compatibility
    final message = (json['message'] as String?) ?? (json['body'] as String?) ?? 'No message';

    return AppNotification(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String? ?? 'Notification',
      message: message,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      isRead: json['isRead'] as bool? ?? false,
      createdAt: createdAt,
      bookingId: json['bookingId'] as String?,
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    NotificationType? type,
    bool? isRead,
    DateTime? createdAt,
    String? bookingId,
  }) => AppNotification(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    title: title ?? this.title,
    message: message ?? this.message,
    type: type ?? this.type,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt ?? this.createdAt,
    bookingId: bookingId ?? this.bookingId,
  );
}

/// Notification types
enum NotificationType {
  general,
  serviceComplete,
  reminder,
  promotion,
  bookingCreated,
  bookingModified,
  bookingCanceled,
  adminModified,
  adminCanceled,
}
