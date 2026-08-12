// lib/presentation/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../core/utils/user_utils.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../models/user_profile.dart';
import '../../theme/app_design_system.dart';

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
    final provider = context.watch<UserProfileProvider>();
    final profile = provider.profile;
    final isLoading = provider.isLoading;

    final displayName = _getDisplayName(profile);
    final age = _calculateAge(profile?.dateOfBirth);
    final bmi = _calculateBMI(profile);

    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Food Insight',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w900,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_rounded, color: FoodInsightColors.scannerGreen),
            onPressed: () {
              Navigator.pushNamed(context, '/profile-setup')
                  .then((_) => _loadProfile());
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_rounded, color: FoodInsightColors.midGray),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: FoodInsightColors.scannerGreen,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              color: FoodInsightColors.scannerGreen,
              backgroundColor: Colors.white,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: FoodInsightColors.warmBackground,
                ),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(5.w),
                  child: Column(
                    children: [
                      // Local user banner
                      if (profile?.uid == 'local_user')
                        Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: FoodInsightColors.scannerGreenLight,
                            borderRadius: FoodInsightRadius.mdAll,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.account_circle_rounded,
                                color: FoodInsightColors.scannerGreen,
                                size: 24,
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Local Profile Active',
                                      style: FoodInsightTypography.body(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: FoodInsightColors.scannerGreenDark,
                                      ),
                                    ),
                                    Text(
                                      'All data is saved locally on your device.',
                                      style: FoodInsightTypography.caption(
                                        size: 12,
                                        color: FoodInsightColors.scannerGreenDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: -0.05, end: 0),

                      SizedBox(height: 2.h),

                      // Avatar & Name
                      Center(
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: FoodInsightColors.scannerGreen.withValues(alpha: 0.2),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 12.w,
                                backgroundColor: FoodInsightColors.scannerGreenLight,
                                child: Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : 'U',
                                  style: FoodInsightTypography.display(
                                    size: 28,
                                    weight: FontWeight.w800,
                                    color: FoodInsightColors.scannerGreen,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 1.5.h),
                            Text(
                              displayName,
                              style: FoodInsightTypography.heading(
                                size: 24,
                                weight: FontWeight.w800,
                                color: FoodInsightColors.deepCharcoal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              profile?.email ?? '',
                              style: FoodInsightTypography.caption(
                                size: 13,
                                color: FoodInsightColors.midGray,
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
                            _formatDate(profile?.dateOfBirth), Icons.cake_rounded),
                        _buildInfoSection(
                            context,
                            'Height',
                            profile?.heightCm != null
                                ? '${profile!.heightCm!.toStringAsFixed(0)} cm'
                                : 'Not set',
                            Icons.height_rounded),
                        _buildInfoSection(
                            context,
                            'Weight',
                            profile?.weightKg != null
                                ? '${profile!.weightKg!.toStringAsFixed(1)} kg'
                                : 'Not set',
                            Icons.monitor_weight_rounded),
                        _buildInfoSection(context, 'Health Goal',
                            profile?.healthGoals ?? 'Not set', Icons.flag_rounded),
                        _buildInfoSection(
                            context,
                            'Activity Level',
                            profile?.activityLevel ?? 'Not set',
                            Icons.directions_run_rounded),
                        _buildInfoSection(
                            context,
                            'Medical Conditions',
                            profile?.diseases.join(', ') ??
                                'None',
                            Icons.medical_services_rounded),
                        _buildInfoSection(
                            context,
                            'Allergies',
                            profile?.allergies.join(', ') ??
                                'None',
                            Icons.warning_amber_rounded),
                        _buildInfoSection(
                            context,
                            'Dietary Preferences',
                            profile?.dietaryPreferences.isNotEmpty == true
                                ? profile!.dietaryPreferences.join(', ')
                                : 'None',
                            Icons.restaurant_rounded),
                      ]
                          .asMap()
                          .entries
                          .map((e) => e.value
                              .animate()
                              .fadeIn(
                                  duration: 400.ms,
                                  delay: Duration(milliseconds: 200 + e.key * 60))
                              .slideY(begin: 0.03, end: 0)),

                      SizedBox(height: 10.h),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, String value) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1.w),
      padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        children: [
          Text(
            value,
            style: FoodInsightTypography.heading(
              size: 16,
              weight: FontWeight.w800,
              color: FoodInsightColors.scannerGreen,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 0.3.h),
          Text(
            label,
            style: FoodInsightTypography.caption(
              size: 11,
              color: FoodInsightColors.midGray,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(
      BuildContext context, String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: FoodInsightColors.scannerGreenLight,
              borderRadius: FoodInsightRadius.smAll,
            ),
            child: Icon(icon, color: FoodInsightColors.scannerGreen, size: 20),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: FoodInsightTypography.caption(
                    size: 12,
                    weight: FontWeight.w600,
                    color: FoodInsightColors.midGray,
                  ),
                ),
                SizedBox(height: 0.3.h),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: FoodInsightTypography.body(
                    size: 15,
                    weight: FontWeight.w600,
                    color: FoodInsightColors.deepCharcoal,
                  ),
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
