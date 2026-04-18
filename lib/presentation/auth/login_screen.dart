// lib/presentation/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../core/app_export.dart';
import '../../core/services/auth_service.dart';
import '../../main.dart' show firebaseInitError;

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
        backgroundColor: AppTheme.lightTheme.colorScheme.error,
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
        backgroundColor: AppTheme.lightTheme.colorScheme.primary,
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
    _setLoading(true, _AuthMethod.google);
    try {
      final user = await _authService.signInWithGoogle();
      if (user == null) {
        // User cancelled — not an error
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
    _setLoading(true, _AuthMethod.guest);
    try {
      await _authService.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } catch (e) {
      // If Firebase fails for guest mode, still let user proceed offline
      debugPrint('Guest sign-in failed, proceeding offline: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.profileSetup);
      }
    } finally {
      _setLoading(false);
    }
  }

  void _handleContinueOffline() {
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
                          children: [
                            SizedBox(height: 4.h),
                            // Firebase status banner
                            if (!_authService.isFirebaseReady)
                              GestureDetector(
                                onTap: _isRetrying ? null : _handleRetryConnection,
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(3.w),
                                  margin: EdgeInsets.only(bottom: 2.h),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.cloud_off,
                                          color: Colors.orange, size: 5.w),
                                      SizedBox(width: 2.w),
                                      Expanded(
                                        child: Text(
                                          'Offline mode — tap to retry connection',
                                          style: TextStyle(
                                            color: Colors.orange.shade800,
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
                              ),
                            // Logo
                            CustomIconWidget(
                              iconName: 'qr_code_scanner',
                              color:
                                  AppTheme.lightTheme.colorScheme.primary,
                              size: SizerUtil.deviceType ==
                                      DeviceType.tablet
                                  ? 10.w
                                  : 16.w,
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Food Insight Scanner',
                              textAlign: TextAlign.center,
                              style: AppTheme
                                  .lightTheme.textTheme.headlineSmall
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              'Sign in to continue',
                              style: AppTheme.lightTheme.textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                color: AppTheme.lightTheme.colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            // Email/Password Form
                            Form(
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
                                      if (value == null ||
                                          value.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _handleForgotPassword,
                                child: Text(
                                  'Forgot Password?',
                                  style: AppTheme
                                      .lightTheme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: AppTheme.lightTheme
                                        .colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 1.h),
                            // Sign In button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : _handleEmailSignIn,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(
                                      double.infinity, 6.5.h),
                                ),
                                child: _isLoading &&
                                        _activeMethod ==
                                            _AuthMethod.email
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                  Color>(
                                            AppTheme
                                                .lightTheme
                                                .colorScheme
                                                .onPrimary,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        'Sign In',
                                        style: AppTheme
                                            .lightTheme
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                          color: AppTheme
                                              .lightTheme
                                              .colorScheme
                                              .onPrimary,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 2.5.h),
                            // Divider
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: AppTheme
                                            .lightTheme
                                            .dividerColor)),
                                Padding(
                                  padding:
                                      EdgeInsets.symmetric(
                                          horizontal: 4.w),
                                  child: Text(
                                    'or continue with',
                                    style: AppTheme
                                        .lightTheme
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                      color: AppTheme
                                          .lightTheme
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: AppTheme
                                            .lightTheme
                                            .dividerColor)),
                              ],
                            ),
                            SizedBox(height: 2.5.h),
                            // Google Sign In
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _handleGoogleSignIn,
                                style:
                                    ElevatedButton.styleFrom(
                                  minimumSize: Size(
                                      double.infinity, 6.5.h),
                                  backgroundColor:
                                      Colors.white,
                                  foregroundColor:
                                      Colors.black87,
                                  elevation: 1,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(
                                            12),
                                    side: BorderSide(
                                      color: AppTheme
                                          .lightTheme
                                          .dividerColor,
                                    ),
                                  ),
                                ),
                                icon: _isLoading &&
                                        _activeMethod ==
                                            _AuthMethod.google
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<
                                                      Color>(
                                                  Colors
                                                      .black54),
                                        ),
                                      )
                                    : CustomIconWidget(
                                        iconName:
                                            'google_logo',
                                        size: 2.5.h,
                                      ),
                                label: const Text(
                                    'Sign in with Google'),
                              ),
                            ),
                            SizedBox(height: 2.h),
                            // Guest Mode
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleGuestSignIn,
                              child: _isLoading &&
                                      _activeMethod == _AuthMethod.guest
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<
                                                Color>(
                                          AppTheme
                                              .lightTheme
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Continue as Guest',
                                      style: AppTheme
                                          .lightTheme
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                        color: AppTheme
                                            .lightTheme
                                            .colorScheme
                                            .primary,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                            ),
                            SizedBox(height: 1.h),
                            // Continue Without Account
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : _handleContinueOffline,
                              child: Text(
                                'Continue Without Account',
                                style: AppTheme
                                    .lightTheme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color: AppTheme
                                      .lightTheme
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            // Retry Connection Button (prominent)
                            if (!_authService.isFirebaseReady) ...[
                              SizedBox(height: 1.h),
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color: AppTheme.lightTheme.colorScheme.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.lightTheme.colorScheme.error.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Firebase is not available. Please check your internet connection.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AppTheme.lightTheme.colorScheme.error,
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
                                          backgroundColor: AppTheme.lightTheme.colorScheme.error,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 1.2.h),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Sign Up link
                            Padding(
                              padding:
                                  EdgeInsets.symmetric(vertical: 3.h),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: AppTheme.lightTheme
                                        .textTheme.bodyMedium,
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        Navigator.pushNamed(
                                            context, AppRoutes.signup),
                                    child: Text(
                                      'Sign Up',
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