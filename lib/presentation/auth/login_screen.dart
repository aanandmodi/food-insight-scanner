// lib/presentation/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  // Using a ValueNotifier is more efficient than a simple boolean
  // because it only rebuilds the widgets that listen to it.
  final ValueNotifier<bool> _isLoading = ValueNotifier<bool>(false);

  Future<void> _handleGoogleSignIn() async {
    _isLoading.value = true;
    try {
      await _authService.signInWithGoogle();
      // Navigation to the home screen is handled by the AuthGate,
      // so we don't need to do it here.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in. Please try again. Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _handleGuestSignIn() async {
    _isLoading.value = true;
    try {
      await _authService.signInAnonymously();
      
      // Check for profile existence (simplified for now, assumes new guest needs setup)
      // Ideally we check Firestore here, but for now let's route to Profile Setup
      // if it's a fresh guest.
      if (mounted) {
         // We can assume a fresh guest might need profile setup, or just go to dashboard.
         // Let's go to Dashboard and let Dashboard prompt for missing info if needed,
         // OR go to Profile Setup. The user asked for "Proper profile page".
         Navigator.pushReplacementNamed(context, '/profile-setup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to continue as guest. Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  @override
  void dispose() {
    _isLoading.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      // Using LayoutBuilder to create a responsive layout.
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              // The content will be at least as tall as the screen.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1),
                        AppTheme.lightTheme.scaffoldBackgroundColor,
                      ],
                      stops: const [0.0, 0.7],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Spacer(flex: 2),
                          CustomIconWidget(
                            iconName: 'qr_code_scanner',
                            color: AppTheme.lightTheme.colorScheme.primary,
                            // Using sizer for responsive icon size.
                            size: SizerUtil.deviceType == DeviceType.tablet ? 12.w : 20.w,
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Welcome to\nFood Insight Scanner',
                            textAlign: TextAlign.center,
                            // Using .sp for responsive font size.
                            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: SizerUtil.deviceType == DeviceType.tablet ? 18.sp : 22.sp,
                            ),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            'Sign in to personalize your experience and save your history.',
                            textAlign: TextAlign.center,
                            style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                              fontSize: SizerUtil.deviceType == DeviceType.tablet ? 10.sp : 12.sp,
                            ),
                          ),
                          const Spacer(flex: 3),
                          // ValueListenableBuilder only rebuilds the button when the loading state changes.
                          ValueListenableBuilder<bool>(
                            valueListenable: _isLoading,
                            builder: (context, isLoading, child) {
                              if (isLoading) {
                                return const CircularProgressIndicator();
                              }
                              return Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _handleGoogleSignIn,
                                    style: ElevatedButton.styleFrom(
                                      minimumSize: Size(double.infinity, 7.h),
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black87,
                                      elevation: 2,
                                      shadowColor: Colors.black.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: CustomIconWidget(
                                      iconName: 'google_logo', // Ensure this exists or use fallback
                                      size: 3.h,
                                      // Fallback handling is inside CustomIconWidget
                                    ),
                                    label: Text(
                                      'Sign in with Google',
                                      style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 2.h),
                                  TextButton(
                                    onPressed: _handleGuestSignIn,
                                    child: Text(
                                      'Continue as Guest',
                                      style: AppTheme.lightTheme.textTheme.bodyLarge?.copyWith(
                                        color: AppTheme.lightTheme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const Spacer(flex: 1),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}