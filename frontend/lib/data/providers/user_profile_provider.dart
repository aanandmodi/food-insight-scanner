import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserProfileProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchProfile();
    });
  }

  /// Fetches the user profile from local SharedPreferences.
  /// If a user is logged in, it will first attempt to sync with the cloud.
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    // Always attempt cloud sync first if authenticated
    if (AuthService().isAuthenticated) {
      await syncWithCloud();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name');

      if (name != null && name.isNotEmpty) {
        final dobStr = prefs.getString('user_dob');
        DateTime? dob;
        if (dobStr != null) {
          dob = DateTime.tryParse(dobStr);
        }

        _profile = UserProfile(
          uid: AuthService().currentUser?.uid ?? 'local_user',
          name: name,
          email: AuthService().currentUser?.email ?? prefs.getString('user_email') ?? 'local@user.app',
          photoUrl: AuthService().currentUser?.photoURL,
          gender: prefs.getString('user_gender') ?? 'Male',
          dateOfBirth: dob,
          heightCm: prefs.getDouble('user_height') ?? 170.0,
          weightKg: prefs.getDouble('user_weight') ?? 70.0,
          diseases: prefs.getStringList('user_diseases') ?? [],
          allergies: prefs.getStringList('user_allergies') ?? [],
          dietaryPreferences: prefs.getStringList('user_dietary_preferences') ?? [],
          healthGoals: prefs.getString('user_health_goal') ?? 'Healthy Lifestyle',
          age: prefs.getInt('user_age') ?? 25,
          activityLevel: prefs.getString('user_activity_level') ?? 'moderate',
          profileCompleted: prefs.getBool('profile_completed') ?? true,
        );
      } else {
        // No local profile data exists — leave _profile as null.
        // The auth gate / splash screen will check auth state and route
        // to the login screen or profile setup accordingly.
        _profile = null;
      }
    } catch (e) {
      debugPrint('Error loading local user profile: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save or update the profile locally in SharedPreferences and memory.
  Future<void> saveProfile(UserProfile newProfile) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newProfile.name);
      if (newProfile.email != null) {
        await prefs.setString('user_email', newProfile.email!);
      }
      await prefs.setString('user_gender', newProfile.gender);
      if (newProfile.dateOfBirth != null) {
        await prefs.setString('user_dob', newProfile.dateOfBirth!.toIso8601String());
      }
      if (newProfile.heightCm != null) {
        await prefs.setDouble('user_height', newProfile.heightCm!);
      }
      if (newProfile.weightKg != null) {
        await prefs.setDouble('user_weight', newProfile.weightKg!);
      }
      await prefs.setStringList('user_diseases', newProfile.diseases);
      await prefs.setStringList('user_allergies', newProfile.allergies);
      await prefs.setStringList('user_dietary_preferences', newProfile.dietaryPreferences);
      await prefs.setString('user_health_goal', newProfile.healthGoals);
      await prefs.setInt('user_age', newProfile.age);
      await prefs.setString('user_activity_level', newProfile.activityLevel);
      await prefs.setBool('profile_completed', true);

      _profile = newProfile.copyWith(profileCompleted: true);
      _errorMessage = null;
    } catch (e) {
      debugPrint('Error saving local profile: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Utility to clear profile / reset
  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Syncs local state with Firestore data
  Future<void> syncWithCloud() async {
    try {
      final cloudData = await FirestoreService().getUserProfile();
      if (cloudData != null && cloudData.isNotEmpty) {
        final newProfile = UserProfile(
          uid: AuthService().currentUser?.uid ?? 'cloud_user',
          name: cloudData['name'] ?? 'User',
          email: AuthService().currentUser?.email ?? cloudData['email'] ?? 'local@user.app',
          photoUrl: AuthService().currentUser?.photoURL ?? cloudData['photoUrl'],
          gender: cloudData['gender'] ?? 'Male',
          dateOfBirth: cloudData['dateOfBirth'] != null ? DateTime.tryParse(cloudData['dateOfBirth']) : null,
          heightCm: (cloudData['heightCm'] as num?)?.toDouble() ?? 170.0,
          weightKg: (cloudData['weightKg'] as num?)?.toDouble() ?? 70.0,
          diseases: (cloudData['diseases'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          allergies: (cloudData['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          dietaryPreferences: (cloudData['dietaryPreferences'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          healthGoals: cloudData['healthGoals'] ?? cloudData['healthGoal'] ?? 'Healthy Lifestyle',
          age: (cloudData['age'] as num?)?.toInt() ?? 25,
          activityLevel: cloudData['activityLevel'] ?? 'moderate',
          profileCompleted: cloudData['profileCompleted'] ?? true,
        );
        
        // This will update SharedPreferences AND _profile in memory
        await saveProfile(newProfile);
      }
    } catch (e) {
      debugPrint('Error syncing profile with cloud: $e');
    }
  }
}

