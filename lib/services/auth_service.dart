import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:bimmerwise_connect/models/user_model.dart';

/// AuthService manages Firebase Authentication
/// Handles user registration, login, logout, and admin authentication
class AuthService {
  auth.FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  
  static const String _adminEmail = 'admin@bimmerwise.com';
  static const String _adminPassword = 'admin123';

  AuthService() {
    try {
      _auth = auth.FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
    } catch (e) {
      debugPrint('Firebase not initialized: $e');
    }
  }

  /// Get current Firebase user
  auth.User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  /// Stream of auth state changes
  Stream<auth.User?> get authStateChanges {
    if (_auth == null) return Stream.value(null);
    return _auth!.authStateChanges();
  }

  /// Register a new user with email and password
  Future<User?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    bool isAdmin = false,
  }) async {
    if (_auth == null || _firestore == null) {
      debugPrint('Firebase not initialized');
      throw Exception('Firebase not initialized');
    }
    
    try {
      // Create Firebase Auth user
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Create user document in Firestore
      final user = User(
        id: credential.user!.uid,
        name: name,
        email: email,
        phone: phone,
        isAdmin: isAdmin,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore!.collection('users').doc(user.id).set(user.toJson());

      debugPrint('User registered successfully: ${user.email}');
      return user;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Registration error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Registration error: $e');
      rethrow;
    }
  }

  /// Login user with email and password
  Future<User?> login(String email, String password) async {
    if (_auth == null || _firestore == null) {
      debugPrint('Firebase not initialized');
      throw Exception('Firebase not initialized');
    }
    
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return null;

      // Get user data from Firestore
      final doc = await _firestore!.collection('users').doc(credential.user!.uid).get();
      
      if (!doc.exists) {
        debugPrint('User document not found in Firestore');
        return null;
      }

      final user = User.fromJson(doc.data()!);
      debugPrint('User logged in successfully: ${user.email}');
      return user;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
  }

  /// Admin login - checks if user has isAdmin: true in Firestore
  Future<bool> adminLogin(String email, String password) async {
    if (_auth == null || _firestore == null) {
      debugPrint('Firebase not initialized');
      return false;
    }

    try {
      // First try to authenticate with email and password
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) return false;

      // Check if user has admin privileges in Firestore
      final doc = await _firestore!.collection('users').doc(credential.user!.uid).get();
      
      if (!doc.exists) {
        // If using the default admin credentials, create the admin account
        if (email.toLowerCase() == _adminEmail && password == _adminPassword) {
          final adminUser = User(
            id: credential.user!.uid,
            name: 'Admin',
            email: email,
            phone: '+1234567890',
            isAdmin: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _firestore!.collection('users').doc(adminUser.id).set(adminUser.toJson());
          debugPrint('Admin account created successfully');
          return true;
        }
        debugPrint('User document not found');
        return false;
      }

      final user = User.fromJson(doc.data()!);
      if (user.isAdmin) {
        debugPrint('Admin logged in successfully: ${user.email}');
        return true;
      } else {
        debugPrint('User is not an admin: ${user.email}');
        await _auth!.signOut(); // Sign out non-admin users
        return false;
      }
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Admin login error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Admin login error: $e');
      return false;
    }
  }

  /// Check if current user is admin (based on Firestore isAdmin field)
  Future<bool> isAdmin() async {
    try {
      final user = await getCurrentUserData();
      return user?.isAdmin ?? false;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  /// Logout current user
  Future<void> logout() async {
    if (_auth == null) {
      debugPrint('Firebase not initialized');
      return;
    }
    
    try {
      await _auth!.signOut();
      debugPrint('User logged out successfully');
    } catch (e) {
      debugPrint('Logout error: $e');
      rethrow;
    }
  }

  /// Get current user data from Firestore
  Future<User?> getCurrentUserData() async {
    if (_firestore == null) {
      debugPrint('Firebase not initialized');
      return null;
    }
    
    try {
      final user = currentUser;
      if (user == null) return null;

      final doc = await _firestore!.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      return User.fromJson(doc.data()!);
    } catch (e) {
      debugPrint('Error getting current user data: $e');
      return null;
    }
  }

  /// Send password reset email
  Future<bool> resetPassword(String email) async {
    if (_auth == null) {
      debugPrint('Firebase not initialized');
      return false;
    }
    
    try {
      await _auth!.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to: $email');
      return true;
    } on auth.FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Password reset error: $e');
      return false;
    }
  }

  /// Get admin email
  String getAdminEmail() => _adminEmail;

  /// Get admin user ID
  /// Returns the current user's UID if admin is logged in
  /// Otherwise returns a static 'admin' identifier
  String getAdminUserId() {
    if (currentUser != null && currentUser!.email?.toLowerCase() == _adminEmail) {
      return currentUser!.uid;
    }
    return 'admin';
  }
  
  /// Get admin user ID for notifications (always returns 'admin' for consistency)
  String getAdminUserIdForNotifications() => 'admin';
}
