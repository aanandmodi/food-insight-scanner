// lib/presentation/auth/signup_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/auth_service.dart';

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
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
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
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isDark
                          ? [
                              colorScheme.primary.withValues(alpha: 0.08),
                              theme.scaffoldBackgroundColor,
                              theme.scaffoldBackgroundColor,
                            ]
                          : [
                              colorScheme.primary.withValues(alpha: 0.08),
                              theme.scaffoldBackgroundColor,
                              colorScheme.secondary.withValues(alpha: 0.04),
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
                            // Back button with glass
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Container(
                                    padding: EdgeInsets.all(2.w),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : colorScheme.surface.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : colorScheme.outline.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: CustomIconWidget(
                                      iconName: 'arrow_back',
                                      color: colorScheme.onSurface,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideX(begin: -0.1),
                            SizedBox(height: 3.h),
                            // Header
                            Text(
                              'Create Account',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: isDark
                                    ? AppTheme.textGlow(colorScheme.primary, blur: 6)
                                    : null,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 100.ms),
                            SizedBox(height: 1.h),
                            Text(
                              'Sign up to personalize your food insights and track your nutrition.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 200.ms),
                            SizedBox(height: 4.h),
                            // Form
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  _buildField(
                                    controller: _nameController,
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    icon: 'person',
                                    colorScheme: colorScheme,
                                    capitalization: TextCapitalization.words,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your name';
                                      }
                                      if (value.trim().length < 2) {
                                        return 'Name must be at least 2 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 2.h),
                                  _buildField(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'you@example.com',
                                    icon: 'email',
                                    colorScheme: colorScheme,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                          .hasMatch(value.trim())) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 2.h),
                                  _buildPasswordField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: 'At least 6 characters',
                                    colorScheme: colorScheme,
                                    obscure: _obscurePassword,
                                    onToggle: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
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
                                  _buildPasswordField(
                                    controller: _confirmPasswordController,
                                    label: 'Confirm Password',
                                    hint: 'Re-enter your password',
                                    colorScheme: colorScheme,
                                    obscure: _obscureConfirmPassword,
                                    onToggle: () => setState(() =>
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword),
                                    validator: (value) {
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 300.ms)
                                .slideY(begin: 0.05, end: 0),
                            SizedBox(height: 4.h),
                            // Sign Up Button
                            GlowButton(
                              glowColor: colorScheme.primary,
                              glowIntensity: isDark ? 0.25 : 0.1,
                              onTap: _isLoading ? null : _handleSignUp,
                              child: Container(
                                width: double.infinity,
                                height: 7.h,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: _isLoading
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              colorScheme.onPrimary,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Create Account',
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: colorScheme.onPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 400.ms),
                            const Spacer(),
                            // Already have an account
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      Navigator.pop(context);
                                    },
                                    child: Text(
                                      'Sign In',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.primary,
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String icon,
    required ColorScheme colorScheme,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.all(3.w),
          child: CustomIconWidget(
            iconName: icon,
            color: colorScheme.primary,
            size: 20,
          ),
        ),
      ),
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required ColorScheme colorScheme,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Padding(
          padding: EdgeInsets.all(3.w),
          child: CustomIconWidget(
            iconName: 'lock',
            color: colorScheme.primary,
            size: 20,
          ),
        ),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: CustomIconWidget(
              iconName: obscure ? 'visibility_off' : 'visibility',
              color: colorScheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ),
      ),
      obscureText: obscure,
      validator: validator,
    );
  }
}
