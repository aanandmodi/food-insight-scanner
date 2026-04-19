// lib/presentation/auth/login_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sizer/sizer.dart';
import '../../../core/app_export.dart';
import '../../../services/auth_service.dart';
import '../../../main.dart' show firebaseInitError;

enum _AuthMethod { none, email, google, guest }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  _AuthMethod _activeMethod = _AuthMethod.none;
  bool _obscurePassword = true;
  bool _isRetrying = false;

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
    _emailController.dispose();
    _passwordController.dispose();
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

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _setLoading(bool loading, [_AuthMethod method = _AuthMethod.none]) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      _activeMethod = loading ? method : _AuthMethod.none;
    });
  }

  Future<void> _handleEmailSignIn() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    _setLoading(true, _AuthMethod.email);
    try {
      await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.splash);
      }
    } catch (e) {
      _showError(AuthService.getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();
    _setLoading(true, _AuthMethod.google);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        _setLoading(false);
        return;
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.splash);
      }
    } catch (e) {
      _showError(AuthService.getErrorMessage(e));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleGuestSignIn() async {
    HapticFeedback.lightImpact();
    _setLoading(true, _AuthMethod.guest);
    try {
      await _authService.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } catch (e) {
      debugPrint('Guest sign-in failed, proceeding offline: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } finally {
      _setLoading(false);
    }
  }

  void _handleContinueOffline() {
    HapticFeedback.lightImpact();
    Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
  }

  Future<void> _handleRetryConnection() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      final success = await _authService.retryInit();
      if (mounted) {
        if (success) {
          _showSuccess('Connected to Firebase successfully!');
          setState(() {});
        } else {
          _showError('Still unable to connect. Error: ${firebaseInitError ?? "Unknown"}');
        }
      }
    } catch (e) {
      _showError('Retry failed: $e');
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Please enter your email first.');
      return;
    }

    try {
      await _authService.sendPasswordResetEmail(email);
      _showSuccess('Password reset link sent to $email');
    } catch (e) {
      _showError(AuthService.getErrorMessage(e));
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
                          children: [
                            SizedBox(height: 4.h),
                            // Firebase status banner
                            if (!_authService.isFirebaseReady)
                              _buildOfflineBanner(colorScheme, isDark)
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideY(begin: -0.1),
                            // Logo
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: isDark
                                    ? AppTheme.glowBoxShadow(
                                        colorScheme.primary,
                                        intensity: 0.2,
                                        blur: 20,
                                      )
                                    : null,
                              ),
                              child: CustomIconWidget(
                                iconName: 'qr_code_scanner',
                                color: colorScheme.primary,
                                size: SizerUtil.deviceType == DeviceType.tablet
                                    ? 10.w
                                    : 16.w,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 600.ms, delay: 100.ms)
                                .scaleXY(begin: 0.8, end: 1.0, duration: 600.ms),
                            SizedBox(height: 2.h),
                            Text(
                              'Food Insight Scanner',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                shadows: isDark
                                    ? AppTheme.textGlow(colorScheme.primary, blur: 8)
                                    : null,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 200.ms),
                            SizedBox(height: 0.5.h),
                            Text(
                              'Sign in to continue',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 300.ms),
                            SizedBox(height: 4.h),
                            // Form
                            _buildForm(theme, colorScheme, isDark)
                                .animate()
                                .fadeIn(duration: 500.ms, delay: 400.ms)
                                .slideY(begin: 0.05, end: 0),
                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _handleForgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            // Sign In button
                            _buildSignInButton(theme, colorScheme, isDark),
                            SizedBox(height: 2.5.h),
                            _buildDivider(theme, colorScheme),
                            SizedBox(height: 2.5.h),
                            _buildGoogleSignIn(theme, colorScheme, isDark),
                            SizedBox(height: 2.h),
                            // Guest Mode
                            _buildGuestButton(theme, colorScheme),
                            SizedBox(height: 1.h),
                            _buildOfflineButton(theme, colorScheme),
                            // Retry Connection
                            if (!_authService.isFirebaseReady) ...[
                              SizedBox(height: 1.h),
                              _buildRetrySection(theme, colorScheme, isDark),
                            ],
                            const Spacer(),
                            // Sign Up link
                            _buildSignUpLink(theme, colorScheme),
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

  Widget _buildOfflineBanner(ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: _isRetrying ? null : _handleRetryConnection,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(3.w),
        margin: EdgeInsets.only(bottom: 2.h),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orange, size: 5.w),
            SizedBox(width: 2.w),
            Expanded(
              child: Text(
                'Offline mode — tap to retry connection',
                style: TextStyle(
                  color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                  fontSize: 11.sp,
                ),
              ),
            ),
            if (_isRetrying)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              )
            else
              Icon(Icons.refresh, color: Colors.orange, size: 5.w),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'email',
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              return null;
            },
          ),
          SizedBox(height: 2.h),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Padding(
                padding: EdgeInsets.all(3.w),
                child: CustomIconWidget(
                  iconName: 'lock',
                  color: colorScheme.primary,
                  size: 20,
                ),
              ),
              suffixIcon: GestureDetector(
                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                child: Padding(
                  padding: EdgeInsets.all(3.w),
                  child: CustomIconWidget(
                    iconName: _obscurePassword ? 'visibility_off' : 'visibility',
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
              ),
            ),
            obscureText: _obscurePassword,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GlowButton(
      glowColor: colorScheme.primary,
      glowIntensity: isDark ? 0.25 : 0.1,
      onTap: _isLoading ? null : _handleEmailSignIn,
      child: Container(
        width: double.infinity,
        height: 6.5.h,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: _isLoading && _activeMethod == _AuthMethod.email
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                  ),
                )
              : Text(
                  'Sign In',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(child: Divider(color: theme.dividerColor)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Text(
            'or continue with',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Divider(color: theme.dividerColor)),
      ],
    );
  }

  Widget _buildGoogleSignIn(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            height: 6.5.h,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : theme.dividerColor,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading ? null : _handleGoogleSignIn,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _isLoading && _activeMethod == _AuthMethod.google
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          )
                        : CustomIconWidget(
                            iconName: 'google_logo',
                            size: 2.5.h,
                          ),
                    SizedBox(width: 3.w),
                    Text(
                      'Sign in with Google',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestButton(ThemeData theme, ColorScheme colorScheme) {
    return TextButton(
      onPressed: _isLoading ? null : _handleGuestSignIn,
      child: _isLoading && _activeMethod == _AuthMethod.guest
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            )
          : Text(
              'Continue as Guest',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  Widget _buildOfflineButton(ThemeData theme, ColorScheme colorScheme) {
    return TextButton(
      onPressed: _isLoading ? null : _handleContinueOffline,
      child: Text(
        'Continue Without Account',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildRetrySection(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Firebase is not available. Please check your internet connection.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.error,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRetrying ? null : _handleRetryConnection,
              icon: _isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: Text(_isRetrying ? 'Connecting...' : 'Retry Connection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpLink(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: theme.textTheme.bodyMedium,
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(context, AppRoutes.signup);
            },
            child: Text(
              'Sign Up',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
