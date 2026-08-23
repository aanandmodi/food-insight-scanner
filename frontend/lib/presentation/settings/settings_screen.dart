// lib/presentation/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../theme/app_design_system.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  User? _currentUser;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _loadAppVersion();
  }

  Future<void> _configureGroqKey() async {
    final prefs = await SharedPreferences.getInstance();
    final currentKey = prefs.getString('groq_api_key') ?? '';
    final controller = TextEditingController(text: currentKey);

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Groq AI Key',
          style: FoodInsightTypography.heading(size: 20, weight: FontWeight.w800, color: FoodInsightColors.deepCharcoal),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configure your Groq API key (from console.groq.com) for fast Llama 3 AI nutrition analysis & Chat.',
              style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.midGray),
            ),
            SizedBox(height: 1.5.h),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'gsk_...',
                hintStyle: FoodInsightTypography.body(size: 14, color: FoodInsightColors.lightGray),
                border: OutlineInputBorder(
                  borderRadius: FoodInsightRadius.smAll,
                  borderSide: BorderSide(color: FoodInsightColors.outlineGray),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: FoodInsightRadius.smAll,
                  borderSide: BorderSide(color: FoodInsightColors.scannerGreen, width: 2),
                ),
              ),
              style: FoodInsightTypography.body(size: 14, color: FoodInsightColors.deepCharcoal),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: FoodInsightColors.midGray)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Save Key', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result.isEmpty) {
        await prefs.remove('groq_api_key');
      } else {
        await prefs.setString('groq_api_key', result);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Groq API Key updated!'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      debugPrint('Error loading app version: $e');
    }
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
        await _authService.signOut();
        if (mounted) {
          context.read<UserProfileProvider>().clearProfile();
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error logging out: $e')));
        }
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.warning, color: FoodInsightColors.healthRed),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Delete Account',
                style: FoodInsightTypography.heading(size: 18, weight: FontWeight.w800, color: FoodInsightColors.healthRed),
              ),
            ),
          ],
        ),
        content: Text(
          'This action is permanent and cannot be undone. All your data will be deleted.',
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
              backgroundColor: FoodInsightColors.healthRed,
              shape: RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
            ),
            child: Text('Delete', style: FoodInsightTypography.caption(size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteAccount();
        if (mounted) {
          context.read<UserProfileProvider>().clearProfile();
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting account: $e')));
        }
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No email associated with this account.')),
        );
      }
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Password reset email sent to $email'),
            backgroundColor: FoodInsightColors.scannerGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AuthService.getErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FoodInsightColors.warmWhite,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: FoodInsightTypography.heading(
            size: 20,
            weight: FontWeight.w900,
            color: FoodInsightColors.deepCharcoal,
          ),
        ),
        centerTitle: true,
        backgroundColor: FoodInsightColors.warmWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: FoodInsightColors.deepCharcoal),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: FoodInsightColors.warmBackground,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(5.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              _buildSectionHeader(context, 'Account')
                  .animate()
                  .fadeIn(duration: 400.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your personal information',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, AppRoutes.profileSetup);
                  },
                ),
                if (_currentUser != null && !_currentUser!.isAnonymous) ...[
                  Divider(height: 1, color: FoodInsightColors.outlineGray),
                  _buildSettingsTile(
                    context,
                    icon: Icons.lock_reset_rounded,
                    title: 'Reset Password',
                    subtitle: _currentUser?.email ?? '',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _resetPassword();
                    },
                  ),
                ],
              ])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: 0.03, end: 0),

              SizedBox(height: 3.h),

              // Preferences Section
              _buildSectionHeader(context, 'Preferences')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSwitchTile(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle: 'Get alerts about food safety',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _notificationsEnabled = value);
                  },
                ),
                Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(
                  context,
                  icon: Icons.psychology_outlined,
                  title: 'Groq AI API Key',
                  subtitle: 'Configure Llama 3 AI Engine Key',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _configureGroqKey();
                  },
                ),
              ])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.03, end: 0),

              SizedBox(height: 3.h),

              // Data Section
              _buildSectionHeader(context, 'Data & Privacy')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 250.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.shopping_cart_outlined,
                  title: 'Shopping List',
                  subtitle: 'View your saved products',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, AppRoutes.shoppingList);
                  },
                ),
                Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(
                  context,
                  icon: Icons.history_rounded,
                  title: 'Scan History',
                  subtitle: 'View past scans',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, AppRoutes.scanHistory);
                  },
                ),
                Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(
                  context,
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Diet Log',
                  subtitle: 'Track your daily meals',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pushNamed(context, AppRoutes.dietLog);
                  },
                ),
              ])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 300.ms)
                  .slideY(begin: 0.03, end: 0),

              SizedBox(height: 3.h),

              // About Section
              _buildSectionHeader(context, 'About')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  title: 'App Version',
                  subtitle: _appVersion,
                  onTap: () {},
                ),
              ])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 400.ms),

              SizedBox(height: 4.h),

              // Log Out
              GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: FoodInsightRadius.mdAll,
                    border: Border.all(color: FoodInsightColors.scannerGreen.withValues(alpha: 0.5), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: FoodInsightColors.scannerGreen.withValues(alpha: 0.1),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded, color: FoodInsightColors.scannerGreenDark),
                      SizedBox(width: 2.w),
                      Text(
                        'Log Out',
                        style: FoodInsightTypography.heading(
                          size: 16,
                          weight: FontWeight.w700,
                          color: FoodInsightColors.scannerGreenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 450.ms),

              SizedBox(height: 3.h),

              // Delete Account
              Center(
                child: TextButton.icon(
                  onPressed: _handleDeleteAccount,
                  icon: Icon(Icons.person_remove_rounded, color: FoodInsightColors.healthRed, size: 20),
                  label: Text(
                    'Delete Account',
                    style: FoodInsightTypography.body(
                      size: 14,
                      weight: FontWeight.w700,
                      color: FoodInsightColors.healthRed,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: FoodInsightTypography.heading(
        size: 18,
        weight: FontWeight.w800,
        color: FoodInsightColors.deepCharcoal,
      ),
    );
  }

  Widget _buildGlassSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: FoodInsightRadius.mdAll,
        boxShadow: FoodInsightShadows.subtleCard,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: FoodInsightColors.scannerGreenLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: FoodInsightColors.scannerGreen, size: 20),
      ),
      title: Text(
        title,
        style: FoodInsightTypography.body(
          size: 16,
          weight: FontWeight.w700,
          color: FoodInsightColors.deepCharcoal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: FoodInsightTypography.caption(
          size: 13,
          color: FoodInsightColors.midGray,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: FoodInsightColors.midGray,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: FoodInsightColors.scannerGreenLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: FoodInsightColors.scannerGreen, size: 20),
      ),
      title: Text(
        title,
        style: FoodInsightTypography.body(
          size: 16,
          weight: FontWeight.w700,
          color: FoodInsightColors.deepCharcoal,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: FoodInsightTypography.caption(
          size: 13,
          color: FoodInsightColors.midGray,
        ),
      ),
      value: value,
      activeColor: FoodInsightColors.scannerGreen,
      onChanged: onChanged,
    );
  }
}
