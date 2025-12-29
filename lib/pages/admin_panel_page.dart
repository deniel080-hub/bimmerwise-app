import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:bimmerwise_connect/models/vehicle_model.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:file_picker/file_picker.dart';

class AdminPanelPage extends StatefulWidget {
  final String? highlightBookingId;

  const AdminPanelPage({super.key, this.highlightBookingId});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  List<User> _users = [];
  Map<String, List<Vehicle>> _userVehicles = {};
  Map<String, List<ServiceRecord>> _userServiceRecords = {};
  bool _isLoading = true;
  String? _currentAdminId;
  int _unreadNotificationCount = 0;
  StreamSubscription<List<AppNotification>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initializeAdminNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeAdminNotifications() async {
    try {
      // Get current admin user ID with timeout for Samsung devices
      final authService = AuthService();
      final adminUser = await authService.getCurrentUserData().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Timeout getting admin user data on Samsung device');
          return null;
        },
      );
      
      if (adminUser != null && adminUser.isAdmin) {
        if (mounted) {
          setState(() => _currentAdminId = adminUser.id);
        }
        
        // Load initial unread count with timeout and error handling
        try {
          final notificationService = NotificationService();
          final unreadCount = await notificationService.getUnreadCount(adminUser.id).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ Timeout loading notification count');
              return 0;
            },
          );
          if (mounted) {
            setState(() => _unreadNotificationCount = unreadCount);
          }
          
