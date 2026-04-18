// lib/presentation/auth/signup_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.lightTheme.colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        displayName: _nameController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } catch (e) {
      _showError(AuthService.getErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.lightTheme.colorScheme.primary
                            .withValues(alpha: 0.08),
                        AppTheme.lightTheme.scaffoldBackgroundColor,
                        AppTheme.lightTheme.colorScheme.secondary
                            .withValues(alpha: 0.04),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 7.w),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 2.h),
                            // Back button
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: EdgeInsets.all(2.w),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightTheme.colorScheme.surface
                                      .withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme
                                        .lightTheme.colorScheme.outline
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: CustomIconWidget(
                                  iconName: 'arrow_back',
                                  color: AppTheme
                                      .lightTheme.colorScheme.onSurface,
                                  size: 24,
                                ),
                              ),
                            ),
                            SizedBox(height: 3.h),
                            // Header
                            Text(
                              'Create Account',
                              style: AppTheme
                                  .lightTheme.textTheme.headlineMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'Sign up to personalize your food insights and track your nutrition.',
                              style: AppTheme.lightTheme.textTheme.bodyLarge
                                  ?.copyWith(
                                color: AppTheme
                                    .lightTheme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  // Name
                                  TextFormField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      labelText: 'Full Name',
                                      hintText: 'Enter your full name',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.all(3.w),
                                        child: CustomIconWidget(
                                          iconName: 'person',
                                          color: AppTheme.lightTheme
                                              .colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      if (value.trim().length < 2) {
                                        return 'Name must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 2.h),
                                  // Email
                                  TextFormField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      hintText: 'you@example.com',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.all(3.w),
                                        child: CustomIconWidget(
                                          iconName: 'email',
                                          color: AppTheme.lightTheme
                                              .colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                    keyboardType:
                                        TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(value.trim())) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 2.h),
                                  // Password
                                  TextFormField(
                                    controller: _passwordController,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      hintText: 'At least 6 characters',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.all(3.w),
                                        child: CustomIconWidget(
                                          iconName: 'lock',
                                          color: AppTheme.lightTheme
                                              .colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                        child: Padding(
                                          padding: EdgeInsets.all(3.w),
                                          child: CustomIconWidget(
                                            iconName: _obscurePassword
                                                ? 'visibility_off'
                                                : 'visibility',
                                            color: AppTheme
                                                .lightTheme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    obscureText: _obscurePassword,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (value.length < 6) {
                                        return 'Password must be at least 6 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 2.h),
                                  // Confirm Password
                                  TextFormField(
                                    controller:
                                        _confirmPasswordController,
                                    decoration: InputDecoration(
                                      labelText: 'Confirm Password',
                                      hintText: 'Re-enter your password',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.all(3.w),
                                        child: CustomIconWidget(
                                          iconName: 'lock',
                                          color: AppTheme.lightTheme
                                              .colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() =>
                                            _obscureConfirmPassword =
                                                !_obscureConfirmPassword),
                                        child: Padding(
                                          padding: EdgeInsets.all(3.w),
                                          child: CustomIconWidget(
                                            iconName:
                                                _obscureConfirmPassword
                                                    ? 'visibility_off'
                                                    : 'visibility',
                                            color: AppTheme
                                                .lightTheme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    obscureText:
                                        _obscureConfirmPassword,
                                    validator: (value) {
                                      if (value !=
                                          _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 4.h),
                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _handleSignUp,
                                style: ElevatedButton.styleFrom(
                                  minimumSize:
                                      Size(double.infinity, 7.h),
                                ),
                                child: _isLoading
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(
                                            AppTheme.lightTheme
                                                .colorScheme.onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Create Account',
                                        style: AppTheme.lightTheme
                                            .textTheme.titleMedium
                                            ?.copyWith(
                                          color: AppTheme.lightTheme
                                              .colorScheme.onPrimary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            const Spacer(),
                            // Already have an account
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 3.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: AppTheme
                                        .lightTheme.textTheme.bodyMedium,
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.pop(context),
                                    child: Text(
                                      'Sign In',
                                      style: AppTheme.lightTheme
                                          .textTheme.bodyMedium
                                          ?.copyWith(
                                        color: AppTheme.lightTheme
                                            .colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
