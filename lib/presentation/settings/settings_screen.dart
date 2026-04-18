// lib/presentation/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
              backgroundColor: AppTheme.lightTheme.colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // AuthService.signOut() now handles clearing local data internally
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: AppTheme.lightTheme.colorScheme.error),
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
              backgroundColor: AppTheme.lightTheme.colorScheme.error,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // AuthService.deleteAccount() now handles all cleanup internally
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
              backgroundColor: AppTheme.lightTheme.colorScheme.error,
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
            backgroundColor: AppTheme.lightTheme.colorScheme.primary,
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
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
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
            _buildSectionHeader('Account'),
            SizedBox(height: 1.h),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.person,
                title: 'Edit Profile',
                subtitle: 'Update your personal information',
                onTap: () => Navigator.pushNamed(context, AppRoutes.profileSetup),
              ),
              if (_currentUser != null && !_currentUser!.isAnonymous) ...[
                const Divider(height: 1),
                _buildSettingsTile(
                  icon: Icons.lock_reset,
                  title: 'Reset Password',
                  subtitle: _currentUser?.email ?? '',
                  onTap: _resetPassword,
                ),
              ],
            ]),

            SizedBox(height: 3.h),

            // Preferences Section
            _buildSectionHeader('Preferences'),
            SizedBox(height: 1.h),
            _buildSettingsCard([
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Get alerts about food safety',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() => _darkModeEnabled = value);
                  // TODO: Integrate with actual ThemeMode provider
                },
              ),
            ]),

            SizedBox(height: 3.h),

            // Data Section
            _buildSectionHeader('Data & Privacy'),
            SizedBox(height: 1.h),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.shopping_cart_outlined,
                title: 'Shopping List',
                subtitle: 'View your saved products',
                onTap: () => Navigator.pushNamed(context, AppRoutes.shoppingList),
              ),
              const Divider(height: 1),
              _buildSettingsTile(
                icon: Icons.history,
                title: 'Scan History',
                subtitle: 'View past scans',
                onTap: () => Navigator.pushNamed(context, AppRoutes.scanHistory),
              ),
              const Divider(height: 1),
              _buildSettingsTile(
                icon: Icons.restaurant_menu,
                title: 'Diet Log',
                subtitle: 'Track your daily meals',
                onTap: () => Navigator.pushNamed(context, AppRoutes.dietLog),
              ),
            ]),

            SizedBox(height: 3.h),

            // About Section
            _buildSectionHeader('About'),
            SizedBox(height: 1.h),
            _buildSettingsCard([
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: '1.0.0',
                onTap: () {},
              ),
            ]),

            SizedBox(height: 4.h),

            // Sign Out
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  foregroundColor: AppTheme.lightTheme.colorScheme.error,
                  side: BorderSide(
                      color: AppTheme.lightTheme.colorScheme.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // Delete Account
            Center(
              child: TextButton(
                onPressed: _deleteAccount,
                child: Text(
                  'Delete Account',
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.error,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppTheme.lightTheme.colorScheme.primary,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
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
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.lightTheme.colorScheme.secondary),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary:
          Icon(icon, color: AppTheme.lightTheme.colorScheme.secondary),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
