import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      // Try fetching relevant data from Firestore
      _userProfile = await FirestoreService().getUserProfile();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            icon: Icon(Icons.edit, color: AppTheme.lightTheme.colorScheme.primary),
            onPressed: () {
              Navigator.pushNamed(context, '/profile-setup').then((_) => _loadProfile());
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(5.w),
              child: Column(
                children: [
                   // Avatar & Name
                   Center(
                     child: Column(
                       children: [
                         CircleAvatar(
                           radius: 12.w,
                           backgroundColor: AppTheme.lightTheme.colorScheme.primaryContainer,
                           child: Text(
                             _userProfile?['name'] != null && _userProfile!['name'].isNotEmpty
                                 ? _userProfile!['name'][0].toUpperCase()
                                 : (_currentUser?.isAnonymous == true ? 'G' : 'U'),
                             style: TextStyle(
                               fontSize: 24.sp,
                               fontWeight: FontWeight.bold,
                               color: AppTheme.lightTheme.colorScheme.primary,
                             ),
                           ),
                         ),
                         SizedBox(height: 2.h),
                         Text(
                           _userProfile?['name'] ?? (_currentUser?.isAnonymous == true ? 'Guest User' : 'User'),
                           style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         SizedBox(height: 0.5.h),
                         Text(
                           _currentUser?.email ?? (_currentUser?.isAnonymous == true ? 'Anonymous Account' : ''),
                           style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                             color: Colors.grey,
                           ),
                         ),
                       ],
                     ),
                   ),
                   
                   SizedBox(height: 4.h),
                   
                   // Info Cards
                   _buildInfoSection('Health Goal', _userProfile?['healthGoal'] ?? 'Not set', Icons.flag),
                   _buildInfoSection('Allergies', 
                       (_userProfile?['allergies'] as List?)?.join(', ') ?? 'None', 
                       Icons.warning_amber),
                   _buildInfoSection('Dietary Preferences', 
                       (_userProfile?['dietaryPreferences'] as List?)?.join(', ') ?? 'None', 
                       Icons.restaurant),
                       
                   SizedBox(height: 6.h),
                   
                   // Sign Out Button
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                       onPressed: _signOut,
                       icon: const Icon(Icons.logout),
                       label: const Text('Sign Out'),
                       style: OutlinedButton.styleFrom(
                         padding: EdgeInsets.symmetric(vertical: 2.h),
                         foregroundColor: AppTheme.lightTheme.colorScheme.error,
                         side: BorderSide(color: AppTheme.lightTheme.colorScheme.error),
                       ),
                     ),
                   ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection(String title, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.lightTheme.colorScheme.secondary, size: 24),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
