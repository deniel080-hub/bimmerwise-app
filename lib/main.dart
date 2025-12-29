import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/nav.dart';
import 'package:bimmerwise_connect/firebase_options.dart';
import 'package:bimmerwise_connect/services/fcm_service.dart';

/// Background message handler (must be top-level function)
/// SAMSUNG-SAFE: Wrapped in comprehensive error handling to prevent crash loops
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('📨 Background message: ${message.notification?.title}');
  } catch (e, stackTrace) {
    // CRITICAL: Never throw from background handler - causes crash loops on Samsung
    debugPrint('❌ Background handler error: $e');
    debugPrint('❌ Stack trace: $stackTrace');
  }
}

/// Main entry point for the application
///
/// This sets up:
/// - Firebase initialization
/// - Firebase Cloud Messaging (FCM) for push notifications
/// - go_router navigation
/// - Material 3 theming with light/dark modes
void main() async {
  // Wrap everything in error handling for better crash reporting
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // SAMSUNG CRASH RECOVERY: Track startup crashes to detect crash loops
    SharedPreferences? prefs;
    int crashCount = 0;
    try {
      prefs = await SharedPreferences.getInstance();
      crashCount = prefs.getInt('startup_crash_count') ?? 0;
      
      // If app crashed 3+ times on startup, clear all problematic data
      if (crashCount >= 3) {
        debugPrint('⚠️ Detected crash loop ($crashCount crashes), clearing corrupted data...');
        
        // Clear the crash counter
        await prefs.remove('startup_crash_count');
        
        // Clear Firestore cache (if possible)
        try {
          await FirebaseFirestore.instance.clearPersistence();
          debugPrint('✅ Cleared Firestore cache');
        } catch (e) {
          debugPrint('⚠️ Could not clear Firestore cache: $e');
        }
        
        crashCount = 0; // Reset after cleanup
      } else {
        // Increment crash counter - will be reset after successful startup
        await prefs.setInt('startup_crash_count', crashCount + 1);
      }
    } catch (e) {
      debugPrint('⚠️ Could not access SharedPreferences for crash recovery: $e');
    }
    
    // Initialize Firebase with comprehensive error handling
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      
      // iOS-SAFE: Verify Firebase is properly configured
      if (!kIsWeb) {
        try {
          // Test Firestore connection
          await FirebaseFirestore.instance
              .collection('_health_check')
              .doc('test')
              .get()
              .timeout(const Duration(seconds: 5));
          debugPrint('✅ Firebase Firestore connection verified');
        } catch (e) {
          debugPrint('⚠️ Firebase connection check: $e');
          debugPrint('⚠️ Ensure GoogleService-Info.plist (iOS) or google-services.json (Android) is properly configured');
        }
      }
      
      // Configure Firestore - SAMSUNG-SAFE with limited cache to prevent corruption
      if (!kIsWeb) {
        try {
          // Use LIMITED cache on mobile to prevent Samsung crash loops from corrupted cache
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024, // 100MB limit (was unlimited)
          );
          debugPrint('✅ Firestore persistence enabled with 100MB cache limit');
        } catch (e) {
          debugPrint('⚠️ Error configuring Firestore settings: $e');
        }
      }
      
      // Set up background message handler - SAMSUNG-SAFE with extra protection
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        debugPrint('✅ Background message handler registered');
      } catch (e, stackTrace) {
        debugPrint('⚠️ Error setting up background message handler: $e');
        debugPrint('⚠️ Stack trace: $stackTrace');
        // Don't rethrow - app continues without background messaging
      }
      
      // Initialize FCM Service in the background - SAMSUNG-SAFE (no local notifications)
      // Don't await this - let it happen in the background
      // Delayed start to prevent Samsung crash on app launch
      Future.delayed(const Duration(milliseconds: 1500), () {
        FCMService().initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ FCM timeout (Samsung-safe mode)');
          },
        ).catchError((e) {
          debugPrint('⚠️ FCM error (Samsung-safe): $e');
          // Never block app - Samsung devices continue without FCM
        }, test: (_) => true);
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error (Samsung S24): $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('⚠️ App will continue but Firebase features may not work');
    }
    
    // SAMSUNG CRASH RECOVERY: Reset crash counter after successful initialization
    try {
      if (prefs != null) {
        await prefs.setInt('startup_crash_count', 0);
        debugPrint('✅ Startup successful, crash counter reset');
      }
    } catch (e) {
      debugPrint('⚠️ Could not reset crash counter: $e');
    }
    
    // Initialize the app
    runApp(const MyApp());
  }, (error, stackTrace) {
    // Catch any uncaught errors in the app
    debugPrint('💥 Uncaught error: $error');
    debugPrint('💥 Stack trace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MultiProvider wraps the app to provide state to all widgets
    // As you extend the app, use MultiProvider to wrap the app
    // and provide state to all widgets
    // Example:
    // return MultiProvider(
    //   providers: [
    //     ChangeNotifierProvider(create: (_) => ExampleProvider()),
    //   ],
    //   child: MaterialApp.router(
    //     title: 'Dreamflow Starter',
    //     debugShowCheckedModeBanner: false,
    //     routerConfig: AppRouter.router,
    //   ),
    // );
    return MaterialApp.router(
      title: 'BIMMERWISE',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,

      // Use context.go() or context.push() to navigate to the routes.
      routerConfig: AppRouter.router,
    );
  }
}
