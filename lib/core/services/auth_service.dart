// lib/core/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // For kDebugMode

/// A service class to handle all Firebase Authentication logic.
class AuthService {
  // Instances of Firebase and Google Sign-In
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// A stream that notifies the app about changes in the user's authentication state.
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Gets the currently signed-in user, if any.
  User? get currentUser => _firebaseAuth.currentUser;

  /// Initiates the Google Sign-In flow and authenticates with Firebase.
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Trigger the native Google Sign-In UI to pop up.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // The user canceled the sign-in flow.
        if (kDebugMode) print('Google Sign-In was cancelled by the user.');
        return null;
      }

      // 2. Obtain the authentication tokens from the signed-in Google user.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Create a Firebase credential using the Google tokens.
      // The accessToken and idToken are now available directly on the googleAuth object.
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Sign in to Firebase with the created credential.
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);

      if (kDebugMode) print('Successfully signed in with Google: ${userCredential.user?.displayName}');
      
      return userCredential.user;

    } catch (e) {
      if (kDebugMode) print('Error during Google Sign-In: $e');
      // Re-throwing the exception is good practice, so the UI can catch it
      // and show a user-friendly message.
      rethrow;
    }
  }

  /// Signs in the user anonymously.
  /// Useful for "Guest Mode" or initial app usage where a User ID is needed
  /// for database operations but full registration isn't required yet.
  Future<User?> signInAnonymously() async {
    try {
      final UserCredential userCredential =
          await _firebaseAuth.signInAnonymously();
      if (kDebugMode) {
        print('Signed in anonymously: ${userCredential.user?.uid}');
      }
      return userCredential.user;
    } catch (e) {
      if (kDebugMode) print('Error during anonymous sign-in: $e');
      rethrow;
    }
  }

  /// Signs the current user out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      if (kDebugMode) print('User signed out successfully.');
    } catch (e) {
      if (kDebugMode) print('Error during sign out: $e');
      rethrow;
    }
  }
}