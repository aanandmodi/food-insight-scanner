// lib/presentation/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../core/utils/user_utils.dart';
import 'package:provider/provider.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../models/user_profile.dart';
import '../../theme/app_design_system.dart';
import '../../services/local_database_service.dart';
import '../../services/cloud_function_service.dart';
import '../../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadProfile() async {
    await context.read<UserProfileProvider>().fetchProfile();
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Log Out',
          style: FoodInsightTypography.heading(size: 18, weight: FontWeight.w800, color: FoodInsightColors.deepCharcoal),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: FoodInsightColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
            ),
            child: Text('Log Out', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().signOut();
        if (mounted) {
          context.read<UserProfileProvider>().clearProfile();
          Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
        }
      }
    }
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
          IconButton(
            icon: Icon(Icons.logout_rounded, color: FoodInsightColors.healthRed),
            onPressed: _handleLogout,
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
                                backgroundImage: profile?.photoUrl != null
                                    ? NetworkImage(profile!.photoUrl!)
                                    : null,
                                child: profile?.photoUrl == null
                                    ? Text(
                                        displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : 'U',
                                        style: FoodInsightTypography.display(
                                          size: 28,
                                          weight: FontWeight.w800,
                                          color: FoodInsightColors.scannerGreen,
                                        ),
                                      )
                                    : null,
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

                      // AI Recalibration Section
                      if (profile != null)
                        _buildAiRecalibrationCard(context, profile)
                            .animate()
                            .fadeIn(duration: 500.ms, delay: 150.ms)
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

  Widget _buildAiRecalibrationCard(BuildContext context, UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [FoodInsightColors.scannerGreen, const Color(0xFF1B5E20)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
              SizedBox(width: 2.w),
              Text(
                'AI Macro Recalibration',
                style: FoodInsightTypography.heading(
                  size: 18,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Text(
            'Let Gemini analyze your last 3 days of eating habits to optimize your daily goals dynamically.',
            style: FoodInsightTypography.body(
              size: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _handleAiRecalibration(context, profile),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: FoodInsightColors.scannerGreen,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 1.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: FoodInsightRadius.mdAll,
                ),
              ),
              child: Text(
                'Recalibrate Now',
                style: FoodInsightTypography.body(
                  size: 14,
                  weight: FontWeight.w700,
                  color: FoodInsightColors.scannerGreen,
                ),
              ),
            ),
          ),
          if (profile.lastAiRecalibration != null)
            Padding(
              padding: EdgeInsets.only(top: 1.h),
              child: Text(
                'Last recalibrated: ${_formatDate(profile.lastAiRecalibration)}',
                style: FoodInsightTypography.caption(
                  size: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleAiRecalibration(BuildContext context, UserProfile profile) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: FoodInsightRadius.mdAll,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: FoodInsightColors.scannerGreen),
              SizedBox(height: 2.h),
              Text('Analyzing your habits...', style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal)),
            ],
          ),
        ),
      ),
    );

    try {
      // Fetch last 3 days of logs
      List<Map<String, dynamic>> recentLogs = [];
      final db = LocalDatabaseService();
      final now = DateTime.now();
      for (int i = 0; i < 3; i++) {
        final date = now.subtract(Duration(days: i));
        final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        final dayLogs = await db.getDietLogByDate(dateString);
        recentLogs.addAll(dayLogs);
      }

      final newMacros = await CloudFunctionService().recalibrateMacrosWithAI(
        userProfile: profile.toMap(),
        recentDietLogs: recentLogs,
      );

      Navigator.pop(context); // Close loading

      if (newMacros.containsKey('error')) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('AI Analysis failed: ${newMacros['error']}')));
        return;
      }

      // Show Result Dialog
      _showRecalibrationResult(context, profile, newMacros);

    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showRecalibrationResult(BuildContext context, UserProfile profile, Map<String, dynamic> newMacros) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.lgAll),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: FoodInsightColors.scannerGreen),
            SizedBox(width: 2.w),
            Text('AI Recommendations', style: FoodInsightTypography.heading(size: 18, color: FoodInsightColors.deepCharcoal)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(newMacros['explanation'] ?? 'Here are your optimized goals.', style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray)),
            SizedBox(height: 2.h),
            _buildMacroRow('Calories', '${newMacros['calories']} kcal'),
            _buildMacroRow('Protein', '${newMacros['protein']} g'),
            _buildMacroRow('Carbs', '${newMacros['carbs']} g'),
            _buildMacroRow('Fat', '${newMacros['fat']} g'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: FoodInsightColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update profile
              final updatedProfile = profile.copyWith(
                customCaloriesGoal: (newMacros['calories'] as num?)?.toDouble(),
                customProteinGoal: (newMacros['protein'] as num?)?.toDouble(),
                customCarbsGoal: (newMacros['carbs'] as num?)?.toDouble(),
                customFatGoal: (newMacros['fat'] as num?)?.toDouble(),
                lastAiRecalibration: DateTime.now(),
              );
              await context.read<UserProfileProvider>().saveProfile(updatedProfile);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Macros updated successfully!')));
              _loadProfile();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.mdAll),
            ),
            child: Text('Apply Goals', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: FoodInsightTypography.body(size: 15, weight: FontWeight.w600, color: FoodInsightColors.deepCharcoal)),
          Text(value, style: FoodInsightTypography.body(size: 15, weight: FontWeight.w800, color: FoodInsightColors.scannerGreen)),
        ],
      ),
    );
  }
}
