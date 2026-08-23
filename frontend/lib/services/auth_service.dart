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
    serverClientId: '579993459207-6rcmc0fgucpdc01f3rhvmtlc1oprlou4.apps.googleusercontent.com',
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

  /// True when the session is a guest (anonymous) session. Guests can be
  /// upgraded to a real account without losing their data — see
  /// [linkAnonymousWithEmail] / [linkAnonymousWithGoogle].
  bool get isGuest => currentUser?.isAnonymous ?? false;

  /// Whether the signed-in email user has verified their address.
  /// Anonymous and Google users are always considered verified.
  bool get isEmailVerified {
    final user = currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return true;
    final usesPassword =
        user.providerData.any((p) => p.providerId == 'password');
    return !usesPassword || user.emailVerified;
  }

  /// Take ownership of rows that were written before sign-in (guest usage),
  /// so nothing the user logged is lost when they create an account.
  Future<void> _adoptLocalData(String uid) async {
    try {
      await LocalDatabaseService().adoptLocalRows(uid);
    } catch (e) {
      debugPrint('adoptLocalRows failed (non-fatal): $e');
    }
  }

  /// Creates the Firestore profile document if the user does not have one yet.
  /// Never overwrites an existing profile.
  Future<void> _ensureProfileDocument(User user, {String? displayName}) async {
    try {
      final existingProfile = await FirestoreService()
          .getUserProfile()
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
      if (existingProfile != null) return;

      await FirestoreService().saveUserProfile({
        'email': user.email ?? '',
        // Deliberately blank when unknown: a placeholder like "User" reads as a
        // real, completed profile everywhere downstream.
        'name': (displayName ?? user.displayName ?? '').trim(),
        'photoUrl': user.photoURL ?? '',
        'isAnonymous': user.isAnonymous,
        'createdAt': DateTime.now().toIso8601String(),
        'profileCompleted': false,
      });
    } catch (e) {
      debugPrint('Firestore profile init error (non-fatal): $e');
    }
  }

  // ──────────────────────────── Email / Password ────────────────────────────

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    if (!isFirebaseReady) {
      await retryInit();
    }
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Unable to connect to Google Services. Please check your internet connection and try restarting the app.',
      );
    }

    try {
      final UserCredential userCredential =
          await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = userCredential.user;
      if (user != null) {
        await _adoptLocalData(user.uid);
        await _ensureProfileDocument(user);
      }
      debugPrint('Signed in with email: ${user?.email}');
      return user;
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
    if (!isFirebaseReady) {
      await retryInit();
    }
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Unable to connect to Google Services. Please check your internet connection and try restarting the app.',
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
        await _adoptLocalData(user.uid);
        await _ensureProfileDocument(user, displayName: displayName);
        // Fire-and-forget: a failed verification mail must not block signup.
        try {
          if (!user.emailVerified) await user.sendEmailVerification();
        } catch (e) {
          debugPrint('Could not send verification email (non-fatal): $e');
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
    if (!isFirebaseReady) {
      await retryInit();
    }
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Unable to connect to Google Services. Please check your internet connection and try restarting the app.',
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
        await _adoptLocalData(user.uid);
        await _ensureProfileDocument(user);
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
    if (!isFirebaseReady) {
      await retryInit();
    }
    final auth = _auth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-unavailable',
        message: 'Firebase is not available for guest mode.',
      );
    }

    try {
      final UserCredential userCredential = await auth.signInAnonymously();
      final user = userCredential.user;
      if (user != null) {
        await _adoptLocalData(user.uid);
        // Guests need a profile document too, otherwise every read falls
        // through to the local cache and their data never syncs.
        await _ensureProfileDocument(user);
      }
      debugPrint('Signed in anonymously: ${user?.uid}');
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous sign-in error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    }
  }

  /// Upgrades the current guest session to a permanent email account,
  /// **keeping the same uid** so all previously logged data carries over.
  Future<User?> linkAnonymousWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw AuthException(
        code: 'not-a-guest',
        message: 'You are already signed in with a permanent account.',
      );
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      final linked = result.user;

      if (linked != null) {
        if (displayName != null && displayName.trim().isNotEmpty) {
          await linked.updateDisplayName(displayName.trim());
          await linked.reload();
        }
        try {
          await FirestoreService().saveUserProfile({
            'email': linked.email ?? email.trim(),
            'isAnonymous': false,
          });
        } catch (e) {
          debugPrint('Profile update after link failed (non-fatal): $e');
        }
        try {
          if (!linked.emailVerified) await linked.sendEmailVerification();
        } catch (_) {}
      }

      debugPrint('Guest account upgraded to ${linked?.email}');
      return _auth?.currentUser ?? linked;
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous link error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    }
  }

  /// Upgrades the current guest session to a permanent Google account,
  /// keeping the same uid.
  Future<User?> linkAnonymousWithGoogle() async {
    final user = currentUser;
    if (user == null || !user.isAnonymous) {
      throw AuthException(
        code: 'not-a-guest',
        message: 'You are already signed in with a permanent account.',
      );
    }

    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await user.linkWithCredential(credential);
      final linked = result.user;
      if (linked != null) {
        try {
          await FirestoreService().saveUserProfile({
            'email': linked.email ?? '',
            'photoUrl': linked.photoURL ?? '',
            'isAnonymous': false,
          });
        } catch (e) {
          debugPrint('Profile update after link failed (non-fatal): $e');
        }
      }
      return _auth?.currentUser ?? linked;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google link error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebase(e);
    } catch (e) {
      throw AuthException(
        code: 'google-link-failed',
        message: 'Could not connect your Google account. Please try again.',
      );
    }
  }

  /// Re-sends the verification email to the current user.
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user == null) {
      throw AuthException(
        code: 'no-user',
        message: 'You need to be signed in to verify your email.',
      );
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebase(e);
    }
  }

  /// Refreshes the cached user so `emailVerified` reflects reality.
  Future<bool> reloadUser() async {
    try {
      await currentUser?.reload();
      return isEmailVerified;
    } catch (e) {
      debugPrint('User reload failed: $e');
      return isEmailVerified;
    }
  }

  // ──────────────────────────── Account Management ────────────────────────────

  /// Signs the current user out and clears ALL local cached data.
  /// This is an atomic operation — Firebase signout + Google signout + local purge.
  Future<void> signOut() async {
    // Capture the uid *before* signing out — afterwards the local database can
    // no longer tell which rows belonged to this user.
    final departingUid = currentUser?.uid;
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
      await _clearLocalData(uid: departingUid);

      debugPrint('User signed out successfully — all local data cleared.');
    } catch (e) {
      debugPrint('Error during sign out: $e');
      // Even if something failed, still clear local data
      await _clearLocalData(uid: departingUid);
    }
  }

  /// Delete the current user account and purge all data.
  ///
  /// Firebase refuses `delete()` with `requires-recent-login` when the session
  /// is older than ~5 minutes. Since Google Play requires in-app account
  /// deletion to actually work, we reauthenticate first when we can:
  ///  * password users → pass [password]
  ///  * Google users   → silent re-consent through the Google Sign-In flow
  Future<void> deleteAccount({String? password}) async {
    final user = _auth?.currentUser;
    if (user == null) {
      throw AuthException(
        code: 'no-user',
        message: 'You are not signed in.',
      );
    }

    try {
      await _reauthenticateIfPossible(user, password);
      final deletedUid = user.uid;

      // Delete Firestore profile + subcollections before losing the token.
      try {
        await FirestoreService().deleteUserProfile();
      } catch (e) {
        debugPrint('Firestore profile delete error (non-fatal): $e');
      }

      await user.delete();

      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google sign-out error (non-fatal): $e');
      }

      await _clearLocalData(uid: deletedUid);

      debugPrint('Account deleted successfully.');
    } on FirebaseAuthException catch (e) {
      debugPrint('Account deletion error: ${e.code}');
      if (e.code == 'requires-recent-login') {
        throw AuthException(
          code: 'requires-recent-login',
          message:
              'For your security, please sign in again and then delete your account.',
        );
      }
      throw AuthException.fromFirebase(e);
    }
  }

  Future<void> _reauthenticateIfPossible(User user, String? password) async {
    final providers = user.providerData.map((p) => p.providerId).toList();

    try {
      if (providers.contains('password') &&
          password != null &&
          password.isNotEmpty &&
          (user.email ?? '').isNotEmpty) {
        final cred = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(cred);
        return;
      }

      if (providers.contains('google.com')) {
        final googleUser =
            await _googleSignIn.signInSilently() ?? await _googleSignIn.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          await user.reauthenticateWithCredential(
            GoogleAuthProvider.credential(
              accessToken: googleAuth.accessToken,
              idToken: googleAuth.idToken,
            ),
          );
        }
      }
      // Anonymous users need no reauthentication.
    } on FirebaseAuthException catch (e) {
      // Surface bad-password immediately rather than failing later on delete().
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw AuthException.fromFirebase(e);
      }
      debugPrint('Reauthentication skipped: ${e.code}');
    } catch (e) {
      debugPrint('Reauthentication skipped: $e');
    }
  }

  /// Clears all locally cached user data to prevent leakage between accounts.
  Future<void> _clearLocalData({String? uid}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Every key any screen writes about the user must be listed here, or the
      // next account inherits the previous one's values.
      const userKeys = <String>[
        'user_name',
        'user_email',
        'user_photoUrl',
        'user_gender',
        'user_dob',
        'user_age',
        'user_height',
        'user_weight',
        'user_diseases',
        'user_allergies',
        'user_health_goal',
        'user_dietary_preferences',
        'user_activity_level',
        'profile_completed',
        'custom_calories_goal',
        'custom_protein_goal',
        'custom_carbs_goal',
        'custom_fat_goal',
        'last_ai_recalibration',
      ];
      for (final key in userKeys) {
        await prefs.remove(key);
      }

      // Clear local scan history (SQLite)
      try {
        await ProductService().clearLocalHistory();
      } catch (e) {
        debugPrint('Error clearing local scan history: $e');
      }

      // Clear all local SQLite tables (scan_history, diet_log, shopping_list)
      try {
        await LocalDatabaseService().clearAllLocalData(forUid: uid);
      } catch (e) {
        debugPrint('Error clearing local database tables: $e');
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
