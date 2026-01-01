import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:bimmerwise_connect/services/theme.dart';
import 'package:bimmerwise_connect/nav.dart';
import 'package:bimmerwise_connect/firebase_options.dart';
import 'package:bimmerwise_connect/services/fcm_service.dart';

/// Main entry point for the application
///
/// This sets up:
/// - Flutter binding initialization (synchronous)
/// - Material app starts immediately (no blocking)
/// - Firebase initialization happens AFTER first frame (async)
void main() {
  // CRITICAL: Initialize Flutter bindings first
  WidgetsFlutterBinding.ensureInitialized();
  
  // Start the app immediately (no await, no blocking)
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;
  bool _appReady = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize Firebase asynchronously (non-blocking)
    _initAsync();
    
    // Request FCM permissions AFTER first frame is rendered
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('🎯 First frame rendered, requesting FCM permissions...');
        FCMService().requestPermissionsAfterFirstFrame();
      });
    }
  }
  
  Future<void> _initAsync() async {
    try {
      debugPrint('🚀 Starting Firebase initialization...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('✅ Firebase initialized successfully');
      
      // Configure Firestore with platform-specific settings
      if (!kIsWeb) {
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: 100 * 1024 * 1024, // 100MB
          );
          debugPrint('✅ Firestore persistence enabled');
        } catch (e) {
          debugPrint('⚠️ Firestore settings error: $e');
        }
      } else {
        debugPrint('✅ Firestore configured for web');
      }
      
      // Set up background message handler
      try {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        debugPrint('✅ Background message handler registered');
      } catch (e) {
        debugPrint('⚠️ Background handler error: $e');
      }
      
      // Initialize FCM Service (without permissions yet)
      if (!kIsWeb) {
        FCMService().initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ FCM timeout');
            return null;
          },
        ).catchError((e) {
          debugPrint('⚠️ FCM error: $e');
          return null;
        });
      }
      
      // Create router ONLY after Firebase initialization completes
      setState(() {
        _router = AppRouter.createRouter();
        _appReady = true;
      });
      debugPrint('🎉 Router created and app ready');
    } catch (e, stackTrace) {
      debugPrint('❌ Firebase initialization error: $e');
      debugPrint('❌ Stack: $stackTrace');
      debugPrint('⚠️ App continues without Firebase');
      
      // Create router even if Firebase fails (graceful degradation)
      setState(() {
        _router = AppRouter.createRouter();
        _appReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen until Firebase initialization completes
    if (!_appReady || _router == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Only show router after Firebase is ready
    return MaterialApp.router(
      title: 'BIMMERWISE',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: _router!,
    );
  }
}
