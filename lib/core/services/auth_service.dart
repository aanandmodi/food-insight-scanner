// lib/core/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

import 'firestore_service.dart';
import 'local_database_service.dart';
import 'product_service.dart';
import '../../main.dart' show retryFirebaseInit;

/// A service class to handle all Firebase Authentication logic.
/// All methods are resilient to Firebase being unavailable.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ──────────────────────────── Firebase Readiness ────────────────────────────

  /// Check if Firebase is available
  bool get isFirebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Re-attempt Firebase initialization. Returns true if successful.
  /// Also syncs any locally stored diet entries to Firestore on success.
  Future<bool> retryInit() async {
    final success = await retryFirebaseInit();
    if (success) {
      // Sync local diet entries to cloud now that Firebase is available
      try {
        await FirestoreService().syncLocalEntriesToCloud();
      } catch (e) {
        debugPrint('Failed to sync local entries after retry: $e');
      }
    }
    return success;
  }

  FirebaseAuth? get _auth {
    if (!isFirebaseReady) return null;
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      debugPrint('FirebaseAuth unavailable: $e');
      return null;
    }
  }

  /// A stream that notifies the app about changes in the user's authentication state.
  Stream<User?> get authStateChanges {
    final auth = _auth;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges();
  }

  /// Gets the currently signed-in user, if any.
  User? get currentUser => _auth?.currentUser;

  /// Whether user is authenticated (Firebase or offline guest)
  bool get isAuthenticated => currentUser != null;

  // ──────────────────────────── Email / Password ────────────────────────────

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available. Please check your internet connection and try again.',
      );
    }

    try {
      final UserCredential userCredential =
          await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      debugPrint('Signed in with email: ${userCredential.user?.email}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign-in error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    } catch (e) {
      debugPrint('Email sign-in unexpected error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during sign in.',
      );
    }
  }

  /// Create a new account with email and password
  Future<User?> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available. Please check your internet connection and try again.',
      );
    }

    try {
      final UserCredential userCredential =
          await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await userCredential.user?.updateDisplayName(displayName);
        await userCredential.user?.reload();
      }

      // Initialize Firestore profile
      final user = auth.currentUser ?? userCredential.user;
      if (user != null) {
        try {
          final existingProfile = await FirestoreService()
              .getUserProfile()
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (existingProfile == null) {
            await FirestoreService().saveUserProfile({
              'email': user.email ?? '',
              'name': user.displayName ?? displayName ?? 'User',
              'createdAt': DateTime.now().toIso8601String(),
              'profileCompleted': false,
            });
          }
        } catch (e) {
          debugPrint('Firestore profile init error (non-fatal): $e');
        }
      }

      debugPrint('Account created for: ${userCredential.user?.email}');
      return auth.currentUser ?? userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Email sign-up error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    } catch (e) {
      debugPrint('Email sign-up unexpected error: $e');
      throw AuthException(
        code: 'unknown',
        message: 'An unexpected error occurred during sign up.',
      );
    }
  }

  /// Send a password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available.',
      );
    }

    try {
      await auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    }
  }

  // ──────────────────────────── Google Sign-In ────────────────────────────

  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  Future<User?> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available. Please check your internet connection.',
      );
    }

    try {
      // Clear any previous Google Sign-In state to prevent stale sessions
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await auth.signInWithCredential(credential);

      // Initialize Firestore profile if it doesn't exist
      final user = userCredential.user;
      if (user != null) {
        try {
          final existingProfile = await FirestoreService()
              .getUserProfile()
              .timeout(const Duration(seconds: 5), onTimeout: () => null);
          if (existingProfile == null) {
            await FirestoreService().saveUserProfile({
              'email': user.email ?? '',
              'name': user.displayName ?? 'Google User',
              'createdAt': DateTime.now().toIso8601String(),
              'profileCompleted': false,
            });
          }
        } catch (e) {
          debugPrint('Firestore profile init error (non-fatal): $e');
        }
      }

      debugPrint('Successfully signed in with Google: ${user?.displayName}');
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in Firebase error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    } catch (e) {
      debugPrint('╔══════════════════════════════════════════════════');
      debugPrint('║ GOOGLE SIGN-IN ERROR');
      debugPrint('║ Type: ${e.runtimeType}');
      debugPrint('║ Raw: $e');
      if (e is PlatformException) {
        debugPrint('║ PlatformException Code: ${e.code}');
        debugPrint('║ PlatformException Message: ${e.message}');
        debugPrint('║ PlatformException Details: ${e.details}');
      }
      debugPrint('╚══════════════════════════════════════════════════');
      throw AuthException(
        code: 'google-sign-in-failed',
        message: 'Google Sign-In failed: ${e is PlatformException ? '${e.code} – ${e.message}' : e.toString()}',
      );
    }
  }

  // ──────────────────────────── Anonymous ────────────────────────────

  /// Signs in the user anonymously (Guest Mode).
  Future<User?> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available for guest mode.',
      );
    }

    try {
      final UserCredential userCredential = await auth.signInAnonymously();
      debugPrint('Signed in anonymously: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous sign-in error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    }
  }

  // ──────────────────────────── Account Management ────────────────────────────

  /// Signs the current user out and clears ALL local cached data.
  /// This is an atomic operation — Firebase signout + Google signout + local purge.
  Future<void> signOut() async {
    try {
      // 1. Sign out of Google first (prevents reuse of cached credentials)
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign-out error (non-fatal): $e');
      }

      // 2. Sign out of Firebase
      try {
        await _auth?.signOut();
      } catch (e) {
        debugPrint('Firebase sign-out error (non-fatal): $e');
      }

      // 3. Clear all local user data
      await _clearLocalData();

      debugPrint('User signed out successfully — all local data cleared.');
    } catch (e) {
      debugPrint('Error during sign out: $e');
      // Even if something failed, still clear local data
      await _clearLocalData();
    }
  }

  /// Delete the current user account and purge all data
  Future<void> deleteAccount() async {
    try {
      // Delete Firestore profile first
      try {
        await FirestoreService().deleteUserProfile();
      } catch (e) {
        debugPrint('Firestore profile delete error (non-fatal): $e');
      }

      // Delete Firebase Auth account
      await _auth?.currentUser?.delete();

      // Sign out of Google
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign-out error (non-fatal): $e');
      }

      // Clear all local data
      await _clearLocalData();

      debugPrint('Account deleted successfully.');
    } on FirebaseAuthException catch (e) {
      debugPrint('Account deletion error: ${e.code}');
      throw AuthException.fromFirebase(e);
    }
  }

  /// Clears all locally cached user data to prevent leakage between accounts.
  Future<void> _clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_name');
      await prefs.remove('user_gender');
      await prefs.remove('user_dob');
      await prefs.remove('user_height');
      await prefs.remove('user_weight');
      await prefs.remove('user_diseases');
      await prefs.remove('user_allergies');
      await prefs.remove('user_health_goal');
      await prefs.remove('user_dietary_preferences');
      await prefs.remove('profile_completed');

      // Clear local scan history (SQLite)
      try {
        await ProductService().clearLocalHistory();
      } catch (e) {
        debugPrint('Error clearing local scan history: $e');
      }

      // Clear local diet log (SQLite)
      try {
        await LocalDatabaseService().clearDietLog();
      } catch (e) {
        debugPrint('Error clearing local diet log: $e');
      }
    } catch (e) {
      debugPrint('Error clearing local data: $e');
    }
  }

  /// Get a friendly error message from an AuthException or any error
  static String getErrorMessage(dynamic error) {
    if (error is AuthException) {
      return error.message;
    }
    if (error is FirebaseAuthException) {
      return AuthException.fromFirebase(error).message;
    }
    final msg = error.toString();
    if (msg.contains('firebase-unavailable') ||
        msg.contains('Firebase is not available')) {
      return 'Unable to connect to the server. Please check your internet and try again.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}

/// Custom exception class for auth errors with user-friendly messages.
class AuthException implements Exception {
  final String code;
  final String message;

  AuthException({required this.code, required this.message});

  factory AuthException.fromFirebase(FirebaseAuthException e) {
    final message = switch (e.code) {
      'user-not-found' => 'No account found with this email address.',
      'wrong-password' => 'Incorrect password. Please try again.',
      'invalid-credential' => 'Invalid email or password. Please check and try again.',
      'email-already-in-use' => 'An account already exists with this email.',
      'invalid-email' => 'Please enter a valid email address.',
      'weak-password' => 'Password is too weak. Use at least 6 characters.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'user-disabled' => 'This account has been disabled.',
      'operation-not-allowed' => 'This sign-in method is not enabled.',
      'requires-recent-login' =>
        'Please sign in again to perform this action.',
      'network-request-failed' =>
        'Network error. Please check your internet connection.',
      'account-exists-with-different-credential' =>
        'An account already exists with a different sign-in method.',
      _ => e.message ?? 'An authentication error occurred.',
    };
    return AuthException(code: e.code, message: message);
  }

  @override
  String toString() => 'AuthException($code): $message';
}