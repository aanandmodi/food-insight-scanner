import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_profile.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  UserProfileProvider() {
    fetchProfile();
  }

  /// Fetches the user profile from local SharedPreferences.
  Future<void> fetchProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

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
          uid: 'local_user',
          name: name,
          email: prefs.getString('user_email') ?? 'local@user.app',
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
        // Fallback default local profile so app features work immediately
        _profile = UserProfile(
          uid: 'local_user',
          name: 'Local User',
          email: 'local@user.app',
          gender: 'Male',
          heightCm: 170.0,
          weightKg: 70.0,
          diseases: [],
          allergies: [],
          dietaryPreferences: [],
          healthGoals: 'Healthy Lifestyle',
          age: 25,
          activityLevel: 'moderate',
          profileCompleted: false,
        );
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
}