          // Listen to notification changes with comprehensive error handling for Samsung devices
          _notificationSubscription = notificationService
              .streamNotificationsByUserId(adminUser.id)
              .listen(
                (notifications) {
                  if (mounted) {
                    final unreadCount = notifications.where((n) => !n.isRead).length;
                    setState(() => _unreadNotificationCount = unreadCount);
                  }
                },
                onError: (error, stackTrace) {
                  debugPrint('❌ Error in notification stream: $error');
                  debugPrint('❌ Stack trace: $stackTrace');
                  // Don't crash - just log the error and continue
                  if (mounted) {
                    setState(() => _unreadNotificationCount = 0);
                  }
                },
                cancelOnError: false, // Don't cancel stream on error, keep trying
              );
        } catch (e, stackTrace) {
          debugPrint('❌ Error loading notifications: $e');
          debugPrint('❌ Stack trace: $stackTrace');
          // Continue without notifications - don't block admin panel
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing admin notifications: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      // Don't crash - continue without notification support
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userService = UserService();
      final vehicleService = VehicleService();
      final serviceRecordService = ServiceRecordService();

      // Add timeout for getting all users - critical for Samsung devices
      debugPrint('📊 Loading users...');
      final users = await userService.getAllUsers().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ Timeout loading users on Samsung device');
          return <User>[];
        },
      );
      debugPrint('📊 Loaded ${users.length} users');

      final Map<String, List<Vehicle>> vehicles = {};
      final Map<String, List<ServiceRecord>> records = {};

      // Load data for each user with individual timeouts to prevent cascade failures
      for (var user in users) {
        if (!mounted) return; // Check if widget is still mounted
        
        try {
          // Add timeout for vehicle loading
          final userVehicles = await vehicleService.getVehiclesByUserId(user.id).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ Timeout loading vehicles for user ${user.id}');
              return <Vehicle>[];
            },
          );
          vehicles[user.id] = userVehicles;

          final List<ServiceRecord> userRecords = [];
          for (var vehicle in userVehicles) {
            if (!mounted) return; // Check if widget is still mounted
            
            try {
              // Add timeout for service record loading
              final vehicleRecords = await serviceRecordService.getRecordsByVehicleId(vehicle.id).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⚠️ Timeout loading records for vehicle ${vehicle.id}');
                  return <ServiceRecord>[];
                },
              );
              userRecords.addAll(vehicleRecords);
            } catch (e) {
              debugPrint('❌ Error loading records for vehicle ${vehicle.id}: $e');
              // Continue loading other records
            }
          }
          records[user.id] = userRecords;
        } catch (e) {
          debugPrint('❌ Error loading data for user ${user.id}: $e');
          // Initialize empty data for this user and continue
          vehicles[user.id] = [];
          records[user.id] = [];
        }
      }

      if (mounted) {
        setState(() {
          _users = users;
          _userVehicles = vehicles;
          _userServiceRecords = records;
        });
        debugPrint('✅ Admin data loaded successfully');
      }

      // Auto-show user details if highlightBookingId is provided
      if (mounted && widget.highlightBookingId != null && widget.highlightBookingId!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showUserDetailsForBooking(widget.highlightBookingId!);
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Critical error loading admin data: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      // Show error to user but don't crash
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading data. Please try refreshing.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadData,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showUserDetailsForBooking(String bookingId) {
    // Find the user associated with this booking
    for (var user in _users) {
      final userRecords = _userServiceRecords[user.id] ?? [];
      if (userRecords.any((r) => r.id == bookingId)) {
        _showUserDetails(user, highlightBookingId: bookingId);
        return;
      }
    }
    // If booking not found, show error
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking not found')),
      );
    }
  }

  Future<void> _updateServiceProgress(ServiceRecord record, String newStatus) async {
    if (!mounted) return;
    
    try {
      int newProgress;
      switch (newStatus) {
        case 'Booking In Progress':
          newProgress = 0; // 0% - Booking pending admin confirmation
          break;
        case 'Booking Confirmed':
          newProgress = 50; // 50% - Admin confirmed, service in progress
          break;
        case 'Completed':
          newProgress = 100; // 100% - Service completed, ready for pickup
          break;
        case 'Booking Canceled':
          newProgress = 0;
          break;
        default:
          newProgress = record.progress;
      }

      String? mileage;
      String? adminNotes;
      List<String>? attachedImages;
      
      // If completing service, ask for mileage, notes and allow image upload
      if (newStatus == 'Completed') {
        if (!mounted) return;
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _ServiceCompletionDialog(
            currentMileage: record.mileage ?? '',
          ),
        );
        
        if (result == null) return; // User cancelled
        mileage = result['mileage'] as String?;
        adminNotes = result['notes'] as String?;
        attachedImages = result['images'] as List<String>?;
      }

      final updatedRecord = record.copyWith(
        status: newStatus,
        progress: newProgress,
        mileage: newStatus == 'Completed' ? mileage : record.mileage,
        adminNotes: newStatus == 'Completed' ? adminNotes : record.adminNotes,
        attachedImages: newStatus == 'Completed' ? attachedImages : record.attachedImages,
        updatedAt: DateTime.now(),
      );

      // Update record with timeout
      await ServiceRecordService().updateRecord(updatedRecord).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('⚠️ Timeout updating service record');
          throw TimeoutException('Failed to update service record');
        },
      );

      // Get vehicle and user info for notifications with error handling
      try {
        final vehicle = _userVehicles.values
            .expand((v) => v)
            .firstWhere((v) => v.id == record.vehicleId);
        final user = _users.firstWhere((u) => u.id == vehicle.userId);

        // Send appropriate notification based on status - with timeout and error handling
        try {
          if (newStatus == 'Completed') {
            await NotificationService().sendServiceCompletionNotification(
              userId: user.id,
              userEmail: user.email,
              serviceName: record.serviceType,
              vehicleInfo: vehicle.model,
            ).timeout(const Duration(seconds: 10));
          } else if (newStatus == 'Booking Canceled') {
            await NotificationService().sendAdminCanceledNotificationToUser(
              userId: user.id,
              userEmail: user.email,
              serviceName: record.serviceType,
              vehicleInfo: vehicle.model,
            ).timeout(const Duration(seconds: 10));
          } else {
            // For any other status change (Confirm, In Progress, etc.)
            await NotificationService().sendAdminModifiedNotificationToUser(
              userId: user.id,
              userEmail: user.email,
              serviceName: record.serviceType,
              vehicleInfo: vehicle.model,
              newStatus: newStatus,
            ).timeout(const Duration(seconds: 10));
          }
        } catch (notifError) {
          debugPrint('⚠️ Error sending notification (non-critical): $notifError');
          // Don't block the update if notification fails
        }
      } catch (lookupError) {
        debugPrint('⚠️ Error looking up user/vehicle info: $lookupError');
        // Continue even if we can't send notifications
      }

      // Reload data with error handling
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Service status updated to: $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating service status: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update service: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showUserDetails(User user, {String? highlightBookingId}) {
    final vehicles = _userVehicles[user.id] ?? [];
    final serviceRecords = _userServiceRecords[user.id] ?? [];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              Container(
                padding: AppSpacing.paddingMd,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.name,
                                style: context.textStyles.titleLarge?.semiBold,
                              ),
                              Text(
                                user.email,
                                style: context.textStyles.bodyMedium,
                              ),
                              Text(
                                user.phone,
                                style: context.textStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/customer/${user.id}${highlightBookingId != null ? "?highlightBookingId=$highlightBookingId" : ""}');
                        },
                        icon: Icon(Icons.person, color: Theme.of(context).colorScheme.onPrimary),
                        label: Text(
                          'View Customer Profile',
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: AppSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vehicles (${vehicles.length})',
                        style: context.textStyles.titleMedium?.semiBold,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (vehicles.isEmpty)
                        const Text('No vehicles registered')
                      else
                        ...vehicles.map((vehicle) => Card(
                              child: ListTile(
                                leading: const Icon(Icons.directions_car),
                                title: Text(vehicle.model),
                                subtitle: Text('${vehicle.year} • ${vehicle.licensePlate}'),
                              ),
                            )),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Service Records (${serviceRecords.length})',
                        style: context.textStyles.titleMedium?.semiBold,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (serviceRecords.isEmpty)
                        const Text('No service records')
                      else
                        ...serviceRecords.map((record) {
                          final vehicle = vehicles.firstWhere(
                            (v) => v.id == record.vehicleId,
                            orElse: () => Vehicle(
                              id: '',
                              userId: '',
                              model: 'Unknown',
                              year: '',
                              vin: '',
                              licensePlate: '',
                              color: '',
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          );
                          final isHighlighted = highlightBookingId != null && record.id == highlightBookingId;
                          return Card(
                            elevation: isHighlighted ? 8 : 1,
                            color: isHighlighted ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                            shape: isHighlighted
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    side: BorderSide(
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 2,
                                    ),
                                  )
                                : null,
                            child: Padding(
                              padding: AppSpacing.paddingMd,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isHighlighted)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.notifications_active,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.onPrimary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'From Notification',
                                            style: context.textStyles.labelSmall?.semiBold.withColor(
                                              Theme.of(context).colorScheme.onPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              record.serviceType,
                                              style: context.textStyles.titleSmall?.semiBold,
                                            ),
                                            Text(
                                              vehicle.model,
                                              style: context.textStyles.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(record.status).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(AppRadius.sm),
                                        ),
                                        child: Text(
                                          record.status,
                                          style: context.textStyles.labelSmall?.semiBold.withColor(
                                            _getStatusColor(record.status),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  LinearProgressIndicator(
                                    value: record.progress / 100,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    valueColor: AlwaysStoppedAnimation(
                                      _getStatusColor(record.status),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await Future.delayed(const Duration(milliseconds: 100));
                                          if (mounted) {
                                            await _updateServiceProgress(record, 'Booking Confirmed');
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('Confirm'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await Future.delayed(const Duration(milliseconds: 100));
                                          if (mounted) {
                                            await _updateServiceProgress(record, 'Completed');
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('Complete'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () async {
                                          Navigator.of(context).pop();
                                          await Future.delayed(const Duration(milliseconds: 100));
                                          if (mounted) {
                                            await _updateServiceProgress(record, 'Booking Canceled');
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).colorScheme.error,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: const Text('Cancel'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Booking In Progress':
        return Colors.orange;
      case 'Booking Confirmed':
        return Theme.of(context).colorScheme.primary;
      case 'Booking Canceled':
        return Theme.of(context).colorScheme.error;
      case 'Completed':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  void _showNotifications() {
    if (_currentAdminId == null) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationDrawer(
        adminId: _currentAdminId!,
        users: _users,
        onNotificationTap: (notification) async {
          // Mark as read
          await NotificationService().markAsRead(notification.id);
          
          // If it's a booking notification, show the user's details with highlighted booking
          if (notification.bookingId != null && notification.bookingId!.isNotEmpty) {
            // Find the user associated with this booking
            for (var user in _users) {
              final userRecords = _userServiceRecords[user.id] ?? [];
              if (userRecords.any((r) => r.id == notification.bookingId)) {
                Navigator.of(context).pop(); // Close notification drawer
                _showUserDetails(user, highlightBookingId: notification.bookingId); // Show user details with highlighted booking
                break;
              }
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: _currentAdminId != null ? () => _showNotifications() : null,
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.home, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: AppSpacing.paddingLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: AppSpacing.paddingMd,
                      child: Column(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            size: 48,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'BIMMERWISE Admin Panel',
                            style: context.textStyles.titleLarge?.semiBold,
                          ),
                          Text(
                            'Manage users and service records',
                            style: context.textStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: AppSpacing.paddingMd,
                            child: Column(
                              children: [
                                Text(
                                  '${_users.length}',
                                  style: context.textStyles.displaySmall?.semiBold.withColor(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Total Users',
                                  style: context.textStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: AppSpacing.paddingMd,
                            child: Column(
                              children: [
                                Text(
                                  '${_userVehicles.values.expand((v) => v).length}',
                                  style: context.textStyles.displaySmall?.semiBold.withColor(
                                    Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                Text(
                                  'Total Vehicles',
                                  style: context.textStyles.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/admin-products'),
                    icon: const Icon(Icons.inventory),
                    label: const Text('Manage Products'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Registered Users',
                    style: context.textStyles.titleLarge?.semiBold,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_users.isEmpty)
                    Center(
                      child: Text(
                        'No users registered yet',
                        style: context.textStyles.bodyLarge,
                      ),
                    )
                  else
                    ..._users.map((user) {
                      final vehicles = _userVehicles[user.id] ?? [];
                      final serviceRecords = _userServiceRecords[user.id] ?? [];
                      return Card(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(user.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              Text(
                                '${vehicles.length} vehicles • ${serviceRecords.length} records',
                                style: context.textStyles.bodySmall?.withColor(
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 16,
                          ),
                          onTap: () => _showUserDetails(user),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _NotificationDrawer extends StatelessWidget {
  final String adminId;
  final List<User> users;
  final Function(AppNotification) onNotificationTap;

  const _NotificationDrawer({
    required this.adminId,
    required this.users,
    required this.onNotificationTap,
  });

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.bookingCreated:
        return Icons.event_available;
      case NotificationType.bookingModified:
        return Icons.edit_calendar;
      case NotificationType.bookingCanceled:
        return Icons.event_busy;
      case NotificationType.serviceComplete:
        return Icons.check_circle;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(BuildContext context, NotificationType type) {
    switch (type) {
      case NotificationType.bookingCreated:
        return Colors.blue;
      case NotificationType.bookingModified:
        return Colors.orange;
      case NotificationType.bookingCanceled:
        return Colors.red;
      case NotificationType.serviceComplete:
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: context.textStyles.titleLarge?.semiBold,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Notifications list
            Expanded(
              child: StreamBuilder<List<AppNotification>>(
                stream: NotificationService().streamNotificationsByUserId(adminId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading notifications',
                            style: context.textStyles.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No notifications',
                            style: context.textStyles.titleMedium?.withColor(Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You\'ll see new booking alerts here',
                            style: context.textStyles.bodySmall?.withColor(Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationTile(
                        notification: notification,
                        icon: _getNotificationIcon(notification.type),
                        color: _getNotificationColor(context, notification.type),
                        timeAgo: _formatTimeAgo(notification.createdAt),
                        onTap: () => onNotificationTap(notification),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final IconData icon;
  final Color color;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.icon,
    required this.color,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: notification.isRead 
          ? Colors.transparent 
          : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: context.textStyles.titleSmall?.semiBold,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: context.textStyles.bodySmall?.withColor(Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: context.textStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Unread indicator
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceCompletionDialog extends StatefulWidget {
  final String currentMileage;

  const _ServiceCompletionDialog({required this.currentMileage});

  @override
  State<_ServiceCompletionDialog> createState() => _ServiceCompletionDialogState();
}

class _ServiceCompletionDialogState extends State<_ServiceCompletionDialog> {
  late final TextEditingController _mileageController;
  late final TextEditingController _notesController;
  final List<_ImageData> _images = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(text: widget.currentMileage);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _mileageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      debugPrint('Starting image picker...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        debugPrint('Selected ${result.files.length} images');
        final newImages = <_ImageData>[];
        
        for (var file in result.files) {
          if (file.bytes != null) {
            debugPrint('Adding image: ${file.name} (${file.bytes!.length} bytes)');
            final extension = file.extension?.toLowerCase() ?? 'png';
            final mimeType = extension == 'jpg' || extension == 'jpeg'
                ? 'image/jpeg'
                : extension == 'png'
                    ? 'image/png'
                    : 'image/$extension';
            
            newImages.add(_ImageData(
              bytes: file.bytes!,
              mimeType: mimeType,
              name: file.name,
            ));
          }
        }
        
        if (newImages.isNotEmpty && mounted) {
          setState(() => _images.addAll(newImages));
          debugPrint('Added ${newImages.length} images');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${newImages.length} image(s) added successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('No images selected');
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick images: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<List<String>> _encodeImages() async {
    final List<String> encodedImages = [];
    for (var image in _images) {
      try {
        final base64Image = base64Encode(image.bytes);
        final dataUrl = 'data:${image.mimeType};base64,$base64Image';
        encodedImages.add(dataUrl);
      } catch (e) {
        debugPrint('Error encoding image ${image.name}: $e');
      }
    }
    return encodedImages;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Service Completion'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _mileageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Mileage (km) *',
                hintText: 'Required',
                prefixIcon: Icon(Icons.speed),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Admin Notes (optional)',
                hintText: 'Add any notes about the service...',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: Text('Add Pictures (${_images.length})'),
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${_images.length} image(s) selected',
                style: const TextStyle(
                  color: Colors.green,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _images.asMap().entries.map((entry) {
                  final index = entry.key;
                  final imageData = entry.value;
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                      color: Colors.grey.shade200,
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            imageData.bytes,
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Error displaying image $index: $error');
                              return const Icon(Icons.error);
                            },
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _images.removeAt(index));
                            },
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : () async {
            // Validate mileage is required
            if (_mileageController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mileage is required to complete service'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            
            setState(() => _isProcessing = true);
            
            // Encode images in background
            List<String>? encodedImages;
            if (_images.isNotEmpty) {
              try {
                encodedImages = await _encodeImages();
                debugPrint('Successfully encoded ${encodedImages.length} images');
              } catch (e) {
                debugPrint('Error encoding images: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error processing images: $e'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                  setState(() => _isProcessing = false);
                  return;
                }
              }
            }
            
            if (mounted) {
              Navigator.of(context).pop({
                'mileage': _mileageController.text.trim(),
                'notes': _notesController.text.trim().isEmpty 
                    ? null 
                    : _notesController.text.trim(),
                'images': encodedImages,
              });
            }
          },
          child: _isProcessing 
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Complete Service'),
        ),
      ],
    );
  }
}

class _ImageData {
  final Uint8List bytes;
  final String mimeType;
  final String name;

  _ImageData({
    required this.bytes,
    required this.mimeType,
    required this.name,
  });
}
