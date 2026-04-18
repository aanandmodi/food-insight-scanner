// lib/presentation/profile/profile_screen.dart


import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userProfile;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = AuthService().currentUser;

      // Try Firestore first, fall back to local
      _userProfile = await FirestoreService().getUserProfile().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );

      // If Firestore returned nothing, load from SharedPreferences
      if (_userProfile == null) {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name');
        if (name != null && name.isNotEmpty) {
          _userProfile = {
            'name': name,
            'gender': prefs.getString('user_gender') ?? '',
            'dateOfBirth': prefs.getString('user_dob'),
            'heightCm': prefs.getDouble('user_height'),
            'weightKg': prefs.getDouble('user_weight'),
            'diseases': prefs.getStringList('user_diseases') ?? [],
            'allergies': prefs.getStringList('user_allergies') ?? [],
            'healthGoal': prefs.getString('user_health_goal') ?? '',
            'dietaryPreferences': prefs.getStringList('user_dietary_preferences') ?? [],
          };
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getDisplayName() {
    if (_userProfile?['name'] != null &&
        _userProfile!['name'].toString().isNotEmpty) {
      return _userProfile!['name'];
    }
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.isNotEmpty) {
      return _currentUser!.displayName!;
    }
    if (_currentUser?.isAnonymous == true) return 'Guest User';
    return 'User';
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Not set';
    try {
      final date = DateTime.parse(isoDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Not set';
    }
  }

  int? _calculateAge(String? isoDate) {
    if (isoDate == null) return null;
    try {
      final dob = DateTime.parse(isoDate);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) {
        age--;
      }
      return age;
    } catch (e) {
      return null;
    }
  }

  String? _calculateBMI() {
    final height = (_userProfile?['heightCm'] as num?)?.toDouble();
    final weight = (_userProfile?['weightKg'] as num?)?.toDouble();
    if (height == null || weight == null || height == 0) return null;
    final heightM = height / 100;
    final bmi = weight / (heightM * heightM);
    return bmi.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final age = _calculateAge(_userProfile?['dateOfBirth']);
    final bmi = _calculateBMI();

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit,
                color: AppTheme.lightTheme.colorScheme.primary),
            onPressed: () {
              Navigator.pushNamed(context, '/profile-setup')
                  .then((_) => _loadProfile());
            },
          ),
          IconButton(
            icon: Icon(Icons.settings,
                color: AppTheme.lightTheme.colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(5.w),
                child: Column(
                  children: [
                    // Avatar & Name
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 12.w,
                            backgroundColor: AppTheme.lightTheme
                                .colorScheme.primaryContainer,
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: TextStyle(
                                fontSize: 22.sp,
                                fontWeight: FontWeight.bold,
                                color: AppTheme
                                    .lightTheme.colorScheme.primary,
                              ),
                            ),
                          ),
                          SizedBox(height: 1.5.h),
                          Text(
                            displayName,
                            style: AppTheme
                                .lightTheme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            _currentUser?.email ??
                                (_currentUser?.isAnonymous == true
                                    ? 'Anonymous Account'
                                    : ''),
                            style: AppTheme.lightTheme.textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 3.h),

                    // Quick Stats Row
                    if (_userProfile != null)
                      Row(
                        children: [
                          if (age != null)
                            Expanded(
                                child:
                                    _buildStatChip('Age', '$age yrs')),
                          if (_userProfile?['gender'] != null &&
                              _userProfile!['gender']
                                  .toString()
                                  .isNotEmpty)
                            Expanded(
                                child: _buildStatChip(
                                    'Gender',
                                    _userProfile!['gender'])),
                          if (bmi != null)
                            Expanded(
                                child:
                                    _buildStatChip('BMI', bmi)),
                        ],
                      ),

                    SizedBox(height: 3.h),

                    // Detailed Info
                    _buildInfoSection(
                        'Date of Birth',
                        _formatDate(
                            _userProfile?['dateOfBirth']),
                        Icons.cake),
                    _buildInfoSection(
                        'Height',
                        _userProfile?['heightCm'] != null
                            ? '${(_userProfile!['heightCm'] as num).toStringAsFixed(0)} cm'
                            : 'Not set',
                        Icons.height),
                    _buildInfoSection(
                        'Weight',
                        _userProfile?['weightKg'] != null
                            ? '${(_userProfile!['weightKg'] as num).toStringAsFixed(1)} kg'
                            : 'Not set',
                        Icons.monitor_weight_outlined),
                    _buildInfoSection(
                        'Health Goal',
                        _userProfile?['healthGoal'] ?? 'Not set',
                        Icons.flag),
                    _buildInfoSection(
                        'Medical Conditions',
                        (_userProfile?['diseases'] as List?)
                                ?.join(', ') ??
                            'None',
                        Icons.medical_services_outlined),
                    _buildInfoSection(
                        'Allergies',
                        (_userProfile?['allergies'] as List?)
                                ?.join(', ') ??
                            'None',
                        Icons.warning_amber),
                    _buildInfoSection(
                        'Dietary Preferences',
                        (_userProfile?['dietaryPreferences'] as List?)
                                ?.join(', ') ??
                            'None',
                        Icons.restaurant),

                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1.w),
      padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.primaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.colorScheme.primary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 0.3.h),
          Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon,
              color: AppTheme.lightTheme.colorScheme.secondary,
              size: 22),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.labelMedium
                      ?.copyWith(color: Colors.grey[600]),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: AppTheme.lightTheme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
