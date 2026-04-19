import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../services/firestore_service.dart';

class UserProfileProvider extends ChangeNotifier {
  UserProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Fetches the user profile from Firestore once and stores it in memory.
  Future<void> fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _errorMessage = "User not logged in.";
      _profile = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await FirestoreService().getUserProfile();
      if (data != null) {
        _profile = UserProfile.fromMap(data);
      } else {
        _errorMessage = "Profile not found.";
        _profile = null;
      }
    } catch (e) {
      _errorMessage = e.toString();
      _profile = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Utility to clear profile when signing out
  void clearProfile() {
    _profile = null;
    _errorMessage = null;
    notifyListeners();
  }
}
