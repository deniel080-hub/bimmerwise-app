import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/services/auth_service.dart';
import 'package:bimmerwise_connect/services/user_service.dart';
import 'package:bimmerwise_connect/services/vehicle_service.dart';
import 'package:bimmerwise_connect/services/service_record_service.dart';
import 'package:bimmerwise_connect/services/notification_service.dart';
import 'package:bimmerwise_connect/services/fcm_service.dart';
import 'package:bimmerwise_connect/services/cart_service.dart';
import 'package:bimmerwise_connect/models/user_model.dart';
import 'package:bimmerwise_connect/models/service_record_model.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin, WidgetsBindingObserver {
  User? _loggedInUser;
  bool _isLoading = true;
  ServiceRecord? _activeService;
  List<ServiceRecord> _allActiveBookings = [];
  late AnimationController _progressAnimationController;
  late AnimationController _progressValueController;
  late Animation<double> _progressValueAnimation;
  late AnimationController _textSwapController;
  int _tapCount = 0;
  DateTime? _firstTapTime;
  bool _showAdminAccess = false;
  double _targetProgress = 0;
  bool _showCollectText = false;
  int _unreadNotificationCount = 0;
  int _cartItemCount = 0;
  int _unconfirmedBookingsCount = 0;
  bool _showExpandedProgress = false;
  List<AppNotification> _adminBookingNotifications = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    try {
      // Initialize animation controllers without starting them immediately
      _progressAnimationController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 1),
      );
      
      _progressValueController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      );
      _progressValueAnimation = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _progressValueController, curve: Curves.linear),
      );
      
      // Text swap animation for completed services (disabled to prevent crash)
      _textSwapController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('⚠️ Animation controller initialization error: $e');
    }
    
    // Delay login check to allow UI to fully initialize (helps on Samsung devices)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _checkLoginStatus();
        });
      }
    });
  }

  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh once to avoid excessive rebuilds
    if (!_hasInitialized) {
      _hasInitialized = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
  }

  void _refreshData() {
    if (_loggedInUser != null) {
      _loadActiveService(_loggedInUser!.id);
      _loadUnreadNotifications(_loggedInUser!.id);
      _loadCartItemCount(_loggedInUser!.id);
      if (_loggedInUser!.isAdmin) {
        _loadUnconfirmedBookingsCount();
        _loadAdminBookingNotifications(_loggedInUser!.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _progressAnimationController.dispose();
      _progressValueController.dispose();
      _textSwapController.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing animation controllers: $e');
    }
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      debugPrint('🔍 Checking login status... Current user: ${currentUser?.email}');
      
      if (currentUser != null) {
        final userService = UserService();
        final user = await userService.getUserById(currentUser.uid);
        debugPrint('👤 User loaded from Firestore: ${user?.email} (isAdmin: ${user?.isAdmin})');
        
        if (!mounted) return;
        setState(() => _loggedInUser = user);
        
        if (user != null) {
          // Load data in parallel with individual error handling to prevent one failure from blocking others
          await Future.wait([
            _loadActiveService(user.id).catchError((e) {
              debugPrint('⚠️ Error loading active service: $e');
              return null;
            }),
            _loadUnreadNotifications(user.id).catchError((e) {
              debugPrint('⚠️ Error loading notifications: $e');
              return null;
            }),
            _loadCartItemCount(user.id).catchError((e) {
              debugPrint('⚠️ Error loading cart: $e');
              return null;
            }),
            if (user.isAdmin) ...[
              _loadUnconfirmedBookingsCount().catchError((e) {
                debugPrint('⚠️ Error loading bookings count: $e');
                return null;
              }),
              _loadAdminBookingNotifications(user.id).catchError((e) {
                debugPrint('⚠️ Error loading admin notifications: $e');
                return null;
              }),
            ],
          ]);
          
          // Save FCM token separately with timeout - don't block on this
          FCMService().saveTokenToUser(user.id).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⚠️ FCM token save timeout - will retry later');
            },
          ).catchError((e) {
            debugPrint('⚠️ Error saving FCM token: $e');
          });
        }
      } else {
        debugPrint('❌ No current user found');
      }
    } catch (e, stackTrace) {
      debugPrint('💥 Error checking login status: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Clear loading state even on error to prevent stuck UI
      if (mounted) {
        setState(() {
          _loggedInUser = null;
          _isLoading = false;
        });
      }
      return; // Exit early on error
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Load unread notifications with real-time stream
  /// This ensures notifications update instantly without app refresh
  Future<void> _loadUnreadNotifications(String userId) async {
    try {
      final notificationService = NotificationService();
      
      // Set up real-time stream for instant notification updates
      notificationService.streamNotificationsByUserId(userId).listen((notifications) {
        if (mounted) {
          final unreadCount = notifications.where((n) => !n.isRead).length;
          setState(() => _unreadNotificationCount = unreadCount);
          debugPrint('📬 Real-time update: $unreadCount unread notifications');
        }
      }, onError: (e) {
        debugPrint('❌ Error in notification stream: $e');
      });
      
      // Also get initial count immediately
      final unreadCount = await notificationService.getUnreadCount(userId);
      if (mounted) {
        setState(() => _unreadNotificationCount = unreadCount);
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _loadCartItemCount(String userId) async {
    try {
      final cartService = CartService();
      final count = await cartService.getCartItemCount(userId);
      if (mounted) {
        setState(() => _cartItemCount = count);
      }
    } catch (e) {
      debugPrint('Error loading cart count: $e');
    }
  }

  Future<void> _loadUnconfirmedBookingsCount() async {
    try {
      final serviceRecordService = ServiceRecordService();
      final allRecords = await serviceRecordService.getAllRecords();
      final unconfirmedCount = allRecords.where((r) => r.status == 'Booking In Progress').length;
      if (mounted) {
        setState(() => _unconfirmedBookingsCount = unconfirmedCount);
      }
      debugPrint('📊 Admin: $unconfirmedCount unconfirmed bookings found');
    } catch (e) {
      debugPrint('Error loading unconfirmed bookings count: $e');
    }
  }

  /// Load admin booking notifications with real-time stream
  Future<void> _loadAdminBookingNotifications(String userId) async {
    try {
      final notificationService = NotificationService();
      
      // Set up real-time stream for instant admin notification updates
      notificationService.streamNotificationsByUserId(userId).listen((notifications) {
        if (mounted) {
          final bookingNotifications = notifications.where((n) =>
            n.type == NotificationType.bookingCreated ||
            n.type == NotificationType.bookingModified ||
            n.type == NotificationType.bookingCanceled
          ).take(5).toList();
          
          setState(() => _adminBookingNotifications = bookingNotifications);
          debugPrint('📬 Admin: ${bookingNotifications.length} booking notifications loaded (real-time)');
        }
      }, onError: (e) {
        debugPrint('❌ Error in admin notification stream: $e');
      });
      
      // Also get initial notifications immediately
      final notifications = await notificationService.getNotificationsByUserId(userId);
      final bookingNotifications = notifications.where((n) =>
        n.type == NotificationType.bookingCreated ||
        n.type == NotificationType.bookingModified ||
        n.type == NotificationType.bookingCanceled
      ).take(5).toList();
      
      if (mounted) {
        setState(() => _adminBookingNotifications = bookingNotifications);
      }
      debugPrint('📬 Admin: ${bookingNotifications.length} booking notifications loaded');
    } catch (e) {
      debugPrint('Error loading admin booking notifications: $e');
    }
  }

  Future<void> _loadActiveService(String userId) async {
    try {
      final vehicleService = VehicleService();
      final serviceRecordService = ServiceRecordService();
      
      // Get user's vehicles first
      final userVehicles = await vehicleService.getVehiclesByUserId(userId);
      if (!mounted) return;
      
      if (userVehicles.isEmpty) {
        // No vehicles, no active services
        if (mounted) {
          setState(() {
            _activeService = null;
            _targetProgress = 0;
            _showCollectText = false;
          });
          try {
            if (_progressValueController.isAnimating) _progressValueController.stop();
            if (_textSwapController.isAnimating) _textSwapController.stop();
          } catch (e) {
            debugPrint('⚠️ Error stopping animations: $e');
          }
        }
        return;
      }
      
      // Get vehicle IDs
      final vehicleIds = userVehicles.map((v) => v.id).toSet();
      
      // Get all service records and filter by user's vehicles
      final allRecords = await serviceRecordService.getAllRecords();
      if (!mounted) return;
      
      final userRecords = allRecords.where((r) => vehicleIds.contains(r.vehicleId)).toList();
      
      if (userRecords.isNotEmpty) {
        // Filter: show only active services (not collected or canceled)
        // Include 'Completed' status to show 100% with swipe option
        final activeRecords = userRecords.where((r) => 
          r.status != 'Collected' && 
          r.status != 'Booking Canceled'
        ).toList();
        
        if (activeRecords.isNotEmpty) {
          activeRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final latestService = activeRecords.first;
          
          // Calculate average progress across all bookings
          int totalProgress = 0;
          for (var record in activeRecords) {
            if (record.status == 'Completed') {
              totalProgress += 100;
            } else if (record.status == 'Booking Confirmed') {
              totalProgress += 50;
            } else if (record.status == 'Booking In Progress') {
              totalProgress += 0;
            } else {
              totalProgress += record.progress;
            }
          }
          final avgProgress = (totalProgress / activeRecords.length).round();
          
          // Use average progress for display when multiple bookings
          final displayProgress = activeRecords.length > 1 ? avgProgress : 
              (latestService.status == 'Completed' ? 100 :
               latestService.status == 'Booking Confirmed' ? 50 :
               latestService.status == 'Booking In Progress' ? 0 : latestService.progress);
          
          if (!mounted) return;
          
          // Start or stop text swap animation based on completion
          try {
            if (displayProgress >= 100) {
              if (!_textSwapController.isAnimating) {
                _textSwapController.forward();
              }
            } else {
              if (_textSwapController.isAnimating) _textSwapController.stop();
              _showCollectText = false;
            }
          } catch (e) {
            debugPrint('⚠️ Text swap animation error: $e');
          }
          
          setState(() {
            _activeService = latestService;
            _allActiveBookings = activeRecords;
            _targetProgress = displayProgress.toDouble();
          });
          
          debugPrint('📊 Progress: ${activeRecords.length} bookings, avg: $avgProgress%, display: $displayProgress%');
          _startProgressAnimation(displayProgress.toDouble());
        } else {
          if (mounted) {
            setState(() {
              _activeService = null;
              _allActiveBookings = [];
              _targetProgress = 0;
              _showCollectText = false;
            });
            try {
              if (_progressValueController.isAnimating) _progressValueController.stop();
              if (_textSwapController.isAnimating) _textSwapController.stop();
            } catch (e) {
              debugPrint('⚠️ Error stopping animations: $e');
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _activeService = null;
            _allActiveBookings = [];
            _targetProgress = 0;
            _showCollectText = false;
          });
          try {
            if (_progressValueController.isAnimating) _progressValueController.stop();
            if (_textSwapController.isAnimating) _textSwapController.stop();
          } catch (e) {
            debugPrint('⚠️ Error stopping animations: $e');
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('💥 Error loading active service: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _activeService = null;
          _allActiveBookings = [];
          _targetProgress = 0;
          _showCollectText = false;
        });
        try {
          if (_progressValueController.isAnimating) _progressValueController.stop();
          if (_textSwapController.isAnimating) _textSwapController.stop();
        } catch (animError) {
          debugPrint('⚠️ Error stopping animations: $animError');
        }
      }
    }
  }

  void _startProgressAnimation(double targetProgress) {
    if (!mounted) return;
    // Disabled animation to prevent Samsung device crashes
    // Progress will update directly without animation
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    
    // Reset if more than 10 seconds have passed
    if (_firstTapTime == null || now.difference(_firstTapTime!) > const Duration(seconds: 10)) {
      _tapCount = 1;
      _firstTapTime = now;
      setState(() => _showAdminAccess = false);
    } else {
      _tapCount++;
      
      // Show admin access after 5 taps within 10 seconds
      if (_tapCount >= 5) {
        setState(() => _showAdminAccess = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin access unlocked'),
            duration: Duration(seconds: 2),
          ),
        );
        _tapCount = 0;
        _firstTapTime = null;
      }
    }
  }

  Future<void> _showNotifications() async {
    if (_loggedInUser == null) {
      debugPrint('❌ Cannot show notifications: user not logged in');
      return;
    }
    
    try {
      final notificationService = NotificationService();
      debugPrint('📬 Fetching notifications for user: ${_loggedInUser!.id}');
      final notifications = await notificationService.getNotificationsByUserId(_loggedInUser!.id);
      
      debugPrint('📬 Fetched ${notifications.length} notifications');
      if (notifications.isEmpty) {
        debugPrint('📬 No notifications found. Check Firestore collection "notifications" for userId: ${_loggedInUser!.id}');
      } else {
        debugPrint('📬 Notification titles: ${notifications.map((n) => n.title).join(", ")}');
      }
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Text('Notifications'),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B9DD8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${notifications.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: notifications.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return ListTile(
                        leading: Icon(
                          notification.isRead ? Icons.notifications : Icons.notifications_active,
                          color: notification.isRead ? Colors.grey : const Color(0xFF3B9DD8),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          notification.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () async {
                            await notificationService.deleteNotification(notification.id);
                            Navigator.of(context).pop();
                            await _showNotifications();
                            if (_loggedInUser != null) {
                              await _loadUnreadNotifications(_loggedInUser!.id);
                            }
                          },
                        ),
                        onTap: () async {
                          // Mark as read
                          if (!notification.isRead) {
                            await notificationService.markAsRead(notification.id);
                            if (_loggedInUser != null) {
                              await _loadUnreadNotifications(_loggedInUser!.id);
                            }
                          }
                          
                          // Handle navigation for booking notifications
                          if (notification.bookingId != null && 
                              notification.bookingId!.isNotEmpty &&
                              _loggedInUser?.isAdmin == true) {
                            Navigator.of(context).pop();
                            // Navigate to admin panel with highlighted booking
                            context.push('/admin-panel?highlightBookingId=${notification.bookingId}');
                          } else {
                            // Just close and reopen for other notification types
                            Navigator.of(context).pop();
                            await _showNotifications();
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [
            if (notifications.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await notificationService.clearNotificationsByUserId(_loggedInUser!.id);
                  Navigator.of(context).pop();
                  await _loadUnreadNotifications(_loggedInUser!.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('All notifications cleared')),
                    );
                  }
                },
                child: const Text('Clear All'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ Error showing notifications: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notifications: $e')),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await AuthService().logout();
      setState(() => _loggedInUser = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001E50),
              Color(0xFF2B6A9E),
              Color(0xFF8B3A8B),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // Top bar with WhatsApp button, User name, and Profile button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                      // Notification and Cart buttons (for all logged-in users, including admins)
                    if (_loggedInUser != null)
                      Row(
                        children: [
                          InkWell(
                            onTap: () async {
                              await _showNotifications();
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.notifications,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  if (_unreadNotificationCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          _unreadNotificationCount > 9 ? '9+' : '$_unreadNotificationCount',
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
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              await context.push('/cart');
                              if (_loggedInUser != null) {
                                await _loadCartItemCount(_loggedInUser!.id);
                              }
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Icon(
                                    Icons.shopping_cart,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  if (_cartItemCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          _cartItemCount > 9 ? '9+' : '$_cartItemCount',
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
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox(width: 40),
                    // Logo (center)
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleLogoTap,
                        child: Center(
                          child: Image.asset(
                            'assets/images/bimmerwise33.png',
                            height: 70,
                            fit: BoxFit.fitHeight,
                            errorBuilder: (context, error, stackTrace) {
                              debugPrint('Failed to load logo: $error, tried path: assets/images/bimmerwise33.png');
                              return Text(
                                'BIMMERWISE',
                                style: context.textStyles.titleLarge?.bold.withColor(Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // Admin Access or Profile button (right side)
                    if (_showAdminAccess)
                      InkWell(
                        onTap: () => context.push('/admin-login'),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.red.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      )
                    else if (_loggedInUser != null)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          switch (value) {
                            case 'my_profile':
                              context.push('/user-profile/${_loggedInUser!.id}');
                              break;
                            case 'edit_profile':
                              context.push('/user-profile/${_loggedInUser!.id}?scrollTo=edit_profile');
                              break;
                            case 'my_vehicles':
                              context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_vehicles');
                              break;
                            case 'my_bookings':
                              context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_bookings');
                              break;
                            case 'service_history':
                              context.push('/user-profile/${_loggedInUser!.id}?scrollTo=service_history');
                              break;
                            case 'logout':
                              final authService = AuthService();
                              await authService.logout();
                              setState(() {
                                _loggedInUser = null;
                                _activeService = null;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Logged out successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                              break;
                          }
                        },
                        offset: const Offset(0, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: Colors.white,
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'my_profile',
                            child: Row(
                              children: [
                                Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('My Profile'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'edit_profile',
                            child: Row(
                              children: [
                                Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('Edit My Profile'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'my_vehicles',
                            child: Row(
                              children: [
                                Icon(Icons.directions_car, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('My Vehicles'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'my_bookings',
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('My Bookings'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'service_history',
                            child: Row(
                              children: [
                                Icon(Icons.history, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 12),
                                const Text('My Service History'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'logout',
                            child: Row(
                              children: [
                                const Icon(Icons.logout, color: Colors.red),
                                const SizedBox(width: 12),
                                Text(
                                  'Log Out',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.white,
                                backgroundImage: _getProfileImage(),
                                child: _loggedInUser!.profilePicture == null
                                    ? const Icon(
                                        Icons.person,
                                        size: 22,
                                        color: Color(0xFF001E50),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 40),
                  ],
                ),
              ),
                  // Main scrollable content with pull-to-refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        if (_loggedInUser != null) {
                          await _loadActiveService(_loggedInUser!.id);
                          await _loadUnreadNotifications(_loggedInUser!.id);
                          await _loadCartItemCount(_loggedInUser!.id);
                          if (_loggedInUser!.isAdmin) {
                            await _loadUnconfirmedBookingsCount();
                            await _loadAdminBookingNotifications(_loggedInUser!.id);
                          }
                        }
                      },
                      color: const Color(0xFF3B9DD8),
                      backgroundColor: Colors.white,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            top: 16,
                            bottom: 140, // Space for fixed bottom bar with progress and call button
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                      const SizedBox(height: 16),
                      // Admin booking notifications section
                      if (_loggedInUser?.isAdmin == true && _adminBookingNotifications.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_active,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Recent Booking Activity',
                                    style: context.textStyles.titleMedium?.bold.withColor(Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_adminBookingNotifications.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                              child: Column(
                                children: [
                                  ..._adminBookingNotifications.asMap().entries.map((entry) {
                                    final notification = entry.value;
                                    final isLast = entry.key == _adminBookingNotifications.length - 1;
                                        
                                        IconData icon;
                                        Color iconColor;
                                        switch (notification.type) {
                                          case NotificationType.bookingCreated:
                                            icon = Icons.add_circle;
                                            iconColor = Colors.green;
                                            break;
                                          case NotificationType.bookingModified:
                                            icon = Icons.edit;
                                            iconColor = Colors.orange;
                                            break;
                                          case NotificationType.bookingCanceled:
                                            icon = Icons.cancel;
                                            iconColor = Colors.red;
                                            break;
                                          default:
                                            icon = Icons.notifications;
                                            iconColor = Colors.blue;
                                        }
                                        
                                        return Column(
                                          children: [
                                            InkWell(
                                              onTap: () async {
                                                await NotificationService().markAsRead(notification.id);
                                                
                                                // Navigate to admin panel with highlighted booking
                                                if (notification.bookingId != null && notification.bookingId!.isNotEmpty && mounted) {
                                                  context.push('/admin-panel?highlightBookingId=${notification.bookingId}');
                                                } else if (mounted) {
                                                  // No booking ID, just go to admin panel
                                                  context.push('/admin-panel');
                                                }
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(16),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: iconColor.withValues(alpha: 0.1),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(icon, color: iconColor, size: 20),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            notification.title,
                                                            style: context.textStyles.bodyMedium?.bold.withColor(
                                                              notification.isRead ? Colors.grey : const Color(0xFF001E50),
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            notification.message,
                                                            style: context.textStyles.bodySmall?.withColor(Colors.grey[600]!),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    if (!notification.isRead)
                                                      Container(
                                                        width: 8,
                                                        height: 8,
                                                        decoration: const BoxDecoration(
                                                          color: Color(0xFF3B9DD8),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            if (!isLast)
                                              Divider(height: 1, color: Colors.grey[300]),
                                          ],
                                        );
                                      }),
                                      InkWell(
                                        onTap: () => context.push('/admin-panel'),
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF001E50).withValues(alpha: 0.05),
                                            borderRadius: const BorderRadius.only(
                                              bottomLeft: Radius.circular(16),
                                              bottomRight: Radius.circular(16),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                'View All in Admin Panel',
                                                style: context.textStyles.bodyMedium?.bold.withColor(
                                                  const Color(0xFF3B9DD8),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.arrow_forward,
                                                color: Color(0xFF3B9DD8),
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                          ],
                        ),
                      // Service cards in 2 columns
                      Row(
                        children: [
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.bolt,
                              title: 'High Voltage\nServices',
                              subtitle: '',
                              onTap: () => context.push('/service-selection?category=bookin'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.build_circle,
                              title: 'Car Service',
                              subtitle: '',
                              onTap: () => context.push('/service-selection?category=service'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.computer,
                              title: 'Coding',
                              subtitle: '',
                              onTap: () => context.push('/service-selection?category=coding'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.fact_check,
                              title: 'Vehicle Health\nCheck',
                              subtitle: '',
                              onTap: () => context.push('/service-selection?category=healthcheck'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.directions_car_filled,
                              title: 'Cars for Sale',
                              subtitle: '',
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Coming soon!')),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BMWServiceCard(
                              icon: Icons.shopping_bag,
                              title: 'Products',
                              subtitle: '',
                              onTap: () => context.push('/products'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Location card
                      BMWAccentCard(
                        icon: Icons.location_on,
                        title: 'Visit Our Location',
                        subtitle: 'Navigate with Google Maps',
                        buttonText: 'GET DIRECTIONS',
                        onTap: () async {
                          try {
                            final Uri url = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=BIMMERWISE+BMW+Service',
                            );
                            if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not open Google Maps')),
                                );
                              }
                            }
                          } catch (e) {
                            debugPrint('Error launching Google Maps: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Error opening Google Maps')),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      // Social media icons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Google Profile icon
                          InkWell(
                            onTap: () async {
                              try {
                                final Uri url = Uri.parse('https://share.google/PP8zIUTyUeImfx7Nt');
                                if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                                  debugPrint('Could not launch Google Profile URL: $url');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open Google Profile')),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error launching Google Profile: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error opening Google Profile')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.g_mobiledata_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          // Facebook icon
                          InkWell(
                            onTap: () async {
                              try {
                                final Uri url = Uri.parse('https://www.facebook.com/bimmerwise');
                                if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                                  debugPrint('Could not launch Facebook URL: $url');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open Facebook')),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error launching Facebook: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error opening Facebook')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.facebook,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          // Instagram icon
                          InkWell(
                            onTap: () async {
                              try {
                                final Uri url = Uri.parse('https://www.instagram.com/bimmer_wise/');
                                if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                                  debugPrint('Could not launch Instagram URL: $url');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open Instagram')),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error launching Instagram: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error opening Instagram')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                          // Web icon
                          InkWell(
                            onTap: () async {
                              try {
                                final Uri url = Uri.parse('https://bimmerwise.com/');
                                if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                                  debugPrint('Could not launch website URL: $url');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not open website')),
                                    );
                                  }
                                }
                              } catch (e) {
                                debugPrint('Error launching website: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Error opening website')),
                                  );
                                }
                              }
                            },
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.language,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Auth buttons
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else if (_loggedInUser == null)
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.push('/register'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF001E50),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'REGISTER',
                                  style: context.textStyles.titleMedium?.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.push('/login?service=&category='),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B9DD8),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: Text(
                                  'LOG IN',
                                  style: context.textStyles.titleMedium?.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Fixed bottom section - Progress bar on top, Call button below
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: const Color(0xFF001E50).withValues(alpha: 0.95),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Call Now and Chat Now buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final Uri url = Uri.parse('tel:+353852624258');
                                  final launched = await launchUrl(url);
                                  if (!launched && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not make phone call')),
                                    );
                                  }
                                } catch (e) {
                                  debugPrint('Error launching phone: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Phone calling not supported')),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.phone, color: Colors.white, size: 18),
                              label: const Text('Call Now', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B9DD8),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                try {
                                  final Uri url = Uri.parse('https://wa.me/353852624258');
                                  if (!await launchUrl(url, webOnlyWindowName: '_blank')) {
                                    debugPrint('Could not launch WhatsApp URL: $url');
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Could not open WhatsApp')),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error launching WhatsApp: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Error opening WhatsApp')),
                                    );
                                  }
                                }
                              },
                              icon: Image.asset('assets/images/whatsappwhite.png', width: 18, height: 18, errorBuilder: (context, error, stackTrace) => const Icon(Icons.chat, color: Colors.white, size: 18)),
                              label: const Text('Chat Now', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Progress bars section - multiple bars for multiple bookings
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: _loggedInUser?.isAdmin == true
                            ? GestureDetector(
                                onTap: () => context.push('/admin-panel'),
                                child: _buildProgressBarWithCount(_unconfirmedBookingsCount),
                              )
                            : _allActiveBookings.isEmpty
                                ? GestureDetector(
                                    onTap: _loggedInUser != null 
                                        ? () => context.push('/user-profile/${_loggedInUser!.id}')
                                        : () => context.push('/login?service=&category='),
                                    child: _buildProgressBar(null, 0, false),
                                  )
                                : _allActiveBookings.length == 1
                                    ? _buildSingleBookingProgress(_allActiveBookings.first)
                                    : _buildMultipleBookingsProgress(),
                      ),
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

  Widget _buildSingleBookingProgress(ServiceRecord booking) {
    final progress = booking.status == 'Completed' ? 100.0 :
        booking.status == 'Booking Confirmed' ? 50.0 :
        booking.status == 'Booking In Progress' ? 0.0 : booking.progress.toDouble();
    final isCompleted = progress >= 99.5;
    
    // Use Dismissible for swipe-to-collect when service is completed
    if (isCompleted && _loggedInUser != null) {
          return Dismissible(
            key: Key(booking.id),
            direction: DismissDirection.startToEnd,
            confirmDismiss: (direction) async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Collection'),
                  content: Text('Have you collected your vehicle for ${booking.serviceType}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes, Collected'),
                    ),
                  ],
                ),
              );
              
              if (confirm == true) {
                final updatedService = booking.copyWith(
                  status: 'Collected',
                  updatedAt: DateTime.now(),
                );
                await ServiceRecordService().updateRecord(updatedService);
                
                await _loadActiveService(_loggedInUser!.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${booking.serviceType} collection confirmed!')),
                  );
                }
              }
              return false;
            },
            background: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF4CAF50),
                    Color(0xFF66BB6A),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Collected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        child: GestureDetector(
          onTap: () => context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_bookings'),
          child: _buildProgressBar(booking, progress, isCompleted),
        ),
      );
    }
    
    return GestureDetector(
      onTap: () => context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_bookings'),
      child: _buildProgressBar(booking, progress, isCompleted),
    );
  }

  Widget _buildMultipleBookingsProgress() {
    if (!_showExpandedProgress) {
      // Show collapsed progress bar with summary text
      return GestureDetector(
        onTap: () {
          setState(() => _showExpandedProgress = true);
        },
        child: _buildCollapsedProgressBar(),
      );
    }
    
    // Calculate height for scrollable area: max 4 items visible (58px each: 50px bar + 8px padding)
    final maxVisibleHeight = 4 * 58.0 + 48.0; // 48px for header
    final needsScrolling = _allActiveBookings.length > 4;
    
    // Show expanded progress bars for all bookings
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with collapse button
        GestureDetector(
          onTap: () {
            setState(() => _showExpandedProgress = false);
          },
          child: Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF001E50).withValues(alpha: 0.95),
                  const Color(0xFF1B4470).withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                  SizedBox(width: 4),
                  Text(
                    'Hide Booking Progress',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ),
        // Individual progress bars - scrollable if more than 4
        SizedBox(
          height: needsScrolling ? maxVisibleHeight - 48.0 : null,
          child: needsScrolling
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildProgressBarList(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _buildProgressBarList(),
                ),
        ),
      ],
    );
  }

  List<Widget> _buildProgressBarList() {
    return _allActiveBookings.map((booking) {
      final progress = booking.status == 'Completed' ? 100.0 :
          booking.status == 'Booking Confirmed' ? 50.0 :
          booking.status == 'Booking In Progress' ? 0.0 : booking.progress.toDouble();
      final isCompleted = progress >= 99.5;
      
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: isCompleted && _loggedInUser != null
            ? Dismissible(
                key: Key(booking.id),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (direction) async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Collection'),
                      content: Text('Have you collected your vehicle for ${booking.serviceType}?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Yes, Collected'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    final updatedService = booking.copyWith(
                      status: 'Collected',
                      updatedAt: DateTime.now(),
                    );
                    await ServiceRecordService().updateRecord(updatedService);
                    
                    await _loadActiveService(_loggedInUser!.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${booking.serviceType} collection confirmed!')),
                      );
                    }
                  }
                  return false;
                },
                background: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0xFF4CAF50),
                        Color(0xFF66BB6A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Collected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                child: GestureDetector(
                  onTap: () => context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_bookings'),
                  child: _buildProgressBar(booking, progress, isCompleted),
                ),
              )
            : GestureDetector(
                onTap: () => context.push('/user-profile/${_loggedInUser!.id}?scrollTo=my_bookings'),
                child: _buildProgressBar(booking, progress, isCompleted),
              ),
      );
    }).toList();
  }

  Widget _buildCollapsedProgressBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF001E50).withValues(alpha: 0.95),
            const Color(0xFF1B4470).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Click to show my booking progress (${_allActiveBookings.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black54,
                      offset: Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Safe base64 image decoder with error handling
  ImageProvider? _getProfileImage() {
    try {
      if (_loggedInUser?.profilePicture == null) return null;
      final base64String = _loggedInUser!.profilePicture!.split(',').last;
      return MemoryImage(base64Decode(base64String));
    } catch (e) {
      debugPrint('⚠️ Failed to decode profile picture: $e');
      return null;
    }
  }

  // Helper method for admin progress bar with explicit count
  Widget _buildProgressBarWithCount(int count) {
    final statusText = count > 0
        ? '$count Unconfirmed Booking${count != 1 ? 's' : ''}'
        : 'All Bookings Confirmed';
    final progress = 100.0;
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF001E50).withValues(alpha: 0.95),
            const Color(0xFF1B4470).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Progress fill
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: FractionallySizedBox(
              widthFactor: progress / 100,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: count > 0
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFF6B6B),
                            Color(0xFFFF8E8E),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF66BB6A),
                          ],
                        ),
                ),
              ),
            ),
          ),
          // Text
          Center(
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ServiceRecord? booking, double displayProgress, bool isCompleted) {
    String statusText;
    bool showPercentage = false;
    double adminProgress = 0.0;
    bool isAdmin = _loggedInUser?.isAdmin == true;
    
    // Admin users: Show unconfirmed bookings count
    if (isAdmin) {
      statusText = _unconfirmedBookingsCount > 0
          ? '$_unconfirmedBookingsCount Unconfirmed Booking${_unconfirmedBookingsCount != 1 ? 's' : ''}'
          : 'All Bookings Confirmed';
      showPercentage = false;
      // Always show full bar for admins (red when unconfirmed, green when all confirmed)
      adminProgress = 100.0;
    } else if (_loggedInUser == null) {
      statusText = 'Awaiting Your First Booking';
      showPercentage = false;
    } else if (booking == null) {
      statusText = 'Ready to Book in your service';
      showPercentage = false;
    } else {
      // Show the service name instead of generic text
      final serviceName = booking.serviceType;
      
      if (isCompleted) {
        statusText = '$serviceName - Ready to Collect';
        showPercentage = true;
      } else if (booking.status == 'Booking Confirmed') {
        statusText = '$serviceName - In Progress';
        showPercentage = true;
      } else if (booking.status == 'Booking In Progress') {
        statusText = '$serviceName - Pending';
        showPercentage = true;
      } else {
        statusText = '$serviceName - ${booking.status}';
        showPercentage = true;
      }
    }

    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF001E50).withValues(alpha: 0.95),
            const Color(0xFF1B4470).withValues(alpha: 0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Progress fill with gradient (green at 100%, static on web for performance)
          ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: FractionallySizedBox(
              widthFactor: (isAdmin ? adminProgress : displayProgress) / 100,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: (isAdmin && adminProgress >= 100) || isCompleted
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF4CAF50),
                            Color(0xFF66BB6A),
                          ],
                        )
                      : (isAdmin && _unconfirmedBookingsCount > 0)
                      ? const LinearGradient(
                          colors: [
                            Color(0xFFFF6B6B),
                            Color(0xFFFF8E8E),
                          ],
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF3B9DD8),
                            Color(0xFF5AB3E8),
                          ],
                        ),
                ),
              ),
            ),
          ),
          // Progress text centered with animated number and status
          Center(
            child: Text(
              showPercentage
                  ? '${displayProgress.toInt()}% - $statusText'
                  : statusText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class BMWServiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const BMWServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF001E50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF001E50),
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              child: Text(
                title,
                style: context.textStyles.bodyMedium?.bold.withColor(
                  const Color(0xFF001E50),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BMWAccentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const BMWAccentCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF001E50),
            Color(0xFF003366),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textStyles.titleMedium?.bold.withColor(Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.textStyles.bodySmall?.withColor(
                        Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B9DD8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: context.textStyles.titleSmall?.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

