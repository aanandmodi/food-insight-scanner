import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/data_refresh_bus.dart';
import '../../models/user_profile.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/local_database_service.dart';

/// Owns the signed-in user's profile and keeps it bound to the Firebase uid.
///
/// Behaviour that this class guarantees (each point was previously broken):
///  * It re-fetches on every **change of user** and clears on sign-out, so one
///    account never sees another's profile.
///  * `profileCompleted` is only ever true because onboarding said so — it is
///    never inferred or forced, which is what used to let brand-new users skip
///    setup and land on an empty dashboard named "User".
///  * Saving writes to Firestore as well as SharedPreferences, so profile edits
///    actually reach the cloud and survive a reinstall.
class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = true;
  String? _errorMessage;
  String? _boundUid;
  StreamSubscription<User?>? _authSub;
  bool _disposed = false;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// True when the last load failed for a reason other than "no profile yet".
  /// The gate uses this to show a retry instead of dumping the user into
  /// onboarding after a transient network failure.
  bool get hasError => _errorMessage != null;

  /// True only when we positively know onboarding is finished.
  bool get isProfileComplete => _profile?.profileCompleted == true;

  /// The uid this profile belongs to, for debugging / assertions.
  String? get boundUid => _boundUid;

  UserProfileProvider() {
    _listenToAuth();
  }

  void _listenToAuth() {
    try {
      _authSub = AuthService()
          .authStateChanges
          .distinct((a, b) => a?.uid == b?.uid)
          .listen(_onUserChanged, onError: (Object e) {
        debugPrint('Auth stream error in UserProfileProvider: $e');
      });
    } catch (e) {
      debugPrint('Could not attach auth listener: $e');
      // Firebase unavailable — still try a local read so offline users see data.
      WidgetsBinding.instance.addPostFrameCallback((_) => fetchProfile());
    }
  }

  Future<void> _onUserChanged(User? user) async {
    _boundUid = user?.uid;

    if (user == null) {
      _profile = null;
      _errorMessage = null;
      _isLoading = false;
      _safeNotify();
      return;
    }

    // Claim anything the user logged before signing in.
    try {
      await LocalDatabaseService().adoptLocalRows(user.uid);
    } catch (e) {
      debugPrint('adoptLocalRows failed: $e');
    }

    await fetchProfile();
  }

  /// Loads the profile for the current user: Firestore first, SharedPreferences
  /// as an offline fallback (both handled by [FirestoreService.getUserProfile]).
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    _safeNotify();

    final authUser = AuthService().currentUser;

    try {
      final data = await FirestoreService().getUserProfile();

      if (data == null) {
        // No profile anywhere — a genuinely new user. Onboarding will create it.
        _profile = null;
      } else {
        var loaded = UserProfile.fromMap(data);

        // Identity always comes from Firebase Auth, never from the cached copy.
        loaded = loaded.copyWith(
          uid: authUser?.uid ?? loaded.uid,
          email: authUser?.email ?? loaded.email,
          photoUrl: authUser?.photoURL ?? loaded.photoUrl,
        );

        // A profile with no name is not usable — treat it as "not set up yet".
        _profile = loaded.name.trim().isEmpty ? null : loaded;

        // Keep the offline cache in step with what we just read.
        if (_profile != null) {
          await _writeToPrefs(_profile!);
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Persist the profile locally **and** to Firestore.
  ///
  /// [markCompleted] must be passed explicitly by onboarding when it finishes.
  /// Everything else preserves the flag that is already on [newProfile] — the
  /// old implementation force-set it to true on every save, including during
  /// cloud sync, which silently completed profiles that were never filled in.
  Future<bool> saveProfile(UserProfile newProfile,
      {bool? markCompleted}) async {
    _isLoading = true;
    _safeNotify();

    final authUser = AuthService().currentUser;
    final resolved = newProfile.copyWith(
      uid: authUser?.uid ?? newProfile.uid,
      email: authUser?.email ?? newProfile.email,
      photoUrl: authUser?.photoURL ?? newProfile.photoUrl,
      profileCompleted: markCompleted ?? newProfile.profileCompleted,
    );

    bool cloudOk = false;
    try {
      await _writeToPrefs(resolved);
      cloudOk = await FirestoreService().saveUserProfile(resolved.toMap());
      if (!cloudOk) {
        debugPrint('Profile saved locally; cloud write will retry on next sync');
      }
      _profile = resolved;
      _errorMessage = null;
      DataRefreshBus.profileChanged();
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _safeNotify();
    }
    return cloudOk;
  }

  Future<void> _writeToPrefs(UserProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', p.name);
    if (p.email != null) await prefs.setString('user_email', p.email!);
    if (p.photoUrl != null) {
      await prefs.setString('user_photoUrl', p.photoUrl!);
    }
    await prefs.setString('user_gender', p.gender);
    if (p.dateOfBirth != null) {
      await prefs.setString('user_dob', p.dateOfBirth!.toIso8601String());
    }
    if (p.heightCm != null) await prefs.setDouble('user_height', p.heightCm!);
    if (p.weightKg != null) await prefs.setDouble('user_weight', p.weightKg!);
    await prefs.setStringList('user_diseases', p.diseases);
    await prefs.setStringList('user_allergies', p.allergies);
    await prefs.setStringList(
        'user_dietary_preferences', p.dietaryPreferences);
    await prefs.setString('user_health_goal', p.healthGoals);
    await prefs.setInt('user_age', p.age);
    await prefs.setString('user_activity_level', p.activityLevel);
    // Mirrors the real flag instead of hardcoding true.
    await prefs.setBool('profile_completed', p.profileCompleted);
  }

  /// Clear in-memory profile (called on sign-out).
  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    _boundUid = null;
    _isLoading = false;
    _safeNotify();
  }

  /// Re-read the cloud copy. Kept for callers that want an explicit refresh;
  /// unlike the old version it does not write back through [saveProfile], so it
  /// can no longer flip `profileCompleted` from false to true.
  Future<void> syncWithCloud() => fetchProfile();

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }
}
