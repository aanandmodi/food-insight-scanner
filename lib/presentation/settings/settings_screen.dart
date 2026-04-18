// lib/presentation/settings/settings_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
  }

  Future<void> _signOut() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : null,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error signing out: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.cardDark : null,
        title: Row(
          children: [
            Icon(Icons.warning, color: colorScheme.error),
            SizedBox(width: 2.w),
            const Text('Delete Account'),
          ],
        ),
        content: const Text(
          'This action is permanent and cannot be undone. '
          'All your data including profile, scan history, and diet logs will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.deleteAccount();
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.login, (route) => false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AuthService.getErrorMessage(e)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
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
            backgroundColor: Theme.of(context).colorScheme.primary,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Section
            _buildSectionHeader(context, 'Account')
                .animate()
                .fadeIn(duration: 400.ms),
            SizedBox(height: 1.h),
            _buildGlassSettingsCard(context, isDark, [
              _buildSettingsTile(
                context,
                icon: Icons.person,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, AppRoutes.profileSetup);
                },
              ),
              if (_currentUser != null && !_currentUser!.isAnonymous) ...[
                Divider(height: 1, color: isDark ? AppTheme.dividerDark : null),
                _buildSettingsTile(
                  context,
                  icon: Icons.lock_reset,
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
            SizedBox(height: 1.h),
            _buildGlassSettingsCard(context, isDark, [
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
              Divider(height: 1, color: isDark ? AppTheme.dividerDark : null),
              _buildSwitchTile(
                context,
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: _darkModeEnabled,
                onChanged: (value) {
                  HapticFeedback.lightImpact();
                  setState(() => _darkModeEnabled = value);
                  // TODO: Integrate with actual ThemeMode provider
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
            SizedBox(height: 1.h),
            _buildGlassSettingsCard(context, isDark, [
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
              Divider(height: 1, color: isDark ? AppTheme.dividerDark : null),
              _buildSettingsTile(
                context,
                icon: Icons.history,
                title: 'Scan History',
                subtitle: 'View past scans',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pushNamed(context, AppRoutes.scanHistory);
                },
              ),
              Divider(height: 1, color: isDark ? AppTheme.dividerDark : null),
              _buildSettingsTile(
                context,
                icon: Icons.restaurant_menu,
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
            SizedBox(height: 1.h),
            _buildGlassSettingsCard(context, isDark, [
              _buildSettingsTile(
                context,
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
            ])
                .animate()
                .fadeIn(duration: 500.ms, delay: 400.ms),

            SizedBox(height: 4.h),

            // Sign Out
            GlowButton(
              glowColor: colorScheme.error,
              glowIntensity: isDark ? 0.15 : 0.05,
              onTap: _signOut,
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.error),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, color: colorScheme.error),
                    SizedBox(width: 2.w),
                    Text(
                      'Sign Out',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms, delay: 450.ms),

            SizedBox(height: 2.h),

            // Delete Account
            Center(
              child: TextButton(
                onPressed: _deleteAccount,
                child: Text(
                  'Delete Account',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildGlassSettingsCard(
      BuildContext context, bool isDark, List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
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
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      leading: Icon(icon, color: colorScheme.secondary),
      title: Text(title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          )),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SwitchListTile(
      secondary: Icon(icon, color: colorScheme.secondary),
      title: Text(title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
          )),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
