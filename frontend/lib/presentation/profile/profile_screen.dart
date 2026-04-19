// lib/presentation/profile/profile_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_export.dart';
import '../../services/firestore_service.dart';
import '../../core/utils/user_utils.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProfileProvider>().fetchProfile();
    });
  }

  Future<void> _loadProfile() async {
    await context.read<UserProfileProvider>().fetchProfile();
  }

  String _getDisplayName(UserProfile? profile) {
    if (profile?.name != null && profile!.name.isNotEmpty) {
      return profile.name;
    }
    return 'User';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    try {
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Not set';
    }
  }

  int? _calculateAge(DateTime? dob) {
    if (dob == null) return null;
    return UserUtils.calculateAge(dob);
  }

  String? _calculateBMI(UserProfile? profile) {
    final height = profile?.heightCm;
    final weight = profile?.weightKg;
    if (height == null || weight == null || height == 0) return null;
    final heightM = height / 100;
    final bmi = weight / (heightM * heightM);
    return bmi.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final provider = context.watch<UserProfileProvider>();
    final profile = provider.profile;
    final isLoading = provider.isLoading;

    final displayName = _getDisplayName(profile);
    final age = _calculateAge(profile?.dateOfBirth);
    final bmi = _calculateBMI(profile);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Profile',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: colorScheme.primary),
            onPressed: () {
              Navigator.pushNamed(context, '/profile-setup')
                  .then((_) => _loadProfile());
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: colorScheme.onSurfaceVariant),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(color: colorScheme.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: colorScheme.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(5.w),
                child: Column(
                  children: [
                    // Avatar & Name
                    Center(
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: isDark
                                  ? AppTheme.glowBoxShadow(
                                      colorScheme.primary,
                                      intensity: 0.2,
                                      blur: 20,
                                    )
                                  : null,
                            ),
                            child: CircleAvatar(
                              radius: 12.w,
                              backgroundColor: isDark
                                  ? colorScheme.primary.withValues(alpha: 0.15)
                                  : colorScheme.primaryContainer,
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 1.5.h),
                          Text(
                            displayName,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              shadows: isDark
                                  ? AppTheme.textGlow(colorScheme.primary, blur: 6)
                                  : null,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),
                          Text(
                            profile?.email ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scaleXY(begin: 0.95, end: 1.0, duration: 500.ms),
                    SizedBox(height: 3.h),

                    // Quick Stats Row
                    if (profile != null)
                      Row(
                        children: [
                          if (age != null)
                            Expanded(
                              child: _buildStatChip(context, 'Age', '$age yrs'),
                            ),
                          if (profile.gender.isNotEmpty)
                            Expanded(
                              child: _buildStatChip(
                                  context, 'Gender', profile.gender),
                            ),
                          if (bmi != null)
                            Expanded(
                              child: _buildStatChip(context, 'BMI', bmi),
                            ),
                        ],
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 100.ms)
                          .slideY(begin: 0.05, end: 0),

                    SizedBox(height: 3.h),

                    // Detailed Info
                    ...[
                      _buildInfoSection(context, 'Date of Birth',
                          _formatDate(profile?.dateOfBirth), Icons.cake),
                      _buildInfoSection(
                          context,
                          'Height',
                          profile?.heightCm != null
                              ? '${profile!.heightCm!.toStringAsFixed(0)} cm'
                              : 'Not set',
                          Icons.height),
                      _buildInfoSection(
                          context,
                          'Weight',
                          profile?.weightKg != null
                              ? '${profile!.weightKg!.toStringAsFixed(1)} kg'
                              : 'Not set',
                          Icons.monitor_weight_outlined),
                      _buildInfoSection(context, 'Health Goal',
                          profile?.healthGoals ?? 'Not set', Icons.flag),
                      _buildInfoSection(
                          context,
                          'Medical Conditions',
                          profile?.diseases.join(', ') ??
                              'None',
                          Icons.medical_services_outlined),
                      _buildInfoSection(
                          context,
                          'Allergies',
                          profile?.allergies.join(', ') ??
                              'None',
                          Icons.warning_amber),
                      _buildInfoSection(
                          context,
                          'Dietary Preferences',
                          profile?.dietaryPreferences ?? 'None',
                          Icons.restaurant),
                    ]
                        .asMap()
                        .entries
                        .map((e) => e.value
                            .animate()
                            .fadeIn(
                                duration: 400.ms,
                                delay: Duration(milliseconds: 200 + e.key * 60))
                            .slideY(begin: 0.03, end: 0))
                        .toList(),

                    SizedBox(height: 4.h),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
            decoration: isDark
                ? AppTheme.glassmorphicDecoration(borderRadius: 12)
                : BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
            child: Column(
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                    shadows: isDark
                        ? AppTheme.textGlow(colorScheme.primary, blur: 4)
                        : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 0.3.h),
                Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection(
      BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: isDark
                ? AppTheme.glassmorphicDecoration(borderRadius: 12)
                : BoxDecoration(
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
                Icon(icon, color: colorScheme.secondary, size: 22),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 0.3.h),
                      Text(
                        value.isEmpty ? 'Not set' : value,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
