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
    
    // iOS-SAFE: Simple crash tracking without Firestore cache clearing
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final crashCount = prefs.getInt('startup_crash_count') ?? 0;
      
      if (crashCount >= 3) {
        debugPrint('⚠️ Detected crash loop ($crashCount crashes), resetting counter...');
        await prefs.remove('startup_crash_count');
      } else {
        // Increment crash counter - will be reset after successful startup
        await prefs.setInt('startup_crash_count', crashCount + 1);
      }
    } catch (e) {
      debugPrint('⚠️ Could not access SharedPreferences: $e');
    }
    
    // Initialize Firebase with iOS-safe error handling
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      
      // Configure Firestore - SAMSUNG-SAFE with limited cache
      if (!kIsWeb) {
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024, // 100MB limit
          );
          debugPrint('✅ Firestore persistence enabled');
        } catch (e) {
          debugPrint('⚠️ Firestore settings error: $e');
        }
      }
      
      // Set up background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        debugPrint('✅ Background message handler registered');
      } catch (e) {
        debugPrint('⚠️ Background handler error: $e');
      }
      
      // Initialize FCM Service - delayed start for stability
      Future.delayed(const Duration(milliseconds: 2000), () {
        FCMService().initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ FCM timeout');
          },
        ).catchError((e) {
          debugPrint('⚠️ FCM error: $e');
        }, test: (_) => true);
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('❌ Stack: $stackTrace');
      debugPrint('⚠️ App continues without Firebase');
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
