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
/// - Flutter binding initialization
/// - Firebase initialization with error handling
/// - Firebase Cloud Messaging (FCM) for push notifications
/// - go_router navigation
/// - Material 3 theming with light/dark modes
void main() async {
  // Wrap everything in error handling for better crash reporting
  runZonedGuarded(() async {
    // CRITICAL: Initialize Flutter bindings first (iOS-safe)
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase with comprehensive error handling (iOS-safe)
    try {
      debugPrint('🚀 Starting Firebase initialization...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      
      // Configure Firestore with platform-specific settings
      if (!kIsWeb) {
        try {
          // iOS/Android: Enable offline persistence with cache limit
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024, // 100MB limit
          );
          debugPrint('✅ Firestore persistence enabled (mobile)');
        } catch (e) {
          debugPrint('⚠️ Firestore settings error: $e');
          // Continue without persistence if it fails
        }
      } else {
        debugPrint('✅ Firestore configured for web');
      }
      
      // Set up background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        debugPrint('✅ Background message handler registered');
      } catch (e) {
        debugPrint('⚠️ Background handler error: $e');
      }
      
      // Initialize FCM Service - delayed start for stability (iOS-safe)
      if (!kIsWeb) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          FCMService().initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ FCM timeout');
            },
          ).catchError((e) {
            debugPrint('⚠️ FCM error: $e');
          }, test: (_) => true);
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('❌ Stack: $stackTrace');
      debugPrint('⚠️ App continues without Firebase');
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
