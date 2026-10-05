import 'account_deletion_dialog.dart';
// lib/presentation/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../data/providers/user_profile_provider.dart';
import '../../theme/app_design_system.dart';
import '../../services/crash_reporting_service.dart';
import '../../services/analytics_service.dart';
import '../../data/providers/activity_provider.dart';
import '../../widgets/health_connection_prompt.dart';
import 'legal_information_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _isDeleting = false;
  User? _currentUser;
  String _appVersion = '1.0.0';

  void _openLegal(LegalPage page) {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => LegalInformationScreen(page: page),
        ));
  }

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _loadAppVersion();
  }

  Future<void> _chooseCuisine() async {
    final provider = context.read<UserProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;
    final region = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
              title: const Text('Preferred Indian cuisine'),
              children: [
                'All India',
                'North India',
                'South India',
                'West India',
                'East India',
                'Northeast India',
                'Gujarati',
                'Maharashtrian',
                'Punjabi',
                'Bengali',
                'Tamil',
                'Kerala',
                'Karnataka',
                'Andhra / Telangana',
                'Rajasthani'
              ]
                  .map((value) => SimpleDialogOption(
                        onPressed: () => Navigator.pop(ctx, value),
                        child: Text(value),
                      ))
                  .toList(),
            ));
    if (region != null && mounted) {
      await provider
          .saveProfile(profile.copyWith(country: 'India', region: region));
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
          style: FoodInsightTypography.heading(
              size: 18,
              weight: FontWeight.w800,
              color: FoodInsightColors.deepCharcoal),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: FoodInsightTypography.body(
              size: 14, color: FoodInsightColors.midGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: FoodInsightTypography.caption(
                    size: 14,
                    weight: FontWeight.w700,
                    color: FoodInsightColors.midGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: FoodInsightColors.scannerGreen,
              shape:
                  RoundedRectangleBorder(borderRadius: FoodInsightRadius.smAll),
            ),
            child: Text('Log Out',
                style: FoodInsightTypography.caption(
                    size: 14, weight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await _authService.signOut();
        if (mounted) {
          context.read<UserProfileProvider>().clearProfile();
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error logging out: $e')));
        }
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    if (_isDeleting) return;
    final confirmed = await confirmAccountDeletion(context);

    if (confirmed == true) {
      if (!mounted) return;
      try {
        String? password;
        if (_currentUser?.providerData
                .any((provider) => provider.providerId == 'password') ==
            true) {
          final controller = TextEditingController();
          password = await showDialog<String>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                    title: const Text('Confirm your password'),
                    content: TextField(
                        controller: controller,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration:
                            const InputDecoration(labelText: 'Password')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(dialogContext, controller.text),
                          child: const Text('Delete account'))
                    ],
                  ));
          controller.dispose();
          if (password == null || password.isEmpty || !mounted) return;
        }
        if (!mounted) return;
        setState(() => _isDeleting = true);
        await _authService.deleteAccount(password: password);
        if (mounted) {
          context.read<UserProfileProvider>().clearProfile();
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AuthService.getErrorMessage(e))));
        }
      } finally {
        if (mounted) setState(() => _isDeleting = false);
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
        iconTheme: const IconThemeData(color: FoodInsightColors.deepCharcoal),
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
                if (_currentUser?.isAnonymous == true)
                  _buildSettingsTile(
                    context,
                    icon: Icons.person_add_alt_1_rounded,
                    title: 'Save your guest account',
                    subtitle:
                        'Add email sign-in and keep your profile and meals',
                    onTap: () => Navigator.pushNamed(context, AppRoutes.signup),
                  ),
                if (_currentUser != null && !_currentUser!.isAnonymous) ...[
                  const Divider(
                      height: 1, color: FoodInsightColors.outlineGray),
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
              _buildSectionHeader(context, 'Health & Personalization')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.restaurant_menu,
                  title: 'Preferred Indian cuisine',
                  subtitle:
                      context.watch<UserProfileProvider>().profile?.region ??
                          'All India',
                  onTap: _chooseCuisine,
                ),
              ])
                  .animate()
                  .fadeIn(duration: 500.ms, delay: 200.ms)
                  .slideY(begin: 0.03, end: 0),

              SizedBox(height: 3.h),

              _buildSectionHeader(context, 'Permissions'),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                _buildSettingsTile(
                  context,
                  icon: Icons.directions_walk_rounded,
                  title: 'Activity connection',
                  subtitle: switch (context.watch<ActivityProvider>().source) {
                    ActivityDataSource.healthConnect => 'Health Connect',
                    ActivityDataSource.pedometerEstimate =>
                      'Phone step counter · estimated calories',
                    ActivityDataSource.none => 'Not connected',
                  },
                  onTap: () => showHealthConnectionPrompt(context),
                ),
              ]),

              SizedBox(height: 3.h),

              // Data Section
              _buildSectionHeader(context, 'Data & Privacy')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 250.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.insights_outlined),
                  title: const Text('Optional usage analytics'),
                  subtitle: const Text(
                      'Share feature counts without food, health or chat details'),
                  value: AnalyticsService.enabled,
                  onChanged: (value) async {
                    await AnalyticsService.setEnabled(value);
                    if (mounted) setState(() {});
                  },
                ),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.bug_report_outlined),
                  title: const Text('Crash reporting'),
                  subtitle: const Text(
                      'Send minimized diagnostics to help fix crashes'),
                  value: CrashReportingService.enabled,
                  onChanged: (value) async {
                    await CrashReportingService.setEnabled(value);
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
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
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
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
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
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

              // App and legal information
              _buildSectionHeader(context, 'App & Legal')
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 350.ms),
              SizedBox(height: 1.5.h),
              _buildGlassSettingsCard(context, [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('App version'),
                  subtitle: Text(_appVersion),
                ),
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(context,
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    subtitle: 'How your data is used',
                    onTap: () => _openLegal(LegalPage.privacy)),
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(context,
                    icon: Icons.description_outlined,
                    title: 'Terms of Use',
                    subtitle: 'Food and health information terms',
                    onTap: () => _openLegal(LegalPage.terms)),
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(context,
                    icon: Icons.dataset_outlined,
                    title: 'Data Sources',
                    subtitle: 'Open Food Facts and AI information',
                    onTap: () => _openLegal(LegalPage.dataSources)),
                const Divider(height: 1, color: FoodInsightColors.outlineGray),
                _buildSettingsTile(context,
                    icon: Icons.code_rounded,
                    title: 'Open Source Licenses',
                    subtitle: 'Software used by Food Insight',
                    onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Food Insight',
                        applicationVersion: _appVersion)),
              ]).animate().fadeIn(duration: 500.ms, delay: 400.ms),

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
                    border: Border.all(
                        color: FoodInsightColors.scannerGreen
                            .withValues(alpha: 0.5),
                        width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: FoodInsightColors.scannerGreen
                            .withValues(alpha: 0.1),
                        blurRadius: 10,
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: FoodInsightColors.scannerGreenDark),
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
                  onPressed: _isDeleting ? null : _handleDeleteAccount,
                  icon: const Icon(Icons.person_remove_rounded,
                      color: FoodInsightColors.healthRed, size: 20),
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
        decoration: const BoxDecoration(
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
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: FoodInsightColors.midGray,
      ),
      onTap: onTap,
    );
  }
}
